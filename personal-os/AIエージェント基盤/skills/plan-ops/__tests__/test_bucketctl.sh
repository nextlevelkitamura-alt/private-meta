#!/usr/bin/env bash
# plan-ops / bucketctl.sh のテスト。毎回mktempの独立git repoだけを操作する。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
# shellcheck source=_test_lib.sh
source "$HERE/_test_lib.sh"

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/bucketctl-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
REPO="$WORKDIR/repo"
mkdir -p "$REPO/plans/planning/昇格対象" "$REPO/plans/planning/上限超過対象" \
  "$REPO/plans/active/実行中A" "$REPO/plans/active/実行中B" "$REPO/plans/active/実行中C"
printf 'plan\n' > "$REPO/plans/planning/昇格対象/plan.md"
printf 'plan\n' > "$REPO/plans/planning/上限超過対象/plan.md"
printf 'plan\n' > "$REPO/plans/active/実行中A/plan.md"
printf 'plan\n' > "$REPO/plans/active/実行中B/plan.md"
printf 'plan\n' > "$REPO/plans/active/実行中C/plan.md"
git -C "$REPO" init -q
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" add plans
git -C "$REPO" commit -qm seed

# (a) 既定dry-run: 移動せず、上限内の昇格予定を表示する。
dry_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/昇格対象" --to active)"
assert_contains "(a) dry-runを表示" "$dry_out" "dry-run"
assert_contains "(a) active件数の変化を表示" "$dry_out" "active: 3/4 → 4/4"
[ -d "$REPO/plans/planning/昇格対象" ] && assert_eq "(a) dry-runでは元の場所に残る" "yes" "yes" || assert_eq "(a) dry-runでは元の場所に残る" "no" "yes"

# (b) --apply: git mvだけを適用し、コミットは作らない。
apply_before="$(git -C "$REPO" rev-list --count HEAD)"
apply_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/昇格対象" --to active --apply)"
assert_contains "(b) 未コミット適用を表示" "$apply_out" "適用済み（未コミット）"
[ -d "$REPO/plans/active/昇格対象" ] && assert_eq "(b) activeへ移動する" "yes" "yes" || assert_eq "(b) activeへ移動する" "no" "yes"
[ ! -d "$REPO/plans/planning/昇格対象" ] && assert_eq "(b) planningから消える" "yes" "yes" || assert_eq "(b) planningから消える" "no" "yes"
assert_eq "(b) --applyはコミットを作らない" "$(git -C "$REPO" rev-list --count HEAD)" "$apply_before"

# (c) 4件に達したら拒否し、active一覧を出す。
limit_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/上限超過対象" --to active 2>&1)"
limit_rc=$?
assert_eq "(c) 上限超過はexit 1" "$limit_rc" "1"
assert_contains "(c) 上限を説明" "$limit_out" "上限4件"
assert_contains "(c) active一覧を表示" "$limit_out" "昇格対象"
[ -d "$REPO/plans/planning/上限超過対象" ] && assert_eq "(c) 拒否時は移動しない" "yes" "yes" || assert_eq "(c) 拒否時は移動しない" "no" "yes"

# (d) active=4を一箇所で強制し、既存超過はcheckで可視化する。
TEMP_REPO="$WORKDIR/temp-ai-repo"
TEMP_PLANS="$TEMP_REPO/personal-os/my-brain/areas/ai運用/plans"
TEMP_NAME="2026-07-14-計画運用ハーネス検証"
mkdir -p "$TEMP_PLANS/planning/$TEMP_NAME" "$TEMP_PLANS/planning/通常対象" \
  "$TEMP_PLANS/active/実行中A" "$TEMP_PLANS/active/実行中B" "$TEMP_PLANS/active/実行中C" "$TEMP_PLANS/active/実行中D"
for p in "$TEMP_PLANS/planning/$TEMP_NAME" "$TEMP_PLANS/planning/通常対象" \
  "$TEMP_PLANS/active/実行中A" "$TEMP_PLANS/active/実行中B" "$TEMP_PLANS/active/実行中C" "$TEMP_PLANS/active/実行中D"; do
  printf 'plan\n' > "$p/plan.md"
done
git -C "$TEMP_REPO" init -q
git -C "$TEMP_REPO" config user.name test
git -C "$TEMP_REPO" config user.email test@example.invalid
git -C "$TEMP_REPO" add personal-os
git -C "$TEMP_REPO" commit -qm seed
temp_limit_out="$($SCRIPTS/bucketctl.sh promote "$TEMP_PLANS/planning/$TEMP_NAME" --to active 2>&1)"
temp_limit_rc=$?
assert_eq "(d) active=4の流入は拒否" "$temp_limit_rc" "1"
assert_contains "(d) 上限と人間判断を表示" "$temp_limit_out" "上限4件"
check_out="$($SCRIPTS/bucketctl.sh check "$TEMP_PLANS" --json 2>&1)"
assert_contains "(d) check --jsonは対象一覧を返す" "$check_out" "実行中A"
assert_contains "(d) check --jsonは上限件数を返す" "$check_out" '"count": 4'

