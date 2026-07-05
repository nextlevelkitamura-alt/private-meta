#!/usr/bin/env bash
# plan-ops / new-child — テンプレ正本(skills/plan-ops/templates/子計画.md)から
# programの子計画ファイル(plans/NN-*.md)を生成する。
#
# 親計画: backlinkは --out から --program への相対パスを自動算出する（手書きのパス間違いを潰す）。
# 子計画マップへの行追加は対象外（progctlはset=既存ブロック更新のみ・追加は非スコープ）。
set -euo pipefail

SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SELFDIR/../templates"

usage() {
  cat >&2 <<'EOF'
usage: new-child.sh --out <生成する子計画.mdの絶対パス> --program <親program.mdの絶対パス> [--class <分類>] [--kind <種別>]
  --out      生成先（例: .../plans/11-新しい子計画.md）。既存ファイルは上書きしない
  --program  親program.mdの絶対パス（必須・実在チェック）。生成ファイルの「親計画:」backlinkを
             --outからの相対パスで自動算出して埋める
  --class    分類。省略時はプレースホルダのまま
  --kind     種別。省略時はプレースホルダのまま

テンプレ本文の正本: skills/plan-ops/templates/子計画.md（areas/AGENTS.md §3 転記）
生成後、子計画マップ（program.md側）へこの子を追記するのは引き続き手動（progctlはset専用）。
EOF
  exit 2
}

out="" program="" class="" kind=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2;;
    --program) program="${2:-}"; shift 2;;
    --class) class="${2:-}"; shift 2;;
    --kind) kind="${2:-}"; shift 2;;
    -h|--help) usage;;
    *) echo "不明なオプション: $1" >&2; usage;;
  esac
done

[ -n "$out" ] || { echo "--out は必須" >&2; usage; }
[ -n "$program" ] || { echo "--program は必須" >&2; usage; }
case "$out" in /*) ;; *) echo "--out は絶対パスで指定: $out" >&2; exit 2;; esac
case "$program" in /*) ;; *) echo "--program は絶対パスで指定: $program" >&2; exit 2;; esac
[ -f "$program" ] || { echo "親program.mdが見つからない: $program" >&2; exit 1; }
[ -e "$out" ] && { echo "既に存在する（上書きしない）: $out" >&2; exit 1; }

tpl="$TEMPLATES/子計画.md"
[ -f "$tpl" ] || { echo "テンプレが見つからない: $tpl" >&2; exit 1; }

mkdir -p "$(dirname "$out")"

python3 - "$tpl" "$out" "$program" "$class" "$kind" <<'PYEOF'
import os, re, sys
tpl, out, program, klass, kind = sys.argv[1:6]
with open(tpl, encoding="utf-8") as f:
    content = f.read()
rel = os.path.relpath(program, os.path.dirname(out))
content = content.replace("../program.md", rel, 1)
# 分類:/種別: の直後の <…> は同一プレースホルダ文字列のため、直前ラベルにアンカーして個別置換する
if klass:
    content = re.sub(r"(分類: )<…>", lambda m: m.group(1) + klass, content, count=1)
if kind:
    content = re.sub(r"(種別: )<…>", lambda m: m.group(1) + kind, content, count=1)
with open(out, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF

echo "$out"
