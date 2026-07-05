#!/usr/bin/env bash
# orca-cockpit / cockpit.sh の spawn / 引数渡し起動 / send安全ガード / ペイン台帳(panes.jsonl) のテスト。
# 実orca CLIは叩かない: orcaをシェル関数でスタブしてからcockpit.shをsourceする（末尾main "$@"は
# helpで無害化）。実HOME・実state配下には一切書き込まない（COCKPIT_*_FILE/DIRを全てmktemp配下へ上書き）。
# cmd_spawn/cmd_sendはサブシェル/コマンド置換内で走るため、スタブの状態(agent数・create引数)は
# 変数でなくファイルで受け渡す（サブシェルの変数代入は親へ伝播しないため）。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCKPIT_SH="$HERE/cockpit.sh"

pass=0
fail=0

assert_eq(){ if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '[PASS] %s\n' "$1"; else fail=$((fail+1)); printf '[FAIL] %s: expected [%s] got [%s]\n' "$1" "$3" "$2"; fi; }
assert_contains(){ if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); printf '[PASS] %s\n' "$1"; else fail=$((fail+1)); printf '[FAIL] %s: expected to contain [%s]\n  got: %s\n' "$1" "$3" "$2"; fi; }
assert_not_contains(){ if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); printf '[FAIL] %s: expected NOT to contain [%s]\n  got: %s\n' "$1" "$3" "$2"; else pass=$((pass+1)); printf '[PASS] %s\n' "$1"; fi; }
assert_file(){ if [ -f "$2" ]; then pass=$((pass+1)); printf '[PASS] %s\n' "$1"; else fail=$((fail+1)); printf '[FAIL] %s: file無し %s\n' "$1" "$2"; fi; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/cockpit-spawn-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT
CREATE_CAPTURE_FILE="$WORKDIR/create-capture.log"; : > "$CREATE_CAPTURE_FILE"
SEND_CAPTURE_FILE="$WORKDIR/send-capture.log"; : > "$SEND_CAPTURE_FILE"
STUB_AGENTS_FILE="$WORKDIR/agents.count"; echo 0 > "$STUB_AGENTS_FILE"
set_agents(){ echo "$1" > "$STUB_AGENTS_FILE"; }

# ---- orca CLIスタブ ----
# terminal create: 引数をファイルへ捕捉＋「新ペインのagent出現」をシミュレート（count+1）＋ネストhandle返却。
# worktree ps: agents.countの数だけagentを持つ /fake/wt を返す。
orca(){
  case "$1 $2" in
    "terminal create")
      printf '%s\n' "$*" >> "$CREATE_CAPTURE_FILE"
      local c; c="$(cat "$STUB_AGENTS_FILE" 2>/dev/null || echo 0)"; echo $((c+1)) > "$STUB_AGENTS_FILE"
      printf '{"result":{"handle":{"handle":"term_stub","tabId":"t1"}}}'
      return 0 ;;
    "terminal send")
      [ -n "${SEND_CAPTURE_FILE:-}" ] && printf '%s\n' "$*" >> "$SEND_CAPTURE_FILE"
      # STALEHANDLE=ok:false+非0（明示エラー）。OKFALSE0=ok:false+exit0（本番hazard=終了コードだけでは
      # 検知できず --json ok で弾く経路のテスト・codexレビュー指摘）。
      case "$*" in
        *STALEHANDLE*) printf '{"ok":false,"error":{"code":"terminal_handle_stale"}}'; return 1 ;;
        *OKFALSE0*)    printf '{"ok":false,"error":{"code":"terminal_handle_stale"}}'; return 0 ;;
      esac
      printf '{"ok":true}'; return 0 ;;
    "terminal wait") return 0 ;;
    "terminal list") printf '{"result":{"terminals":[]}}'; return 0 ;;
    "terminal stop") return 0 ;;
    "worktree rm") printf '{"ok":true}'; return 0 ;;
    "worktree ps")
      python3 - "$(cat "$STUB_AGENTS_FILE" 2>/dev/null || echo 0)" <<'PY'
import sys, json
n = int(sys.argv[1])
agents = [{"agentType": "claude", "state": "working"} for _ in range(n)]
print(json.dumps({"result": {"worktrees": [
    {"path": "/fake/wt", "displayName": "D", "branch": "fake", "repo": "FakeRepo", "agents": agents}
]}}))
PY
      return 0 ;;
    *) return 0 ;;
  esac
}

