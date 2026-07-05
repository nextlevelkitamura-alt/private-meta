#!/usr/bin/env bash
# renderer / claude-backfill — hook が取りこぼした Claude セッションを auto:log 末尾に追記する（pull保証）。
# 既存行は一切変更・並べ替えしない。CLAUDE_PROJECTS_BASE 配下の当日(JST) mtime の *.jsonl のうち
# session_id（ファイル名stem）が既存行に無いものだけを、タイムスタンプ昇順で決定的に追記する。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"

daily_file="${1:?usage: claude-backfill.sh <daily-file> <YYYY-MM-DD>}"
date_str="${2:?date required}"
projects_base="${CLAUDE_PROJECTS_BASE:-$HOME/.claude/projects}"

get_marker="$DAILY_DIGEST_SCRIPTS/get-marker-block.sh"
set_marker="$DAILY_DIGEST_SCRIPTS/set-marker-block.sh"

set +e
existing="$("$get_marker" "$daily_file" log 2>/dev/null)"
rc=$?
set -e
if [ "$rc" -eq 3 ]; then
  echo "警告: auto:log マーカーが無いため Claude backfill をスキップ: $daily_file" >&2
  exit 0
elif [ "$rc" -ne 0 ]; then
  exit "$rc"
fi

[ -d "$projects_base" ] || exit 0

existing_sessions="$(printf '%s\n' "$existing" | grep -oE 'session=[^ |]+' | sed 's/^session=//' || true)"

sanitize_field() { printf '%s' "$1" | tr '\r\n' '  '; }
sanitize_inline() { printf '%s' "$1" | tr '\r\n|' '  /'; }

rows_file="$(mktemp "${TMPDIR:-/tmp}/renderer-backfill-rows.XXXXXX")"
merged_file="$(mktemp "${TMPDIR:-/tmp}/renderer-backfill-merged.XXXXXX")"
cleanup() { rm -f "$rows_file" "$merged_file"; }
trap cleanup EXIT

while IFS= read -r -d '' f; do
  mtime_date="$(TZ=Asia/Tokyo stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null || echo '')"
  [ "$mtime_date" = "$date_str" ] || continue

  session_id="$(basename "$f" .jsonl)"
  if [ -n "$existing_sessions" ] && printf '%s\n' "$existing_sessions" | grep -qxF "$session_id"; then
    continue
  fi

  cwd_path="$(jq -r 'select(.cwd != null) | .cwd' "$f" 2>/dev/null | head -1 || true)"
  [ -n "$cwd_path" ] || continue

  ts_epoch="$(stat -f '%m' "$f" 2>/dev/null || echo 0)"
  timestamp="$(TZ=Asia/Tokyo date -r "$ts_epoch" '+%Y-%m-%d %H:%M JST' 2>/dev/null || echo "$date_str 00:00 JST")"

  safe_cwd="$(sanitize_field "$cwd_path")"
  safe_session="$(sanitize_field "$session_id")"
  safe_transcript="$(sanitize_field "$f")"

  new_line="$timestamp | cwd=$safe_cwd"
  if git -C "$cwd_path" rev-parse --git-dir >/dev/null 2>&1; then
    repo_root="$(git -C "$cwd_path" rev-parse --show-toplevel 2>/dev/null || true)"
    repo=""
    [ -n "$repo_root" ] && repo="$(sanitize_inline "$(basename "$repo_root")")"
    branch="$(sanitize_inline "$(git -C "$cwd_path" branch --show-current 2>/dev/null || true)")"
    dirty="$(git -C "$cwd_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    session_start="$(jq -r 'select(.timestamp) | .timestamp' "$f" 2>/dev/null | head -1 || true)"
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

  printf '%s\t%s\t%s\n' "$ts_epoch" "$session_id" "$new_line" >> "$rows_file"
done < <(find "$projects_base" -type f -name '*.jsonl' -print0 2>/dev/null)

[ -s "$rows_file" ] || exit 0

{
  [ -n "$existing" ] && printf '%s\n' "$existing"
  sort -t $'\t' -k1,1n -k2,2 "$rows_file" | cut -f3-
} > "$merged_file"

"$set_marker" "$daily_file" log "$merged_file" >/dev/null
