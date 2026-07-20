#!/usr/bin/env bash
# daily-start / tests/test_run.sh — run.sh の分岐を実 AI 起動なしで検査する。
# 起動コマンド（cockpit / orca / claude）を stub に差し替え、state・output・lock を tmp サンドボックスに逃がす。
# 実ボード・実 Orca・実 claude には一切触れない。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_SH="$LOOP_DIR/scripts/run.sh"
PLIST="$LOOP_DIR/com.kitamura.daily-start.plist"

pass=0; fail=0
ok() { echo "PASS: $1"; pass=$((pass+1)); }
ng() { echo "FAIL: $1" >&2; fail=$((fail+1)); }

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/daily-start-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

STUB_DIR="$SANDBOX/stubs"
mkdir -p "$STUB_DIR" "$SANDBOX/state" "$SANDBOX/out"

CALL_LOG="$SANDBOX/calls.log"
export CALL_LOG
# Orca 応答回復マーカー。orca-app stub が APP_RECOVER=1 の時に touch し、orca stub が ORCA_OK=recover で参照する。
RECOVER_FLAG="$SANDBOX/recover-flag"
export RECOVER_FLAG

# --- stub: 呼ばれたら CALL_LOG に1行残す。挙動は env で切り替える ---
# orca stub: `worktree ps` に対し、ORCA_OK=1 なら常に exit 0（即応答）、
#   ORCA_OK=recover なら RECOVER_FLAG が存在する時だけ exit 0（app 起動で回復した状態を模す）、
#   それ以外は exit 1（応答なし）。
cat > "$STUB_DIR/orca" <<'ORCA'
#!/usr/bin/env bash
echo "orca $*" >> "$CALL_LOG"
if [ "$1" = "worktree" ] && [ "$2" = "ps" ]; then
  if [ "${ORCA_OK:-0}" = "1" ]; then echo '{"result":{"worktrees":[]}}'; exit 0; fi
  if [ "${ORCA_OK:-0}" = "recover" ] && [ -f "${RECOVER_FLAG:-/nonexistent}" ]; then
    echo '{"result":{"worktrees":[]}}'; exit 0
  fi
fi
exit 1
ORCA

# orca-app stub: run.sh が Orca 不応答時に呼ぶ app 起動コマンドの代役。
#   APP_RECOVER=1 で RECOVER_FLAG を touch（＝以降 orca stub が応答するようになる）。
#   APP_OK=0 で起動コマンド自体が非0を返す（run.sh はそれでもポーリングを継続する）。
cat > "$STUB_DIR/orca-app" <<'APP'
#!/usr/bin/env bash
echo "orca-app $*" >> "$CALL_LOG"
[ "${APP_RECOVER:-0}" = "1" ] && touch "${RECOVER_FLAG:-/tmp/ds-recover-flag}"
[ "${APP_OK:-1}" = "1" ] && exit 0
exit 1
APP

# cockpit stub: SPAWN_OK=1 で成功(exit 0)、それ以外は失敗(exit 1)。
cat > "$STUB_DIR/cockpit.sh" <<'COCKPIT'
#!/usr/bin/env bash
echo "cockpit $*" >> "$CALL_LOG"
[ "${SPAWN_OK:-1}" = "1" ] && exit 0
exit 1
COCKPIT

# claude stub: HEADLESS_OK=1 で成功(exit 0)、それ以外は失敗(exit 1)。
cat > "$STUB_DIR/claude" <<'CLAUDE'
#!/usr/bin/env bash
echo "claude $*" >> "$CALL_LOG"
[ "${HEADLESS_OK:-1}" = "1" ] && exit 0
exit 1
CLAUDE

chmod +x "$STUB_DIR/orca" "$STUB_DIR/orca-app" "$STUB_DIR/cockpit.sh" "$STUB_DIR/claude"

# run.sh を stub 環境で1回実行。CALL_LOG と RECOVER_FLAG を毎回リセット。挙動トグルは呼び出し側で export 済み。
# ポーリングはテストでは既定 WAIT=0/INTERVAL=0（即時1回チェック）で瞬時に判定する。回復の順序を検証したい
# ケースだけ WAIT_SECS/POLL_INT を上書きして sleep 経路を通す。
run_case() {
  : > "$CALL_LOG"
  rm -f "$RECOVER_FLAG"
  DAILY_START_STATE_DIR="$SANDBOX/state" \
  DAILY_START_OUTPUT_DIR="$SANDBOX/out" \
  DAILY_START_LOCK_DIR="$SANDBOX/lock-$RANDOM" \
  DAILY_START_DATE="2026-07-20" \
  DAILY_START_COCKPIT="$STUB_DIR/cockpit.sh" \
  DAILY_START_ORCA_BIN="$STUB_DIR/orca" \
  DAILY_START_ORCA_APP="$STUB_DIR/orca-app" \
  DAILY_START_ORCA_WAIT_SECONDS="${WAIT_SECS:-0}" \
  DAILY_START_ORCA_POLL_INTERVAL="${POLL_INT:-0}" \
  DAILY_START_CLAUDE_BIN="$STUB_DIR/claude" \
    bash "$RUN_SH" >/dev/null 2>&1
}

