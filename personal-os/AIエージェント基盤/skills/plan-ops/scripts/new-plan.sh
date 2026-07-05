#!/usr/bin/env bash
# plan-ops / new-plan — テンプレ正本(skills/plan-ops/templates/)から単発plan.md/program.mdを生成する。
#
# 痛点対策: テンプレ本文の正本が areas/AGENTS.md §3 の埋め込みテキストのみだった二重管理の芽を、
#           単一正本(templates/)からの生成に置き換える。中身（目的/現状/方針等）は書かない＝雛形のみ。
set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SELFDIR/../templates"

usage() {
  cat >&2 <<'EOF'
usage: new-plan.sh --out <生成する.mdの絶対パス> [--program] [--class <分類>] [--kind <種別>]
  --out      生成先の絶対パス（必須。親ディレクトリが無ければ作成。既存ファイルは上書きしない）
  --program  単発plan.mdでなくprogram.mdテンプレ（子計画マップ雛形付き）を生成する
  --class    分類（skill/repo/loop/横断 等）。省略時はプレースホルダのまま
  --kind     種別（新規作成/既存改善/統合整理）。省略時はプレースホルダのまま

テンプレ本文の正本: skills/plan-ops/templates/{plan.md,program.md}（areas/AGENTS.md §3 転記）
EOF
  exit 2
}

out="" is_program=0 class="" kind=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2;;
    --program) is_program=1; shift;;
    --class) class="${2:-}"; shift 2;;
    --kind) kind="${2:-}"; shift 2;;
    -h|--help) usage;;
    *) echo "不明なオプション: $1" >&2; usage;;
  esac
done

[ -n "$out" ] || { echo "--out は必須" >&2; usage; }
case "$out" in /*) ;; *) echo "--out は絶対パスで指定: $out" >&2; exit 2;; esac
[ -e "$out" ] && { echo "既に存在する（上書きしない）: $out" >&2; exit 1; }

if [ "$is_program" = 1 ]; then
  tpl="$TEMPLATES/program.md"
else
  tpl="$TEMPLATES/plan.md"
fi
[ -f "$tpl" ] || { echo "テンプレが見つからない: $tpl" >&2; exit 1; }

mkdir -p "$(dirname "$out")"

python3 - "$tpl" "$out" "$class" "$kind" "$is_program" <<'PYEOF'
import re, sys
tpl, out, klass, kind, is_program = sys.argv[1:6]
with open(tpl, encoding="utf-8") as f:
    content = f.read()
if klass:
    ph = "<skill/repo/loop>" if is_program == "1" else "<skill/repo/loop/横断>"
    content = content.replace(ph, klass, 1)
if kind:
    content = re.sub(r"(種別: )<新規作成/既存改善/統合整理>", lambda m: m.group(1) + kind, content, count=1)
with open(out, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF

echo "$out"