# state系を全てWORKDIR配下へ隔離（実skills/orca-cockpit/state/へ書かない）。source前にexport。
export COCKPIT_STATE_DIR="$WORKDIR/state"
export COCKPIT_EVENTS_FILE="$WORKDIR/state/events.jsonl"
export COCKPIT_PANES_FILE="$WORKDIR/state/panes.jsonl"

# shellcheck source=/dev/null
source "$COCKPIT_SH" help >/dev/null 2>&1

LONG="SENTINEL_LONG_PROMPT_BODY_XYZ $(printf 'x%.0s' $(seq 1 300))"
PF="$WORKDIR/prompt.md"
printf '%s\n' "$LONG" > "$PF"

# ============================================================
# t1: _build_agent_wrapper がプロンプトを保存し exec起動ラッパーを生成する（リテラルUTF-8で保存パスを囲む）
# ============================================================
W1="$(_build_agent_wrapper "claude --model M" "$PF" "テスト役割/A" "20260703-000000")"
assert_file "(t1) wrapper生成" "$W1"
[ -x "$W1" ] && { pass=$((pass+1)); printf '[PASS] (t1) wrapperは実行可能\n'; } || { fail=$((fail+1)); printf '[FAIL] (t1) wrapperが非実行可能\n'; }
SAVED1="$COCKPIT_STATE_DIR/prompts/20260703-000000-テスト役割-A.md"
assert_file "(t1) プロンプト保存(記録兼用)" "$SAVED1"
assert_eq "(t1) 保存内容が一致" "$(cat "$SAVED1")" "$LONG"
assert_contains "(t1) wrapperにexec起動行(--でオプション終端しプロンプトを位置引数化)" "$(cat "$W1")" 'exec claude --model M -- "$(cat'
# 保存パスは $'...' でなくリテラルのダブルクォートで囲む（JPパスのエンコード崩れ回避）
assert_contains "(t1) 保存パスはリテラル(ダブルクォート)で囲む" "$(cat "$W1")" '"$(cat "'
assert_not_contains "(t1) %qのdollar-quote(octal)エスケープを使わない" "$(cat "$W1")" "\$'"
assert_not_contains "(t1) wrapperのexec行にプロンプト本文を直埋めしない" "$(grep '^exec' "$W1")" "SENTINEL_LONG_PROMPT_BODY_XYZ"

# ============================================================
# t2: spawn --no-mcp → 空mcp.json生成・wrapper--strict-mcp-config・短い--command・baseline増でconfirm・handle掘り出し
# ============================================================
set_agents 0
OUT2="$( ( cmd_spawn --worktree path:/fake/wt --title "中間3" --model claude-sonnet-5 --prompt-file "$PF" --owner "中間指揮官2" --stage "実装" --no-mcp ) 2>/dev/null )"
assert_file "(t2) 空mcp.json生成" "$COCKPIT_STATE_DIR/empty-mcp.json"
assert_contains "(t2) 空mcpはmcpServers空" "$(cat "$COCKPIT_STATE_DIR/empty-mcp.json")" '"mcpServers"'
W2="$(ls -t "$COCKPIT_STATE_DIR"/spawn/*.sh | head -1)"
assert_contains "(t2) wrapperに--strict-mcp-config" "$(cat "$W2")" "--strict-mcp-config --mcp-config"
CREATE2="$(tail -1 "$CREATE_CAPTURE_FILE")"
assert_contains "(t2) terminal createは 'bash <wrapper>' の短い--command" "$CREATE2" "--command bash "
assert_not_contains "(t2) コマンド行にプロンプト本文を載せない(ENAMETOOLONG回避)" "$CREATE2" "SENTINEL_LONG_PROMPT_BODY_XYZ"
assert_contains "(t2) 出力JSON mcp=off" "$OUT2" '"mcp":"off"'
assert_contains "(t2) baseline増加でagent確認済" "$OUT2" '"agent_confirmed":true'
assert_contains "(t2) ネストhandleからterm_を掘り出す" "$OUT2" '"terminal":"term_stub"'

