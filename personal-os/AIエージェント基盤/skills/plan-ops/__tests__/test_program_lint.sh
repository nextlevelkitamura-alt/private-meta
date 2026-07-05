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
assert_contains "(b) file:行 形式で出力される" "$viol_out" "$FIX/lint-violations/program.md:14:"

# ============================================================
# (c) 状態語彙: 実運用の「完了（注記）」「実装中（注記）」「保留」は違反にならない
#     （lint-clean fixtureの01=完了/02=実装中がchecks (a) で既に0件通過していることで担保済み）。
#     一方「実装破綻」のような前方一致の抜け穴は(b)06で非0になることを確認済み。
# ============================================================
assert_not_contains "(c) 「実装中」単体はvocab違反にならない(clean fixtureに現れない)" "$clean_out" "状態語彙に無い状態"

# ============================================================
# (d) 引数なし・存在しないファイルはusageエラー(exit 2)
# ============================================================
"$SCRIPTS/program-lint.sh" >/dev/null 2>&1
assert_eq "(d) 引数なしはexit 2" "$?" "2"
"$SCRIPTS/program-lint.sh" "/no/such/program.md" >/dev/null 2>&1
assert_eq "(d) 存在しないファイルはexit 2" "$?" "2"

report
