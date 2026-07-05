#!/usr/bin/env bash
# plan-ops __tests__ 共通アサーションヘルパ。各テストファイルが source して使う。
# 合成データ専用。実HOME・実デイリー・~/Private実ファイルへ書き込むテストはここに置かない。
pass=0
fail=0

assert_eq() { # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail + 1)); printf '[FAIL] %s: expected [%s] got [%s]\n' "$1" "$3" "$2"
  fi
}

assert_contains() { # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    pass=$((pass + 1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail + 1)); printf '[FAIL] %s: expected to contain [%s]\n  got: %s\n' "$1" "$3" "$2"
  fi
}

assert_not_contains() { # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF -- "$3"; then
    fail=$((fail + 1)); printf '[FAIL] %s: expected NOT to contain [%s]\n' "$1" "$3"
  else
    pass=$((pass + 1)); printf '[PASS] %s\n' "$1"
  fi
}

report() {
  printf '\n合計: %d pass / %d fail\n' "$pass" "$fail"
  [ "$fail" -eq 0 ]
}
