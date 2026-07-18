#!/usr/bin/env bash
# plan-ops / program-lint.sh のテスト。fixtures/lint-clean・fixtures/lint-violations（いずれも合成データ）を検査する。
# 実HOME・実デイリー・~/Private実ファイルには一切書き込まない（読み取りもしない・fixture固定）。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
FIX="$HERE/fixtures"
# shellcheck source=_test_lib.sh
source "$HERE/_test_lib.sh"

# ============================================================
# (a) 正常fixture: 違反0件・exit 0
# ============================================================
clean_out="$("$SCRIPTS/program-lint.sh" "$FIX/lint-clean/program.md")"
clean_rc=$?
assert_eq "(a) 正常fixtureはexit 0" "$clean_rc" "0"
assert_contains "(a) 正常fixtureは「違反なし」を出す" "$clean_out" "違反なし"

# ============================================================
# (b) 違反fixture: exit非0・6種の違反すべてを検出・file:行形式で指摘
# ============================================================
viol_out="$("$SCRIPTS/program-lint.sh" "$FIX/lint-violations/program.md")"
viol_rc=$?
assert_eq "(b) 違反fixtureはexit非0" "$viol_rc" "1"
assert_contains "(b) 01=実ファイル無しを検出" "$viol_out" "NN=01 実ファイルが無い"
assert_contains "(b) 02=backlink壊れを検出" "$viol_out" "backlink壊れ子.md:1: 親計画backlinkが解決しない"
assert_contains "(b) 03=状態語彙崩れを検出" "$viol_out" "NN=03 状態語彙に無い状態"
assert_contains "(b) 04=完了なのに未チェックを検出（行番号つき）" "$viol_out" "未チェック子.md:20: 「完了」なのに完了条件が未チェック"
assert_contains "(b) 05=場所のNNが見出しと不一致を検出" "$viol_out" "NN=05 場所のNNが見出しと不一致: plans/01"
assert_contains "(b) 06=状態語彙の完全一致違反(実装破綻)を検出" "$viol_out" "NN=06 状態語彙に無い状態: 「実装破綻」"
assert_contains "(b) [x]なのに未完の不整合を検出" "$viol_out" "NN=03 チェックボックスと状態が不整合: [x] / でたらめな状態"
assert_contains "(b) [ ]なのに完了の不整合を検出" "$viol_out" "NN=04 チェックボックスと状態が不整合: [ ] / 完了"
assert_contains "(b) file:行 形式で出力される" "$viol_out" "$FIX/lint-violations/program.md:14:"

# ============================================================
# (c) 状態語彙: 実運用の「完了（注記）」「実装中（注記）」「保留」は違反にならない
#     （lint-clean fixtureの01=完了/02=実装中がchecks (a) で既に0件通過していることで担保済み）。
#     一方「実装破綻」のような前方一致の抜け穴は(b)06で非0になることを確認済み。
# ============================================================
assert_not_contains "(c) 「実装中」単体はvocab違反にならない(clean fixtureに現れない)" "$clean_out" "状態語彙に無い状態"

# ============================================================
# (d) 子計画ブロックを0件検出したprogramは、形式不追従として誤合格させない。
# ============================================================
empty_map="$(mktemp "${TMPDIR:-/tmp}/planops-empty-map.XXXXXX.md")"
trap 'rm -f "$empty_map"' EXIT
printf '%s\n' '# 空マップ' '' '## 子計画マップ' '' '（まだ子計画を追加していない）' > "$empty_map"
empty_out="$("$SCRIPTS/program-lint.sh" "$empty_map")"
empty_rc=$?
assert_eq "(d) 子計画0件はexit 1" "$empty_rc" "1"
assert_contains "(d) 子計画0件を明示する" "$empty_out" "子計画ブロックが無い"

# ============================================================
# (e) 引数なし・存在しないファイルはusageエラー(exit 2)
# ============================================================
"$SCRIPTS/program-lint.sh" >/dev/null 2>&1
assert_eq "(e) 引数なしはexit 2" "$?" "2"
"$SCRIPTS/program-lint.sh" "/no/such/program.md" >/dev/null 2>&1
assert_eq "(e) 存在しないファイルはexit 2" "$?" "2"

# ============================================================
# (f) 役割別コンテキスト（2026-07-18格上げ）: programでは実装/共通.md・レビュー/共通.mdを無条件必須。
#     フォルダ有無に関係なく欠落は違反（lint-clean fixtureは両ファイルを持ちexit 0で担保）。
# ============================================================
ROLE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/planops-role-ctx.XXXXXX")"
trap 'rm -rf "$ROLE_DIR"; rm -f "$empty_map"' EXIT
mkdir -p "$ROLE_DIR/plans" "$ROLE_DIR/実装"
cat > "$ROLE_DIR/plans/01-子.md" <<'EOF'
親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成

# 子

## 完了条件

- [x] fixture
EOF
cat > "$ROLE_DIR/program.md" <<'EOF'
# 合成program

## 子計画マップ

- [x] 01  子 … 完了
    場所: plans/01
EOF
role_out="$("$SCRIPTS/program-lint.sh" "$ROLE_DIR/program.md")"
role_rc=$?
assert_eq "(f) 実装/だけあり共通.md無しはexit 1" "$role_rc" "1"
assert_contains "(f) 共通.md欠落を指摘" "$role_out" "実装/共通.md が無い"
printf '# 実装共通\n' > "$ROLE_DIR/実装/共通.md"
mkdir -p "$ROLE_DIR/レビュー"
printf '# レビュー共通\n' > "$ROLE_DIR/レビュー/共通.md"
role_ok_out="$("$SCRIPTS/program-lint.sh" "$ROLE_DIR/program.md")"
assert_eq "(f) 共通.mdが揃えばexit 0" "$?" "0"
assert_contains "(f) 違反なしになる" "$role_ok_out" "違反なし"

report
