#!/bin/bash
# 受け口シム経由のE2E（Claude=plain / Codex=JSON / 二段注入 / ガード / Stop）
# パスはスクリプト位置から相対解決（worktree でもそのまま動く）
set -u
SB="$(cd "$(dirname "$0")/.." && pwd)"
CL="$(cd "$(dirname "$0")/../../../claude" && pwd)"
CX="$(cd "$(dirname "$0")/../../../codex" && pwd)"
SP="$(mktemp -d)/sbtest2"   # 作業ゴミは tests/ でなく tmp へ（tests/ を汚さない）
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-02" SESSION_BOARD_TX_ROOTS="$SP/tx" SESSION_BOARD_NO_TURSO=1
BOARD="$SB/board.py"
DAILY="$SP/goal/2099/01/2099-01-02.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }

J_SS='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J_UP='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","prompt":"セッションボードを再設計して実装まで進めたい"}'

echo "=== 1. Claude SessionStart: 枠登録しない＋1行通知（遅延登録） ==="
OUT=$(echo "$J_SS" | python3 "$CL/session-start/session-board-session-start.py")
echo "$OUT" | grep -q "ボードキー s:beefcafe"; ok "SS通知1行" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "1" ]; ok "SS注入は1行だけ" test $? -eq 0
echo "$OUT" | grep -q "最初のプロンプト時に登録"; ok "SS通知は遅延登録を告知" test $? -eq 0
# 遅延登録なので初回SS時点ではデイリー自体が未作成（reconcileは無ファイルなら何もしない）→ 枠は載らない
! grep -qF "s:beefcafe" "$DAILY" 2>/dev/null; ok "SessionStartでは枠行が増えない" test $? -eq 0

