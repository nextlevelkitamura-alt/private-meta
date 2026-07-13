#!/usr/bin/env bash
# plan-ops / new-plan.sh・new-child.sh のテスト。
# 生成物は必ずmktemp配下へ出力する。実HOME・実デイリー・~/Private実ファイルには一切書き込まない。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
# shellcheck source=_test_lib.sh
source "$HERE/_test_lib.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/scaffold-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

has_heading() { # <file> <見出しテキスト(#抜き)>
  grep -qF -- "## $2" "$1"
}

# ============================================================
# (a) new-plan.sh（単発plan.md・既定）: 目的/現状/方針/完了条件（レビュー項目）を満たす
# ============================================================
plan_out="$("$SCRIPTS/new-plan.sh" --out "$WORKDIR/a-plan/plan.md" --class skill --kind 新規作成)"
assert_eq "(a) 出力先パスをstdoutへ返す" "$plan_out" "$WORKDIR/a-plan/plan.md"
assert_true_file() { [ -f "$1" ] && { pass=$((pass+1)); printf '[PASS] %s\n' "$2"; } || { fail=$((fail+1)); printf '[FAIL] %s\n' "$2"; }; }
assert_true_file "$WORKDIR/a-plan/plan.md" "(a) 生成ファイルが実在する"
for h in 目的 現状 方針 "完了条件（レビュー項目）"; do
  if has_heading "$WORKDIR/a-plan/plan.md" "$h"; then
    pass=$((pass+1)); printf '[PASS] %s\n' "(a) 見出し「${h}」を含む"
  else
    fail=$((fail+1)); printf '[FAIL] %s\n' "(a) 見出し「${h}」を含む"
  fi
done
assert_contains "(a) 分類が埋まる" "$(cat "$WORKDIR/a-plan/plan.md")" "分類: skill"
assert_contains "(a) 種別が埋まる" "$(cat "$WORKDIR/a-plan/plan.md")" "種別: 新規作成"
assert_contains "(a) 並列欄を持つ" "$(cat "$WORKDIR/a-plan/plan.md")" "並列: <可/不可>"
assert_contains "(a) レビュー欄を持つ" "$(cat "$WORKDIR/a-plan/plan.md")" "レビュー: <都度/一括>"
assert_not_contains "(a) 形態行を持たない(単発)" "$(cat "$WORKDIR/a-plan/plan.md")" "形態: program"

# ============================================================
# (b) new-plan.sh --program: 目的/全体像/子計画マップ/完了条件（レビュー項目）/関連を満たす
# ============================================================
"$SCRIPTS/new-plan.sh" --out "$WORKDIR/b-program/program.md" --program --class 横断 --kind 統合整理 >/dev/null
for h in 目的 全体像 子計画マップ "完了条件（レビュー項目）" 関連; do
  if has_heading "$WORKDIR/b-program/program.md" "$h"; then
    pass=$((pass+1)); printf '[PASS] %s\n' "(b) 見出し「${h}」を含む"
  else
    fail=$((fail+1)); printf '[FAIL] %s\n' "(b) 見出し「${h}」を含む"
  fi
done
assert_contains "(b) 形態: programを持つ" "$(cat "$WORKDIR/b-program/program.md")" "形態: program"
assert_contains "(b) 子マップの並列欄を持つ" "$(cat "$WORKDIR/b-program/program.md")" "並列: <可/不可>"
assert_contains "(b) 子マップのレビュー欄を持つ" "$(cat "$WORKDIR/b-program/program.md")" "レビュー: <都度/一括>"

# ============================================================
# (c) new-child.sh: 目的/現状/方針/完了条件（レビュー項目）＋親計画backlinkが正しく解決する
# ============================================================
"$SCRIPTS/new-child.sh" --out "$WORKDIR/b-program/plans/11-新子.md" --program "$WORKDIR/b-program/program.md" --class skill --kind 既存改善 >/dev/null
for h in 目的 現状 方針 "完了条件（レビュー項目）"; do
  if has_heading "$WORKDIR/b-program/plans/11-新子.md" "$h"; then
    pass=$((pass+1)); printf '[PASS] %s\n' "(c) 見出し「${h}」を含む"
  else
    fail=$((fail+1)); printf '[FAIL] %s\n' "(c) 見出し「${h}」を含む"
  fi
done
assert_contains "(c) 分類/種別が個別に正しく埋まる（順序非依存）" "$(cat "$WORKDIR/b-program/plans/11-新子.md")" "分類: skill ／ 種別: 既存改善"
assert_contains "(c) 並列欄を持つ" "$(cat "$WORKDIR/b-program/plans/11-新子.md")" "並列: <可/不可>"
assert_contains "(c) レビュー欄を持つ" "$(cat "$WORKDIR/b-program/plans/11-新子.md")" "レビュー: <都度/一括>"
backlink_target="$(cd "$WORKDIR/b-program/plans" && python3 -c "
import re
with open('11-新子.md', encoding='utf-8') as f:
    first = f.readline()
m = re.search(r'親計画:\s*([^\s／]+)', first)
print(m.group(1))
")"
resolved="$(cd "$WORKDIR/b-program/plans" && python3 -c "import os,sys; print(os.path.isfile(os.path.normpath(os.path.join(os.getcwd(), sys.argv[1]))))" "$backlink_target")"
assert_eq "(c) 親計画backlinkが実ファイルへ解決する" "$resolved" "True"

# ============================================================
# (d) --class/--kindが逆順・片方のみでも取り違えない（分類/種別ラベルアンカー検証）
# ============================================================
"$SCRIPTS/new-child.sh" --out "$WORKDIR/b-program/plans/12-片方だけ.md" --program "$WORKDIR/b-program/program.md" --kind 新規作成 >/dev/null
c12="$(cat "$WORKDIR/b-program/plans/12-片方だけ.md")"
assert_contains "(d) --kindのみ指定でも種別に正しく入る" "$c12" "種別: 新規作成"
assert_contains "(d) --classのみ未指定なら分類はプレースホルダのまま" "$c12" "分類: <…>"

# ============================================================
# (e) 既存ファイルは上書きしない（安全ガード）
# ============================================================
"$SCRIPTS/new-plan.sh" --out "$WORKDIR/a-plan/plan.md" >/dev/null 2>&1
assert_eq "(e) 既存ファイルへのnew-planはexit非0" "$?" "1"
"$SCRIPTS/new-child.sh" --out "$WORKDIR/b-program/plans/11-新子.md" --program "$WORKDIR/b-program/program.md" >/dev/null 2>&1
assert_eq "(e) 既存ファイルへのnew-childはexit非0" "$?" "1"

report