# === 1) skip 分岐: done マーカーがある日は起動せず exit 0 ===
: > "$SANDBOX/state/done-2026-07-20"
ORCA_OK=1 SPAWN_OK=1 run_case; rc=$?
unset ORCA_OK SPAWN_OK
if [ "$rc" = "0" ] && [ ! -s "$CALL_LOG" ]; then
  ok "done マーカーあり → exit 0・起動コマンド未呼び出し"
else
  ng "skip 分岐（rc=$rc・calls=$(cat "$CALL_LOG" 2>/dev/null)）"
fi
rm -f "$SANDBOX/state/done-2026-07-20"

# === 2) Orca 即応答・spawn 成功 → 可視ペイン起動（cockpit・app 起動不要・claude 不使用） ===
export ORCA_OK=1 SPAWN_OK=1; run_case; rc=$?; unset ORCA_OK SPAWN_OK
if [ "$rc" = "0" ] && grep -q '^cockpit ' "$CALL_LOG" \
   && ! grep -q '^orca-app ' "$CALL_LOG" && ! grep -q '^claude ' "$CALL_LOG"; then
  ok "Orca 即応答 → cockpit spawn 起動・app 起動不要・headless 不使用"
else
  ng "即応答→可視ペイン分岐（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 3) Orca 不応答 → app 起動 → 応答回復 → 可視ペイン起動（orca-app と cockpit・claude 不使用） ===
# ポーリング経路（sleep 込み）を通すため WAIT/INTERVAL を非0にする。回復マーカーは app stub が touch。
export ORCA_OK=recover APP_RECOVER=1 SPAWN_OK=1 WAIT_SECS=5 POLL_INT=1
run_case; rc=$?
unset ORCA_OK APP_RECOVER SPAWN_OK WAIT_SECS POLL_INT
if [ "$rc" = "0" ] && grep -q '^orca-app ' "$CALL_LOG" && grep -q '^cockpit ' "$CALL_LOG" \
   && ! grep -q '^claude ' "$CALL_LOG"; then
  ok "Orca 不応答 → app 起動で回復 → cockpit spawn・headless 不使用"
else
  ng "app 起動→回復分岐（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 4) Orca 不応答 → app 起動しても回復せず → headless フォールバック（orca-app と claude・cockpit 不使用） ===
export ORCA_OK=recover APP_RECOVER=0 HEADLESS_OK=1 WAIT_SECS=2 POLL_INT=1
run_case; rc=$?
unset ORCA_OK APP_RECOVER HEADLESS_OK WAIT_SECS POLL_INT
if [ "$rc" = "0" ] && grep -q '^orca-app ' "$CALL_LOG" && grep -q '^claude ' "$CALL_LOG" \
   && ! grep -q '^cockpit ' "$CALL_LOG"; then
  ok "Orca 不応答・回復せず → headless 起動・cockpit 不使用"
else
  ng "app 起動→非回復→headless 分岐（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 5) Orca 即応答・spawn 失敗 → headless フォールバック（cockpit も claude も呼ばれる・app 起動不要） ===
export ORCA_OK=1 SPAWN_OK=0 HEADLESS_OK=1; run_case; rc=$?; unset ORCA_OK SPAWN_OK HEADLESS_OK
if [ "$rc" = "0" ] && grep -q '^cockpit ' "$CALL_LOG" && grep -q '^claude ' "$CALL_LOG" \
   && ! grep -q '^orca-app ' "$CALL_LOG"; then
  ok "spawn 失敗 → headless へフォールバック"
else
  ng "spawn 失敗フォールバック（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 6) 可視ペイン・headless 両方失敗 → exit 1（Orca 不応答・回復せず・headless も失敗） ===
export ORCA_OK=recover APP_RECOVER=0 HEADLESS_OK=0; run_case; rc=$?; unset ORCA_OK APP_RECOVER HEADLESS_OK
if [ "$rc" = "1" ]; then
  ok "可視ペイン・headless 両方失敗 → exit 1"
else
  ng "両失敗 exit 1（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 7) plist lint ===
if plutil -lint "$PLIST" >/dev/null 2>&1; then
  ok "plutil -lint OK"
else
  ng "plutil -lint 失敗"
fi

# === 8) StartCalendarInterval が Hour=10 Minute=3 で RunAtLoad が無い ===
h="$(plutil -extract StartCalendarInterval.Hour raw "$PLIST" 2>/dev/null)"
m="$(plutil -extract StartCalendarInterval.Minute raw "$PLIST" 2>/dev/null)"
if [ "$h" = "10" ] && [ "$m" = "3" ] && ! plutil -extract RunAtLoad raw "$PLIST" >/dev/null 2>&1; then
  ok "発火 10:03・RunAtLoad なし"
else
  ng "発火設定（Hour=$h Minute=$m・RunAtLoad 有無を確認）"
fi

echo "----"
echo "PASS=$pass FAIL=$fail"
[ "$fail" = "0" ]
