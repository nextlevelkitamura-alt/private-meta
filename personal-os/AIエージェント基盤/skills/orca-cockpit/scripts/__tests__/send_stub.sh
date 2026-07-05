#!/usr/bin/env bash
# watch.test.sh 用のsendスタブ: 呼び出し引数をSEND_STUB_LOGへ1行記録し、SEND_STUB_RC(既定0)で終了する。
# 実orca/実cockpit.shへは一切触れない（合成テスト専用）。
printf '%s\n' "$*" >> "${SEND_STUB_LOG:?SEND_STUB_LOGが未設定}"
exit "${SEND_STUB_RC:-0}"
