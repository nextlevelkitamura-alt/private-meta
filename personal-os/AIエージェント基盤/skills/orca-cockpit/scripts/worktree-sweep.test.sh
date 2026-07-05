#!/usr/bin/env bash
# orca-cockpit / worktree-sweep.sh の判定関数 _classify のテスト。
# 計画07完了条件「マージ未済／未コミット差分／稼働中は候補にしない（誤検知ガード）」を担保する。
# worktree-sweep.sh を source すると BASH_SOURCE ガードで sweep_run は走らない（実orca/実git не呼ぶ）。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEP_SH="$HERE/worktree-sweep.sh"

pass=0
fail=0

assert_eq(){ # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    pass=$((pass+1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail+1)); printf '[FAIL] %s: expected [%s] got [%s]\n' "$1" "$3" "$2"
  fi
}

# source で _classify を取り込む（sweep_run は BASH_SOURCE!=$0 で走らない）。
# shellcheck source=/dev/null
source "$SWEEP_SH"

# (a) 正常系: マージ済み・clean・idle/empty → candidate
assert_eq "(a) merged+clean+idle=候補"  "$(_classify 1 1 idle)"  "candidate"
assert_eq "(a) merged+clean+empty=候補" "$(_classify 1 1 empty)" "candidate"

# (b) 誤検知ガード: 未マージは候補にしない
assert_eq "(b) 未マージは注意" "$(_classify 0 1 idle)" "attention:未マージ"

# (c) 誤検知ガード: 未コミット差分(dirty)は候補にしない
assert_eq "(c) dirtyは注意" "$(_classify 1 0 idle)" "attention:未コミット差分"

# (d) 誤検知ガード: 稼働中(active)は候補にしない（merged/cleanでも）
assert_eq "(d) 稼働中は注意" "$(_classify 1 1 active)" "attention:稼働中"

# (e) エージェントerrorは候補にしない
assert_eq "(e) errorは注意" "$(_classify 1 1 error)" "attention:エージェントerror"

# (f) 複合理由は ; 区切りで全て出る（稼働中+未マージ+未コミット差分）
assert_eq "(f) 複合理由" "$(_classify 0 0 active)" "attention:稼働中; 未マージ; 未コミット差分"

# (g) 保守側の確認: merged判定不能(0)は clean/idle でも候補にしない
assert_eq "(g) merged不能(0)は候補にしない" "$(_classify 0 1 empty)" "attention:未マージ"

printf '\n合計: %d pass / %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
