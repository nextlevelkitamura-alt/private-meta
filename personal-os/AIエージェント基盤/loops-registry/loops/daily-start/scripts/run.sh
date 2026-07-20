#!/usr/bin/env bash
# daily-start / run.sh — 朝10:03（JST）の「デイリースタート」儀式を起動する薄い起動役。
# 設計正本: ../../../../my-brain/areas/ai運用/plans/planning/2026-07-09-デイリー運用刷新/plans/03-儀式の自動実行.md（実装スコープ C）
#
# このスクリプトは「起動」だけを担う。themes/todos の起票・判断・question 発行・実行ログ書き込みは、
# 起動された AI（daily-start スキルの無人モード）が行う。ここは判断を持たない（起動役に徹する）。
#
# 実行の流れ:
#   ① 多重起動防止ロック（mkdir ベース・stale 自己修復。macOS に flock が無いため既存 loop と同方式）。
#   ② 当日の実行ログ state/done-<YYYY-MM-DD(JST)> があれば「skip: already done」を残して exit 0
#      （手動で「デイリースタート」を実行済みの日は、10:03 の定期起動をスキップする）。
#   ③ Orca CLI 応答確認。応答が無ければ Orca.app を起動し（`open -a Orca`）、上限秒までポーリングして
#      runtime の応答回復を待つ（人間指示 2026-07-21「Orca でしっかり起動できる形」）。
#   ④ 応答が取れたら cockpit.sh spawn で可視1ペインを Private repo に起動（人が監督できる既定経路）。
#   ⑤ Orca が上限までに応答しない（または spawn 失敗）なら claude -p で headless 起動（フォールバック）。
#   ⑥ ④⑤どちらも起動に失敗したら output ログにエラーを残し exit 1（リトライは launchd に任せず今回は無し）。
#
# 実行ログ done-<date> は起動された AI（スキル側）が書く。run.sh は書かない（②で読むだけ）。
# secret/token は一切扱わない（このスクリプトは認証情報に触れない）。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- 差し替え可能な設定（既定値。テスト・運用調整用に env で上書きできる） ---
STATE_DIR="${DAILY_START_STATE_DIR:-$LOOP_DIR/state}"
OUTPUT_DIR="${DAILY_START_OUTPUT_DIR:-$LOOP_DIR/output/logs}"
LOCK_DIR="${DAILY_START_LOCK_DIR:-/tmp/daily-start.lock}"
LOCK_STALE_SECONDS="${DAILY_START_LOCK_STALE_SECONDS:-3600}"   # headless 実行が長引く可能性を見て 1h
TODAY="${DAILY_START_DATE:-$(TZ=Asia/Tokyo date '+%Y-%m-%d')}"
LOG_FILE="${DAILY_START_LOG_FILE:-$OUTPUT_DIR/daily-start.log}"

# 起動対象（AI runtime）。モデルは AIモデル一覧.md のレーン規約に従い実装時に選定（loop.md「モデル選定」参照）。
# 既定は claude-sonnet-5（cockpit spawn の既定と揃える）。判断を重くしたい時は人間が opus4.8 等へ差し替える。
DS_MODEL="${DAILY_START_MODEL:-claude-sonnet-5}"
DS_WT="${DAILY_START_WT:-name:Private}"                        # cockpit spawn の worktree selector
DS_PERM="${DAILY_START_PERM:-acceptEdits}"                     # 可視ペインの permission-mode
DS_PROMPT_FILE="${DAILY_START_PROMPT_FILE:-$SCRIPT_DIR/prompt.md}"
DS_OWNER="${DAILY_START_OWNER:-daily-start-loop}"

# Orca アプリ起動（Orca 不応答時にまず GUI を立ち上げてから応答を待つ）。
# 既定は `open -a Orca`（/Applications/Orca.app 実在を確認済み）。`orca open` も「起動＋runtime到達待ち」を
# 行う純正経路で代替可（loop.md「Orca 起動強化」参照）。テストでは stub パスに差し替える。
ORCA_APP_CMD="${DAILY_START_ORCA_APP:-open -a Orca}"
ORCA_WAIT_SECONDS="${DAILY_START_ORCA_WAIT_SECONDS:-60}"   # アプリ起動後、応答回復を待つ上限（秒）
ORCA_POLL_INTERVAL="${DAILY_START_ORCA_POLL_INTERVAL:-3}"  # 応答ポーリングの間隔（秒）

# 起動コマンド（フルパス解決。launchd の最小 PATH でも動くよう command -v → 既知パス fallback）。
COCKPIT="${DAILY_START_COCKPIT:-/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/orca-cockpit/scripts/cockpit.sh}"
ORCA_BIN="${DAILY_START_ORCA_BIN:-$(command -v orca 2>/dev/null || echo /Users/kitamuranaohiro/.local/bin/orca)}"
CLAUDE_BIN="${DAILY_START_CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo /Users/kitamuranaohiro/.npm-global/bin/claude)}"
# headless の tool 実行許可。既定は acceptEdits（安全側）。完全無人で board.py 等を実行させるには
# 人間が DAILY_START_HEADLESS_ARGS='--dangerously-skip-permissions' を plist env に設定する（loop.md 参照）。
HEADLESS_ARGS="${DAILY_START_HEADLESS_ARGS:---permission-mode acceptEdits}"

mkdir -p "$STATE_DIR" "$OUTPUT_DIR" 2>/dev/null || true

