#!/usr/bin/env bash
# exec-audit / tests / run-tests.sh — 出力先スイッチ（既定=inbox／readycard=温存）のfixtureベーステスト。
# 実HOME（~/Private等）には一切書き込まない。各テストは独立の mktemp -d を $HOME として audit.sh に渡す。
# 終了コードで全体の合否を表す（0=全PASS／非0=1件以上FAIL）。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXEC_AUDIT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
AUDIT_SH="$EXEC_AUDIT_DIR/scripts/audit.sh"
# audit.sh は日付引数を取らず常に実行時点のJST当日を見るため、fixtureも同じ基準で日付を決める
# （ハードコード日付だと実行日によってdaily_file_forの参照先とfixtureがズレて壊れる）。
DATE="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"

pass_count=0
fail_count=0
fail_names=()
workdirs=()

cleanup_all() {
  local d
  for d in "${workdirs[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
trap cleanup_all EXIT

# --- ヘルパ ---

# audit.sh が参照する $HOME 配下の最小構成を fixture として用意する。
# $PREF にマッチするが正本plist(srcs側)が存在せず、かつ plutil -lint が失敗する「壊れplist」を
# 1つ置くことで、実機のlaunchctl状態に依存せずドリフト非空（＝出力先分岐への到達）を保証する。
new_fake_home() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/exec-audit-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/Library/LaunchAgents"
  mkdir -p "$d/Private/personal-os/AIエージェント基盤/loops-registry"
  mkdir -p "$d/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs"/{ready,running,review,reviewing,done}
  mkdir -p "$d/Private/projects/active/仕事/scripts"
  printf 'not a valid plist' > "$d/Library/LaunchAgents/com.kitamura.faketest.plist"
  printf '%s' "$d"
}

daily_dir_of() {
  local home="$1" y m
  y="${DATE%%-*}"
  m="${DATE#*-}"; m="${m%%-*}"
  printf '%s/Private/personal-os/my-brain/ゴール/デイリー/%s/%s' "$home" "$y" "$m"
}

daily_file_of() {
  printf '%s/%s.md' "$(daily_dir_of "$1")" "$DATE"
}

# $1 = home, $2 = デイリー本文。ディレクトリを掘って書き込む。
write_daily() {
  local home="$1" body="$2" dir
  dir="$(daily_dir_of "$home")"
  mkdir -p "$dir"
  printf '%s' "$body" > "$(daily_file_of "$home")"
}

DAILY_TEMPLATE_BODY='## 逆算
<!-- auto:goal:begin — renderer: 年間計画の的を自動転記。人間はマーカー外に書く -->
仮の逆算内容
<!-- auto:goal:end -->
<!-- auto:align:begin — renderer: 当日の自動記録の件数集計 -->
仮のalign内容
<!-- auto:align:end -->

## 今日のTODO
- [ ]

## 依頼インボックス
- 人間の既存依頼

## 今やっていること
<!-- auto:board-now:begin — renderer: 自動描画。人間はマーカー外に書く -->
仮のboard-now内容
<!-- auto:board-now:end -->
'

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

# ============================================================
# t1: readycard — 既存カードが一部フォルダ（review）のみにある → 再生成しない
# 2026-07-02実発生バグの回帰テスト（audit.sh冪等バグ修正は前半aで完了済み・ここは非退行の確認）。
# 明示的に EXEC_AUDIT_OUTPUT=readycard を指定する（既定がinboxに変わったため）。
# ============================================================
t1_existing_card_in_one_folder_blocks_regeneration() (
  set -euo pipefail
  home="$(new_fake_home)"
  base="$home/Private/personal-os/AIエージェント基盤"
  ready="$base/loops-registry/ai-jobs/ready"
  review="$base/loops-registry/ai-jobs/review"

  echo "担当: orca" > "$review/exec-audit-20260701.md"

  out="$(HOME="$home" EXEC_AUDIT_OUTPUT=readycard bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -q "既存カード処理待ちのため新規投下せず" || { echo "既存カード検出メッセージが出ていない: $out"; return 1; }

  local ready_cards
  shopt -s nullglob
  ready_cards=( "$ready"/exec-audit-*.md )
  shopt -u nullglob
  [ "${#ready_cards[@]}" -eq 0 ] || { echo "既存カードがreviewにあるのにreadyへ新規カードが生成された: ${ready_cards[*]}"; return 1; }

  return 0
)

# ============================================================
# t2: readycard — どのフォルダにも既存カードが無い → 新規カードを生成する
# ============================================================
t2_no_existing_card_generates_new_one() (
  set -euo pipefail
  home="$(new_fake_home)"
  base="$home/Private/personal-os/AIエージェント基盤"
  ready="$base/loops-registry/ai-jobs/ready"

  out="$(HOME="$home" EXEC_AUDIT_OUTPUT=readycard bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -q "カード投下" || { echo "新規カード投下メッセージが出ていない: $out"; return 1; }

  local ready_cards
  shopt -s nullglob
  ready_cards=( "$ready"/exec-audit-*.md )
  shopt -u nullglob
  [ "${#ready_cards[@]}" -eq 1 ] || { echo "新規カードが1件生成されていない: ${ready_cards[*]:-なし}"; return 1; }

  return 0
)

