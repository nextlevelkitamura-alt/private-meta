#!/usr/bin/env bash
# inbox-patrol / tests / run-tests.sh — 抽出・処理済みスキップ・冪等性・二重起案防止・後始末の安全性に加え、
# 権限契約（役割別settings・skip-permissions廃止・t13）・1tick件数上限（t14）・起案完了通知（PC通知/
# Notion PATCH・t15〜t17）を検証（2026-07-09 デイリー運用刷新 子06で拡張）。
# 実HOME（~/Private等）には一切書き込まない。各テストは独立の fixture $HOME / ロックパスを patrol.sh に渡す。
# AI呼び出しはすべてstub（tests/内で組み立てる偽AI script）に差し替え、実際のclaude/codexは一切起動しない。
# 通知(osascript)・keychain(security)・Notion API(curl)もすべてstub＝実機の通知・実API・実トークンに触れない。
# 終了コードで全体の合否を表す（0=全PASS／非0=1件以上FAIL）。
#
# 後始末の安全性（差し戻し1回目・指摘1対応）:
#   テスト全体で使う専用ルート TEST_ROOT を mktemp -d で1個だけ作る。全ての一時ファイル・ディレクトリ・
#   ログはこの配下にしか作らない。後始末は safe_rm_rf() が TEST_ROOT 配下であることを確認してから
#   TEST_ROOT 1個だけを rm -rf する。TEST_ROOT が空文字列・"/"・"/tmp"・実HOMEなど危険な値になって
#   いたら何もせず警告する（最終防衛線）。
#   旧実装は個々のヘルパが作った一時ファイル/ディレクトリを workdirs 配列に集め、mktemp（ファイル）の
#   dirname を誤って削除対象に含めていた（TMPDIR直下にファイルを作ると dirname が $TMPDIR 自体＝
#   多くの環境で /tmp になり、cleanup が /tmp を rm -rf しかねない致命的バグだった）。この方式は全廃した。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$TESTS_DIR/.." && pwd)"
PATROL_SH="$LOOP_DIR/scripts/patrol.sh"
DATE="2026-07-02"

# --- 専用ルート（このテスト実行だけのもの）と、安全な後始末 ---
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/inbox-patrol-tests.XXXXXX")" || { echo "TEST_ROOT作成に失敗" >&2; exit 1; }
[ -d "$TEST_ROOT" ] || { echo "TEST_ROOT作成に失敗（ディレクトリが存在しない）: $TEST_ROOT" >&2; exit 1; }

