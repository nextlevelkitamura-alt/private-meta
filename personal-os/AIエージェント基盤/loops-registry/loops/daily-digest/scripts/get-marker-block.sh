#!/usr/bin/env bash
# daily-digest / get-marker-block — <!-- auto:<key>:begin/end --> の内側だけを抽出して表示する。
# 対になる set-marker-block.sh の読み取り版。マーカーが片方でも無ければ何もせず exit 3。
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: get-marker-block.sh <file> <key>
  <key>  log | done | align （<!-- auto:<key>:begin --> 〜 <!-- auto:<key>:end --> の内側を出す）
  マーカーが無い場合は何も出力せず exit 3（呼び出し側は「入力0件」として扱ってよい）。
EOF
  exit 2
}

file="${1:-}"; key="${2:-}"
{ [ -n "$file" ] && [ -n "$key" ]; } || usage
[ -f "$file" ] || { echo "ファイルが無い: $file" >&2; exit 2; }

if ! grep -qE "^<!-- auto:${key}:begin" "$file" || ! grep -qE "^<!-- auto:${key}:end -->" "$file"; then
  echo "マーカー無し: auto:${key} in $file" >&2
  exit 3
fi

awk -v key="$key" '
  BEGIN { inside = 0 }
  $0 ~ ("^<!-- auto:" key ":begin") { inside = 1; next }
  $0 ~ ("^<!-- auto:" key ":end -->") { inside = 0; next }
  inside { print }
' "$file"