log() { # <message> — 時刻付き1行を stdout（launchd が StandardOut に拾う）とログファイルへ。
  local line
  line="$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S') daily-start: $1"
  echo "$line"
  echo "$line" >> "$LOG_FILE" 2>/dev/null || true
}

# --- ① 多重起動防止ロック（mkdir はアトミック。stale なら自己修復して奪う） ---
if [ -d "$LOCK_DIR" ]; then
  lock_mtime="$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)"
  now_ts="$(date +%s)"
  lock_age=$((now_ts - lock_mtime))
  if [ "$lock_age" -gt "$LOCK_STALE_SECONDS" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
fi
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "skip: 前回 run がロック中のため多重起動を回避（$LOCK_DIR）"
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# --- ② 当日の冪等ガード（手動実行済みならスキップ） ---
DONE_MARKER="$STATE_DIR/done-$TODAY"
if [ -e "$DONE_MARKER" ]; then
  log "skip: already done（$DONE_MARKER 済み・起動しない）"
  exit 0
fi

# 起動プロンプトの存在確認（無ければ起動しても意味が無い＝失敗扱い）。
if [ ! -f "$DS_PROMPT_FILE" ]; then
  log "error: 起動プロンプトが見つからない（$DS_PROMPT_FILE）"
  exit 1
fi

# --- ③ Orca 応答確認 → 不応答なら app 起動＋ポーリング ---
orca_responsive() {
  [ -n "$ORCA_BIN" ] && [ -x "$ORCA_BIN" ] || return 1
  # worktree ps が exit 0 で返れば Orca アプリと疎通できている（GUI 未起動なら非0で降りる）。
  "$ORCA_BIN" worktree ps --json >/dev/null 2>&1
}

launch_orca_app() { # Orca.app を起動する（応答回復は呼び出し側が待つ）。成功=0 / 失敗=非0
  [ -n "$ORCA_APP_CMD" ] || { log "warn: Orca 起動コマンドが空（DAILY_START_ORCA_APP 未設定）"; return 1; }
  log "起動: Orca.app（$ORCA_APP_CMD・応答回復を最大 ${ORCA_WAIT_SECONDS}s 待つ）"
  # 文字列コマンド（`open -a Orca` 等）も stub パスも同じ経路で起動できるよう shell 経由で実行。
  bash -c "$ORCA_APP_CMD" >>"$LOG_FILE" 2>&1
}

# Orca が応答するまで ORCA_WAIT_SECONDS を上限にポーリングする。応答すれば 0、上限超過で 1。
# アプリ起動直後に応答することもあるため、まず即時チェックしてから間隔を空けて再試行する。
wait_for_orca() {
  local deadline now
  now="$(date +%s)"
  deadline=$((now + ORCA_WAIT_SECONDS))
  while :; do
    if orca_responsive; then return 0; fi
    now="$(date +%s)"
    [ "$now" -ge "$deadline" ] && return 1
    sleep "$ORCA_POLL_INTERVAL"
  done
}

# Orca 応答を確保する（既に応答／app 起動→回復のいずれか）。確保できたら 0、できなければ 1。
ensure_orca_responsive() {
  if orca_responsive; then return 0; fi
  log "info: Orca 応答なし → Orca.app 起動を試みる"
  launch_orca_app || log "warn: Orca.app 起動コマンドが非0（回復ポーリングは継続する）"
  wait_for_orca
}

launch_visible_pane() { # 成功=0 / 失敗=非0
  [ -x "$COCKPIT" ] || { log "warn: cockpit.sh が実行できない（$COCKPIT）"; return 1; }
  log "起動: 可視ペイン（cockpit spawn・model=$DS_MODEL・wt=$DS_WT）"
  "$COCKPIT" spawn \
    --worktree "$DS_WT" \
    --title "daily-start" \
    --model "$DS_MODEL" \
    --permission-mode "$DS_PERM" \
    --prompt-file "$DS_PROMPT_FILE" \
    --owner "$DS_OWNER" \
    --no-mcp >>"$LOG_FILE" 2>&1
}

launch_headless() { # 成功=0 / 失敗=非0
  [ -n "$CLAUDE_BIN" ] && [ -x "$CLAUDE_BIN" ] || { log "warn: claude CLI が実行できない（$CLAUDE_BIN）"; return 1; }
  log "起動: headless（claude -p・model=$DS_MODEL・args=$HEADLESS_ARGS）"
  # プロンプト本文を -p に渡して1回実行（single-fire の calendar job なので前景実行でよい）。
  # shellcheck disable=SC2086
  "$CLAUDE_BIN" -p "$(cat "$DS_PROMPT_FILE")" --model "$DS_MODEL" $HEADLESS_ARGS >>"$LOG_FILE" 2>&1
}

if ensure_orca_responsive; then
  if launch_visible_pane; then
    log "ok: 可視ペインを起動した（実体の起票は起動された AI が行う）"
    exit 0
  fi
  log "warn: 可視ペイン起動に失敗 → headless へフォールバック"
else
  log "info: Orca が上限までに応答しない → headless で起動"
fi

# --- ⑤ headless フォールバック ---
if launch_headless; then
  log "ok: headless 起動が完了した（実体の起票は起動された AI が行う）"
  exit 0
fi

# --- ⑥ ④⑤どちらも失敗 ---
log "error: 可視ペイン・headless のどちらも起動できなかった（今回は起票なし・リトライは次回 launchd 発火に任せる）"
exit 1