echo "=== 2. Claude UPS 初回: 枠を登録＋フルガイド＋今の仮置き ==="
OUT=$(echo "$J_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
grep -qF "<!-- s:beefcafe -->" "$DAILY"; ok "初回プロンプトで枠が登録される（遅延登録の実体化）" test $? -eq 0
grep -qF "| repoZ | その他 | claude/? | 計画:? <!-- s:beefcafe -->" "$DAILY"; ok "登録される枠は既定値（repo/runtime確定・意味づけは?）" test $? -eq 0
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

echo "=== 8. Codex 受け口: JSON契約（枠は初回プロンプトで登録）==="
J3_SS='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J3_UP='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","prompt":"Codexからの依頼テスト"}'
OUT=$(echo "$J3_SS" | python3 "$CX/session-start/session-board-session-start.py")
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "ボードキー s:c0dec0de" in d["hookSpecificOutput"]["additionalContext"]'; ok "Codex SS=JSON" test $? -eq 0
! grep -qF "s:c0dec0de" "$DAILY" 2>/dev/null; ok "Codex SS時点では枠なし(遅延登録)" test $? -eq 0
OUT=$(echo "$J3_UP" | python3 "$CX/prompt-register/session-board-prompt-register.py")
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d["hookSpecificOutput"]["additionalContext"]; assert "最初の依頼" in c and d["hookSpecificOutput"]["hookEventName"]=="UserPromptSubmit"'; ok "Codex UPS=JSONガイド" test $? -eq 0
grep -qF "| codex/? | 計画:? <!-- s:c0dec0de -->" "$DAILY"; ok "Codex枠行(初回プロンプトで登録・runtime=codex)" test $? -eq 0

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
echo "$OUT" | grep -qF "対象repoの最寄りAGENTS.md"; ok "D11 repo AGENTSで計画箱解決" test $? -eq 0
echo "$OUT" | grep -qF "宣言範囲の既存planを検索"; ok "D11 宣言範囲で既存計画検索" test $? -eq 0
echo "$OUT" | grep -qF "root plansを推定・作成せず停止"; ok "D11 計画箱不明時は停止" test $? -eq 0
echo "$OUT" | grep -qF "新しい可視sessionへhandoff"; ok "D11 Privateから可視sessionへhandoff" test $? -eq 0
echo "$OUT" | grep -qF "既存session IDの移管・reparentはしない"; ok "D11 session reparent禁止" test $? -eq 0
echo "$OUT" | grep -q "計画種別なら、置く前に3判定"; ok "D11 3判定見出し" test $? -eq 0
[ "$(echo "$OUT" | grep -c -E '^ [^ ]')" = "4" ]; ok "D11 3判定は4小項目(①②③置き場)" test $? -eq 0
# D9: 実装で 計画:? → ミラーに催促行（3行）→ update --plan 後のターンで消える（2行）
"$BOARD" update --key d1a10001 --type 実装 --goal "計画列実装" --now "着手" --model claude
OUT=$(echo "$J4_UP" | python3 "$CL/prompt-register/session-board-prompt-register.py")
echo "$OUT" | grep -Eq "(計画:\? → 拠り所|実装で計画:\? →)"; ok "D9 計画:?催促が出る" test $? -eq 0
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

echo "=== 11. Codexシム: SubagentStart/Stop → sub-start/sub-end（体数増減） ==="
J3_SUBS='{"session_id":"c0dec0de-0000-1111-2222-333344445555","cwd":"/tmp/repoZ","hook_event_name":"SubagentStart"}'
J3_SUBE='{"session_id":"c0dec0de-0000-1111-2222-333344445555","cwd":"/tmp/repoZ","hook_event_name":"SubagentStop"}'
echo "$J3_SUBS" | python3 "$CX/subagent/session-board-subagent.py"
echo "$J3_SUBS" | python3 "$CX/subagent/session-board-subagent.py"
[ "$("$BOARD" check --key c0dec0de)" = "sub" ]; ok "Codex SubagentStart×2→🔵" test $? -eq 0
grep -qF "<!-- s:c0dec0de sub:2 -->" "$DAILY"; ok "Codex sub:2コメント" test $? -eq 0
grep -qF "    ↳ 🔵 サブ2体" "$DAILY"; ok "Codex ↳サブ2体" test $? -eq 0
echo "$J3_SUBE" | python3 "$CX/subagent/session-board-subagent.py"
[ "$("$BOARD" check --key c0dec0de)" = "sub" ]; ok "Codex Stop×1→🔵維持(残1体)" test $? -eq 0
grep -qF "    ↳ 🔵 サブ1体" "$DAILY"; ok "Codex 体数1へ減少" test $? -eq 0
echo "$J3_SUBE" | python3 "$CX/subagent/session-board-subagent.py"
[ "$("$BOARD" check --key c0dec0de)" = "run" ]; ok "Codex 全Stop→🟢復帰" test $? -eq 0
! grep -qF "s:c0dec0de sub:" "$DAILY"; ok "Codex sub:痕跡なし(0は書かない)" test $? -eq 0

echo "=== 12. Claude受け口シム: SubagentStart/Stop E2E（新設） ==="
J_SUBS='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000/subagents/agent-sub1.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SubagentStart"}'
J_SUBE='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000/subagents/agent-sub1.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SubagentStop"}'
echo "$J_SUBS" | python3 "$CL/subagent/session-board-subagent.py"
[ "$("$BOARD" check --key beefcafe)" = "sub" ]; ok "Claude SubagentStart→🔵" test $? -eq 0
grep -qF "<!-- s:beefcafe sub:1 -->" "$DAILY"; ok "Claude sub:1コメント" test $? -eq 0
grep -qF "    ↳ 🔵 サブ1体" "$DAILY"; ok "Claude ↳サブ1体" test $? -eq 0
echo "$J_SUBE" | python3 "$CL/subagent/session-board-subagent.py"
[ "$("$BOARD" check --key beefcafe)" = "run" ]; ok "Claude SubagentStop→🟢復帰" test $? -eq 0
! grep -qF "s:beefcafe sub:" "$DAILY"; ok "Claude sub:痕跡なし" test $? -eq 0
OUT=$(echo '{"session_id":"agent-xyz","cwd":"/tmp","hook_event_name":"SubagentStart"}' | python3 "$CL/subagent/session-board-subagent.py")
[ -z "$OUT" ]; ok "Claude subagent自身のsid(agent-*)は無視" test $? -eq 0

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