# 削除対象が TEST_ROOT 自身、または TEST_ROOT/ 配下のパスである場合だけ rm -rf する。
# TEST_ROOT が危険な値（空・"/"・"/tmp"・実HOME）なら何もせず警告して戻る（/ や /tmp を絶対に消さない）。
safe_rm_rf() {
  local target="$1"
  case "${TEST_ROOT:-}" in
    ""|"/"|"/tmp"|"$HOME"|"$HOME/")
      echo "警告: TEST_ROOTが危険な値のため削除をスキップ: target=[$target] TEST_ROOT=[${TEST_ROOT:-}]" >&2
      return 1
      ;;
  esac
  case "$target" in
    "$TEST_ROOT"|"$TEST_ROOT"/*) ;;
    *)
      echo "警告: 削除対象がTEST_ROOT配下でないためスキップ: target=[$target] TEST_ROOT=[$TEST_ROOT]" >&2
      return 1
      ;;
  esac
  rm -rf -- "$target"
}

cleanup_all() {
  safe_rm_rf "$TEST_ROOT"
}
trap cleanup_all EXIT

# --- 通知・Notionの安全既定（全テスト共通・2026-07-09子06） ---
# patrol.sh は起案成功（→計画作成済み）時に notify-drafted.sh を呼ぶ。テストでは実osascript・
# 実keychain・実Notion API・実state（repo配下 inbox-patrol/state/）に一切触れないよう、既定で
# 無音stubとTEST_ROOT配下の空stateへ差し替える（通知系の個別テストは記録用stubで上書きする）。
DEFAULT_NOTIFY_STUB="$TEST_ROOT/default-notify-stub.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$DEFAULT_NOTIFY_STUB"
chmod +x "$DEFAULT_NOTIFY_STUB"
export INBOX_NOTIFY_CMD="$DEFAULT_NOTIFY_STUB"
export NOTION_PUSH_STATE_DIR="$TEST_ROOT/default-notion-state"  # 出所マップ無し＝Notion PATCH経路に入らない
export NOTION_SECURITY_CMD="false"                              # 万一入ってもkeychainに触れない
export NOTION_CURL_CMD="false"                                  # 万一入っても実APIに触れない

pass_count=0
fail_count=0
fail_names=()

# --- ヘルパ ---

# patrol.sh が参照する $HOME 配下（TEST_ROOT配下）に fixture のデイリーファイルを1本置く。
# $1 = デイリー本文（"## 依頼インボックス" 節を含むテキスト）
new_fake_home_with_daily() {
  local body="$1" d y m
  d="$(mktemp -d "$TEST_ROOT/home.XXXXXX")"
  y="${DATE%%-*}"
  m="${DATE#*-}"; m="${m%%-*}"
  local daily_dir="$d/Private/personal-os/my-brain/ゴール/デイリー/$y/$m"
  mkdir -p "$daily_dir"
  printf '%s' "$body" > "$daily_dir/$DATE.md"
  printf '%s' "$d"
}

daily_file_of() {
  local home="$1" y m
  y="${DATE%%-*}"
  m="${DATE#*-}"; m="${m%%-*}"
  printf '%s/Private/personal-os/my-brain/ゴール/デイリー/%s/%s/%s.md' "$home" "$y" "$m" "$DATE"
}

# AI呼び出しをstubするための偽AIスクリプトを作る（TEST_ROOT配下）。実際のclaude/codexは一切起動しない。
# patrol.sh は起案直前に「→処理中(...)」というクレーム印を対象行へ先行書込してから、
# クレーム済みの行文字列を第2引数としてこのstubへ渡す。
# $1 = 1なら「本物のinbox-triage Skillがクレーム印を最終マーカーへ置換する」動作までシミュレートする。
# $2 = 起動ごとのsleep秒（省略時0。並行実行テストでロック保持時間を伸ばすために使う）。
#
# SKILL.md の契約に忠実に「claimed_lineと完全一致する行のうち最初の1行だけ」を書き換える
# （awkのdoneフラグで1回目の一致だけを置換）。同一内容の兄弟行が他にあっても一切触れない。
# 差し戻し2回目以前は「一致する全行」を置換していたため、Skillが「対象行だけを書き換える」契約に
# 反する形で重複行の後始末が誤魔化されており、patrol.sh側のクレーム残留バグ（→処理中(...)が
# 永久に残る）を隠していた。この修正でその欠陥が露見しないstubから、契約通りの挙動を再現するstubへ
# 変える（patrol.sh側の finalize_duplicate_leftovers が本当に後始末できているかをt8/t10で検証する）。
new_stub_ai() {
  local mark_on_call="$1" sleep_secs="${2:-0}" d stub
  d="$(mktemp -d "$TEST_ROOT/stub.XXXXXX")"
  stub="$d/stub-ai.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
set -uo pipefail
daily_file="\$1"
claimed_line="\$2"
: "\${STUB_LOG:?STUB_LOG required}"
echo "\$claimed_line" >> "\$STUB_LOG"
if [ "$sleep_secs" != "0" ]; then
  sleep "$sleep_secs"
fi
if [ "$mark_on_call" -eq 1 ]; then
  orig_part="\${claimed_line%% →処理中(*}"
  final_line="\${orig_part} →計画作成済み(/fixture/plan.md)"
  tmp="\$(mktemp "\${daily_file}.stubmark.XXXXXX")"
  # LC_ALL=C 必須: macOS標準awkはUTF-8ロケール下で日本語文字列同士の"=="が誤って真になる実測バグがある
  # (patrol.sh側の同種コメント参照)。stubでも同じ理由でC(バイト比較)ロケールに固定する。
  # doneフラグで最初の一致行だけを置換し、以降の一致行（同一内容の兄弟行）は素通りする＝契約通り。
  LC_ALL=C awk -v from="\$claimed_line" -v to="\$final_line" '
    { if (\$0 == from && !done) { print to; done=1 } else print }
  ' "\$daily_file" > "\$tmp"
  mv "\$tmp" "\$daily_file"
fi
exit 0
STUB
  chmod +x "$stub"
  printf '%s' "$stub"
}

# 通知呼び出しを「title<TAB>body」で$1に記録するstubを作る（watch-keeperテストと同じ流儀）。
new_notify_stub() {
  local log="$1" d stub
  d="$(mktemp -d "$TEST_ROOT/notify.XXXXXX")"
  stub="$d/notify-stub.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
printf '%s\t%s\n' "\$1" "\$2" >> "$log"
exit 0
STUB
  chmod +x "$stub"
  printf '%s' "$stub"
}

# claude起動引数を1行1引数で$1へ記録するstub（INBOX_PATROL_CLAUDE_CMD差し替え用。
# 実claudeは一切起動しない。exit 0＝AI成功として扱われる）。
new_claude_recorder() {
  local log="$1" d stub
  d="$(mktemp -d "$TEST_ROOT/claude.XXXXXX")"
  stub="$d/claude-recorder.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
for a in "\$@"; do printf '%s\n' "\$a" >> "$log"; done
exit 0
STUB
  chmod +x "$stub"
  printf '%s' "$stub"
}

run_test() {
  local name="$1"
  echo "=== $name ==="
  if "$name"; then
    echo "PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $name"
    fail_count=$((fail_count + 1))
    fail_names+=("$name")
  fi
  echo
}

DAILY_MIXED='## 依頼インボックス
- 未処理の依頼A
- 処理済みの依頼B→計画作成済み(/fixture/plan-b.md)
-
- 未処理の依頼C

## 今やっていること
（子04で自動結線予定）
'

# サクッと判定済みの行を含むデイリー（差し戻し・指摘対応: t11で再抽出されないことを検証）
DAILY_WITH_SAKUTTO='## 依頼インボックス
- 未処理の依頼A
- サクッと判定済みの依頼D→サクッと判定(1〜2ファイル・戻し容易・人間ゲート無し)
- 未処理の依頼C

## 今やっていること
'

# →完了/→着手 注記済みの行を含むデイリー（采配9玉B: 事故ts=1783057581=→計画作成済みを持たず→完了だけの
# 行を再claimしていた事故の回帰。→着手行も同様にskipされること）。
DAILY_WITH_DONE='## 依頼インボックス
- 未処理の依頼A
- 確認できている？ →完了(2026-07-03 14:43 全体管理者Aが検知しチャットで応答)
- 着手済みの依頼E →着手(2026-07-03 担当:中間指揮官1)
- 未処理の依頼C

## 今やっていること
'

# ============================================================
# t1: 未処理行だけを抽出する（空bullet・処理済み行は除外）
# ============================================================
t1_dry_run_extracts_only_unprocessed() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_MIXED")"

  out="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -qF -- "- 未処理の依頼A" || { echo "未処理Aが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "- 未処理の依頼C" || { echo "未処理Cが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "処理済みの依頼B" && { echo "処理済み行が抽出されてしまった: $out"; return 1; }

  local n
  n="$(printf '%s\n' "$out" | grep -c '^- ')"
  [ "$n" -eq 2 ] || { echo "抽出件数が2件でない (${n}件): $out"; return 1; }

  return 0
)

# ============================================================
# t2: --dry-run は決定的（2回連続実行で出力が同一。副作用なし）
# ============================================================
t2_dry_run_is_deterministic_and_idempotent() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_MIXED")"
  daily="$(daily_file_of "$home")"
  before="$(cat "$daily")"

  out1="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"
  out2="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"
  [ "$out1" = "$out2" ] || { echo "2回の--dry-run出力が一致しない: [$out1] != [$out2]"; return 1; }

  after="$(cat "$daily")"
  [ "$before" = "$after" ] || { echo "--dry-runがデイリーファイルを書き換えた"; return 1; }

  return 0
)

# ============================================================
# t3: 当日デイリーが存在しない → クラッシュせずexit 0でスキップ
# ============================================================
t3_missing_daily_file_skips_cleanly() (
  set -euo pipefail
  d="$(mktemp -d "$TEST_ROOT/nodaily.XXXXXX")"

  out="$(HOME="$d" INBOX_PATROL_LOCK_DIR="$d/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  echo "$out" | grep -q "スキップ" || { echo "スキップメッセージが出ていない: $out"; return 1; }

  return 0
)

# ============================================================
# t4: 「## 依頼インボックス」節が無いデイリー → 未処理0件（クラッシュしない）
# ============================================================
t4_no_inbox_section_yields_zero_lines() (
  set -euo pipefail
  home="$(new_fake_home_with_daily $'## 今日のTODO\n- [ ]\n')"

  out="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  [ -z "$out" ] || { echo "節が無いのに出力がある: $out"; return 1; }

  return 0
)

# ============================================================
# t5: 処理済みスキップ — stub AIは未処理行にのみ起動され、処理済み行では起動されない
# ============================================================
t5_processed_line_is_skipped_from_ai_invocation() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_MIXED")"
  stub="$(new_stub_ai 0)"
  log="$(mktemp "$home/log.XXXXXX")"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  grep -qF -- "未処理の依頼A" "$log" || { echo "未処理Aでstubが呼ばれていない: $(cat "$log")"; return 1; }
  grep -qF -- "未処理の依頼C" "$log" || { echo "未処理Cでstubが呼ばれていない: $(cat "$log")"; return 1; }
  grep -qF -- "処理済みの依頼B" "$log" && { echo "処理済み行でstubが呼ばれてしまった: $(cat "$log")"; return 1; }

  local n
  n=$(wc -l < "$log" | tr -d ' ')
  [ "$n" -eq 2 ] || { echo "stub呼び出し件数が2件でない (${n}件): $(cat "$log")"; return 1; }

  return 0
)

# ============================================================
# t6: 冪等性 — マーカーを付けるstubで1回目に処理された行は、2回目のpatrol.shで再度AI起動されない
# ============================================================
t6_marked_line_is_not_reinvoked_on_next_run() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_MIXED")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"
  lockdir="$home/lock"

  HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$lockdir" bash "$PATROL_SH" "$DATE" >/dev/null 2>&1
  local n1
  n1=$(wc -l < "$log" | tr -d ' ')
  [ "$n1" -eq 2 ] || { echo "1回目のstub呼び出しが2件でない (${n1}件): $(cat "$log")"; return 1; }

  HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$lockdir" bash "$PATROL_SH" "$DATE" >/dev/null 2>&1
  local n2
  n2=$(wc -l < "$log" | tr -d ' ')
  [ "$n2" -eq 2 ] || { echo "2回目実行後にstubが再度呼ばれた（冪等でない）。累計 ${n2} 件: $(cat "$log")"; return 1; }

  # DAILY_MIXED は元々1件（依頼B）処理済み。stubが依頼A・Cを新たに処理済みにするので合計3件になる。
  local daily marked
  daily="$(daily_file_of "$home")"
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 3 ] || { echo "処理済み印が3件になっていない (${marked}件)"; return 1; }

  return 0
)

# ============================================================
# t7: 並行2プロセス同時実行 — mkdirロックにより二重起案が起きない（差し戻し1回目・指摘2対応）
# ============================================================
t7_concurrent_runs_do_not_double_draft() (
  set -euo pipefail
  local daily_single
  daily_single='## 依頼インボックス
- 並行テストの依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_single")"
  # sleep=1.5秒: 1つ目のプロセスがロックを保持している間に2つ目が確実に競合するよう間を空ける。
  stub="$(new_stub_ai 1 1.5)"
  log="$(mktemp "$home/log.XXXXXX")"
  lockdir="$home/lock"
  out1="$home/out1.log"
  out2="$home/out2.log"

  ( HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$lockdir" bash "$PATROL_SH" "$DATE" >"$out1" 2>&1 ) &
  pid1=$!
  sleep 0.3
  ( HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$lockdir" bash "$PATROL_SH" "$DATE" >"$out2" 2>&1 ) &
  pid2=$!

  wait "$pid1" || true
  wait "$pid2" || true

  # 2プロセスのうち、ちょうど1つだけがロック競合で即終了しているはず（もう1つは正常に処理する）。
  local lockfail_count=0
  grep -q "他のinbox-patrolが実行中のため終了" "$out1" && lockfail_count=$((lockfail_count + 1))
  grep -q "他のinbox-patrolが実行中のため終了" "$out2" && lockfail_count=$((lockfail_count + 1))
  [ "$lockfail_count" -eq 1 ] || {
    echo "ロック競合で終了したプロセスがちょうど1つでない (${lockfail_count}件)"
    echo "out1: $(cat "$out1")"; echo "out2: $(cat "$out2")"
    return 1
  }

  # AI(stub)は合計1回だけ呼ばれているはず(=二重起案が起きていない)
  local n
  n=$(wc -l < "$log" | tr -d ' ')
  [ "$n" -eq 1 ] || { echo "stub呼び出しが合計1回でない (${n}回・二重起案の恐れ): $(cat "$log")"; return 1; }

  local daily marked
  daily="$(daily_file_of "$home")"
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 1 ] || { echo "処理済み印が1件になっていない (${marked}件)"; return 1; }

  return 0
)

# ============================================================
# t8: 同一内容の重複行 — 内容一致キーで1つの冪等ユニットとして扱われ、二重起案が起きない
# t8: 同一内容の重複行 — 内容一致キーで1つの冪等ユニットとして扱われ、二重起案が起きない
# 差し戻し2回目対応: stubはSKILL.mdの契約に忠実な「最初の一致行のみ書き換え」に修正済み
#（new_stub_ai参照）。そのためこのテストは単に「AIが1回しか呼ばれない」だけでなく、
# 「Skillが書き換えなかった側の兄弟行がpatrol.shのfinalize_duplicate_leftoversによって
# →重複(...) へ正しく後始末され、→処理中(...) が一切残らない」ことまで検証する。
# ============================================================
t8_duplicate_content_lines_do_not_double_draft() (
  set -euo pipefail
  local daily_dup
  daily_dup='## 依頼インボックス
- 重複した依頼
- 重複した依頼
- 単独の依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_dup")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  # 「重複した依頼」1回＋「単独の依頼」1回＝合計2回だけ呼ばれるはず（重複2行目は二重起動しない）。
  local n
  n=$(wc -l < "$log" | tr -d ' ')
  [ "$n" -eq 2 ] || { echo "stub呼び出しが合計2回でない (${n}回・重複行の統合に失敗): $(cat "$log")"; return 1; }

  local dup_calls
  dup_calls=$(grep -cF -- "重複した依頼" "$log")
  [ "$dup_calls" -eq 1 ] || { echo "重複した依頼の呼び出しが1回でない (${dup_calls}回): $(cat "$log")"; return 1; }

  # stubは最初の一致行だけを最終マーカーへ書き換える（契約通り）ので、
  # 最終マーカーは「重複した依頼」1本＋「単独の依頼」1本＝合計2件。
  # 残るもう1本の「重複した依頼」はpatrol.shが「→重複(...)」へ後始末するはずで1件。
  # 「→処理中(...)」の残留はゼロでなければならない（差し戻し2回目の核心）。
  local daily marked duplicated stuck
  daily="$(daily_file_of "$home")"
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 2 ] || { echo "最終マーカーが2件になっていない (${marked}件): $(cat "$daily")"; return 1; }

  duplicated=$(grep -c '→重複(' "$daily")
  [ "$duplicated" -eq 1 ] || { echo "重複終了マーカーが1件になっていない (${duplicated}件): $(cat "$daily")"; return 1; }

  stuck=$(grep -c '→処理中(' "$daily")
  [ "$stuck" -eq 0 ] || { echo "クレーム印(→処理中)が残留している (${stuck}件・後始末漏れ): $(cat "$daily")"; return 1; }

  return 0
)

# ============================================================
# t9: 後始末の安全性 — safe_rm_rf は TEST_ROOT 配下しか削除しない（差し戻し1回目・指摘1対応）
# ============================================================
t9_cleanup_never_deletes_outside_own_root() (
  set -euo pipefail
  local sandbox fake_root decoy
  sandbox="$(mktemp -d "$TEST_ROOT/t9-sandbox.XXXXXX")"
  fake_root="$sandbox/fake-root"
  decoy="$sandbox/decoy"
  mkdir -p "$fake_root/inner" "$decoy"
  touch "$decoy/must-survive.txt"
  touch "$fake_root/inner/must-be-removed.txt"

  # このサブシェル内だけ TEST_ROOT を fake_root に差し替えて safe_rm_rf を直接検証する。
  # t9_...() は "(" "..." ")" のサブシェルなので、ここでの TEST_ROOT 再代入は
  # 外側（本物のテストランナー・実際の後始末）には一切影響しない。
  TEST_ROOT="$fake_root"

  # 1) fake_root配下でない対象(decoy)は拒否され、実体は残る
  if safe_rm_rf "$decoy" 2>/dev/null; then
    echo "fake_root外のdecoyが削除できてしまった（拒否すべき）"; return 1
  fi
  [ -f "$decoy/must-survive.txt" ] || { echo "decoyの中身が消えている（誤爆）"; return 1; }

  # 2) TEST_ROOTが空文字列のときは、fake_root自身を対象にしても何もしない
  TEST_ROOT=""
  if safe_rm_rf "$fake_root" 2>/dev/null; then
    echo "TEST_ROOTが空文字列なのに削除が実行されてしまった"; return 1
  fi
  [ -d "$fake_root/inner" ] || { echo "危険なTEST_ROOT状態でfake_rootの中身が消えている"; return 1; }

  # 3) TEST_ROOTが"/"のときも同様に何もしない
  TEST_ROOT="/"
  if safe_rm_rf "$fake_root" 2>/dev/null; then
    echo "TEST_ROOTが'/'なのに削除が実行されてしまった"; return 1
  fi
  [ -d "$fake_root/inner" ] || { echo "TEST_ROOT='/'状態でfake_rootの中身が消えている"; return 1; }

  # 4) 正規のTEST_ROOT配下（自分自身）は正しく削除される
  TEST_ROOT="$fake_root"
  safe_rm_rf "$fake_root" || { echo "正規の削除対象（fake_root自身）が削除できなかった"; return 1; }
  [ ! -d "$fake_root" ] || { echo "fake_rootが削除されていない"; return 1; }

  return 0
)

# ============================================================
# t10: 重複行の後始末 — N件(3件)の重複でも「→処理中(...)」が一切残留しないことを明示的に検証
# （差し戻し2回目・指摘対応。t8とは別に、後始末の完全性そのものに焦点を絞ったテスト）
# ============================================================
t10_duplicate_leftovers_never_stay_claimed() (
  set -euo pipefail
  local daily_triple
  daily_triple='## 依頼インボックス
- 三重複の依頼
- 三重複の依頼
- 三重複の依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_triple")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  # 3件とも同一内容なので、AI(stub)は1回だけ呼ばれるはず。
  local n
  n=$(wc -l < "$log" | tr -d ' ')
  [ "$n" -eq 1 ] || { echo "stub呼び出しが1回でない (${n}回): $(cat "$log")"; return 1; }

  local daily marked duplicated stuck total_lines
  daily="$(daily_file_of "$home")"

  # 核心の検証: 「→処理中(...)」（クレーム印）は実行後に1件も残っていてはならない。
  stuck=$(grep -c '→処理中(' "$daily")
  [ "$stuck" -eq 0 ] || { echo "クレーム印が残留している (${stuck}件・処理中のまま宙に浮いている): $(cat "$daily")"; return 1; }

  # stubが書き換えたのは1件（最終マーカー）、残り2件はpatrol.shが「→重複(...)」へ後始末したはず。
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 1 ] || { echo "最終マーカーが1件になっていない (${marked}件): $(cat "$daily")"; return 1; }

  duplicated=$(grep -c '→重複(' "$daily")
  [ "$duplicated" -eq 2 ] || { echo "重複終了マーカーが2件になっていない (${duplicated}件): $(cat "$daily")"; return 1; }

  # 依頼インボックス節の元の3行はすべて残っている（削除されていない）ことも確認する。
  total_lines=$(grep -c '三重複の依頼' "$daily")
  [ "$total_lines" -eq 3 ] || { echo "元の3行が維持されていない (${total_lines}行): $(cat "$daily")"; return 1; }

  return 0
)

# ============================================================
# t11: サクッと判定済みの行 — 「→サクッと判定(...)」付きの行は未処理として再抽出されない
# （差し戻し・指摘対応: patrol.shの非対象マーカー集合に→サクッと判定(を追加した効果を検証）
# ============================================================
t11_sakutto_marked_line_is_not_reextracted() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_WITH_SAKUTTO")"

  out="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -qF -- "- 未処理の依頼A" || { echo "未処理Aが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "- 未処理の依頼C" || { echo "未処理Cが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "サクッと判定済みの依頼D" && { echo "サクッと判定済みの行が再抽出されてしまった: $out"; return 1; }

  local n
  n="$(printf '%s\n' "$out" | grep -c '^- ')"
  [ "$n" -eq 2 ] || { echo "抽出件数が2件でない (${n}件): $out"; return 1; }

  # AI起動経路でもスキップされることを確認（--dry-runだけでなく実運用の非対象判定も同じロジックを通る）
  stub="$(new_stub_ai 0)"
  log="$(mktemp "$home/log.XXXXXX")"
  out2="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock2" bash "$PATROL_SH" "$DATE" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "exit非0 ($rc2): $out2"; return 1; }
  grep -qF -- "サクッと判定済みの依頼D" "$log" && { echo "サクッと判定済み行でstubが呼ばれてしまった: $(cat "$log")"; return 1; }
  local n2
  n2=$(wc -l < "$log" | tr -d ' ')
  [ "$n2" -eq 2 ] || { echo "stub呼び出し件数が2件でない (${n2}件): $(cat "$log")"; return 1; }

  return 0
)

# ============================================================
# t12: →完了/→着手 注記済みの行は再抽出されない（采配9玉B・事故ts=1783057581の回帰）。
# 特に →計画作成済み( を持たず →完了 だけが付いた行（例「確認できている？ →完了(...)」）を未処理と誤判定して
# 再claimしていた事故の再発防止。AI起動経路（実運用）でも同じ非対象判定を通ることを確認する。
# ============================================================
t12_done_and_started_lines_are_not_reextracted() (
  set -euo pipefail
  home="$(new_fake_home_with_daily "$DAILY_WITH_DONE")"

  out="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" --dry-run 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -qF -- "- 未処理の依頼A" || { echo "未処理Aが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "- 未処理の依頼C" || { echo "未処理Cが抽出されていない: $out"; return 1; }
  echo "$out" | grep -qF -- "確認できている？" && { echo "→完了行が再抽出された(再claim事故の再発): $out"; return 1; }
  echo "$out" | grep -qF -- "着手済みの依頼E" && { echo "→着手行が再抽出された: $out"; return 1; }

  local n
  n="$(printf '%s\n' "$out" | grep -c '^- ')"
  [ "$n" -eq 2 ] || { echo "抽出件数が2件でない (${n}件): $out"; return 1; }

  # AI起動経路でも→完了/→着手行でstubが呼ばれないこと（実運用の非対象判定も同ロジック）。
  local stub log out2 rc2 n2
  stub="$(new_stub_ai 0)"
  log="$(mktemp "$home/log.XXXXXX")"
  out2="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock2" bash "$PATROL_SH" "$DATE" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "exit非0 ($rc2): $out2"; return 1; }
  grep -qF -- "確認できている？" "$log" && { echo "→完了行でstubが呼ばれた(再claim事故): $(cat "$log")"; return 1; }
  grep -qF -- "着手済みの依頼E" "$log" && { echo "→着手行でstubが呼ばれた: $(cat "$log")"; return 1; }
  n2=$(wc -l < "$log" | tr -d ' ')
  [ "$n2" -eq 2 ] || { echo "stub呼び出し件数が2件でない (${n2}件): $(cat "$log")"; return 1; }

  return 0
)

# ============================================================
# t13: 権限契約（2026-07-09子06） — headless AIは skip-permissions で起動されず、役割別許可設定
#      （--settings＋--setting-sources ""＋--permission-mode dontAsk＋--max-budget-usd）で起動される。
#      INBOX_PATROL_CLAUDE_CMD の記録stubで実際の起動引数を検証する（実claudeは起動しない）。
#      あわせて settings JSON の中身（deny に push/削除系・defaultMode=dontAsk）も機械チェックする。
# ============================================================
t13_claude_invocation_uses_role_settings() (
  set -euo pipefail
  local daily_single
  daily_single='## 依頼インボックス
- 権限契約テストの依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_single")"
  args_log="$(mktemp "$home/claude-args.XXXXXX")"
  recorder="$(new_claude_recorder "$args_log")"

  # TRIAGE_AI_CMD を敢えて使わず、実起動系統（invoke_ai の claude 分岐）を recorder で通す。
  out="$(HOME="$home" TRIAGE_AI_CMD= INBOX_PATROL_CLAUDE_CMD="$recorder" \
    INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  grep -qx -- "-p" "$args_log" || { echo "-p が渡されていない: $(cat "$args_log")"; return 1; }
  grep -qx -- "--settings" "$args_log" || { echo "--settings が渡されていない: $(cat "$args_log")"; return 1; }
  grep -q "settings/inbox-triage-permissions.json$" "$args_log" \
    || { echo "役割別settingsのパスが渡されていない: $(cat "$args_log")"; return 1; }
  grep -qx -- "--permission-mode" "$args_log" || { echo "--permission-mode が無い"; return 1; }
  grep -qx -- "dontAsk" "$args_log" || { echo "dontAsk が無い"; return 1; }
  grep -qx -- "--max-budget-usd" "$args_log" || { echo "--max-budget-usd が無い"; return 1; }
  grep -q -- "dangerously-skip-permissions" "$args_log" \
    && { echo "skip-permissions が残っている: $(cat "$args_log")"; return 1; }
  # --setting-sources の直後に空文字列が渡っている（ユーザー/プロジェクト設定の遮断）
  LC_ALL=C awk 'prev == "--setting-sources" && $0 == "" { found = 1 } { prev = $0 } END { exit found ? 0 : 1 }' "$args_log" \
    || { echo "--setting-sources \"\" が渡されていない: $(cat "$args_log")"; return 1; }

  # patrol.sh 本文にも skip-permissions が残っていない（静的契約）
  grep -q -- "dangerously-skip-permissions" "$PATROL_SH" \
    && { echo "patrol.sh に skip-permissions の文字列が残っている"; return 1; }

  # settings JSON の中身: defaultMode=dontAsk・denyに push/rm/launchctl/security・allowに書込の限定
  python3 - "$LOOP_DIR/settings/inbox-triage-permissions.json" <<'PY' || return 1
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))["permissions"]
assert p["defaultMode"] == "dontAsk", "defaultModeがdontAskでない"
deny = set(p["deny"])
for must in ["Bash(git push:*)", "Bash(git commit:*)", "Bash(rm:*)", "Bash(launchctl:*)", "Bash(security:*)"]:
    assert must in deny, "denyに必須項目が無い: " + must
assert any("plans/active" in d for d in deny), "plans/active への書込denyが無い"
allow = p["allow"]
for a in allow:
    assert "dangerously" not in a and "bypass" not in a.lower(), "allowに危険項目: " + a
writes = [a for a in allow if a.startswith(("Write(", "Edit("))]
assert writes, "書込allowが1つも無い"
for w in writes:
    assert ("plans/planning" in w) or ("デイリー" in w), "書込allowが planning/デイリー以外に開いている: " + w
PY

  return 0
)

# ============================================================
# t14: 1tickの処理件数上限（INBOX_PATROL_MAX_PER_TICK） — 上限で頭打ちし、残りは次tickへ持ち越す
#      （取りこぼしなし: 2tick目で残りが処理される）
# ============================================================
t14_max_per_tick_limits_ai_invocations() (
  set -euo pipefail
  local daily_four
  daily_four='## 依頼インボックス
- 上限テストの依頼1
- 上限テストの依頼2
- 上限テストの依頼3
- 上限テストの依頼4

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_four")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_MAX_PER_TICK=2 \
    INBOX_PATROL_LOCK_DIR="$home/lock" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  local n1
  n1=$(wc -l < "$log" | tr -d ' ')
  [ "$n1" -eq 2 ] || { echo "1tick目のAI起動が2件でない (${n1}件): $(cat "$log")"; return 1; }
  echo "$out" | grep -q "1tick上限" || { echo "上限到達のログが出ていない: $out"; return 1; }

  # 残り2件は未処理のまま（--dry-runで再抽出できる＝取りこぼしなし）
  local remain
  remain="$(HOME="$home" INBOX_PATROL_LOCK_DIR="$home/lock2" bash "$PATROL_SH" "$DATE" --dry-run 2>&1 | grep -c '^- ')"
  [ "$remain" -eq 2 ] || { echo "持ち越しが2件でない (${remain}件)"; return 1; }

  # 2tick目で残りが処理される
  HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_MAX_PER_TICK=2 \
    INBOX_PATROL_LOCK_DIR="$home/lock3" bash "$PATROL_SH" "$DATE" >/dev/null 2>&1
  local n2
  n2=$(wc -l < "$log" | tr -d ' ')
  [ "$n2" -eq 4 ] || { echo "2tick累計のAI起動が4件でない (${n2}件): $(cat "$log")"; return 1; }

  local daily marked
  daily="$(daily_file_of "$home")"
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 4 ] || { echo "処理済み印が4件になっていない (${marked}件)"; return 1; }

  return 0
)

# ============================================================
# t15: 起案完了通知 — PC通知が1回だけ呼ばれ、出所マップ一致のNotion行へ 状態=起案済み＋計画パスが
#      PATCHされる（DBスキーマの冪等PATCHは初回のみ）。トークンはどの出力・ログにも現れない。
# ============================================================
t15_notify_patches_notion_and_notifies_once() (
  set -euo pipefail
  local daily_single
  daily_single='## 依頼インボックス
- 依頼テキストA

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_single")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"

  # 出所マップ・DB idキャッシュを持つ専用state（Notion経由でpull済みの行を模す）
  state_dir="$home/notion-state"
  mkdir -p "$state_dir"
  printf 'row-1\t依頼テキストA\n' > "$state_dir/notion-inbox-origin-ids"
  printf 'db-1' > "$state_dir/notion-inbox-database-id"

  notify_log="$(mktemp "$home/notify.XXXXXX")"
  notify_stub="$(new_notify_stub "$notify_log")"
  curl_log="$(mktemp "$home/curl.XXXXXX")"
  security_ok="$home/security-ok.sh"
  printf '#!/usr/bin/env bash\nprintf %%s fake-token-t15\n' > "$security_ok"
  chmod +x "$security_ok"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" \
    NOTION_PUSH_STATE_DIR="$state_dir" INBOX_NOTIFY_CMD="$notify_stub" \
    NOTION_SECURITY_CMD="$security_ok" NOTION_CURL_CMD="python3 $TESTS_DIR/fixtures/curl-record-stub.py" \
    NOTION_CURL_STUB_LOG="$curl_log" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  # PC通知はちょうど1回・本文に計画パスと依頼テキストが入る
  local n
  n=$(wc -l < "$notify_log" | tr -d ' ')
  [ "$n" -eq 1 ] || { echo "PC通知が1回でない (${n}回): $(cat "$notify_log")"; return 1; }
  grep -qF -- "/fixture/plan.md" "$notify_log" || { echo "通知本文に計画パスが無い: $(cat "$notify_log")"; return 1; }
  grep -qF -- "依頼テキストA" "$notify_log" || { echo "通知本文に依頼テキストが無い: $(cat "$notify_log")"; return 1; }

  # Notion: DBスキーマPATCH（起案済み選択肢＋計画パス）1回 ＋ 行PATCH（起案済み＋計画パス）1回
  local schema_calls row_calls
  schema_calls=$(grep -c "/databases/db-1" "$curl_log")
  [ "$schema_calls" -eq 1 ] || { echo "スキーマPATCHが1回でない (${schema_calls}回): $(cat "$curl_log")"; return 1; }
  row_calls=$(grep -c "/pages/row-1" "$curl_log")
  [ "$row_calls" -eq 1 ] || { echo "行PATCHが1回でない (${row_calls}回): $(cat "$curl_log")"; return 1; }
  grep "/pages/row-1" "$curl_log" | grep -qF "起案済み" || { echo "行PATCHに状態=起案済みが無い"; return 1; }
  grep "/pages/row-1" "$curl_log" | grep -qF "/fixture/plan.md" || { echo "行PATCHに計画パスが無い"; return 1; }
  grep "/pages/row-1" "$curl_log" | grep -qF "計画パス" || { echo "行PATCHに計画パスプロパティが無い"; return 1; }
  [ -f "$state_dir/notion-inbox-schema-planpath" ] || { echo "スキーママーカーが書かれていない"; return 1; }

  # secret規律: トークン値がpatrol出力・通知ログ・curlログのどこにも現れない
  { echo "$out"; cat "$notify_log" "$curl_log"; } | grep -qF "fake-token-t15" \
    && { echo "トークン値が出力/ログに漏れている"; return 1; }

  # スキーマPATCHは初回のみ（マーカー済みなら2回目のnotifyで /databases を再PATCHしない）
  daily="$(daily_file_of "$home")"
  HOME="$home" NOTION_PUSH_STATE_DIR="$state_dir" INBOX_NOTIFY_CMD="$notify_stub" \
    NOTION_SECURITY_CMD="$security_ok" NOTION_CURL_CMD="python3 $TESTS_DIR/fixtures/curl-record-stub.py" \
    NOTION_CURL_STUB_LOG="$curl_log" bash "$LOOP_DIR/scripts/notify-drafted.sh" "$daily" "- 依頼テキストA" >/dev/null 2>&1
  schema_calls=$(grep -c "/databases/db-1" "$curl_log")
  [ "$schema_calls" -eq 1 ] || { echo "スキーマPATCHが冪等でない (${schema_calls}回)"; return 1; }

  return 0
)

# ============================================================
# t16: 出所マップに無い行（デイリー直書き・kickoff起票） — PC通知のみでNotionには一切触れない
# ============================================================
t16_notify_without_origin_is_local_only() (
  set -euo pipefail
  local daily_single
  daily_single='## 依頼インボックス
- 直書きの依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_single")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"
  state_dir="$home/notion-state-empty"
  mkdir -p "$state_dir"
  notify_log="$(mktemp "$home/notify.XXXXXX")"
  notify_stub="$(new_notify_stub "$notify_log")"
  curl_log="$(mktemp "$home/curl.XXXXXX")"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" \
    NOTION_PUSH_STATE_DIR="$state_dir" INBOX_NOTIFY_CMD="$notify_stub" \
    NOTION_CURL_CMD="python3 $TESTS_DIR/fixtures/curl-record-stub.py" \
    NOTION_CURL_STUB_LOG="$curl_log" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  local n
  n=$(wc -l < "$notify_log" | tr -d ' ')
  [ "$n" -eq 1 ] || { echo "PC通知が1回でない (${n}回): $(cat "$notify_log")"; return 1; }
  [ ! -s "$curl_log" ] || { echo "出所マップ無しなのにNotion APIが呼ばれた: $(cat "$curl_log")"; return 1; }

  return 0
)

# ============================================================
# t17: 通知失敗はベストエフォート — PC通知コマンドが失敗してもpatrolはexit 0で、起案結果
#      （→計画作成済み）はそのまま残る
# ============================================================
t17_notify_failure_does_not_break_patrol() (
  set -euo pipefail
  local daily_single
  daily_single='## 依頼インボックス
- 通知失敗テストの依頼

## 今やっていること
'
  home="$(new_fake_home_with_daily "$daily_single")"
  stub="$(new_stub_ai 1)"
  log="$(mktemp "$home/log.XXXXXX")"
  failing_notify="$home/notify-fail.sh"
  printf '#!/usr/bin/env bash\nexit 1\n' > "$failing_notify"
  chmod +x "$failing_notify"

  out="$(HOME="$home" STUB_LOG="$log" TRIAGE_AI_CMD="$stub" INBOX_PATROL_LOCK_DIR="$home/lock" \
    INBOX_NOTIFY_CMD="$failing_notify" bash "$PATROL_SH" "$DATE" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "通知失敗でpatrolが失敗した ($rc): $out"; return 1; }
  echo "$out" | grep -q "PC通知コマンドが失敗" || { echo "通知失敗の警告が出ていない: $out"; return 1; }

  local daily marked
  daily="$(daily_file_of "$home")"
  marked=$(grep -c '→計画作成済み(' "$daily")
  [ "$marked" -eq 1 ] || { echo "起案結果の最終マーカーが残っていない (${marked}件)"; return 1; }

  return 0
)

# ============================================================
run_test t1_dry_run_extracts_only_unprocessed
run_test t2_dry_run_is_deterministic_and_idempotent
run_test t3_missing_daily_file_skips_cleanly
run_test t4_no_inbox_section_yields_zero_lines
run_test t5_processed_line_is_skipped_from_ai_invocation
run_test t6_marked_line_is_not_reinvoked_on_next_run
run_test t7_concurrent_runs_do_not_double_draft
run_test t8_duplicate_content_lines_do_not_double_draft
run_test t9_cleanup_never_deletes_outside_own_root
run_test t10_duplicate_leftovers_never_stay_claimed
run_test t11_sakutto_marked_line_is_not_reextracted
run_test t12_done_and_started_lines_are_not_reextracted
run_test t13_claude_invocation_uses_role_settings
run_test t14_max_per_tick_limits_ai_invocations
run_test t15_notify_patches_notion_and_notifies_once
run_test t16_notify_without_origin_is_local_only
run_test t17_notify_failure_does_not_break_patrol

echo "=== 結果: PASS=$pass_count FAIL=$fail_count ==="
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