# ============================================================
# t3: inbox（既定）— 当日デイリー＋節あり → 依頼インボックス節末尾に1行追記される
# ============================================================
t3_inbox_default_appends_line_to_inbox_section() (
  set -euo pipefail
  home="$(new_fake_home)"
  write_daily "$home" "$DAILY_TEMPLATE_BODY"
  daily="$(daily_file_of "$home")"

  out="$(HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  echo "$out" | grep -q "インボックスへ追記" || { echo "追記メッセージが出ていない: $out"; return 1; }

  grep -qF -- "[exec-audit $DATE] 壊れplist 1件" "$daily" || { echo "壊れplistの行が追記されていない: $(cat "$daily")"; return 1; }
  grep -qF -- "人間の既存依頼" "$daily" || { echo "既存の人間行が消えている: $(cat "$daily")"; return 1; }

  # readyカードは作られていない（inboxモードのため）
  local ready="$home/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs/ready"
  local ready_cards
  shopt -s nullglob
  ready_cards=( "$ready"/exec-audit-*.md )
  shopt -u nullglob
  [ "${#ready_cards[@]}" -eq 0 ] || { echo "inboxモードなのにreadyカードが生成された: ${ready_cards[*]}"; return 1; }

  return 0
)

# ============================================================
# t4: inbox — 重複スキップ（同一日に2回実行しても同じ行が二重に増えない）
# ============================================================
t4_inbox_duplicate_content_is_skipped_on_rerun() (
  set -euo pipefail
  home="$(new_fake_home)"
  write_daily "$home" "$DAILY_TEMPLATE_BODY"
  daily="$(daily_file_of "$home")"

  HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" >/dev/null 2>&1
  local n1
  n1=$(grep -c -- "\[exec-audit $DATE\] 壊れplist" "$daily")
  [ "$n1" -eq 1 ] || { echo "1回目実行後の行数が1件でない (${n1}件): $(cat "$daily")"; return 1; }

  out2="$(HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "2回目exit非0 ($rc): $out2"; return 1; }
  echo "$out2" | grep -q "追記スキップ" || { echo "重複スキップメッセージが出ていない: $out2"; return 1; }

  local n2
  n2=$(grep -c -- "\[exec-audit $DATE\] 壊れplist" "$daily")
  [ "$n2" -eq 1 ] || { echo "2回目実行後も行数が1件でない (${n2}件・重複追記の恐れ): $(cat "$daily")"; return 1; }

  return 0
)

# ============================================================
# t5: inbox — 「## 依頼インボックス」節が無いデイリー → 追記せず非0 exit・警告
# ============================================================
t5_inbox_missing_section_exits_nonzero_without_writing() (
  set -euo pipefail
  home="$(new_fake_home)"
  write_daily "$home" $'## 今日のTODO\n- [ ]\n'
  daily="$(daily_file_of "$home")"
  before="$(cat "$daily")"

  out="$(HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "exitが0（非0を期待）: $out"; return 1; }
  echo "$out" | grep -q "節が無いため追記できません" || { echo "節なし警告が出ていない: $out"; return 1; }

  after="$(cat "$daily")"
  [ "$before" = "$after" ] || { echo "節が無いのにデイリーが書き換えられた"; return 1; }

  return 0
)

# ============================================================
# t6: inbox — 当日デイリー自体が無い → 追記せず非0 exit・警告
# ============================================================
t6_inbox_missing_daily_file_exits_nonzero() (
  set -euo pipefail
  home="$(new_fake_home)"

  out="$(HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" 2>&1)"; rc=$?
  [ "$rc" -ne 0 ] || { echo "exitが0（非0を期待）: $out"; return 1; }
  echo "$out" | grep -q "当日デイリーが無いため" || { echo "デイリーなし警告が出ていない: $out"; return 1; }

  local daily
  daily="$(daily_file_of "$home")"
  [ ! -e "$daily" ] || { echo "存在しないはずのデイリーが作られた: $daily"; return 1; }

  return 0
)

# ============================================================
# t7: inbox — auto:* マーカー区画には一切触れない（依頼インボックス節のみ変更）
# ============================================================
t7_inbox_never_touches_auto_marker_sections() (
  set -euo pipefail
  home="$(new_fake_home)"
  write_daily "$home" "$DAILY_TEMPLATE_BODY"
  daily="$(daily_file_of "$home")"

  HOME="$home" TZ=Asia/Tokyo bash "$AUDIT_SH" >/dev/null 2>&1

  grep -qF -- "仮の逆算内容" "$daily" || { echo "auto:goal区画の内容が消えている: $(cat "$daily")"; return 1; }
  grep -qF -- "仮のalign内容" "$daily" || { echo "auto:align区画の内容が消えている: $(cat "$daily")"; return 1; }
  grep -qF -- "仮のboard-now内容" "$daily" || { echo "auto:board-now区画の内容が消えている: $(cat "$daily")"; return 1; }

  # 追記行が「## 依頼インボックス」節の中（「## 今やっていること」より前）にあることを確認する。
  local inbox_line_no board_line_no
  inbox_line_no=$(grep -n -- "\[exec-audit $DATE\] 壊れplist" "$daily" | head -1 | cut -d: -f1)
  board_line_no=$(grep -n "^## 今やっていること" "$daily" | head -1 | cut -d: -f1)
  [ -n "$inbox_line_no" ] || { echo "追記行が見つからない: $(cat "$daily")"; return 1; }
  [ "$inbox_line_no" -lt "$board_line_no" ] || { echo "追記行が依頼インボックス節の外にある（line=$inbox_line_no, board=$board_line_no）: $(cat "$daily")"; return 1; }

  return 0
)

# ============================================================
run_test t1_existing_card_in_one_folder_blocks_regeneration
run_test t2_no_existing_card_generates_new_one
run_test t3_inbox_default_appends_line_to_inbox_section
run_test t4_inbox_duplicate_content_is_skipped_on_rerun
run_test t5_inbox_missing_section_exits_nonzero_without_writing
run_test t6_inbox_missing_daily_file_exits_nonzero
run_test t7_inbox_never_touches_auto_marker_sections

echo "=== 結果: PASS=$pass_count FAIL=$fail_count ==="
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