# (e) --commitは昇格元の既存変更を同梱しない。
git -C "$REPO" restore --staged --worktree plans/planning/上限超過対象/plan.md >/dev/null 2>&1 || true
rm -rf "$REPO/plans/active/昇格対象"
git -C "$REPO" restore --staged --worktree plans
printf 'dirty\n' >> "$REPO/plans/planning/上限超過対象/plan.md"
dirty_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/上限超過対象" --to active --commit 2>&1)"
dirty_rc=$?
assert_eq "(e) dirtyな昇格元の--commitはexit 1" "$dirty_rc" "1"
assert_contains "(e) --applyへの誘導を表示" "$dirty_out" "--apply"
[ -d "$REPO/plans/planning/上限超過対象" ] && assert_eq "(e) dirty元は移動しない" "yes" "yes" || assert_eq "(e) dirty元は移動しない" "no" "yes"

# (f) planning直下でないパスは安全に拒否する。
bad_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/active/実行中A" --to active 2>&1)"
bad_rc=$?
assert_eq "(f) active内のパスはexit 2" "$bad_rc" "2"
assert_contains "(f) 許可する起点を示す" "$bad_out" "plans/planning/直下"

# (g) --commit: 移動だけを定型コミットし、作業ツリーを残さない。
COMMIT_REPO="$WORKDIR/commit-repo"
mkdir -p "$COMMIT_REPO/plans/planning/コミット対象" "$COMMIT_REPO/plans/active/実行中A"
printf 'plan\n' > "$COMMIT_REPO/plans/planning/コミット対象/plan.md"
printf 'plan\n' > "$COMMIT_REPO/plans/active/実行中A/plan.md"
git -C "$COMMIT_REPO" init -q
git -C "$COMMIT_REPO" config user.name test
git -C "$COMMIT_REPO" config user.email test@example.invalid
git -C "$COMMIT_REPO" add plans
git -C "$COMMIT_REPO" commit -qm seed
commit_before="$(git -C "$COMMIT_REPO" rev-list --count HEAD)"
commit_out="$("$SCRIPTS/bucketctl.sh" promote "$COMMIT_REPO/plans/planning/コミット対象" --to active --commit)"
assert_contains "(g) commit済みを表示" "$commit_out" "commit済み"
assert_eq "(g) --commitは1コミットだけ作る" "$(git -C "$COMMIT_REPO" rev-list --count HEAD)" "$((commit_before + 1))"
[ -d "$COMMIT_REPO/plans/active/コミット対象" ] && assert_eq "(g) commit後にactiveへ移動する" "yes" "yes" || assert_eq "(g) commit後にactiveへ移動する" "no" "yes"
assert_eq "(g) 作業ツリーを残さない" "$(git -C "$COMMIT_REPO" status --short)" ""

