#!/usr/bin/env bash
# inbox-patrol / patrol.sh — 当日デイリーの「依頼インボックス」から未処理行を決定的に抽出し、
# 1行ごとにheadless AI（inbox-triage Skill）へ渡す。抽出は非AI・決定的・読み取り専用。
# --dry-run はAIを一切起動せず抽出結果のみ標準出力する（動作確認・テスト専用）。
#
# 二重起案防止（差し戻し1回目・指摘2件対応）:
#   1. 実行全体を mkdir ロックで排他する（bash3.2でも原子的。取得失敗は即終了＝他インスタンスに譲る）。
#   2. 各行は「起案（AI起動）直前」に再度 extract_unprocessed で未処理かを確認してからクレームする
#      （マーカー先行書込→AI起動→成功時はAI自身が最終マーカーへ置換／失敗時はpatrol.shがクレームを剥がす）。
#   3. 同一内容の重複行は「内容一致」を鍵にした冪等ユニットとして扱う。クレームは内容一致の全行へ
#      同時に書き込むため、同一内容の2行目はその時点で「もう未処理ではない」と判定されAIを再起動しない。
#      （行内容ハッシュ相当の識別子＝クレームマーカーにcksum値を埋め込み診断用に残す。実際の一致判定は
#      内容そのものの完全一致で行う＝ハッシュ値と等価だが衝突・依存を増やさない）。
#
# 重複行の終了状態の後始末（差し戻し2回目・指摘対応）:
#   inbox-triage Skillの契約は「渡された対象行だけを書き換え、他行には触れない」。クレームは内容一致の
#   全行へ同時に付くが、Skillは自分に渡された1行しか書き換えないため、同一内容の兄弟行はSkill完了後も
#   クレーム印（→処理中(...)）のまま取り残される。extract_unprocessedはクレーム印付きの行を未処理として
#   拾わないため、これを放置すると「→処理中(...)」が永久に残留しスキップされ続けるバグになる。
#   これを防ぐため、AI起動成功後にpatrol.sh自身が後処理として、自分が付けたクレーム文字列とまだ完全一致
#   する残存行（＝Skillが書き換えなかった側の重複行）を「→重複(同一依頼として処理済み)」という終了状態
#   サフィックスへ書き換える（finalize_duplicate_leftovers）。重複が無い（一致行が最初から1件だけ）場合は
#   Skillの書き換えで既に0件になっているため、この後処理は何もしない（冪等・no-op）。
#
# 権限（2026-07-09 デイリー運用刷新 子06で強化）:
#   headless AIは skip-permissions で起動しない。役割別の許可設定 settings/inbox-triage-permissions.json
#   （読み=広く／書き=plans/planning配下とデイリーの処理印行のみ／push・削除・git破壊deny）を
#   --settings で渡し、--setting-sources "" でユーザー/プロジェクト設定の混入を遮断、
#   --permission-mode dontAsk で「allowlist外は黙って拒否」に固定する。-pモードは不正なsettingsを
#   黙って無視する仕様のため、起動前にJSONとして読めることを検証し、読めなければAIを起動しない
#   （クレームはロールバックされ次tickで再挑戦）。1tickの処理件数は INBOX_PATROL_MAX_PER_TICK
#   （既定3）で頭打ちにする（暴走・費用の上限。残りは次tickが拾う）。
#
# 通知（子06追加）: 起案成功（→計画作成済み）の行ごとに notify-drafted.sh を1回呼ぶ
# （PC通知＋Notion行の状態=起案済みPATCH。ベストエフォート・失敗してもpatrol自体は失敗にしない）。
#
# usage: patrol.sh [YYYY-MM-DD] [--dry-run]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"

# 役割別許可設定（正本はこのloop配下。差し替えは INBOX_PATROL_SETTINGS）
SETTINGS_FILE="${INBOX_PATROL_SETTINGS:-$LOOP_DIR/settings/inbox-triage-permissions.json}"
# 1tickあたりのheadless AI起動数の上限（費用・暴走の上限。残りは次tickへ持ち越す）
MAX_PER_TICK="${INBOX_PATROL_MAX_PER_TICK:-3}"

