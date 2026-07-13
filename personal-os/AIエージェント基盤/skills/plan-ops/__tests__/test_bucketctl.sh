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
  "$REPO/plans/active/実行中A" "$REPO/plans/active/実行中B"
printf 'plan\n' > "$REPO/plans/planning/昇格対象/plan.md"
printf 'plan\n' > "$REPO/plans/planning/上限超過対象/plan.md"
printf 'plan\n' > "$REPO/plans/active/実行中A/plan.md"
printf 'plan\n' > "$REPO/plans/active/実行中B/plan.md"
git -C "$REPO" init -q
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" add plans
git -C "$REPO" commit -qm seed

# (a) 既定dry-run: 移動せず、上限内の昇格予定を表示する。
dry_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/昇格対象" --to active)"
assert_contains "(a) dry-runを表示" "$dry_out" "dry-run"
assert_contains "(a) active件数の変化を表示" "$dry_out" "active: 2/3 → 3/3"
[ -d "$REPO/plans/planning/昇格対象" ] && assert_eq "(a) dry-runでは元の場所に残る" "yes" "yes" || assert_eq "(a) dry-runでは元の場所に残る" "no" "yes"

# (b) --apply: git mvだけを適用し、コミットは作らない。
apply_before="$(git -C "$REPO" rev-list --count HEAD)"
apply_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/昇格対象" --to active --apply)"
assert_contains "(b) 未コミット適用を表示" "$apply_out" "適用済み（未コミット）"
[ -d "$REPO/plans/active/昇格対象" ] && assert_eq "(b) activeへ移動する" "yes" "yes" || assert_eq "(b) activeへ移動する" "no" "yes"
[ ! -d "$REPO/plans/planning/昇格対象" ] && assert_eq "(b) planningから消える" "yes" "yes" || assert_eq "(b) planningから消える" "no" "yes"
assert_eq "(b) --applyはコミットを作らない" "$(git -C "$REPO" rev-list --count HEAD)" "$apply_before"

# (c) 3件に達したら拒否し、active一覧を出す。
limit_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/上限超過対象" --to active 2>&1)"
limit_rc=$?
assert_eq "(c) 上限超過はexit 1" "$limit_rc" "1"
assert_contains "(c) 上限を説明" "$limit_out" "上限3件"
assert_contains "(c) active一覧を表示" "$limit_out" "昇格対象"
[ -d "$REPO/plans/planning/上限超過対象" ] && assert_eq "(c) 拒否時は移動しない" "yes" "yes" || assert_eq "(c) 拒否時は移動しない" "no" "yes"

# (d) --commitは昇格元の既存変更を同梱しない。
git -C "$REPO" restore --staged --worktree plans/planning/上限超過対象/plan.md >/dev/null 2>&1 || true
rm -rf "$REPO/plans/active/昇格対象"
git -C "$REPO" restore --staged --worktree plans
printf 'dirty\n' >> "$REPO/plans/planning/上限超過対象/plan.md"
dirty_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/planning/上限超過対象" --to active --commit 2>&1)"
dirty_rc=$?
assert_eq "(d) dirtyな昇格元の--commitはexit 1" "$dirty_rc" "1"
assert_contains "(d) --applyへの誘導を表示" "$dirty_out" "--apply"
[ -d "$REPO/plans/planning/上限超過対象" ] && assert_eq "(d) dirty元は移動しない" "yes" "yes" || assert_eq "(d) dirty元は移動しない" "no" "yes"

# (e) planning直下でないパスは安全に拒否する。
bad_out="$("$SCRIPTS/bucketctl.sh" promote "$REPO/plans/active/実行中A" --to active 2>&1)"
bad_rc=$?
assert_eq "(e) active内のパスはexit 2" "$bad_rc" "2"
assert_contains "(e) 許可する起点を示す" "$bad_out" "plans/planning/直下"

# (e) --commit: 移動だけを定型コミットし、作業ツリーを残さない。
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
assert_contains "(e) commit済みを表示" "$commit_out" "commit済み"
assert_eq "(e) --commitは1コミットだけ作る" "$(git -C "$COMMIT_REPO" rev-list --count HEAD)" "$((commit_before + 1))"
[ -d "$COMMIT_REPO/plans/active/コミット対象" ] && assert_eq "(e) commit後にactiveへ移動する" "yes" "yes" || assert_eq "(e) commit後にactiveへ移動する" "no" "yes"
assert_eq "(e) 作業ツリーを残さない" "$(git -C "$COMMIT_REPO" status --short)" ""

report