# (h) 許可遷移、誤遷移、超過バケットからの退出、completed archive拒否を個別に検査する。
TRANS="$WORKDIR/transitions"
for bucket in planning active paused done archive; do mkdir -p "$TRANS/plans/$bucket"; done
make_plan() { mkdir -p "$1"; printf '# plan\n\n## 完了条件\n- [%s] 確認\n' "$2" > "$1/plan.md"; }
make_record() { cat > "$1/終了記録.md" <<EOF
# 終了記録
- 終了区分: $2
- 終了日時: 2026-07-15 12:00 JST
- 人間確認: 確認済み
- 理由: テスト
- 後継・統合先: ${3:-該当なし}
- 実装済み範囲: テスト
- 未完了事項: なし
- レビュー・判断根拠: テスト
- 関連commit/評価: test
EOF
}
make_plan "$TRANS/plans/active/active-to-paused" ' '
make_plan "$TRANS/plans/paused/paused-to-planning" ' '
make_plan "$TRANS/plans/paused/paused-to-active" ' '
make_plan "$TRANS/plans/done/done-to-active" x
make_plan "$TRANS/plans/planning/cancel-to-archive" ' '
make_record "$TRANS/plans/planning/cancel-to-archive" cancelled
make_plan "$TRANS/plans/done/completed-unchecked" ' '
make_record "$TRANS/plans/done/completed-unchecked" completed
make_plan "$TRANS/plans/done/completed-fail-eval" x
make_record "$TRANS/plans/done/completed-fail-eval" completed
cat > "$TRANS/plans/done/completed-fail-eval/評価01.md" <<'EOF'
## 項目別採点
- [FAIL] 確認
## 総合判定
FAIL
EOF
make_plan "$TRANS/plans/done/completed-no-eval" x
make_record "$TRANS/plans/done/completed-no-eval" completed
git -C "$TRANS" init -q && git -C "$TRANS" config user.name test && git -C "$TRANS" config user.email test@example.invalid
git -C "$TRANS" add plans && git -C "$TRANS" commit -qm seed
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/active/active-to-paused" --to paused --apply >/dev/null
assert_eq "(h) active→pausedを許可" "$(test -d "$TRANS/plans/paused/active-to-paused"; echo $?)" "0"
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/paused/paused-to-planning" --to planning --apply >/dev/null
assert_eq "(h) paused→planningを許可" "$(test -d "$TRANS/plans/planning/paused-to-planning"; echo $?)" "0"
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/paused/paused-to-active" --to active --apply >/dev/null
assert_eq "(h) paused→activeを許可" "$(test -d "$TRANS/plans/active/paused-to-active"; echo $?)" "0"
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/done/done-to-active" --to active --apply >/dev/null
assert_eq "(h) done→activeを許可" "$(test -d "$TRANS/plans/active/done-to-active"; echo $?)" "0"
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/planning/cancel-to-archive" --to archive --apply >/dev/null
assert_eq "(h) 非completed直接archiveを許可" "$(test -d "$TRANS/plans/archive/cancel-to-archive"; echo $?)" "0"
wrong_out="$($SCRIPTS/bucketctl.sh move "$TRANS/plans/planning/paused-to-planning" --to done 2>&1)"; wrong_rc=$?
assert_eq "(h) planning→doneは拒否" "$wrong_rc" "2"
assert_contains "(h) 誤遷移理由を返す" "$wrong_out" "許可されない遷移"
unchecked_out="$($SCRIPTS/bucketctl.sh move "$TRANS/plans/done/completed-unchecked" --to archive 2>&1)"; unchecked_rc=$?
assert_eq "(h) 未チェックcompleted archiveは拒否" "$unchecked_rc" "1"
assert_contains "(h) 未チェック理由を返す" "$unchecked_out" "全完了条件"
fail_eval_out="$($SCRIPTS/bucketctl.sh move "$TRANS/plans/done/completed-fail-eval" --to archive 2>&1)"; fail_eval_rc=$?
assert_eq "(h) FAIL評価completed archiveは拒否" "$fail_eval_rc" "1"
assert_contains "(h) FAIL評価理由を返す" "$fail_eval_out" "最終評価"
no_eval_out="$($SCRIPTS/bucketctl.sh move "$TRANS/plans/done/completed-no-eval" --to archive 2>&1)"; no_eval_rc=$?
assert_eq "(h) 最終評価なしcompleted archiveは拒否（完了条件は全チェック済み）" "$no_eval_rc" "1"
assert_contains "(h) 最終評価なし理由を返す" "$no_eval_out" "最終評価"
for n in 1 2 3 4; do make_plan "$TRANS/plans/paused/over-$n" ' '; done
git -C "$TRANS" add plans/paused && git -C "$TRANS" commit -qm overflow
overcheck="$($SCRIPTS/bucketctl.sh check "$TRANS/plans" --json 2>&1)"; overcheck_rc=$?
assert_eq "(h) 既存超過のcheckは非0" "$overcheck_rc" "1"
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/paused/over-1" --to planning --apply >/dev/null
assert_eq "(h) 超過バケットからの退出を許可" "$(test -d "$TRANS/plans/planning/over-1"; echo $?)" "0"

# (i) 評価/ 新配置（2026-07-17）: completedのarchiveを通し、子評価のFAILと混同しない。
make_plan "$TRANS/plans/done/completed-eval-folder" x
make_record "$TRANS/plans/done/completed-eval-folder" completed
mkdir -p "$TRANS/plans/done/completed-eval-folder/評価"
cat > "$TRANS/plans/done/completed-eval-folder/評価/評価01.md" <<'EOF'
## 項目別採点
- [PASS] 確認
## 総合判定
全PASS
EOF
cat > "$TRANS/plans/done/completed-eval-folder/評価/01-子-評価01.md" <<'EOF'
## 項目別採点
- [FAIL] 子の項目
## 総合判定
FAILあり
EOF
git -C "$TRANS" add plans/done/completed-eval-folder && git -C "$TRANS" commit -qm eval-folder
"$SCRIPTS/bucketctl.sh" move "$TRANS/plans/done/completed-eval-folder" --to archive --apply >/dev/null
assert_eq "(i) 評価/配置のcompleted archiveを許可（子評価FAILと混同しない）" "$(test -d "$TRANS/plans/archive/completed-eval-folder"; echo $?)" "0"
make_plan "$TRANS/plans/done/completed-eval-folder-fail" x
make_record "$TRANS/plans/done/completed-eval-folder-fail" completed
mkdir -p "$TRANS/plans/done/completed-eval-folder-fail/評価"
cat > "$TRANS/plans/done/completed-eval-folder-fail/評価/評価01.md" <<'EOF'
## 項目別採点
- [FAIL] 確認
## 総合判定
FAILあり
EOF
folder_fail_out="$($SCRIPTS/bucketctl.sh move "$TRANS/plans/done/completed-eval-folder-fail" --to archive 2>&1)"; folder_fail_rc=$?
assert_eq "(i) 評価/配置のFAILはarchive拒否" "$folder_fail_rc" "1"
assert_contains "(i) FAIL理由を返す" "$folder_fail_out" "最終評価"

report