FINAL_MARKER='→計画作成済み('
CLAIM_MARKER='→処理中('
DUPLICATE_MARKER='→重複('
SAKUTTO_MARKER='→サクッと判定('
# 進捗/終端注記（2026-07-03 采配9玉B）: →着手/→完了 が付いた行は処理済みとしてskipする。
# 事故(ts=1783057581): →計画作成済み( を持たず →完了 だけが付いた行（例「確認できている？ →完了(...)」）を
# 未処理と誤判定して再claimしていた。→着手/→完了 は →計画作成済み( の後ろへ追記される想定だが、計画を伴わず
# 直接完了注記される行があるため、非対象マーカーとして独立に持つ（bare形で→着手(担当X)/→完了(...)双方に一致）。
STARTED_MARKER='→着手'
COMPLETE_MARKER='→完了'

dry_run=0
date_str=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -*) echo "不明なオプション: $arg" >&2; exit 2 ;;
    *) date_str="$arg" ;;
  esac
done
[ -n "$date_str" ] || date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"

# --- 実行全体の排他ロック（mkdirは原子的。既に存在すれば即失敗＝他インスタンスが実行中） ---
# 既定は/tmp配下（loop-runbook.md §5準拠）。テスト時は INBOX_PATROL_LOCK_DIR で fixture 専用パスに差し替える。
LOCK_DIR="${INBOX_PATROL_LOCK_DIR:-${TMPDIR:-/tmp}/com.kitamura.inbox-patrol.lock}"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "[inbox-patrol] 他のinbox-patrolが実行中のため終了（lock: ${LOCK_DIR}）" >&2
  exit 1
fi
trap 'rm -rf -- "$LOCK_DIR"' EXIT
printf '%s\n' "pid=$$ started=$(date '+%Y-%m-%d %H:%M:%S')" > "$LOCK_DIR/owner" 2>/dev/null || true
# ロックが何らかの理由で取得したまま残った場合（プロセス異常終了等）は、
# 人間が `rm -rf "$LOCK_DIR"` で手動解除する（自動stale回収は持たない＝MVP。loop.md参照）。

daily_file="$(daily_file_for "$date_str")"

if [ ! -f "$daily_file" ]; then
  echo "[inbox-patrol] 当日デイリーが無いためスキップ: $daily_file" >&2
  exit 0
fi

# --- 依頼インボックス節から未処理行を決定的に抽出 ---
# 節: "## 依頼インボックス" 〜 次の "## " 見出し直前（無ければEOF）。
# 対象: 行頭 "- " で始まりbullet本文が非空、かつ最終・クレーム・重複終了のいずれのマーカーも含まない行。
#
# 全awk呼び出しは LC_ALL=C を明示する: macOS標準awk（one true awk）はUTF-8ロケール下で
# `==` の文字列完全一致が日本語の異なる文字列同士を誤って等しいと判定することを実測で確認した
# （例: "重複した依頼" == "単独の依頼" が真になる）。C(バイト比較)ロケールに固定することで
# 意図通りの厳密一致に戻す。行の抽出・見出し検出・空白trimは元々ASCIIパターン＋バイト単位一致で
# 完結するため、C ロケールに切り替えても抽出結果は変わらない（実測で確認済み）。
extract_unprocessed() {
  LC_ALL=C awk -v final="$FINAL_MARKER" -v claim="$CLAIM_MARKER" -v dup="$DUPLICATE_MARKER" -v sakutto="$SAKUTTO_MARKER" -v started="$STARTED_MARKER" -v complete="$COMPLETE_MARKER" '
    /^## 依頼インボックス[ \t]*$/ { insec=1; next }
    insec && /^## / { insec=0 }
    insec && /^- / {
      body=$0; sub(/^- /, "", body)
      gsub(/[ \t]+$/, "", body)
      if (body == "") next
      if (index($0, final) > 0) next
      if (index($0, claim) > 0) next
      if (index($0, dup) > 0) next
      if (index($0, sakutto) > 0) next
      if (index($0, started) > 0) next
      if (index($0, complete) > 0) next
      print $0
    }
  ' "$daily_file"
}

# 指定文字列が現時点（ファイルを再読込）でなお未処理行かどうか。
currently_unprocessed() {
  local target="$1" current found
  current="$(extract_unprocessed)"
  found=1
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    if [ "$l" = "$target" ]; then found=0; break; fi
  done <<< "$current"
  return "$found"
}

# 内容一致キー（診断用。ハッシュ相当。実際の同一判定は完全一致で行う）。
line_hash() {
  printf '%s' "$1" | cksum | awk '{print $1}'
}

