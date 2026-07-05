#!/usr/bin/env bash
# renderer / build-goal — 年間計画（GOAL_BASE/年間計画/<YYYY>.md）の「## 領域別の目標」から
# auto:goal マーカーへ差し込む本文を決定的に組み立てる（AIを呼ばない）。
# 領域の順序はファイル出現順。bullet無し領域は「未記入」警告行にする。
set -euo pipefail

date_str="${1:?usage: build-goal.sh <YYYY-MM-DD>}"
: "${GOAL_BASE:?GOAL_BASE required}"

y="${date_str%%-*}"
plan_file="$GOAL_BASE/年間計画/${y}.md"

if [ ! -f "$plan_file" ]; then
  echo "- [auto] 警告: 年間計画ファイルが見つからない: $plan_file"
  exit 0
fi

awk -v year="$y" '
  BEGIN { insection = 0; domain = ""; n = 0 }
  /^## 領域別の目標/ { insection = 1; next }
  insection && /^## / { insection = 0 }
  insection && /^### / {
    if (domain != "") { order[n] = domain; n++ }
    domain = $0
    sub(/^### /, "", domain)
    gsub(/[ \t]+$/, "", domain)
    next
  }
  insection && /^- / {
    if (domain == "") next
    line = $0
    sub(/^- /, "", line)
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    if (line != "") {
      if (bullets[domain] == "") { bullets[domain] = line }
      else { bullets[domain] = bullets[domain] " ／ " line }
    }
    next
  }
  END {
    if (domain != "") { order[n] = domain; n++ }
    printf "🎯 %s年の的（今日のTODOはここに繋げる）:\n", year
    for (i = 0; i < n; i++) {
      d = order[i]
      if (bullets[d] != "") {
        printf "- %s: %s\n", d, bullets[d]
      } else {
        printf "- %s: ⚠️ 未記入 ── 埋めると逆算が効く\n", d
      }
    }
  }
' "$plan_file"
