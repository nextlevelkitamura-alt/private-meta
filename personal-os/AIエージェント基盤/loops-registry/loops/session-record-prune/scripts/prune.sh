#!/bin/zsh
# session-record-prune — 古いセッション記録を保持日数超で ~/.Trash へ移す（launchd 日次入口）。
# 本処理は scripts/prune.py（Python・安全ガード・保持日数の既定は30日・方式=Trash移動）。
# 入口は薄いグルー（フック言語規約: launchd入口は sh 可）。--apply で実移動。
set -u
DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec /usr/bin/env python3 "$DIR/scripts/prune.py" --apply
