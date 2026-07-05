#!/usr/bin/env bash
# renderer / claude-log-bullets — auto:log 行から Claude セッションの箇条書きを組み立てる
# （旧 daily-digest/build-content.sh の対話ログ整形ロジックの正本。ここへ一本化）。
# hook は short-sha（ポインタ）しか残さないので、subject 本文は git から解決する（AIを呼ばない）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"

daily_file="${1:?usage: claude-log-bullets.sh <daily-file>}"

log_lines="$("$DAILY_DIGEST_SCRIPTS/get-marker-block.sh" "$daily_file" log 2>/dev/null || true)"
[ -n "$log_lines" ] || exit 0

# auto:log の1行から "key=..." フィールド値を取り出す（パイプ区切り・前後空白トリム）。
field_value() {
  printf '%s' "$1" | awk -F'|' -v k="$2" '
    {
      for (i = 1; i <= NF; i++) {
        f = $i; gsub(/^[ \t]+|[ \t]+$/, "", f)
        if (index(f, k "=") == 1) { print substr(f, length(k) + 2); exit }
      }
    }'
}

while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in *"cwd="*) : ;; *) continue ;; esac
  ts="$(printf '%s' "$line" | awk -F'|' '{ s=$1; gsub(/^[ \t]+|[ \t]+$/, "", s); print s }')"
  cwd="$(field_value "$line" cwd)"
  repo="$(field_value "$line" repo)"
  branch="$(field_value "$line" branch)"
  commits="$(field_value "$line" commits)"
  sess="$(field_value "$line" session)"
  where="${repo:-$cwd}"
  [ -n "$branch" ] && where="$where ($branch)"
  header="- [auto] 対話セッション $ts: $where"
  [ -n "$sess" ] && header="$header / session=$sess"
  echo "$header"
  if [ -n "$commits" ] && [ -n "$cwd" ]; then
    IFS=',' read -ra _shas <<< "$commits" || true
    for sha in "${_shas[@]}"; do
      [ -z "$sha" ] && continue
      subj="$(git -C "$cwd" log -1 --pretty=%s "$sha" 2>/dev/null || true)"
      if [ -n "$subj" ]; then
        echo "  - ${sha} ${subj}"
      else
        echo "  - ${sha}"
      fi
    done
  fi
done <<< "$log_lines"
