#!/usr/bin/env bash
# renderer / tests / keeper-tick-tests.sh — 統合見張り毎分tick入口（keeper-tick.sh・子06フェーズ1）の
# テスト。keeper.sh 自身の検知ロジック・seen重複ガードの正本テストは watch-keeper/tests/keeper-tests.sh。
# ここは tick入口ラッパの契約だけを検証する:
#   (1) keeper-tick.sh が keeper.sh を起動し、検知が通知・alerts.jsonlに載る（相乗り配線）
#   (2) 連続2tick（=1分間隔を模擬）で同一状態なら通知は1回だけ
#       （keeper.sh の seen.txt 完全一致ガードが tick を跨いで効く＝1分化で二重通知しない）
#   (3) KEEPER_TICK_DISABLED 非空で tick 全体 skip（keeper.sh を呼ばない・lanesコアテストの切り離し口）
#   (4) keeper.sh が失敗しても keeper-tick は exit 0（フェイルセーフ・呼び出し元本流を止めない）
# 実orca CLI・実osascript・実HOME書込・実claudeは一切使わない（KEEPER_* envでstub）。
# 終了コードで合否（0=全PASS／非0=1件以上FAIL）。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_DIR="$(cd "$TESTS_DIR/.." && pwd)"
KEEPER_TICK="$RENDERER_DIR/scripts/keeper-tick.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/keeper-tick-tests.XXXXXX")" || { echo "TEST_ROOT作成に失敗" >&2; exit 1; }
[ -d "$TEST_ROOT" ] || { echo "TEST_ROOT作成に失敗（存在しない）: $TEST_ROOT" >&2; exit 1; }
cleanup() {
  case "${TEST_ROOT:-}" in ""|"/"|"/tmp"|"$HOME"|"$HOME/") return 0 ;; esac
  case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/keeper-tick-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap cleanup EXIT

pass=0; fail=0; fails=()
check() { local name="$1"; shift; if "$@"; then echo "[PASS] $name"; pass=$((pass+1)); else echo "[FAIL] $name"; fail=$((fail+1)); fails+=("$name"); fi; }

# agent持ちworktreeでDONE_MARKERを出すfixture（keeper-tests.shのFIX_DONE相当）。
FIX_DONE='{"result":{"worktrees":[{"path":"/fake/wt/impl-lane","displayName":"impl","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"実装完了しました。\nIMPL_DONE"}]}]}}'

new_fixture() { local d f; d="$(mktemp -d "$TEST_ROOT/fx.XXXXXX")"; f="$d/ps.json"; printf '%s' "$1" > "$f"; printf '%s' "$f"; }
# 通知呼び出しを title<TAB>body で $1 に記録するstub。実osascriptは呼ばない。
new_notify_stub() {
  local log="$1" d stub
  d="$(mktemp -d "$TEST_ROOT/notify.XXXXXX")"; stub="$d/notify.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
printf '%s\t%s\n' "\$1" "\$2" >> "$log"
STUB
  chmod +x "$stub"; printf '%s' "$stub"
}
new_state_dir() { mktemp -d "$TEST_ROOT/state.XXXXXX"; }
count_lines() { [ -f "$1" ] || { echo 0; return; }; wc -l < "$1" | tr -d ' '; }

# keeper-tick.sh を1tick実行する。KEEPER_* env は keeper-tick 経由で keeper.sh へ透過する
# （prefix代入はコマンドの環境になり子プロセス keeper.sh に継承される＝keeper-tests.sh と同方式）。
run_tick() { # <ps_json> <state_dir> <notify_log> [disabled]
  local ps="$1" state="$2" nlog="$3" disabled="${4:-}" stub
  stub="$(new_notify_stub "$nlog")"
  KEEPER_TICK_DISABLED="$disabled" \
  KEEPER_PS_CMD="cat $ps" \
  KEEPER_STATE_DIR="$state" \
  KEEPER_NOTIFY_CMD="$stub" \
  KEEPER_PGREP_CMD="echo 1" \
  KEEPER_AUTOPILOT="0" \
  COCKPIT_EVENTS_FILE="$state/no-events.jsonl" \
  "$KEEPER_TICK"
}

t_relay() {
  local ps state nlog
  ps="$(new_fixture "$FIX_DONE")"; state="$(new_state_dir)"; nlog="$TEST_ROOT/relay.log"
  run_tick "$ps" "$state" "$nlog" "" || { echo "keeper-tick が非0終了"; return 1; }
  grep -q '"kind": "DONE_MARKER"' "$state/alerts.jsonl" 2>/dev/null || { echo "検知がalerts.jsonlに無い"; return 1; }
  grep -qF "DONE_MARKER" "$nlog" 2>/dev/null || { echo "通知本文にDONE_MARKERが無い"; return 1; }
}

t_two_ticks_dedup() {
  local ps state nlog n
  ps="$(new_fixture "$FIX_DONE")"; state="$(new_state_dir)"; nlog="$TEST_ROOT/dedup.log"
  run_tick "$ps" "$state" "$nlog" "" || return 1
  run_tick "$ps" "$state" "$nlog" "" || return 1
  n="$(count_lines "$nlog")"
  [ "$n" -eq 1 ] || { echo "連続2tick後の通知回数が1でない（1分二重通知）: $n"; return 1; }
}

t_disabled_skips() {
  local ps state nlog
  ps="$(new_fixture "$FIX_DONE")"; state="$(new_state_dir)"; nlog="$TEST_ROOT/disabled.log"
  run_tick "$ps" "$state" "$nlog" "1" || { echo "DISABLED時にexit非0"; return 1; }
  [ -f "$nlog" ] && { echo "KEEPER_TICK_DISABLEDなのに通知された"; return 1; }
  { [ -f "$state/alerts.jsonl" ] && [ -s "$state/alerts.jsonl" ]; } && { echo "DISABLEDなのにalertsが書かれた"; return 1; }
  return 0
}

t_failsafe_exit0() {
  # KEEPER_PS_CMD が空出力 → keeper.sh は「ps空」でexit 0、keeper-tick もフェイルセーフでexit 0。
  local state nlog stub rc
  state="$(new_state_dir)"; nlog="$TEST_ROOT/failsafe.log"; stub="$(new_notify_stub "$nlog")"
  KEEPER_TICK_DISABLED="" KEEPER_PS_CMD="true" KEEPER_STATE_DIR="$state" \
    KEEPER_NOTIFY_CMD="$stub" KEEPER_PGREP_CMD="echo 1" KEEPER_AUTOPILOT="0" "$KEEPER_TICK"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "keeper.sh失敗(ps空)でkeeper-tickがexit非0: $rc"; return 1; }
}

check "相乗り配線: keeper-tickがkeeper.shを起動し検知が通知/記録される" t_relay
check "1分二重通知しない: 連続2tickで通知1回（seen.txtガードがtickを跨ぐ）" t_two_ticks_dedup
check "KEEPER_TICK_DISABLEDでtick全体skip（keeper.shを呼ばない）" t_disabled_skips
check "keeper.sh失敗でもkeeper-tickはexit 0（フェイルセーフ）" t_failsafe_exit0

echo "=================================="
echo "PASS: $pass / $((pass + fail))"
if [ "$fail" -gt 0 ]; then echo "FAILED: ${fails[*]}"; exit 1; fi
exit 0
