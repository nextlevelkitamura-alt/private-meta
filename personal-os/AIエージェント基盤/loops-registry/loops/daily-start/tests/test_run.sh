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

# --- stub: 呼ばれたら CALL_LOG に1行残す。挙動は env で切り替える ---
# orca stub: ORCA_OK=1 なら `worktree ps` を exit 0（応答あり）、それ以外は exit 1（応答なし）。
cat > "$STUB_DIR/orca" <<'ORCA'
#!/usr/bin/env bash
echo "orca $*" >> "$CALL_LOG"
if [ "${ORCA_OK:-0}" = "1" ] && [ "$1" = "worktree" ] && [ "$2" = "ps" ]; then
  echo '{"result":{"worktrees":[]}}'
  exit 0
fi
exit 1
ORCA

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

chmod +x "$STUB_DIR/orca" "$STUB_DIR/cockpit.sh" "$STUB_DIR/claude"

# run.sh を stub 環境で1回実行。CALL_LOG を毎回リセット。挙動トグル（ORCA_OK 等）は呼び出し側で export 済み。
run_case() {
  : > "$CALL_LOG"
  DAILY_START_STATE_DIR="$SANDBOX/state" \
  DAILY_START_OUTPUT_DIR="$SANDBOX/out" \
  DAILY_START_LOCK_DIR="$SANDBOX/lock-$RANDOM" \
  DAILY_START_DATE="2026-07-20" \
  DAILY_START_COCKPIT="$STUB_DIR/cockpit.sh" \
  DAILY_START_ORCA_BIN="$STUB_DIR/orca" \
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

# === 2) Orca 応答あり・spawn 成功 → 可視ペイン起動（cockpit 呼び出し・claude 不使用） ===
export ORCA_OK=1 SPAWN_OK=1; run_case; rc=$?; unset ORCA_OK SPAWN_OK
if [ "$rc" = "0" ] && grep -q '^cockpit ' "$CALL_LOG" && ! grep -q '^claude ' "$CALL_LOG"; then
  ok "Orca 応答あり → cockpit spawn 起動・headless 不使用"
else
  ng "可視ペイン分岐（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 3) Orca 応答なし → headless フォールバック（claude 呼び出し・cockpit 不使用） ===
export ORCA_OK=0 HEADLESS_OK=1; run_case; rc=$?; unset ORCA_OK HEADLESS_OK
if [ "$rc" = "0" ] && grep -q '^claude ' "$CALL_LOG" && ! grep -q '^cockpit ' "$CALL_LOG"; then
  ok "Orca 応答なし → headless 起動・cockpit 不使用"
else
  ng "headless フォールバック分岐（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 4) Orca 応答あり・spawn 失敗 → headless フォールバック（cockpit も claude も呼ばれる） ===
export ORCA_OK=1 SPAWN_OK=0 HEADLESS_OK=1; run_case; rc=$?; unset ORCA_OK SPAWN_OK HEADLESS_OK
if [ "$rc" = "0" ] && grep -q '^cockpit ' "$CALL_LOG" && grep -q '^claude ' "$CALL_LOG"; then
  ok "spawn 失敗 → headless へフォールバック"
else
  ng "spawn 失敗フォールバック（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 5) 両方失敗 → exit 1 ===
export ORCA_OK=0 HEADLESS_OK=0; run_case; rc=$?; unset ORCA_OK HEADLESS_OK
if [ "$rc" = "1" ]; then
  ok "可視ペイン・headless 両方失敗 → exit 1"
else
  ng "両失敗 exit 1（rc=$rc・calls=$(cat "$CALL_LOG")）"
fi

# === 6) plist lint ===
if plutil -lint "$PLIST" >/dev/null 2>&1; then
  ok "plutil -lint OK"
else
  ng "plutil -lint 失敗"
fi

# === 7) StartCalendarInterval が Hour=10 Minute=3 で RunAtLoad が無い ===
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
