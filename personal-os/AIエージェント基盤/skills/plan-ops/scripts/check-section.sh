#!/usr/bin/env bash
# plan-ops / check-section — markdown の指定セクションだけを抽出して表示 or パターン判定する。
#
# 痛点③対策: ファイル全体を grep すると完了条件の範囲外（例示・別節・「なぜ未確定」等）を
#            誤って拾う。完了条件が明示する「対象セクション」に範囲を絞ってから判定する。
# 使い方の前提: areas/AGENTS.md §3「各項目は対象（ファイル/セクション）を明示する」。
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: check-section <file> <section-heading> [grep-pattern]
  <section-heading> は見出しテキスト（先頭の # は付けない）。前方一致で照合するので、
  "## 子計画マップ   ※ …" のような末尾コメント付き見出しは "子計画マップ" だけで指定してよい。

  抽出範囲: 一致した見出し行の次行から、同レベル以上の見出しが来る直前まで。
  pattern 無し: セクション本文をそのまま表示（人/AIが目視判定する）。
  pattern 有り: そのセクション内だけで grep -E し、一致行と件数を出す。
                exit 0 = 1件以上一致 / exit 1 = 一致なし。
EOF
  exit 2
}

file="${1:-}"; heading="${2:-}"; pat="${3:-}"
{ [ -n "$file" ] && [ -n "$heading" ]; } || usage
[ -f "$file" ] || { echo "ファイルが無い: $file" >&2; exit 2; }

# 見出し（# の数=レベル）から、同レベル以上の見出しが来るまでを抽出。
# 見出し本文は前方一致（startswith）で照合する。
section="$(awk -v h="$heading" '
  function level(s,  n){ if (match(s, /^#+/)) return RLENGTH; return 0 }
  /^#+[[:space:]]/ {
    t=$0; sub(/^#+[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
    lv=level($0)
    if (inside && lv <= curlvl) inside=0
    if (!inside && index(t, h)==1) { inside=1; curlvl=lv; next }
    next
  }
  inside { print }
' "$file")"

if [ -z "$section" ]; then
  echo "セクションが空 or 見つからない: 「$heading」 in $file" >&2
  exit 1
fi

if [ -z "$pat" ]; then
  printf '%s\n' "$section"
  exit 0
fi

hits="$(printf '%s\n' "$section" | grep -nE "$pat" || true)"
if [ -n "$hits" ]; then cnt="$(printf '%s\n' "$hits" | grep -c .)"; else cnt=0; fi
[ -n "$hits" ] && printf '%s\n' "$hits"
echo "── 一致 ${cnt} 件（範囲: ${file} ## ${heading}）"
[ "$cnt" -gt 0 ]
