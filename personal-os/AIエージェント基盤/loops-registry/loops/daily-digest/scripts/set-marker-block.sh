#!/usr/bin/env bash
# daily-digest / set-marker-block — <!-- auto:<key>:begin/end --> の内側だけを冪等に全置換する。
# マーカー行そのもの・マーカー外（人間の手書き）は一切書き換えない。
# 痛点対策: 夜loopの無人編集が人間の行を壊さないよう、置換範囲をマーカー内側だけに固定する。
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: set-marker-block.sh <file> <key> <content-file>
  <key>           log | done | align
  <content-file>  マーカー内側に差し込む本文。0バイトなら空に冪等更新する。
  マーカー（begin/endどちらか）が無ければ何もせず exit 3（呼び出し側はスキップ扱いにする）。
EOF
  exit 2
}

file="${1:-}"; key="${2:-}"; content_file="${3:-}"
{ [ -n "$file" ] && [ -n "$key" ] && [ -n "$content_file" ]; } || usage
[ -f "$file" ] || { echo "ファイルが無い: $file" >&2; exit 2; }
[ -f "$content_file" ] || { echo "content-fileが無い: $content_file" >&2; exit 2; }

if ! grep -qE "^<!-- auto:${key}:begin" "$file" || ! grep -qE "^<!-- auto:${key}:end -->" "$file"; then
  echo "マーカー無し（skip）: auto:${key} in $file" >&2
  exit 3
fi

tmp="$(mktemp "${file}.tmp.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

awk -v key="$key" -v contentfile="$content_file" '
  BEGIN {
    inside = 0
    n = 0
    while ((getline line < contentfile) > 0) { n++; content[n] = line }
    close(contentfile)
  }
  $0 ~ ("^<!-- auto:" key ":begin") {
    print $0
    for (i = 1; i <= n; i++) print content[i]
    inside = 1
    next
  }
  $0 ~ ("^<!-- auto:" key ":end -->") {
    print $0
    inside = 0
    next
  }
  inside { next }
  { print }
' "$file" > "$tmp"

mv "$tmp" "$file"
trap - EXIT
echo "更新: auto:${key} in $file"
