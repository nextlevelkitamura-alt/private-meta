#!/usr/bin/env bash
# plan-ops / program-lint — program.mdの子計画マップを静的に整合チェックする。
#
# 痛点対策: 「マップactiveなのに実ファイル無し」「完了なのに完了条件未チェック」等の
#           手動追従ドリフトを機械検出する。ライブなレーン状態（cockpit/watch.sh）は見ない。
set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
usage: program-lint.sh <program.mdの絶対パス>
  違反0件: 「違反なし」を出してexit 0
  違反あり: <file>:<行>: <メッセージ> を列挙してexit 1

検査対象: マップNN↔plans/NN-*.md実在／子frontmatterのbacklink解決／
         状態語彙（GLOBAL_AGENTS.md §7＋保留）／「完了」なのに完了条件未チェック。
EOF
  exit 2
}

[ $# -eq 1 ] || usage
case "$1" in -h|--help) usage;; esac
[ -f "$1" ] || { echo "program.mdが見つからない: $1" >&2; exit 2; }

python3 "$SELFDIR/program_lint_core.py" "$1"
