#!/bin/bash
# 受け口シムのE2Eスモーク（正本反転・子03/案b後）。
# 反転後は当日デイリーMDを書かず、状態の正本は board DB（Turso）。本番Tursoへ書かずに subprocess で
# 検証できるのは「DB状態に依存しない shim 配線」だけ:
#   ・SessionStart 通知（Claude=plain / Codex=JSON）
#   ・初回プロンプト=フルガイド本文（board_show がオフラインで missing→新規扱い＝毎回フルガイド）
#   ・ガード（slash / subagent / headless は空出力で無視）
#   ・Codex 受け口の JSON 契約（hookSpecificOutput.additionalContext）
# 状態に依存する密度（ミラー／⏸→🟢復帰／既存目標一覧／サブ体数／回答注入）は、fake DB を使う
# in-process の tests/test_shims.py へ移した（common を実 board へ in-process 結線して同等以上に検証）。
set -u
EV="$(cd "$(dirname "$0")/../../../events" && pwd)"
SP="$(mktemp -d)/sbtest2"
rm -rf "$SP"; mkdir -p "$SP/goal" "$SP/tx/proj"
export GOAL_BASE="$SP/goal" SESSION_BOARD_DATE="2099-01-02" SESSION_BOARD_TX_ROOTS="$SP/tx" SESSION_BOARD_NO_TURSO=1
DAILY="$SP/goal/2099/01/2099-01-02.md"
PASS=0; FAIL=0
ok(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); echo "PASS: $name"; else FAIL=$((FAIL+1)); echo "FAIL: $name"; fi; }
claude_start(){ python3 "$EV/session-start/reconcile-and-notify.py" --runtime claude; }
claude_prompt(){ python3 "$EV/prompt-register/register-and-guide.py" --runtime claude; }
codex_start(){ python3 "$EV/session-start/reconcile-and-notify.py" --runtime codex; }
codex_prompt(){ python3 "$EV/prompt-register/register-and-guide.py" --runtime codex; }

J_SS='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J_UP='{"session_id":"beefcafe-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/beefcafe-0000.jsonl","cwd":"/tmp/repoZ","prompt":"セッションボードを再設計して実装まで進めたい"}'

echo "=== 1. Claude SessionStart: 通知1行（遅延登録・枠は作らない）==="
OUT=$(echo "$J_SS" | claude_start)
echo "$OUT" | grep -q "ボードキー s:beefcafe"; ok "SS通知1行" test $? -eq 0
[ "$(echo "$OUT" | wc -l | tr -d ' ')" = "1" ]; ok "SS注入は1行だけ" test $? -eq 0
echo "$OUT" | grep -q "最初のプロンプト時に登録"; ok "SS通知は遅延登録を告知" test $? -eq 0

echo "=== 2. 正本反転: shim経由でも当日デイリーMDを書かない ==="
echo "$J_UP" | claude_prompt >/dev/null
ok "デイリーMDを作らない" bash -c "! test -e '$DAILY'"

echo "=== 3. Claude 初回プロンプト: フルガイド本文（D11 計画ルーティング含む）==="
OUT=$(echo "$J_UP" | claude_prompt)
echo "$OUT" | grep -q "最初の依頼を理解したら"; ok "初回=フルガイド見出し" test $? -eq 0
echo "$OUT" | grep -q "種別: 計画=進め方を決め文書化"; ok "種別5定義" test $? -eq 0
echo "$OUT" | grep -q "リサーチ"; ok "リサーチ語彙" test $? -eq 0
echo "$OUT" | grep -qF -- '--plan "<企画名[/NN] か なし>"'; ok "ガイドに--plan例" test $? -eq 0
echo "$OUT" | grep -q "計画列: 計画=これから置く先"; ok "計画列1行" test $? -eq 0
echo "$OUT" | grep -qF "対象repoの最寄りAGENTS.md"; ok "repo AGENTSで計画箱解決" test $? -eq 0
echo "$OUT" | grep -qF "宣言範囲の既存planを検索"; ok "宣言範囲で既存計画検索" test $? -eq 0
echo "$OUT" | grep -qF "root plansを推定・作成せず停止"; ok "計画箱不明時は停止" test $? -eq 0
echo "$OUT" | grep -qF "新しい可視sessionへhandoff"; ok "Privateから可視sessionへhandoff" test $? -eq 0
echo "$OUT" | grep -qF "既存session IDの移管・reparentはしない"; ok "session reparent禁止" test $? -eq 0
echo "$OUT" | grep -q "計画種別なら、置く前に3判定"; ok "3判定見出し" test $? -eq 0
[ "$(echo "$OUT" | grep -c -E '^ [^ ]')" = "4" ]; ok "3判定は4小項目(①②③置き場)" test $? -eq 0

echo "=== 4. ガード: slash / subagent / headless は空出力 ==="
OUT=$(echo '{"session_id":"badbad01-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/x.jsonl","cwd":"/tmp","prompt":"/compact"}' | claude_prompt)
[ -z "$OUT" ]; ok "スラッシュは無視" test $? -eq 0
OUT=$(echo '{"session_id":"badbad02-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/s/subagents/agent-x.jsonl","cwd":"/tmp","prompt":"サブの依頼"}' | claude_prompt)
[ -z "$OUT" ]; ok "subagentは無視" test $? -eq 0
OUT=$(echo "$J_UP" | AIJOBS_RUN=1 claude_prompt)
[ -z "$OUT" ]; ok "headless(AIJOBS_RUN)は無視" test $? -eq 0

echo "=== 5. Codex 受け口: JSON契約（SessionStart / UserPromptSubmit）==="
J3_SS='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","hook_event_name":"SessionStart"}'
J3_UP='{"session_id":"c0dec0de-0000-1111-2222-333344445555","transcript_path":"'$SP'/tx/proj/c0dec0de-0000.jsonl","cwd":"/tmp/repoZ","prompt":"Codexからの依頼テスト"}'
OUT=$(echo "$J3_SS" | codex_start)
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "ボードキー s:c0dec0de" in d["hookSpecificOutput"]["additionalContext"]'; ok "Codex SS=JSON" test $? -eq 0
OUT=$(echo "$J3_UP" | codex_prompt)
echo "$OUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d["hookSpecificOutput"]["additionalContext"]; assert "最初の依頼" in c and d["hookSpecificOutput"]["hookEventName"]=="UserPromptSubmit"'; ok "Codex UPS=JSONガイド" test $? -eq 0

echo; echo "== 結果: PASS=$PASS FAIL=$FAIL =="
[ "$FAIL" -eq 0 ]
