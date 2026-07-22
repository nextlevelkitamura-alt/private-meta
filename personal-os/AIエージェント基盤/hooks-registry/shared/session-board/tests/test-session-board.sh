#!/bin/bash
# session-board CLI スモーク（正本反転・子03/案b後）。
# 反転後は当日デイリーMDを一切書かないため、旧「デイリーmdをgrepして状態を確認する」E2Eは
# 成立しない（状態の正本は board DB＝Turso）。本番Tursoへ書かずに検証できるのは:
#   ・各コマンドが SESSION_BOARD_NO_TURSO 下でクラッシュせず exit 0 で返ること（引数解釈・分岐）
#   ・不正引数が usage 停止（非0＋usage文）すること
#   ・CLI引数の後方互換（--time/--todo/--theme/--model/--plan 等を受けてもエラーにしない）
#   ・読み系（check/show/goals）がオフラインで missing/空を返し、hookを止めないこと
#   ・shim ガード（slash/subagent/headless）が空出力で無視すること
# 状態遷移・体数・イベント発行・出力フォーマット・shimミラー/復帰の「密度」は、fake DB を使う
# in-process の Python テストへ移した（同等以上）:
#   tests/test_lifecycle.py（add→check/show/goals→update→flip→sub→log→finish→reconcile）
#   tests/test_events.py（イベント発行・体数・バッチ合流）／ tests/test_reconcile.py（生存照合）
#   tests/test_shims.py（初回ガイド/ミラー/復帰/回答注入/ガード）
set -u
SB="$(cd "$(dirname "$0")/.." && pwd)"
EV="$(cd "$(dirname "$0")/../../../events" && pwd)"
SP="$(mktemp -d)/sbtest"
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-01" SESSION_BOARD_TX_ROOTS="$SP/tx" SESSION_BOARD_NO_TURSO=1
BOARD="$SB/board.py"
DAILY="$SP/goal/2099/01/2099-01-01.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }

echo "=== 1. セッション系コマンドが NO_TURSO 下で exit 0（クラッシュしない）==="
ok "add exit0"        "$BOARD" add --key aaaa0001 --repo RepoA --who "claude/?" --time 14:00
ok "update exit0"     "$BOARD" update --key aaaa0001 --type 実装 --goal "ボード再設計" --now "改修" --model fable5 --plan "統一/03"
ok "flip exit0"       "$BOARD" flip --key aaaa0001 --state wait
ok "sub-start exit0"  "$BOARD" sub-start --key aaaa0001
ok "sub-end exit0"    "$BOARD" sub-end --key aaaa0001
ok "log exit0"        "$BOARD" log --key aaaa0001 --repo RepoA --parent "ボード再設計" --time 14:38 --entry "節目"
ok "finish exit0"     "$BOARD" finish --key aaaa0001 --repo RepoA --parent "ボード再設計" --entry "締め"
ok "reconcile exit0"  "$BOARD" reconcile
ok "sub-label exit0"  "$BOARD" sub-label --key aaaa0001 --label "作業中"

echo "=== 2. 正本反転: 当日デイリーMDファイルを書かない ==="
ok "デイリーMDを作らない" bash -c "! test -e '$DAILY'"

echo "=== 3. 読み系はオフラインで missing/空（hookを止めない）==="
[ "$("$BOARD" check --key aaaa0001)" = "missing" ]; ok "check=missing(オフライン)" test $? -eq 0
[ "$("$BOARD" show --key aaaa0001)" = "missing" ];  ok "show=missing(オフライン)" test $? -eq 0
[ -z "$("$BOARD" goals)" ];                          ok "goals=空(オフライン)" test $? -eq 0

echo "=== 4. inbox系コマンドが exit 0（daily/keyに触れない）==="
ok "todo-add exit0"   "$BOARD" todo-add --title "求人票のドラフト" --assignee ai --route single
ok "theme-add exit0(意図1行のみ)"  "$BOARD" theme-add --name "T"
ok "steps exit0"      "$BOARD" steps --todo T1 --entry "ステップ1" --entry "ステップ2"
ok "step-done exit0"  "$BOARD" step-done --todo T1 --seq 1
ok "ask exit0"        "$BOARD" ask --todo T1 --q "按分は？" --choice A --choice B
ok "goal-add exit0"   "$BOARD" goal-add --name "今週の目標"

echo "=== 5. 不正引数は usage 停止（非0＋usage文）==="
ok "add --key必須"     bash -c "! '$BOARD' add >/dev/null 2>&1"
"$BOARD" todo-add 2>&1 | grep -q "usage: board.py todo-add"; ok "todo-add title欠落=usage" test $? -eq 0
"$BOARD" theme-add --purpose P --done D 2>&1 | grep -q "usage: board.py theme-add"; ok "theme-add 名前欠落=usage" test $? -eq 0
"$BOARD" todo-add --title x --assignee boss 2>&1 | grep -q "assignee"; ok "todo-add 不正assignee=usage" test $? -eq 0
"$BOARD" goal-add 2>&1 | grep -q "usage: board.py goal-add"; ok "goal-add name欠落=usage" test $? -eq 0

echo "=== 6. CLI引数の後方互換（呼び出し側hook・skillが渡す引数を受ける）==="
ok "update --todo/--theme受理" "$BOARD" update --key bbbb0002 --goal G --todo T9 --theme H9
ok "log --todo受理"            "$BOARD" log --key bbbb0002 --repo R --parent P --entry e --todo T9
ok "finish --todo受理"         "$BOARD" finish --key bbbb0002 --repo R --parent P --entry e --todo T9
ok "steps --kind/--session-key受理" "$BOARD" steps --todo T1 --kind fix --session-key s:abcd1234 --entry x
ok "flow-done受理(未宣言=not-routine)" bash -c '"'"$BOARD"'" flow-done --todo T1 --skill adhoc | grep -q "not-routine"'

echo "=== 7. shim ガード（slash/subagent/headless は空出力で無視）==="
claude_prompt(){ python3 "$EV/prompt-register/register-and-guide.py" --runtime claude; }
OUT=$(echo '{"session_id":"badbad01-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/x.jsonl","cwd":"/tmp","prompt":"/compact"}' | claude_prompt)
[ -z "$OUT" ]; ok "スラッシュは無視" test $? -eq 0
OUT=$(echo '{"session_id":"badbad02-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/s/subagents/agent-x.jsonl","cwd":"/tmp","prompt":"サブの依頼"}' | claude_prompt)
[ -z "$OUT" ]; ok "subagentは無視" test $? -eq 0
OUT=$(echo '{"session_id":"badbad03-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/x.jsonl","cwd":"/tmp","prompt":"依頼"}' | AIJOBS_RUN=1 claude_prompt)
[ -z "$OUT" ]; ok "headless(AIJOBS_RUN)は無視" test $? -eq 0

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
