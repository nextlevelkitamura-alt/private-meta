#!/bin/zsh
# board-reconcile — session-board の生存照合を1回実行（launchd 5分毎の保険）。
# 本処理は hooks-registry/shared/session-board/board.py reconcile（flock付き・当日ボードのみ）。
set -u
BOARD="/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/hooks-registry/shared/session-board/board.py"
exec /usr/bin/env python3 "$BOARD" reconcile
