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

cp -R "$FIX/clean-program" "$WORKDIR/legacy-layout"
printf '# 旧親plan\n' > "$WORKDIR/legacy-layout/plan.md"
mkdir -p "$WORKDIR/legacy-layout/レビュー"
printf '\n    レビュー: 都度\n' >> "$WORKDIR/legacy-layout/program.md"
legacy_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/legacy-layout/program.md" 2>&1)"
assert_eq "(b) 旧親plan・レビュー構造はexit 1" "$?" "1"
assert_contains "(b) sibling plan.mdを指摘" "$legacy_out" "併存plan.mdは置けない"
assert_contains "(b) レビュー/を指摘" "$legacy_out" "レビュー/ フォルダは使えない"
assert_contains "(b) レビューfieldを指摘" "$legacy_out" "旧「レビュー:」フィールドは使えない"

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
perl -0pi -e 's/並列: 不可/並列: 可/' "$WORKDIR/mismatch/plans/01-子.md"
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

"$SCRIPTS/new-plan.sh" --out "$WORKDIR/generated-program/program.md" --program --class 横断 --kind 統合整理 >/dev/null
"$SCRIPTS/new-child.sh" --out "$WORKDIR/generated-program/plans/01-子.md" --program "$WORKDIR/generated-program/program.md" --class 横断 --kind 統合整理 >/dev/null
[ -f "$WORKDIR/generated-program/実装/共通.md" ]
assert_eq "(k) program雛形は実装/共通.mdを作る" "$?" "0"
[ -d "$WORKDIR/generated-program/評価" ]
assert_eq "(k) program雛形は評価/を作る" "$?" "0"
[ ! -e "$WORKDIR/generated-program/plan.md" ]
assert_eq "(k) program雛形は親plan.mdを作らない" "$?" "0"
[ ! -e "$WORKDIR/generated-program/レビュー" ]
assert_eq "(k) program雛形はレビュー/を作らない" "$?" "0"
child_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/generated-program/plans/01-子.md" --allow-placeholders)"
assert_eq "(l) repo-local想定の子雛形はplaceholder以外で通る" "$?" "0"
assert_contains "(l) 子雛形lintの成功を表示" "$child_out" "違反なし"

# ── テンプレv2: 工程節の必須化・形式検査・評価混在（frontmatter「テンプレ: v2」の時だけ発火）
# (m) v2マーカー有り＋工程節なし → FAIL
cp "$FIX/clean-plan.md" "$WORKDIR/v2-no-steps.md"
perl -0pi -e 's/^(分類: .*\n)/${1}テンプレ: v2\n/m' "$WORKDIR/v2-no-steps.md"
v2_no_steps_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/v2-no-steps.md" 2>&1)"
assert_eq "(m) v2で工程節なしはexit 1" "$?" "1"
assert_contains "(m) 工程節なしを検出" "$v2_no_steps_out" "工程節が無い（テンプレv2は必須）"

# (n) v2マーカー有り＋工程行が形式不正 → FAIL
cp "$FIX/clean-plan.md" "$WORKDIR/v2-bad-step.md"
perl -0pi -e 's/^(分類: .*\n)/${1}テンプレ: v2\n/m' "$WORKDIR/v2-bad-step.md"
perl -0pi -e 's/## 完了条件/## 工程\n\n- [ ] 実装 内容\n\n## 完了条件/' "$WORKDIR/v2-bad-step.md"
v2_bad_step_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/v2-bad-step.md" 2>&1)"
assert_eq "(n) v2で工程行形式不正はexit 1" "$?" "1"
assert_contains "(n) 工程行形式不正を検出" "$v2_bad_step_out" "工程行の形式不正"

# (o) v2マーカー有り＋正しい工程節 → 違反なし
cp "$FIX/clean-plan.md" "$WORKDIR/v2-ok.md"
perl -0pi -e 's/^(分類: .*\n)/${1}テンプレ: v2\n/m' "$WORKDIR/v2-ok.md"
perl -0pi -e 's/## 完了条件/## 工程\n\n- [ ] 01 実装: 内容  評価: まとめ\n\n## 完了条件/' "$WORKDIR/v2-ok.md"
v2_ok_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/v2-ok.md")"
assert_eq "(o) v2で正しい工程節はexit 0" "$?" "0"
assert_contains "(o) 違反なしを表示" "$v2_ok_out" "違反なし"

# (p) v2マーカー無し（既存相当）＋工程節なし → 新検査が発火しない
cp "$FIX/clean-plan.md" "$WORKDIR/legacy-no-marker.md"
legacy_marker_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/legacy-no-marker.md")"
assert_eq "(p) マーカー無しはexit 0" "$?" "0"
assert_not_contains "(p) マーカー無しでは工程検査が発火しない" "$legacy_marker_out" "工程節が無い"

# (q) v2マーカー有り＋本文に評価スコア混在 → FAIL
cp "$FIX/clean-plan.md" "$WORKDIR/v2-eval-mix.md"
perl -0pi -e 's/^(分類: .*\n)/${1}テンプレ: v2\n/m' "$WORKDIR/v2-eval-mix.md"
perl -0pi -e 's/## 完了条件/## 工程\n\n- [ ] 01 実装: 内容  評価: まとめ\n\n## 完了条件/' "$WORKDIR/v2-eval-mix.md"
printf '\n- [PASS] 混在した評価\n' >> "$WORKDIR/v2-eval-mix.md"
v2_eval_mix_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/v2-eval-mix.md" 2>&1)"
assert_eq "(q) v2で評価混在はexit 1" "$?" "1"
assert_contains "(q) 評価混在を検出" "$v2_eval_mix_out" "評価本文が計画に混在"

# (r) 工程節の「レビュー」種別行は旧「レビュー:」フィールド禁止に誤ヒットしない
cp "$FIX/clean-plan.md" "$WORKDIR/v2-step-review.md"
perl -0pi -e 's/^(分類: .*\n)/${1}テンプレ: v2\n/m' "$WORKDIR/v2-step-review.md"
perl -0pi -e 's/## 完了条件/## 工程\n\n- [ ] 01 実装: 作る  評価: まとめ\n- [ ] 02 レビュー: 見る  評価: まとめ\n\n## 完了条件/' "$WORKDIR/v2-step-review.md"
v2_step_review_out="$("$SCRIPTS/plan-lint.sh" "$WORKDIR/v2-step-review.md" 2>&1)"
assert_eq "(r) 工程レビュー行のplanはexit 0" "$?" "0"
assert_not_contains "(r) 工程レビュー行を旧フィールド扱いしない" "$v2_step_review_out" "旧「レビュー:」フィールド"

report
