#!/bin/bash
# 受け口シム経由のE2E（Claude=plain / Codex=JSON / 二段注入 / ガード / Stop）
# パスはスクリプト位置から相対解決（worktree でもそのまま動く）
set -u
SB="$(cd "$(dirname "$0")/.." && pwd)"
CL="$(cd "$(dirname "$0")/../../../claude" && pwd)"
CX="$(cd "$(dirname "$0")/../../../codex" && pwd)"
SP="$(cd "$(dirname "$0")" && pwd)/sbtest2"
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-02" SESSION_BOARD_TX_ROOTS="$SP/tx"
BOARD="$SB/board.py"
DAILY="$SP/goal/2099/01/2099-01-02.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }

J_SS='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J_UP='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","prompt":"セッションボードを再設計して実装まで進めたい"}'

echo "=== 1. Claude SessionStart: 枠登録＋1行通知 ==="
OUT=$(echo "$J_SS" | python3 "$CL/session-start/session-board-session-start.py")
echo "$OUT" | grep -q "ボードキー s:beefcafe"; ok "SS通知1行" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "1" ]; ok "SS注入は1行だけ" test $? -eq 0
grep -qF "| ? | 今:? | repoZ | その他 | claude/? | 計画:? <!-- s:beefcafe -->" "$DAILY"; ok "枠行が登録される" test $? -eq 0