# ============================================================
# t3: spawn（--no-mcp無し）→ wrapperに--strict-mcp-configを入れない・出力mcp=on
# ============================================================
set_agents 0
OUT3="$( ( cmd_spawn --worktree path:/fake/wt --title "mcp有り" --prompt-file "$PF" ) 2>/dev/null )"
W3="$(ls -t "$COCKPIT_STATE_DIR"/spawn/*.sh | head -1)"
assert_not_contains "(t3) --no-mcp無しならwrapperにstrict-mcp-config無し" "$(cat "$W3")" "--strict-mcp-config"
assert_contains "(t3) 出力JSON mcp=on" "$OUT3" '"mcp":"on"'

# ============================================================
# t4: spawnイベントが events.jsonl に owner付きで記録される
# ============================================================
assert_contains "(t4) event=spawn記録" "$(cat "$COCKPIT_EVENTS_FILE")" '"event": "spawn"'
assert_contains "(t4) owner付きspawnイベントが存在" "$(cat "$COCKPIT_EVENTS_FILE")" '"owner": "中間指揮官2"'

# ============================================================
# t5: ペイン台帳 panes.jsonl に1行記録される（keeperフェーズ2bの正本・書くだけ）
# ============================================================
assert_file "(t5) panes.jsonl生成" "$COCKPIT_PANES_FILE"
PANE_LINE="$(grep '中間3' "$COCKPIT_PANES_FILE" | head -1)"
assert_contains "(t5) handle(掘り出し済)記録" "$PANE_LINE" '"handle": "term_stub"'
assert_contains "(t5) worktree記録" "$PANE_LINE" '"worktree": "/fake/wt"'
assert_contains "(t5) role(title)記録" "$PANE_LINE" '"role": "中間3"'
assert_contains "(t5) owner記録" "$PANE_LINE" '"owner": "中間指揮官2"'
assert_contains "(t5) model記録" "$PANE_LINE" '"model": "claude-sonnet-5"'
assert_contains "(t5) prompt保存パス記録" "$PANE_LINE" '"prompt":'

# ============================================================
# t6: send安全ガード（見つかってagent 0なら拒否・--forceで上書き・agent有りは通す・不明(-1)は通す）
# ============================================================
set_agents 0
( cmd_send --terminal term_x --prompt "P" --worktree /fake/wt ) >/dev/null 2>&1
assert_eq "(t6) agent0で送信拒否(非0終了)" "$?" "1"
OUT6F="$( ( cmd_send --terminal term_x --prompt "P" --worktree /fake/wt --force ) 2>/dev/null )"
assert_contains "(t6) --forceで送信は通る" "$OUT6F" '"sent":true'
set_agents 1
OUT6OK="$( ( cmd_send --terminal term_x --prompt "P" --worktree /fake/wt ) 2>/dev/null )"
assert_contains "(t6) agent有りなら送信は通る" "$OUT6OK" '"sent":true'
# worktree未指定=ガード対象外（従来sendの後方互換・events.test.shの経路）
OUT6N="$( ( cmd_send --terminal term_x --prompt "P" ) 2>/dev/null )"
assert_contains "(t6) --worktree無しはガードせず通す(後方互換)" "$OUT6N" '"sent":true'

# ============================================================
# t7: send はstale/無効ハンドルを ok:false で検知して失敗する（誤送信の無音成功を塞ぐ・追加観点）
# 終了コードだけに頼らず --json の ok で判定する（環境差でstaleでもexit0を返し得るため）。
# ============================================================
set_agents 1   # worktreeガードは通し、handle検知の経路だけを分離してテスト
( cmd_send --terminal STALEHANDLE --prompt "P" --worktree /fake/wt ) >/dev/null 2>&1
assert_eq "(t7) staleハンドルへのsendは非0終了" "$?" "1"
OUT7="$( ( cmd_send --terminal STALEHANDLE --prompt "P" --worktree /fake/wt ) 2>/dev/null )"
assert_not_contains "(t7) staleハンドルでsent:trueを出さない" "$OUT7" '"sent":true'
# 本番hazard: 終了コード0でも ok:false なら誤送信として検知する（--json okで判定・終了コードに頼らない）
( cmd_send --terminal OKFALSE0 --prompt "P" --worktree /fake/wt ) >/dev/null 2>&1
assert_eq "(t7) ok:false+exit0でも検知して非0終了(本番hazard)" "$?" "1"
OUT7B="$( ( cmd_send --terminal OKFALSE0 --prompt "P" --worktree /fake/wt ) 2>/dev/null )"
assert_not_contains "(t7) ok:false+exit0でsent:trueを出さない" "$OUT7B" '"sent":true'

