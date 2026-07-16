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

# (k) Program子の候補lint失敗では子本文・親マップの両方をバイト不変に保つ。
CHILD_PROG="$REPO/plans/active/2026-07-08-子原子性"; mkdir -p "$CHILD_PROG/plans"
cat > "$CHILD_PROG/program.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善 ／ 形態: program
## 子計画マップ
- [ ] 01  子 … 実装
    役割: 実装
    対象repo: repo無し
    並列: 不可
    レビュー: 都度
    人間ゲート: なし
    次: 同期
    場所: plans/01-子.md
    依存: ―
    参照: ―
EOF
{ printf '親計画: ../program.md\n'; cat "$BAD/plan.md"; printf '\n<placeholder>\n'; } > "$CHILD_PROG/plans/01-子.md"
cat > "$CHILD_PROG/plans/01-子-評価01.md" <<'EOF'
対象計画: 01-子.md
## 項目別採点
- [PASS] `a.py` が存在する
## 総合判定
全PASS
EOF
child_before="$(cat "$CHILD_PROG/plans/01-子.md")"; parent_before="$(cat "$CHILD_PROG/program.md")"
child_atomic="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$CHILD_PROG/plans/01-子.md" --plans-root "$REPO/plans" --program "$CHILD_PROG/program.md" --evaluation "$CHILD_PROG/plans/01-子-評価01.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; child_atomic_rc=$?
assert_eq "(k) Program子候補lint失敗は非0" "$child_atomic_rc" "1"
assert_eq "(k) 子本文はバイト不変" "$(cat "$CHILD_PROG/plans/01-子.md")" "$child_before"
assert_eq "(k) 親Programマップはバイト不変" "$(cat "$CHILD_PROG/program.md")" "$parent_before"

# (l) apply-evaluationの4拒否とsync-checkの成功/不整合JSONを個別に固定する。
MISMATCH="$REPO/plans/planning/2026-07-09-評価拒否"; mkdir -p "$MISMATCH"; cp "$BAD/plan.md" "$MISMATCH/plan.md"
cat > "$MISMATCH/対象違い.md" <<'EOF'
対象計画: other.md
## 項目別採点
- [PASS] `a.py` が存在する
## 総合判定
全PASS
EOF
target_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$MISMATCH/plan.md" --plans-root "$REPO/plans" --evaluation "$MISMATCH/対象違い.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; target_rc=$?
assert_eq "(l) 対象計画不一致を拒否" "$target_rc" "1"
assert_contains "(l) 対象計画不一致の理由" "$target_out" "対象計画が一致しない"
cat > "$MISMATCH/文言違い.md" <<'EOF'
対象計画: plan.md
## 項目別採点
- [PASS] 別の文言
## 総合判定
全PASS
EOF
word_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$MISMATCH/plan.md" --plans-root "$REPO/plans" --evaluation "$MISMATCH/文言違い.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; word_rc=$?
assert_eq "(l) 完了条件文言不一致を拒否" "$word_rc" "1"
assert_contains "(l) 完了条件文言不一致の理由" "$word_out" "完全一致しない"
python3 - "$MISMATCH/欠損commit.json" "$BASE" <<'PY'
import json, sys
json.dump({"version":1,"task_id":"missing","status":"done","base_commit":sys.argv[2],"result_commit":"0000000000000000000000000000000000000000","changed_paths":[],"tests":[],"assumptions":[],"blockers":[],"remaining_risks":[],"out_of_scope_findings":[]}, open(sys.argv[1], "w"))
PY
commit_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$MISMATCH/plan.md" --plans-root "$REPO/plans" --evaluation "$MISMATCH/文言違い.md" --result "$MISMATCH/欠損commit.json" --repo-root "$REPO" 2>&1)"; commit_rc=$?
assert_eq "(l) 存在しないresult commitを拒否" "$commit_rc" "1"
assert_contains "(l) result commit欠損の理由" "$commit_out" "result commitが実在しない"
WRONG="$REPO/plans/active/2026-07-10-子番号拒否"; mkdir -p "$WRONG/plans"
cat > "$WRONG/program.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善 ／ 形態: program
## 子計画マップ
- [ ] 02  別子 … 実装
    役割: 実装
    対象repo: repo無し
    並列: 不可
    レビュー: 都度
    人間ゲート: なし
    次: 同期
    場所: plans/02-別子.md
    依存: ―
    参照: ―
