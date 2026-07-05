#!/usr/bin/env bash
# daily-digest / _paths.sh — 共通パス既定値。source して使う（単体実行しない）。
# 本番は既定値のまま使う。テスト時だけ GOAL_BASE / AIJOBS_BASE を環境変数で上書きする。
#
# export する理由: これを source する側（render.sh・session-daily-log.sh等）は自分の
# シェル変数としては GOAL_BASE/AIJOBS_BASE を持つが、export しないと子プロセス
# （build-goal.sh等）には渡らない。実環境（hook/launchd起動でGOAL_BASEが環境に無い場合）で
# build-goal.sh が『GOAL_BASE required』で即死し、auto:goal が空置換される不具合の原因だった。
# ここで一度exportしておけば、_paths.sh を source する全スクリプト・その子プロセス全経路
# （render.sh→部品／hook→render-debounced.sh→render.sh／daily-digest run.sh→render.sh）で
# 一貫して解決する。
: "${GOAL_BASE:=$HOME/Private/personal-os/my-brain/ゴール}"
: "${AIJOBS_BASE:=$HOME/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs}"
: "${AREAS_BASE:=$HOME/Private/personal-os/my-brain/areas}"
export GOAL_BASE AIJOBS_BASE AREAS_BASE

# daily_file_for <YYYY-MM-DD> : 当日デイリーの絶対パスを stdout に出す。
daily_file_for() {
  local d="$1" y rest m
  y="${d%%-*}"
  rest="${d#*-}"
  m="${rest%%-*}"
  printf '%s/デイリー/%s/%s/%s.md' "$GOAL_BASE" "$y" "$m" "$d"
}
