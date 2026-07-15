#!/usr/bin/env bash
# plan-ops / plan-lint — plan.md / 子計画.md / program.md の実行契約を静的検査する。
set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat >&2 <<'EOF'
usage: plan-lint.sh <plan.md|子計画.md|program.mdの明示path> [--allow-placeholders]
  実行契約、必須節、placeholder、親backlink、Programマップ、並列レーン宣言を検査する。
  --allow-placeholders は雛形生成直後だけの検査用で、placeholder検査を省略する。
EOF
  exit 2
}

[ $# -ge 1 ] || usage
path="$1"; shift
allow=0
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-placeholders) allow=1; shift ;;
    -h|--help) usage ;;
    *) echo "不明なオプション: $1" >&2; usage ;;
  esac
done
[ -f "$path" ] || { echo "計画ファイルが見つからない: $path" >&2; exit 2; }

args=("$path")
[ "$allow" = 1 ] && args+=(--allow-placeholders)
python3 "$SELFDIR/plan_lint_core.py" "${args[@]}"
