#!/usr/bin/env bash
# daily-notion-sync / _paths.sh — 共通パス既定値。source して使う（単体実行しない）。
# renderer/daily-digest 配下には依存しない（独立loop化・plan.md方針1）。
# GOAL_BASE は board.py（hooks-registry/shared/session-board/board.py）の daily_path() と
# 同じ既定値・同じ組み立て規則にする（データ源が同一ファイルであるため）。
: "${GOAL_BASE:=$HOME/Private/personal-os/my-brain/ゴール}"
export GOAL_BASE

# daily_file_for <YYYY-MM-DD> : 当日デイリーの絶対パスを stdout に出す。
daily_file_for() {
  local d="$1" y rest m
  y="${d%%-*}"
  rest="${d#*-}"
  m="${rest%%-*}"
  printf '%s/デイリー/%s/%s/%s.md' "$GOAL_BASE" "$y" "$m" "$d"
}