# $2 と完全一致する全行の末尾に $3 を追記して書き戻す（同一内容の重複行はまとめて1回で処理する）。
# LC_ALL=C の理由は extract_unprocessed 冒頭のコメント参照（awkの`==`誤判定を避けるため必須）。
append_suffix_to_matching_lines() {
  local file="$1" target="$2" suffix="$3" tmp
  tmp="$(mktemp "${file}.XXXXXX")" 2>/dev/null || return 1
  LC_ALL=C awk -v target="$target" -v suffix="$suffix" '
    { if ($0 == target) print $0 suffix; else print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# $2 と完全一致する全行を $3 に置き換えて書き戻す（クレームのロールバック用）。
# LC_ALL=C の理由は extract_unprocessed 冒頭のコメント参照（awkの`==`誤判定を避けるため必須）。
replace_matching_lines() {
  local file="$1" from="$2" to="$3" tmp
  tmp="$(mktemp "${file}.XXXXXX")" 2>/dev/null || return 1
  LC_ALL=C awk -v from="$from" -v to="$to" '
    { if ($0 == from) print to; else print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# inbox-triage Skillは「渡された対象行だけを書き換える」契約であり、他行には触れない。
# クレーム（$2=claimed_line）は内容一致の全行へ同時に付くため、同一内容の兄弟行が複数あった場合、
# Skillが書き換えるのはそのうちの1行だけで、残りはクレーム印（→処理中(...)）のまま取り残される。
# これを「→重複(同一依頼として処理済み)」という終了状態サフィックスへ書き換え、
# クレーム印が永久に残留（＝二度と抽出対象にならず宙に浮く）しないことを保証する。
# 対象は「$2(claimed_line)と完全一致する行」に限定するため、Skillが書き換えなかった行以外には触れない。
# 一致行が既に0件（＝重複が無かった、またはSkillが全て書き換えた）なら何もしない冪等な後処理。
finalize_duplicate_leftovers() {
  local file="$1" claimed_line="$2" orig_part duplicate_line tmp
  orig_part="${claimed_line%% ${CLAIM_MARKER}*}"
  duplicate_line="${orig_part} ${DUPLICATE_MARKER}同一依頼として処理済み)"
  tmp="$(mktemp "${file}.XXXXXX")" 2>/dev/null || return 1
  LC_ALL=C awk -v from="$claimed_line" -v to="$duplicate_line" '
    { if ($0 == from) print to; else print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

raw="$(extract_unprocessed)"
unprocessed=()
while IFS= read -r line; do
  [ -z "$line" ] && continue
  unprocessed+=("$line")
done <<< "$raw"

if [ "$dry_run" -eq 1 ]; then
  if [ "${#unprocessed[@]}" -gt 0 ]; then
    printf '%s\n' "${unprocessed[@]}"
  fi
  exit 0
fi

if [ "${#unprocessed[@]}" -eq 0 ]; then
  echo "[inbox-patrol] 未処理行なし: $daily_file"
  exit 0
fi

SKILL_PATH="$(cd "$LOOP_DIR/../../../skills/inbox-triage" && pwd)/SKILL.md"

# 起案直前の再確認＋クレーム書込。
# 戻り値: 0=クレーム成功（標準出力にクレーム済みの行全文を返す）／1=クレーム書込失敗／2=既に処理済み・他へ委譲済み（スキップ対象）
claim_line() {
  local orig="$1" suffix claimed
  if ! currently_unprocessed "$orig"; then
    return 2
  fi
  suffix=" ${CLAIM_MARKER}hash=$(line_hash "$orig") pid=$$ ts=$(date '+%s'))"
  if ! append_suffix_to_matching_lines "$daily_file" "$orig" "$suffix"; then
    return 1
  fi
  claimed="${orig}${suffix}"
  printf '%s' "$claimed"
  return 0
}

build_prompt() {
  local claimed_line="$1"
  cat <<EOF
あなたは inbox-triage Skill の headless 実行者。手順の正本を読み、書かれた手順どおりに実行する。

1. 手順の正本: $SKILL_PATH
2. 対象デイリー: $daily_file
3. 処理対象行（この行だけを処理対象とし、他の行・他のマーカーには一切触れない）:
$claimed_line

この行は patrol.sh が先に「${CLAIM_MARKER}...)」というクレーム印を付けたあとの状態です。
経路判定（対象repo→起案先は対象repoの plans/planning/）→規模判定（plan-triage経由でフル/ライト/サクッと）を
行い、結果に応じてこの行の末尾にある「${CLAIM_MARKER}...)」の部分を次のいずれかに置き換えてください
（追記ではなく置換。手順の正本 §3〜§4 を参照）。

- 規模判定が**フル/ライト**: 対象repoの plans/planning/ に plan.md を起案してから「→計画作成済み(<plan.mdの絶対パス>)」に置き換える。
- 規模判定が**サクッと**: plan.mdは起案せず「${SAKUTTO_MARKER}<1行理由>)」に置き換える（実行はしない・指揮官/人間が拾う）。

いずれの場合も実装・実行・git commit・plans/active/ への配置は一切しない（自動は planning ドラフトまで・active化は人間承認）。
EOF
}

invoke_ai() {
  local claimed_line="$1" prompt
  prompt="$(build_prompt "$claimed_line")"
  if [ -n "${TRIAGE_AI_CMD:-}" ]; then
    "$TRIAGE_AI_CMD" "$daily_file" "$claimed_line" "$prompt"
    return $?
  fi
  # -pモードは不正なsettingsファイルを黙って無視する（=権限が意図せず既定へ広がる）ため、
  # JSONとして読めることを確認できない限りAIを起動しない（呼び出し元がクレームを剥がして次tickへ）。
  if ! python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' "$SETTINGS_FILE" 2>/dev/null; then
    echo "[inbox-patrol] 役割別許可設定が読めない/不正のためAI起動を中止: $SETTINGS_FILE" >&2
    return 1
  fi
  # INBOX_PATROL_CLAUDE_CMD はテスト用の差し替え口（起動引数の契約を検証するため）。本番は claude。
  ${INBOX_PATROL_CLAUDE_CMD:-claude} -p "$prompt" \
    --settings "$SETTINGS_FILE" \
    --setting-sources "" \
    --permission-mode dontAsk \
    --output-format text \
    --max-budget-usd "${INBOX_PATROL_MAX_BUDGET_USD:-5}"
}

status=0
invoked=0
for orig_line in "${unprocessed[@]}"; do
  # 1tickの処理件数上限（AI起動回数で数える。残りは未処理のまま次tickが拾う＝取りこぼしなし）
  if [ "$invoked" -ge "$MAX_PER_TICK" ]; then
    echo "[inbox-patrol] 1tick上限（${MAX_PER_TICK}件）に達したため残りは次tickへ持ち越す"
    break
  fi

  claimed_line="$(claim_line "$orig_line")"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "[inbox-patrol] スキップ（既にクレーム/処理済み。同一内容の重複行の可能性）: $orig_line"
    continue
  elif [ "$rc" -ne 0 ]; then
    echo "[inbox-patrol] クレーム書込に失敗（継続）: $orig_line" >&2
    status=1
    continue
  fi

  echo "[inbox-patrol] 起動: $orig_line"
  invoked=$((invoked + 1))
  if invoke_ai "$claimed_line"; then
    # Skillは対象行だけを書き換える契約のため、同一内容の兄弟行が他にあれば
    # クレーム印のまま取り残っている。終了状態へ書き換えて残留ゼロを保証する（冪等・no-op許容）。
    finalize_duplicate_leftovers "$daily_file" "$claimed_line" \
      || echo "[inbox-patrol] 重複行の終了状態書込に失敗（手動確認が必要）: $orig_line" >&2
    # 起案完了通知（PC通知＋Notion行PATCH）。ベストエフォート＝失敗してもpatrol自体は失敗にしない。
    # →計画作成済み( が付いた場合だけ notify 側が実際に通知する（サクッと判定は無通知で即return）。
    "$SCRIPT_DIR/notify-drafted.sh" "$daily_file" "$orig_line" \
      || echo "[inbox-patrol] 起案通知に失敗（起案自体は成功・手動確認可）: $orig_line" >&2
  else
    echo "[inbox-patrol] 失敗（継続・クレーム解除してリトライ可能に戻す）: $orig_line" >&2
    replace_matching_lines "$daily_file" "$claimed_line" "$orig_line" \
      || echo "[inbox-patrol] クレーム解除にも失敗（手動確認が必要）: $orig_line" >&2
    status=1
  fi
done

exit "$status"