# ============================================================
# t8: title のシェルメタ文字を _safe_slug が無害化する（生成wrapperのcatパスでコマンド置換を起こさない・codex指摘2）
# ============================================================
EVIL='ev$(touch /tmp/PWNED_cockpit)il`id`;rm -rf x'
SLUG="$(_safe_slug "$EVIL")"
assert_not_contains "(t8) slugに \$ を残さない" "$SLUG" '$'
assert_not_contains "(t8) slugに backtick を残さない" "$SLUG" '`'
assert_not_contains "(t8) slugに ( を残さない" "$SLUG" '('
assert_not_contains "(t8) slugに ; を残さない" "$SLUG" ';'
WEVIL="$(_build_agent_wrapper "claude --model M" "$PF" "$EVIL" "20260703-222222")"
EXECLINE="$(grep '^exec' "$WEVIL")"
# exec行は正規の $(cat "<保存パス>") を持つ。titleに由来する注入 $(touch...) やバッククォートが
# 保存パス(＝slug)へ混入していないことを確認する（正規の $(cat は許容）。
assert_not_contains "(t8) exec行に注入 \$(touch を残さない" "$EXECLINE" '$(touch'
assert_not_contains "(t8) exec行に backtick を残さない" "$EXECLINE" '`'
[ ! -e /tmp/PWNED_cockpit ] && { pass=$((pass+1)); printf '[PASS] (t8) 注入は実行されていない\n'; } || { fail=$((fail+1)); printf '[FAIL] (t8) 注入が実行された(/tmp/PWNED_cockpit)\n'; rm -f /tmp/PWNED_cockpit; }

# ============================================================
# t9: opencode(引数渡し非対応)は「未投入」を正直に返し、未検証/レースになる別sendを撃たない（codex指摘1/2）。
#     claude(引数渡し)は prompt_delivered:true。cmd_up はこの値で phantom send イベントを避ける。
# ============================================================
: > "$SEND_CAPTURE_FILE"
OUT9="$(cmd_agent --terminal term_oc --kind opencode --prompt-file "$PF" 2>/dev/null)"
assert_contains "(t9) opencodeはprompt_delivered:false(未投入を正直に返す)" "$OUT9" '"prompt_delivered":"false"'
assert_not_contains "(t9) opencodeはプロンプトを別sendしない(zsh流出/未検証send回避)" "$(cat "$SEND_CAPTURE_FILE")" "SENTINEL_LONG_PROMPT_BODY_XYZ"
OUT9C="$(cmd_agent --terminal term_cl --kind claude --model claude-sonnet-5 --prompt-file "$PF" 2>/dev/null)"
assert_contains "(t9) claude(引数渡し)はprompt_delivered:true" "$OUT9C" '"prompt_delivered":"true"'
# 起動送信(bash wrapper)自体がstale/無効なら agent は起動せず、claudeでも prompt_delivered:false
# （起動送信を --json ok でゲート＝phantom send event を防ぐ・codexレビュー指摘）
OUT9S="$(cmd_agent --terminal STALEHANDLE --kind claude --model claude-sonnet-5 --prompt-file "$PF" 2>/dev/null)"
assert_contains "(t9) 起動送信staleならclaudeでもprompt_delivered:false" "$OUT9S" '"prompt_delivered":"false"'

# ============================================================
# t10: 不正なmodelトークン(シェルメタ文字)は弾く（コマンド注入防止・codex指摘2）
# ============================================================
( cmd_spawn --worktree path:/fake/wt --title T --model 'a;rm -rf /' --prompt-file "$PF" --no-mcp ) >/dev/null 2>&1
assert_eq "(t10) 不正modelでspawnは非0終了" "$?" "1"
( cmd_agent --terminal term_x --kind claude --model 'a$(x)' ) >/dev/null 2>&1
assert_eq "(t10) 不正modelでagentは非0終了" "$?" "1"

# ============================================================
echo "============================================"
printf 'PASS: %s  FAIL: %s\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
