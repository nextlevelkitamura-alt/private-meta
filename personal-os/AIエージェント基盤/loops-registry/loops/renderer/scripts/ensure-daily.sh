#!/usr/bin/env bash
# renderer / ensure-daily — 当日デイリーが無ければテンプレから決定的に生成する。
# 既にファイルがあれば一切触らない（上書きしない）。テンプレが無ければ警告のみでクラッシュしない。
set -euo pipefail

daily_file="${1:?usage: ensure-daily.sh <daily-file> <YYYY-MM-DD> <template-file>}"
date_str="${2:?date required}"
template_file="${3:?template required}"

[ -f "$daily_file" ] && exit 0

if [ ! -f "$template_file" ]; then
  echo "警告: テンプレが無いため当日デイリーを生成できない: $template_file" >&2
  exit 0
fi

y="${date_str%%-*}"
dow="$(LC_ALL=C date -j -f '%Y-%m-%d' "$date_str" '+%a' 2>/dev/null || echo '???')"

mkdir -p "$(dirname "$daily_file")"

tmp="$(mktemp "${TMPDIR:-/tmp}/ensure-daily.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

sed \
  -e "s/<YYYY-MM-DD>/$date_str/g" \
  -e "s/<曜>/$dow/g" \
  -e "s/<YYYY>/$y/g" \
  "$template_file" > "$tmp"

# -n（clobber回避）: 直前のチェックとこのmvの間に他プロセスが生成していたら上書きせずskipする。
# その場合 tmp はこの場に残るので、trap の rm -f に掃除を任せる（先勝ちを尊重・エラーにしない）。
mv -n "$tmp" "$daily_file" 2>/dev/null || true
if [ ! -e "$tmp" ]; then
  echo "生成: $daily_file"
fi
