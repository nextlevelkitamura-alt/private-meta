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
- 変更可能範囲: a.py
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

prepare_out="$(python3 "$SCRIPTS/planctl.py" prepare --plan "$PLAN_DIR/plan.md" --plans-root "$REPO/plans" --task-id prepare --role implementer --runtime codex --repo-root "$REPO" --base-commit "$BASE" --worktree-path "$REPO" --branch task/test --state-dir "$REPO/.planops-state")"
assert_contains "(a) prepareはmanifestを生成" "$prepare_out" "manifest"
[ -f "$REPO/.planops-state/prepare-manifest.json" ] && assert_eq "(a) manifestはgitignore配下" "yes" "yes" || assert_eq "(a) manifestはgitignore配下" "no" "yes"
MANIFEST="$REPO/.planops-state/prepare-manifest.json"
python3 "$SCRIPTS/planctl.py" phase --manifest "$MANIFEST" --to implemented >/dev/null
python3 "$SCRIPTS/planctl.py" phase --manifest "$MANIFEST" --to review_passed >/dev/null
assert_contains "(a) phaseはreview_passedへ進む" "$(cat "$MANIFEST")" '"phase": "review_passed"'

apply_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$PLAN_DIR/plan.md" --plans-root "$REPO/plans" --evaluation "$PLAN_DIR/評価01.md" --result "$PLAN_DIR/実行結果.json" --repo-root "$REPO" --manifest "$MANIFEST")"
assert_contains "(b) 全PASSだけ同期" "$apply_out" "synced"
assert_contains "(b) 完了条件を[x]にする" "$(cat "$PLAN_DIR/plan.md")" '- [x] `a.py` が存在する'
assert_contains "(b) 実装結果を追記" "$(cat "$PLAN_DIR/plan.md")" '実装結果'
assert_contains "(b) 同期後phaseはsynced" "$(cat "$MANIFEST")" '"phase": "synced"'

"$SCRIPTS/bucketctl.sh" move "$PLAN_DIR" --to done --apply >/dev/null
DONE="$REPO/plans/done/2026-07-01-同期試験"
close_out="$(python3 "$SCRIPTS/planctl.py" close --plan "$DONE/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --manifest "$MANIFEST" --disposition completed --human-confirmation '人間 2026-07-15 承認' --reason 完了 --references '評価01.md' --apply)"
assert_contains "(c) closeはbucketctl経由で移動" "$close_out" "適用済み"
[ -f "$REPO/plans/archive/2026-07-01-同期試験/終了記録.md" ] && assert_eq "(c) 終了記録を必須化" "yes" "yes" || assert_eq "(c) 終了記録を必須化" "no" "yes"
assert_contains "(c) close後phaseはclosed" "$(cat "$MANIFEST")" '"phase": "closed"'

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
bad_eval="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$BAD/plan.md" --plans-root "$REPO/plans" --evaluation "$BAD/評価01.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; bad_eval_rc=$?
assert_eq "(e) FAIL評価は同期拒否" "$bad_eval_rc" "1"
assert_contains "(e) FAIL理由を返す" "$bad_eval" "全PASSではない"
cat > "$BAD/不正.json" <<'EOF'
{"version":1,"status":"bogus"}
EOF
packet_out="$(python3 "$SCRIPTS/planctl.py" sync-check --plan "$BAD/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --result "$BAD/不正.json" 2>&1)"; packet_rc=$?
assert_eq "(f) 不正result packetを検出" "$packet_rc" "1"
assert_contains "(f) JSON整合エラーを返す" "$packet_out" "result packet"

# (g) resultの実差分と契約範囲を照合し、禁止範囲を自動修正せず拒否する。
git -C "$REPO" reset >/dev/null
mkdir -p "$REPO/hooks"; printf 'bad\n' > "$REPO/hooks/bad.py"
git -C "$REPO" add hooks/bad.py && git -C "$REPO" commit -qm forbidden
FORBIDDEN_RESULT="$(git -C "$REPO" rev-parse HEAD)"
python3 - "$BAD/範囲違反.json" "$RESULT" "$FORBIDDEN_RESULT" <<'PY'
import json, sys
json.dump({"version":1,"task_id":"bad","status":"done","base_commit":sys.argv[2],"result_commit":sys.argv[3],"changed_paths":["hooks/bad.py"],"tests":[{"command":"test -f a.py","status":"passed","summary":"ok"}],"assumptions":[],"blockers":[],"remaining_risks":[],"out_of_scope_findings":[]}, open(sys.argv[1], "w"))
PY
cp "$REPO/plans/archive/2026-07-01-同期試験/評価01.md" "$BAD/範囲評価.md"
range_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$BAD/plan.md" --plans-root "$REPO/plans" --evaluation "$BAD/範囲評価.md" --result "$BAD/範囲違反.json" --repo-root "$REPO" 2>&1)"; range_rc=$?
assert_eq "(g) 禁止範囲の実差分は拒否" "$range_rc" "1"
assert_contains "(g) 変更可能範囲違反を返す" "$range_out" "変更可能範囲外"