EOF
{ printf '親計画: ../program.md\n'; cat "$BAD/plan.md"; } > "$WRONG/plans/01-子.md"
python3 - "$WRONG/plans/01-子.md" <<'PY'
from pathlib import Path
p = Path(__import__('sys').argv[1])
p.write_text(p.read_text().replace('- [ ] `a.py` が存在する', '- [x] `a.py` が存在する'), encoding='utf-8')
PY
cp "$CHILD_PROG/plans/01-子-評価01.md" "$WRONG/plans/01-子-評価01.md"
nn_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$WRONG/plans/01-子.md" --plans-root "$REPO/plans" --program "$WRONG/program.md" --evaluation "$WRONG/plans/01-子-評価01.md" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --repo-root "$REPO" 2>&1)"; nn_rc=$?
assert_eq "(l) 誤った子番号を拒否" "$nn_rc" "1"
assert_contains "(l) 子番号不一致の理由" "$nn_out" "子番号が一致しない"
sync_ok="$(python3 "$SCRIPTS/planctl.py" sync-check --plan "$REPO/plans/archive/2026-07-01-同期試験/plan.md" --plans-root "$REPO/plans" --repo-root "$REPO" --result "$REPO/plans/archive/2026-07-01-同期試験/実行結果.json" --evaluation "$REPO/plans/archive/2026-07-01-同期試験/評価01.md")"; sync_ok_rc=$?
assert_eq "(l) 整合済みsync-checkは0" "$sync_ok_rc" "0"
assert_contains "(l) 整合済みsync-checkはJSON" "$sync_ok" '"ok": true'
sync_bad="$(python3 "$SCRIPTS/planctl.py" sync-check --plan "$WRONG/plans/01-子.md" --plans-root "$REPO/plans" --program "$WRONG/program.md" --repo-root "$REPO" 2>&1)"; sync_bad_rc=$?
assert_eq "(l) マップ乖離sync-checkは非0" "$sync_bad_rc" "1"
assert_contains "(l) マップ乖離sync-checkはJSON" "$sync_bad" '"ok": false'

# (m) 変更可能範囲がbacktick付き・`・`/`、`混在の実書式でも、範囲内の実差分は正しく許可する。
RANGE_OK="$REPO/plans/planning/2026-07-11-backtick範囲試験"; mkdir -p "$RANGE_OK"
cat > "$RANGE_OK/plan.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善

# backtick範囲試験

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
- 変更可能範囲: `src/backtick.py`（実装本体）、`docs/`・`config/backtick.yaml`
- 変更禁止範囲: なし
- 維持する契約: 明示path
- 検証: bash test
- 停止・エスカレーション条件: 不一致時停止
- 完了時に返す情報: result packet
## 方針
同期する。
## 完了条件（レビュー項目）
- [ ] 変更が実装されている
EOF
git -C "$REPO" add "plans/planning/2026-07-11-backtick範囲試験/plan.md"
git -C "$REPO" commit -qm "backtick範囲試験の計画"
RANGE_OK_BASE="$(git -C "$REPO" rev-parse HEAD)"
mkdir -p "$REPO/src" "$REPO/docs/deep" "$REPO/config"
printf 'x\n' > "$REPO/src/backtick.py"
printf 'y\n' > "$REPO/docs/deep/note.txt"
printf 'z\n' > "$REPO/config/backtick.yaml"
git -C "$REPO" add src/backtick.py docs/deep/note.txt config/backtick.yaml
git -C "$REPO" commit -qm "backtick範囲試験の実装"
RANGE_OK_RESULT="$(git -C "$REPO" rev-parse HEAD)"
cat > "$RANGE_OK/実行結果.json" <<EOF
{"version":1,"task_id":"range-ok","status":"done","base_commit":"$RANGE_OK_BASE","result_commit":"$RANGE_OK_RESULT","changed_paths":["src/backtick.py","docs/deep/note.txt","config/backtick.yaml"],"tests":[{"command":"test -f src/backtick.py","status":"passed","summary":"存在を確認"}],"assumptions":[],"blockers":[],"remaining_risks":[],"out_of_scope_findings":[]}
EOF
cat > "$RANGE_OK/評価01.md" <<'EOF'
対象計画: plan.md ／ ラウンド: 01