echo "=== 2. Claude UPS 初回: フルガイド＋今の仮置き ==="
OUT=$(echo "$J_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "最初の依頼を理解したら"; ok "初回=フルガイド" test $? -eq 0
echo "$OUT" | grep -q "種別: 計画=進め方を決め文書化"; ok "種別5定義を含む" test $? -eq 0
echo "$OUT" | grep -q "リサーチ"; ok "リサーチ語彙" test $? -eq 0
echo "$OUT" | grep -q "repo概要.md"; ok "計画チェーン" test $? -eq 0
grep -qF "今:セッションボードを再設計して実装まで進めたい" "$DAILY"; ok "今の初回仮置き(24字)" test $? -eq 0

echo "=== 3. AIが行を正した後のUPS: 2行ミラー（計画も記入済み）==="
"$BOARD" update --key beefcafe --type 実装 --goal "ボード再設計" --now "common改修" --model fable5 --plan "ボード再設計/03"
OUT=$(echo "$J_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "目標:ボード再設計 | 今:common改修 | 種別:実装 | 計画:ボード再設計/03"; ok "ミラー1行目(計画含む)" test $? -eq 0
echo "$OUT" | grep -q "ズレていたら"; ok "催促行" test $? -eq 0
echo "$OUT" | grep -qv "最初の依頼"; ok "フルガイドは出ない" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "2" ]; ok "ミラーは2行" test $? -eq 0

echo "=== 4. Pythonは今を上書きしない（AI記入が残る） ==="
grep -qF "今:common改修" "$DAILY"; ok "AI記入のnowが維持される" test $? -eq 0

echo "=== 5. 計画種別のミラーは3判定行が付く(3行) ==="
"$BOARD" update --key beefcafe --type 計画
OUT=$(echo "$J_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "計画3判定: ①サクッと"; ok "計画3判定スニペット" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "3" ]; ok "計画時は3行" test $? -eq 0
"$BOARD" update --key beefcafe --type 実装

echo "=== 6. Stop: run→⏸、次のUPSで🟢復帰 ==="
echo "$J_UP" | python3 "$CL/session-end/session-board-session-end.py"
[ "$("$BOARD" check --key beefcafe)" = "wait" ]; ok "Stopで⏸" test $? -eq 0
echo "$J_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py" >/dev/null
[ "$("$BOARD" check --key beefcafe)" = "run" ]; ok "UPSで🟢復帰" test $? -eq 0

echo "=== 7. 初回ガイドに既存目標一覧が出る（別セッション） ==="
J2_SS='{"session_id":"cafe0002-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/cafe0002-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J2_UP='{"session_id":"cafe0002-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/cafe0002-0000.jsonl","cwd":"/tmp/repoZ","prompt":"ボード再設計のREADMEを直したい"}'
echo "$J2_SS" | python3 "$CL/session-start/session-board-session-start.py" >/dev/null
OUT=$(echo "$J2_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "いま動いている他の目標: 「ボード再設計」"; ok "既存目標一覧の注入" test $? -eq 0
echo "$OUT" | grep -q "コピーして合流"; ok "合流規約の案内" test $? -eq 0

echo "=== 8. Codex 受け口: JSON契約 ==="
J3_SS='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J3_UP='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","prompt":"Codexからの依頼テスト"}'
OUT=$(echo "$J3_SS" | python3 "$CX/session-start/session-board-session-start.py")
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "ボードキー s:c0dec0de" in d["hookSpecificOutput"]["additionalContext"]'; ok "Codex SS=JSON" test $? -eq 0
grep -qF "| codex/? | 計画:? <!-- s:c0dec0de -->" "$DAILY"; ok "Codex枠行(runtime=codex)" test $? -eq 0
OUT=$(echo "$J3_UP" | python3 "$CX/prompt-register/session-board-prompt-register.py")
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d["hookSpecificOutput"]["additionalContext"]; assert "最初の依頼" in c and d["hookSpecificOutput"]["hookEventName"]=="UserPromptSubmit"'; ok "Codex UPS=JSONガイド" test $? -eq 0

echo "=== 9. ガード: スラッシュ・subagent・headless・空 ==="
OUT=$(echo '{"session_id":"badbad01-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/x.jsonl","cwd":"/tmp","prompt":"/compact"}' | python3 "$CL/prompt-register/session-board-prompt-register.py")
[ -z "$OUT" ]; ok "スラッシュは無視" test $? -eq 0
OUT=$(echo '{"session_id":"badbad02-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/s/subagents/agent-x.jsonl","cwd":"/tmp","prompt":"サブの依頼"}' | python3 "$CL/prompt-register/session-board-prompt-register.py")
[ -z "$OUT" ]; ok "subagentは無視" test $? -eq 0
OUT=$(echo "$J_UP" | AIJOBS_RUN=1 python3 "$CL/prompt-register/session-board-prompt-register.py")
[ -z "$OUT" ]; ok "headless(AIJOBS_RUN)は無視" test $? -eq 0
grep -c "s:badbad" "$DAILY" | grep -q "^0$" 2>/dev/null || ! grep -q "s:badbad" "$DAILY"; ok "ガード対象は登録されない" test $? -eq 0

echo "=== 10. 計画列ミラー/ガイド（仕様D 9-11）==="
J4_SS='{"session_id":"d1a10001-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/d1a10001-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J4_UP='{"session_id":"d1a10001-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/d1a10001-0000.jsonl","cwd":"/tmp/repoZ","prompt":"計画列の実装を進めたい"}'
# D11: 初回ガイドに --plan・計画列1行・ls確認1行・3判定5行が含まれる
echo "$J4_SS" | python3 "$CL/session-start/session-board-session-start.py" >/dev/null
OUT=$(echo "$J4_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -qF -- '--plan "<企画名[/NN] か なし>"'; ok "D11 ガイドに--plan例" test $? -eq 0
echo "$OUT" | grep -q "計画列: 計画=これから置く先"; ok "D11 計画列1行" test $? -eq 0
echo "$OUT" | grep -qF "ls <repo>/plans/{planning,active}"; ok "D11 既存計画確認(ls)行" test $? -eq 0
echo "$OUT" | grep -q "計画種別なら、置く前に3判定"; ok "D11 3判定見出し" test $? -eq 0
[ "$(echo "$OUT" | grep -c -E '^ [^ ]')" = "4" ]; ok "D11 3判定は4小項目(①②③置き場)" test $? -eq 0
# D9: 実装で 計画:? → ミラーに催促行（3行）→ update --plan 後のターンで消える（2行）
"$BOARD" update --key d1a10001 --type 実装 --goal "計画列実装" --now "着手" --model claude
OUT=$(echo "$J4_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "計画:? → 拠り所"; ok "D9 計画:?催促が出る" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "3" ]; ok "D9 催促時は3行" test $? -eq 0
"$BOARD" update --key d1a10001 --plan "計画実行フロー統一/03"
OUT=$(echo "$J4_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
! echo "$OUT" | grep -q "計画:? → 拠り所"; ok "D9 記入後は催促が消える" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "2" ]; ok "D9 記入後は2行" test $? -eq 0
# D10: 種別=計画 → 3判定行が出る・?催促とは重複しない
"$BOARD" update --key d1a10001 --type 計画 --plan "?"
OUT=$(echo "$J4_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -q "計画3判定: ①サクッと"; ok "D10 種別=計画で3判定行" test $? -eq 0
! echo "$OUT" | grep -q "計画:? → 拠り所"; ok "D10 ?催促は重複しない" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "3" ]; ok "D10 計画時も3行(重複なし)" test $? -eq 0

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