# (h) 非completed archiveは終了記録・人間確認が揃えば通り、後継必須の欠落は拒否する。
CANCEL="$REPO/plans/planning/2026-07-03-中止試験"; mkdir -p "$CANCEL"; cp "$BAD/plan.md" "$CANCEL/plan.md"
git -C "$REPO" add "plans/planning/2026-07-03-中止試験/plan.md" && git -C "$REPO" commit -qm cancelled-plan
cancel_out="$(python3 "$SCRIPTS/planctl.py" close --plan "$CANCEL/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --disposition cancelled --human-confirmation '人間確認済み' --reason 中止 --apply)"
assert_contains "(h) cancelled archiveは正常に閉じる" "$cancel_out" "適用済み"
SUPER="$REPO/plans/planning/2026-07-04-置換試験"; mkdir -p "$SUPER"; cp "$BAD/plan.md" "$SUPER/plan.md"
super_out="$(python3 "$SCRIPTS/planctl.py" close --plan "$SUPER/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --disposition superseded --human-confirmation '人間確認済み' --reason 置換 --apply 2>&1)"; super_rc=$?
assert_eq "(h) supersededの後継欠落は拒否" "$super_rc" "1"
assert_contains "(h) 後継必須を返す" "$super_out" "後継・統合先"

# (i) archive lint・rename --check・dry-run候補とrepo-local plans rootを検証する。
ARCH_BAD="$REPO/plans/archive/2026-07-05-lint試験"; mkdir -p "$ARCH_BAD"; cp "$BAD/plan.md" "$ARCH_BAD/plan.md"
archive_lint="$($SCRIPTS/plan-lint.sh "$ARCH_BAD/plan.md" 2>&1)"; archive_lint_rc=$?
assert_eq "(i) archive lintは終了記録欠落を検出" "$archive_lint_rc" "1"
assert_contains "(i) archive lintの理由" "$archive_lint" "終了記録"
printf '参照: 2026-07-01-同期試験\n' > "$REPO/board.md"
check_out="$(python3 "$SCRIPTS/planctl.py" rename --plan "$REPO/plans/archive/2026-07-01-同期試験/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --check)"
assert_contains "(i) rename --checkは日付不要でJSON" "$check_out" '"rename_required": true'
rename_dry="$(python3 "$SCRIPTS/planctl.py" rename --plan "$REPO/plans/archive/2026-07-01-同期試験/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --date 2026-07-15)"
assert_contains "(i) rename dry-runは参照更新候補を出す" "$rename_dry" "参照更新予定"

# (j) progressは対象子以外を変えず、apply-evaluationのlint失敗は本文を残さない。
PROGDIR="$REPO/plans/active/2026-07-06-進捗試験"; mkdir -p "$PROGDIR"
cat > "$PROGDIR/program.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善 ／ 形態: program
大幅更新日: 2026-07-01
## 子計画マップ
- [ ] 01  対象 … 実装
    次: 更新前
    場所: plans/01 ／ 依存: ―
- [ ] 02  非対象 … 計画
    次: 不変
    場所: plans/02 ／ 依存: ―
EOF
other_before="$(sed -n '1,2p;6,8p' "$PROGDIR/program.md")"
python3 "$SCRIPTS/planctl.py" progress --program "$PROGDIR/program.md" --plans-root "$REPO/plans" --repo-root "$REPO" --nn 01 --next 更新後 --apply >/dev/null
assert_eq "(j) progressは対象外バイトを維持" "$(sed -n '1,2p;6,8p' "$PROGDIR/program.md")" "$other_before"
ATOMIC="$REPO/plans/planning/2026-07-07-原子性試験"; mkdir -p "$ATOMIC"; cp "$BAD/plan.md" "$ATOMIC/plan.md"; printf '\n<placeholder>\n' >> "$ATOMIC/plan.md"
cp "$REPO/plans/archive/2026-07-01-同期試験/評価01.md" "$ATOMIC/評価01.md"
atomic_before="$(cat "$ATOMIC/plan.md")"
atomic_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$ATOMIC/plan.md" --plans-root "$REPO/plans" --evaluation "$ATOMIC/評価01.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; atomic_rc=$?
assert_eq "(j) 候補lint失敗は非0" "$atomic_rc" "1"
assert_eq "(j) 候補lint失敗は本文を不変にする" "$(cat "$ATOMIC/plan.md")" "$atomic_before"
assert_contains "(j) 原子的失敗理由を返す" "$atomic_out" "変更は反映しない"

report