## 項目別採点
- [PASS] 変更が実装されている
  根拠: 3ファイルの実装を確認
## 総合判定
全PASS＝完了可
EOF
range_ok_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$RANGE_OK/plan.md" --plans-root "$REPO/plans" --evaluation "$RANGE_OK/評価01.md" --result "$RANGE_OK/実行結果.json" --repo-root "$REPO" 2>&1)"; range_ok_rc=$?
assert_eq "(m) backtick+・混在の変更可能範囲内は許可" "$range_ok_rc" "0"
assert_contains "(m) backtick+・混在の同期成功" "$range_ok_out" "synced"

# (n) 同じbacktick+・混在の範囲定義でも、宣言範囲外の実差分は引き続き拒否する（範囲検査は緩めない）。
RANGE_BAD="$REPO/plans/planning/2026-07-12-backtick範囲外試験"; mkdir -p "$RANGE_BAD"
cat > "$RANGE_BAD/plan.md" <<'EOF'
分類: 横断 ／ 種別: 既存改善

# backtick範囲外試験

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
- 変更可能範囲: `src/backtick.py`（実装本体）、`docs/`・`config/backtick.yaml`
- 変更禁止範囲: なし
- 維持する契約: 明示path
- 検証: bash test
- 停止・エスカレーション条件: 不一致時停止
- 完了時に返す情報: result packet
## 方針
同期する。
## 完了条件（レビュー項目）
- [ ] 変更が実装されている
EOF
git -C "$REPO" add "plans/planning/2026-07-12-backtick範囲外試験/plan.md"
git -C "$REPO" commit -qm "backtick範囲外試験の計画"
RANGE_BAD_BASE="$(git -C "$REPO" rev-parse HEAD)"
mkdir -p "$REPO/other"
printf 'w\n' > "$REPO/other/outside.py"
git -C "$REPO" add other/outside.py
git -C "$REPO" commit -qm "backtick範囲外試験の逸脱差分"
RANGE_BAD_RESULT="$(git -C "$REPO" rev-parse HEAD)"
cat > "$RANGE_BAD/実行結果.json" <<EOF
{"version":1,"task_id":"range-bad","status":"done","base_commit":"$RANGE_BAD_BASE","result_commit":"$RANGE_BAD_RESULT","changed_paths":["other/outside.py"],"tests":[{"command":"test -f other/outside.py","status":"passed","summary":"存在を確認"}],"assumptions":[],"blockers":[],"remaining_risks":[],"out_of_scope_findings":[]}
EOF
cat > "$RANGE_BAD/評価01.md" <<'EOF'
対象計画: plan.md ／ ラウンド: 01

## 項目別採点
- [PASS] 変更が実装されている
  根拠: ダミー
## 総合判定
全PASS＝完了可
EOF
range_bad_out="$(python3 "$SCRIPTS/planctl.py" apply-evaluation --plan "$RANGE_BAD/plan.md" --plans-root "$REPO/plans" --evaluation "$RANGE_BAD/評価01.md" --result "$RANGE_BAD/実行結果.json" --repo-root "$REPO" 2>&1)"; range_bad_rc=$?
assert_eq "(n) backtick+・混在でも範囲外差分は拒否" "$range_bad_rc" "1"
assert_contains "(n) 範囲外差分の理由" "$range_bad_out" "変更可能範囲外"

report
