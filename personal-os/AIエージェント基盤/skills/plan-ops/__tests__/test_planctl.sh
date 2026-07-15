#!/usr/bin/env bash
# planctl の合成repo E2E。実Privateやruntime stateは触らない。
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
source "$HERE/_test_lib.sh"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/planctl-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
REPO="$WORKDIR/repo"
PLAN_DIR="$REPO/plans/active/2026-07-01-同期試験"
mkdir -p "$PLAN_DIR" "$REPO/plans/planning" "$REPO/plans/paused" "$REPO/plans/done" "$REPO/plans/archive" "$REPO/.planops-state"
printf '.planops-state/\n' > "$REPO/.gitignore"
cat > "$PLAN_DIR/plan.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善

# 同期試験

## 目的
同期する。
## 非対象
なし。
## 現状
未同期。
## 実行契約
- 対象repo: repo無し
- 実行形: delegated-single
- 最初に読む順番: この計画
- 依存成果: なし
- 変更可能範囲: scripts/
- 変更禁止範囲: hooks/
- 維持する契約: 明示path
- 検証: bash test
- 停止・エスカレーション条件: 不一致時停止
- 完了時に返す情報: result packet
## 方針
同期する。
## 完了条件（レビュー項目）
- [ ] `a.py` が存在する
EOF
git -C "$REPO" init -q
git -C "$REPO" config user.name test
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" add .
git -C "$REPO" commit -qm seed
BASE="$(git -C "$REPO" rev-parse HEAD)"
printf 'x\n' > "$REPO/a.py"
git -C "$REPO" add a.py && git -C "$REPO" commit -qm implementation
RESULT="$(git -C "$REPO" rev-parse HEAD)"
cat > "$PLAN_DIR/実行結果.json" <<EOF
{"version":1,"task_id":"t1","status":"done","base_commit":"$BASE","result_commit":"$RESULT","changed_paths":["a.py"],"tests":[{"command":"test -f a.py","status":"passed","summary":"存在を確認"}],"assumptions":[],"blockers":[],"remaining_risks":[],"out_of_scope_findings":[]}
EOF
cat > "$PLAN_DIR/評価01.md" <<'EOF'
対象計画: plan.md ／ ラウンド: 01

## 項目別採点
- [PASS] `a.py` が存在する
  根拠: a.py
## 総合判定
全PASS＝完了可
EOF

prepare_out="$(python3 "$SCRIPTS/planctl.py" prepare --plan "$PLAN_DIR/plan.md" --task-id prepare --role implementer --runtime codex --repo-root "$REPO" --base-commit "$BASE" --worktree-path "$REPO" --branch task/test --state-dir "$REPO/.planops-state")"
assert_contains "(a) prepareはmanifestを生成" "$prepare_out" "manifest"
[ -f "$REPO/.planops-state/prepare-manifest.json" ] && assert_eq "(a) manifestはgitignore配下" "yes" "yes" || assert_eq "(a) manifestはgitignore配下" "no" "yes"

apply_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$PLAN_DIR/plan.md" --evaluation "$PLAN_DIR/評価01.md" --result "$PLAN_DIR/実行結果.json" --repo-root "$REPO")"
assert_contains "(b) 全PASSだけ同期" "$apply_out" "synced"
assert_contains "(b) 完了条件を[x]にする" "$(cat "$PLAN_DIR/plan.md")" '- [x] `a.py` が存在する'
assert_contains "(b) 実装結果を追記" "$(cat "$PLAN_DIR/plan.md")" '実装結果'

"$SCRIPTS/bucketctl.sh" move "$PLAN_DIR" --to done --apply >/dev/null
DONE="$REPO/plans/done/2026-07-01-同期試験"
close_out="$(python3 "$SCRIPTS/planctl.py" close --plan "$DONE/plan.md" --disposition completed --human-confirmation '人間 2026-07-15 承認' --reason 完了 --references '評価01.md' --apply)"
assert_contains "(c) closeはbucketctl経由で移動" "$close_out" "適用済み"
[ -f "$REPO/plans/archive/2026-07-01-同期試験/終了記録.md" ] && assert_eq "(c) 終了記録を必須化" "yes" "yes" || assert_eq "(c) 終了記録を必須化" "no" "yes"

BAD="$REPO/plans/planning/2026-07-02-拒否試験"
mkdir -p "$BAD"
cp "$REPO/plans/archive/2026-07-01-同期試験/plan.md" "$BAD/plan.md"
sed -i '' 's/- \[x\]/- [ ]/' "$BAD/plan.md" 2>/dev/null || sed -i 's/- \[x\]/- [ ]/' "$BAD/plan.md"
bad_out="$("$SCRIPTS/bucketctl.sh" move "$BAD" --to archive 2>&1)"; bad_rc=$?
assert_eq "(d) 終了記録なしarchiveは拒否" "$bad_rc" "1"
assert_contains "(d) 欠落理由を返す" "$bad_out" "終了記録"
cat > "$BAD/評価01.md" <<'EOF'
対象計画: plan.md
## 項目別採点
- [FAIL] `a.py` が存在する
## 総合判定
FAIL
EOF
bad_eval="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$BAD/plan.md" --evaluation "$BAD/評価01.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; bad_eval_rc=$?
assert_eq "(e) FAIL評価は同期拒否" "$bad_eval_rc" "1"
assert_contains "(e) FAIL理由を返す" "$bad_eval" "全PASSではない"
cat > "$BAD/不正.json" <<'EOF'
{"version":1,"status":"bogus"}
EOF
packet_out="$(python3 "$SCRIPTS/planctl.py" sync-check --plan "$BAD/plan.md" --result "$BAD/不正.json" 2>&1)"; packet_rc=$?
assert_eq "(f) 不正result packetを検出" "$packet_rc" "1"
assert_contains "(f) JSON整合エラーを返す" "$packet_out" "result packet"

report
