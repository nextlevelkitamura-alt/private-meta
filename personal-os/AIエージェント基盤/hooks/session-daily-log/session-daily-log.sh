#!/usr/bin/env bash
# Claude Code Stop hook: upsert a session pointer into today's daily auto:log block.
set -euo pipefail

if [ -n "${AIJOBS_RUN:-}" ]; then
  exit 0
fi

json_input="$(cat || true)"

read_json_string() {
  local expr="$1"
  jq -er "$expr // empty | strings" <<<"$json_input" 2>/dev/null || true
}

hook_event_name="$(read_json_string '.hook_event_name')"
[ "$hook_event_name" = "Stop" ] || exit 0

session_id="$(read_json_string '.session_id')"
cwd_path="$(read_json_string '.cwd')"
transcript_path="$(read_json_string '.transcript_path')"

if [ -z "$session_id" ] || [ -z "$cwd_path" ] || [ -z "$transcript_path" ]; then
  exit 0
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
foundation_root="${AI_AGENT_FOUNDATION_ROOT:-$(cd "$script_dir/../.." && pwd -P)}"
daily_scripts_dir="$foundation_root/loops-registry/loops/daily-digest/scripts"
paths_script="$daily_scripts_dir/_paths.sh"
get_marker="$daily_scripts_dir/get-marker-block.sh"
set_marker="$daily_scripts_dir/set-marker-block.sh"

if [ ! -r "$paths_script" ] || [ ! -x "$get_marker" ] || [ ! -x "$set_marker" ]; then
  exit 0
fi

# shellcheck source=/dev/null
source "$paths_script"

today="${SESSION_DAILY_LOG_DATE:-$(TZ=Asia/Tokyo date '+%Y-%m-%d')}"
daily_file="$(daily_file_for "$today")"

# renderer（当日ファイル生成・auto:goal/log backfill/done/align の統合レンダラ）を非同期debounce起動する。
# 呼び出し元（このhook・ひいてはStop本体）を絶対にブロックしない。失敗はすべて握りつぶす。
trigger_renderer() {
  local renderer_script="$foundation_root/loops-registry/loops/renderer/scripts/render-debounced.sh"
  [ -x "$renderer_script" ] || return 0
  ( "$renderer_script" "$today" >/dev/null 2>&1 & disown ) 2>/dev/null || true
}

if [ ! -f "$daily_file" ]; then
  # 当日ファイルが無くても即exitしない: renderer が生成する（hookはauto:logのupsertができないだけ）。
  trigger_renderer
  exit 0
fi

tmp_current="$(mktemp "${TMPDIR:-/tmp}/session-daily-log.current.XXXXXX")"
tmp_updated="$(mktemp "${TMPDIR:-/tmp}/session-daily-log.updated.XXXXXX")"
cleanup() {
  rm -f "$tmp_current" "$tmp_updated"
}
trap cleanup EXIT

if ! "$get_marker" "$daily_file" log >"$tmp_current" 2>/dev/null; then
  exit 0
fi

sanitize_field() {
  printf '%s' "$1" | tr '\r\n' '  '
}

# パイプ区切りを壊さないよう、埋め込むフィールドから改行と '|' を除去する。
sanitize_inline() {
  printf '%s' "$1" | tr '\r\n|' '  /'
}

timestamp="$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M JST')"
safe_cwd="$(sanitize_field "$cwd_path")"
safe_session="$(sanitize_field "$session_id")"
safe_transcript="$(sanitize_field "$transcript_path")"

# --- git 事実を安全側で収集（夜loop が要約しやすいように材料を濃くする）---
# 規律: 載せるのはポインタ／メタのみ。コミットは short-sha（＝git へのポインタ）で、
# 本文・差分・secret は書かない。subject 等の本文は夜loop が git から解決する。
# git 失敗はすべて握りつぶす（記録係は non-blocking／値が取れなければそのフィールドを省く）。
new_line="$timestamp | cwd=$safe_cwd"
if git -C "$cwd_path" rev-parse --git-dir >/dev/null 2>&1; then
  repo_root="$(git -C "$cwd_path" rev-parse --show-toplevel 2>/dev/null || true)"
  repo=""
  [ -n "$repo_root" ] && repo="$(sanitize_inline "$(basename "$repo_root")")"
  branch="$(sanitize_inline "$(git -C "$cwd_path" branch --show-current 2>/dev/null || true)")"
  dirty="$(git -C "$cwd_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  # セッション開始時刻＝transcript の最初の timestamp。その後に積まれたコミットだけを拾う。
  session_start="$( { jq -r 'select(.timestamp) | .timestamp' "$transcript_path" 2>/dev/null || true; } | head -1 || true )"
  commits=""
  if [ -n "$session_start" ]; then
    commits="$(git -C "$cwd_path" log --since="$session_start" --pretty=%h 2>/dev/null | paste -s -d, - 2>/dev/null || true)"
  fi
  [ -n "$repo" ]   && new_line="$new_line | repo=$repo"
  [ -n "$branch" ] && new_line="$new_line | branch=$branch"
  [ -n "$dirty" ]  && new_line="$new_line | dirty=$dirty"
  new_line="$new_line | commits=$commits"
fi
new_line="$new_line | session=$safe_session | transcript=$safe_transcript"

awk_ok=1
awk -v session="$safe_session" -v replacement="$new_line" '
  BEGIN { replaced = 0 }
  {
    n = split($0, fields, /\|/)
    found = 0
    for (i = 1; i <= n; i++) {
      field = fields[i]
      gsub(/^[ \t]+|[ \t]+$/, "", field)
      if (field == "session=" session) {
        found = 1
      }
    }
    if (found) {
      if (!replaced) {
        print replacement
        replaced = 1
      }
      next
    }
    print
  }
  END {
    if (!replaced) {
      print replacement
    }
  }
' "$tmp_current" >"$tmp_updated" || awk_ok=0

# awk 失敗時は空の tmp_updated で書き戻さない（auto:log を消さないため）。set_marker 失敗も握りつぶす。
if [ "$awk_ok" = 1 ]; then
  "$set_marker" "$daily_file" log "$tmp_updated" >/dev/null 2>/dev/null || true
fi

trigger_renderer

# 記録係は常に非ブロッキング。どんな内部失敗でも Claude を止めない（exit 2 を避ける）。
exit 0
