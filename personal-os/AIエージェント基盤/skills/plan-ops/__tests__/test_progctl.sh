#!/usr/bin/env bash
# plan-ops / progctl.sh のテスト。
# fixture(合成データ)をmktemp配下のスクラッチgitリポジトリへコピーしてから操作する。
# 実HOME・実デイリー・~/Private実ファイルには一切書き込まない。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
FIXTURE="$HERE/fixtures/progctl/program.md"
# shellcheck source=_test_lib.sh
source "$HERE/_test_lib.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/progctl-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

git -C "$WORKDIR" init -q
cp "$FIXTURE" "$WORKDIR/program.md"
git -C "$WORKDIR" add program.md
git -C "$WORKDIR" -c user.email=test@example.com -c user.name=test commit -q -m "fixture初期化"

PROGRAM="$WORKDIR/program.md"
orig_content="$(cat "$PROGRAM")"

# ============================================================
# (a) --state/--next/--ref を新規挿入で書き換え（dry-run→--commit）
# ============================================================
dry_out="$("$SCRIPTS/progctl.sh" set "$PROGRAM" 02 --state "完了（マージabc1234）" --next "実装レビューへ" --ref "planops-tools-v1@abc1234")"
assert_contains "(a) dry-runはunified diffを含む" "$dry_out" "- [ ] 02  ふたつめの子"
assert_eq "(a) dry-runは書き込みしない" "$(cat "$PROGRAM")" "$orig_content"

commit_before="$(git -C "$WORKDIR" rev-list --count HEAD)"
commit_out="$("$SCRIPTS/progctl.sh" set "$PROGRAM" 02 --state "完了（マージabc1234）" --next "実装レビューへ" --ref "planops-tools-v1@abc1234" --commit)"
assert_contains "(a) --commitでcommit済みメッセージ" "$commit_out" "commit済み"
commit_after="$(git -C "$WORKDIR" rev-list --count HEAD)"
assert_eq "(a) --commitで新規コミットが1件増える" "$commit_after" "$((commit_before + 1))"

new_content="$(cat "$PROGRAM")"
assert_contains "(a) 見出し行のstateが書き換わった" "$new_content" "- [x] 02  ふたつめの子 … 完了（マージabc1234）"
assert_contains "(a) 次:行が新設された" "$new_content" "    次: 実装レビューへ"
assert_contains "(a) 参照:行が新設された" "$new_content" "    参照: planops-tools-v1@abc1234"

# ============================================================
# (b) マップ外・他ブロック（01/03・目的/完了条件/関連セクション）はバイト不変
# ============================================================
extract_block() { # <content> <NN行の始まり文字列>
  printf '%s\n' "$1" | awk -v s="$2" 'BEGIN{on=0} { if ($0==s) on=1; else if (on && $0 ~ /^(- \[[ x]\] )?[0-9][0-9][ \t]/) exit; if (on) print }'
}
block01_before="$(extract_block "$orig_content" "- [x] 01  最初の子 … 完了")"
block01_after="$(extract_block "$new_content" "- [x] 01  最初の子 … 完了")"
assert_eq "(b) ブロック01はバイト不変" "$block01_after" "$block01_before"

block03_before="$(extract_block "$orig_content" "- [ ] 03  みっつめの子 … 保留")"
block03_after="$(extract_block "$new_content" "- [ ] 03  みっつめの子 … 保留")"
assert_eq "(b) ブロック03はバイト不変" "$block03_after" "$block03_before"

assert_contains "(b) 02ブロックの人間自由記述行(要点:)は不変" "$new_content" "要点: これは人間が書いた自由記述行"

outside_before="$(printf '%s\n' "$orig_content" | awk '/^## 完了条件/{f=1} /^## 関連/{f=1} f')"
outside_after="$(printf '%s\n' "$new_content" | awk '/^## 完了条件/{f=1} /^## 関連/{f=1} f')"
assert_eq "(b) 完了条件/関連セクションはバイト不変" "$outside_after" "$outside_before"

# ============================================================
# (c) 冪等性: 同じ引数でのset 2回目は差分ゼロ・空コミットを作らない
# ============================================================
commit_before2="$(git -C "$WORKDIR" rev-list --count HEAD)"
idempotent_out="$("$SCRIPTS/progctl.sh" set "$PROGRAM" 02 --state "完了（マージabc1234）" --next "実装レビューへ" --ref "planops-tools-v1@abc1234" --commit)"
commit_after2="$(git -C "$WORKDIR" rev-list --count HEAD)"
assert_contains "(c) 2回目は「変更なし（冪等）」" "$idempotent_out" "変更なし（冪等）"
assert_eq "(c) 2回目はコミットが増えない" "$commit_after2" "$commit_before2"
assert_eq "(c) 2回目はファイル内容も不変" "$(cat "$PROGRAM")" "$new_content"

# ============================================================
# (d) 既存の次:/参照:行がある場合は「置換」であり、新規挿入しない（行数不変）
# ============================================================
before_lines="$(wc -l < "$PROGRAM")"
"$SCRIPTS/progctl.sh" set "$PROGRAM" 02 --next "さらに次の一手" --commit >/dev/null
after_lines="$(wc -l < "$PROGRAM")"
assert_eq "(d) 既存次:行の更新では行数が変わらない" "$after_lines" "$before_lines"
assert_contains "(d) 次:行の内容が更新された" "$(cat "$PROGRAM")" "    次: さらに次の一手"

# ============================================================
# (e) 状態変更はチェックボックスを同時同期する（完了→[x]、未完→[ ]）。
# ============================================================
"$SCRIPTS/progctl.sh" set "$PROGRAM" 02 --state "実装" --commit >/dev/null
assert_contains "(e) 未完状態へ戻すと[ ]へ同期" "$(cat "$PROGRAM")" "- [ ] 02  ふたつめの子 … 実装"

# ============================================================
# (f) NN未指定・見つからないNN・state/next/ref全省略はエラー(非0 exit)
# ============================================================
"$SCRIPTS/progctl.sh" set "$PROGRAM" 99 --state "完了" >/dev/null 2>&1
assert_eq "(f) 存在しないNNはexit非0" "$?" "1"
"$SCRIPTS/progctl.sh" set "$PROGRAM" 02 >/dev/null 2>&1
assert_eq "(f) state/next/ref全省略はexit非0" "$?" "2"

report
