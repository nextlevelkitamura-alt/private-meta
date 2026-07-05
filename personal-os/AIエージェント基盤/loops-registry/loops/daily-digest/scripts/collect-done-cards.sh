#!/usr/bin/env bash
# daily-digest / collect-done-cards — ai-jobs/done の当日分カードを1行要約で列挙する。
# 「当日」の判定は mtime（jobctl.sh done で done/ へ mv された時刻）の日付部分で行う。
# run-card 本文は非追跡・揮発物なので、全文を転記せず担当/出所だけを抜き出す（secretは元々書かない契約）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_paths.sh
source "$SCRIPT_DIR/_paths.sh"

date_str="${1:?usage: collect-done-cards.sh <YYYY-MM-DD>}"
done_dir="$AIJOBS_BASE/done"

[ -d "$done_dir" ] || exit 0

for f in "$done_dir"/*; do
  [ -e "$f" ] || continue
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = ".gitkeep" ] && continue

  mtime_date="$(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null || echo '')"
  [ "$mtime_date" = "$date_str" ] || continue

  tanto="$(sed -n 's/^担当:[[:space:]]*//p' "$f" | head -n1)"
  dasho="$(sed -n 's/^出所:[[:space:]]*//p' "$f" | head -n1)"
  dasho_base=""
  [ -n "$dasho" ] && dasho_base="$(basename "$dasho")"

  line="完了カード: ${base}"
  [ -n "$tanto" ] && line="${line} ／ 担当:${tanto}"
  [ -n "$dasho_base" ] && line="${line} ／ 出所:${dasho_base}"
  echo "- [auto] ${line}"
done
