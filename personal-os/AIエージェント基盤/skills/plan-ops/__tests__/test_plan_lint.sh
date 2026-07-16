#!/usr/bin/env bash
# plan-ops / plan-lint.sh の合成fixtureテスト。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
FIX="$HERE/fixtures/plan-lint"
source "$HERE/_test_lib.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/plan-lint-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

cp "$FIX/clean-plan.md" "$WORKDIR/plan.md"
cp -R "$FIX/clean-program" "$WORKDIR/program"

clean_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/plan.md")"
assert_eq "(a) 正常planはexit 0" "$?" "0"
assert_contains "(a) 正常planは違反なし" "$clean_out" "違反なし"

program_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/program/program.md")"
assert_eq "(b) 正常programはexit 0" "$?" "0"
assert_contains "(b) 正常programは違反なし" "$program_out" "違反なし"

child_clean_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/program/plans/01-子.md")"
assert_eq "(b) 子単体でも親マップと整合する" "$?" "0"
assert_contains "(b) 子単体は違反なし" "$child_clean_out" "違反なし"

sed -i '' '/## 非対象/,/## 現状/d' "$WORKDIR/plan.md"
missing_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/plan.md" 2>&1)"
assert_eq "(c) 必須節欠落はexit 1" "$?" "1"
assert_contains "(c) 非対象欠落を検出" "$missing_out" "必須セクションが無い: ## 非対象"

cp "$FIX/clean-plan.md" "$WORKDIR/placeholder.md"
perl -0pi -e 's/plan-lintの正常fixture。/<未記入>/g' "$WORKDIR/placeholder.md"
placeholder_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/placeholder.md" 2>&1)"
assert_eq "(d) placeholderはexit 1" "$?" "1"
assert_contains "(d) placeholderを検出" "$placeholder_out" "placeholderが残っている"

cp "$FIX/clean-plan.md" "$WORKDIR/missing-contract.md"
sed -i '' '/- 検証:/d' "$WORKDIR/missing-contract.md"
contract_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/missing-contract.md" 2>&1)"
assert_eq "(e) 実行契約欠落はexit 1" "$?" "1"
assert_contains "(e) 検証欠落を検出" "$contract_out" "実行契約の必須項目が無い: 検証:"

cp -R "$FIX/clean-program" "$WORKDIR/backlink"
perl -0pi -e 's#親計画: ../program.md#親計画: ../別program.md#' "$WORKDIR/backlink/plans/01-子.md"
backlink_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/backlink/program.md" 2>&1)"
assert_eq "(f) 子backlink不正はexit 1" "$?" "1"
assert_contains "(f) 子backlink不正を検出" "$backlink_out" "親計画backlinkが対象program.mdと不一致"

cp -R "$FIX/clean-program" "$WORKDIR/map"
sed -i '' '/    参照:/d' "$WORKDIR/map/program.md"
map_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/map/program.md" 2>&1)"
assert_eq "(g) マップ必須行欠落はexit 1" "$?" "1"
assert_contains "(g) 参照欠落を検出" "$map_out" "マップ必須行が無い: 参照:"

cp -R "$FIX/clean-program" "$WORKDIR/mismatch"
perl -0pi -e 's/並列: 不可 ／ レビュー: 都度/並列: 可 ／ レビュー: 都度/' "$WORKDIR/mismatch/plans/01-子.md"
mismatch_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/mismatch/program.md" 2>&1)"
assert_eq "(h) 子frontmatter矛盾はexit 1" "$?" "1"
assert_contains "(h) 並列矛盾を検出" "$mismatch_out" "Programマップと子frontmatterが不一致: 並列:"

cp "$FIX/clean-plan.md" "$WORKDIR/parallel.md"
perl -0pi -e 's/実行形: delegated-single/実行形: delegated-parallel/; s/ファイル担当マップ: 不要/ファイル担当マップ: <laneを記載>/; s/worktree方針: 不要/worktree方針: <方針を記載>/' "$WORKDIR/parallel.md"
parallel_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/parallel.md" 2>&1)"
assert_eq "(i) 並列レーン未記載はexit 1" "$?" "1"
assert_contains "(i) lane不足を検出" "$parallel_out" "delegated-parallelにはファイル担当マップ:が必須"
assert_contains "(i) worktree不足を検出" "$parallel_out" "delegated-parallelにはworktree方針:が必須"

"$SCRIPTS/new-plan.sh" --out "$WORKDIR/generated/plan.md" --class skill --kind 新規作成 >/dev/null
generated_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/generated/plan.md" --allow-placeholders)"
assert_eq "(j) 雛形はplaceholder以外で通る" "$?" "0"
assert_contains "(j) 雛形lintの成功を表示" "$generated_out" "違反なし"

"$SCRIPTS/new-plan.sh" --out "$WORKDIR/generated/program.md" --program --class 横断 --kind 統合整理 >/dev/null
"$SCRIPTS/new-child.sh" --out "$WORKDIR/generated/plans/01-子.md" --program "$WORKDIR/generated/program.md" --class 横断 --kind 統合整理 >/dev/null
child_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/generated/plans/01-子.md" --allow-placeholders)"
assert_eq "(k) repo-local想定の子雛形はplaceholder以外で通る" "$?" "0"
assert_contains "(k) 子雛形lintの成功を表示" "$child_out" "違反なし"

report
