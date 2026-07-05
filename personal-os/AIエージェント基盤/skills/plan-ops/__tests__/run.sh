#!/usr/bin/env bash
# plan-ops __tests__ 一括実行。各テストファイルのpass/fail数を合算して最終集計を出す。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

total_pass=0
total_fail=0
overall_rc=0

for t in "$HERE"/test_*.sh; do
  echo "==== $(basename "$t") ===="
  out="$(bash "$t")"
  rc=$?
  printf '%s\n' "$out"
  n_pass="$(printf '%s\n' "$out" | tail -2 | grep -oE '[0-9]+ pass' | grep -oE '[0-9]+')"
  n_fail="$(printf '%s\n' "$out" | tail -2 | grep -oE '[0-9]+ fail' | grep -oE '[0-9]+')"
  total_pass=$((total_pass + ${n_pass:-0}))
  total_fail=$((total_fail + ${n_fail:-0}))
  [ "$rc" -eq 0 ] || overall_rc=1
  echo
done

echo "==== 総合計: ${total_pass} pass / ${total_fail} fail ===="
exit "$overall_rc"
