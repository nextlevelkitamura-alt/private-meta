#!/usr/bin/env bash
# inbox-triage 専用の new-plan.sh ラッパ — --out を plans/planning/ 配下に強制する権限ゲート。
# 生成ロジック・テンプレ正本は plan-ops new-plan.sh（ここに本文コピーしない）。
# 経緯: 敵対的レビュー(2026-07-09)が「new-plan.sh の allow 無制限だと planning 外へ書ける」穴を実証
#       → allowlist はこのラッパのみを許可し、素の new-plan.sh と mkdir を allow から外した。
set -euo pipefail

NEW_PLAN="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/plan-ops/scripts/new-plan.sh"

out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--out" ]; then out="$a"; fi
  prev="$a"
done

[ -n "$out" ] || { echo "new-plan-planning: --out <絶対パス> が必要" >&2; exit 2; }
case "$out" in
  *"/plans/planning/"*) ;;
  *) echo "new-plan-planning: --out は plans/planning/ 配下のみ許可: $out" >&2; exit 3;;
esac
case "$out" in
  *".."*) echo "new-plan-planning: パスに .. を含めない" >&2; exit 3;;
esac

exec bash "$NEW_PLAN" "$@"
