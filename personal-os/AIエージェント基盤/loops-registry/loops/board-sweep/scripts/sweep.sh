#!/bin/zsh
# board-sweep — ⏸行の自動判定を1回実行（launchd入口・薄い起動役。ロジックは scripts/sweep.py）。
# 既定は dry-run（ボード無変更・判定ログのみ）。流し込みは人間確認後に --apply を付ける。
# AIJOBS_RUN=1 で自分と子プロセス（headless LLM）の session-board 自己登録を防ぐ。
set -u
export AIJOBS_RUN=1
DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/env python3 "$DIR/scripts/sweep.py" "$@"
