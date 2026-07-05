#!/usr/bin/env bash
# renderer / build-board-plans — auto:board-plans マーカーへ差し込む「計画ボード」本文を組み立てる。
# AREAS_BASE配下（my-brain/areas/*/plans/active/*）の全領域active一覧（plan.md単発 or program.md子
# 計画マップ）を決定的に整形する（AIを呼ばない）。旧 my-brain/ダッシュボード.md のbullet書式
# （「優先(◎/○) 計画名 … 領域」＋ 場所:）を踏襲する（areas/AGENTS.md §2）。
#
# 部品（plan-scan.sh）の失敗は握りつぶさず非0で終了する。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

plans=""
if ! plans="$("$SCRIPT_DIR/plan-scan.sh")"; then
  echo "警告: plan-scan.sh が失敗した（auto:board-plansの更新に必要なデータが取得できない）" >&2
  exit 1
fi

if [ -z "$plans" ]; then
  echo "- [auto] active計画なし。"
  exit 0
fi

while IFS='|' read -r kind a b c d; do
  case "$kind" in
    plan)
      area="$a"; priority="$b"; title="$c"; path="$d"
      mark="${priority:-・}"
      echo "- [auto] ${mark} ${title} … ${area}"
      echo "  場所: ${path}"
      ;;
    program)
      area="$a"; priority="$b"; title="$c"; path="$d"
      mark="${priority:-・}"
      echo "- [auto] ${mark} ${title} … ${area}（program）"
      echo "  場所: ${path}"
      ;;
    child)
      no="$a"; name="$b"; cstatus="$c"
      echo "  子${no} ${name}: ${cstatus}"
      ;;
  esac
done <<< "$plans"
