#!/usr/bin/env bash
# renderer / render-debounced.sh — Stop hook から起動する非同期debounceラッパ。
# 呼び出し元を一切ブロックしない（即return）。RENDERER_DEBOUNCE_SECONDS（既定60秒）の窓で
# 連続イベントを合流し、同時render は最大1（mkdirロック）。窓の後に必ず1回render.shが走る
# （trailing-edge・イベント取り逃しなし）。状態は RENDERER_STATE_DIR（既定 ~/.cache/personal-os-renderer）。
#
# 取りこぼし対策: トリガは必ず pending を touch してから lock を試みる。lock保持者は
# render完了後に pending を再確認し、render開始時刻より新しければ窓をやり直して再renderする
# （render実行中に来たイベントも拾う）。lock解放直後にも一度だけ再確認し、
# それでも新イベントがあれば自ら lock を取り直して処理を続ける（取れなければ新規トリガ側が処理する）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

state_dir="${RENDERER_STATE_DIR:-$HOME/.cache/personal-os-renderer}"
debounce_seconds="${RENDERER_DEBOUNCE_SECONDS:-60}"
mkdir -p "$state_dir" 2>/dev/null || true

render_args=("$@")
pending="$state_dir/pending"
lockdir="$state_dir/render.lock"

pending_mtime() {
  stat -f '%m' "$pending" 2>/dev/null || echo 0
}

# lockを保持している前提で、静穏窓を待って1回以上renderする。
# render中に新イベントが来ていたら窓をやり直す（取り逃さない）。
process_window() {
  local before after render_start after_render after_release

  while :; do
    while :; do
      before="$(pending_mtime)"
      sleep "$debounce_seconds"
      after="$(pending_mtime)"
      [ "$after" = "$before" ] && break
    done

    render_start="$after"
    echo "invoked $render_start" >> "$state_dir/invocations.log" 2>/dev/null || true
    "$SCRIPT_DIR/render.sh" "${render_args[@]}" >> "$state_dir/render.log" 2>&1 || true

    after_render="$(pending_mtime)"
    [ "$after_render" = "$render_start" ] && break
    # render実行中に新イベントが来ていた → 窓をやり直してもう一度render。
  done

  rmdir "$lockdir" 2>/dev/null || true

  # lock解放の直前・直後に来た新イベントの取りこぼし対策（最後にもう一度だけ確認）。
  after_release="$(pending_mtime)"
  if [ "$after_release" != "$render_start" ] && mkdir "$lockdir" 2>/dev/null; then
    process_window
  fi
  # ここで取れなければ、その新イベントをtouchした側（別プロセス）が処理する。
}

worker() {
  : > "$pending" 2>/dev/null || true

  # 既に誰かが窓を担当中なら pending の mtime 更新だけで終わる（その担当が拾う）。
  mkdir "$lockdir" 2>/dev/null || return 0

  process_window
}

worker </dev/null >/dev/null 2>&1 &
disown "$!" 2>/dev/null || true
exit 0
