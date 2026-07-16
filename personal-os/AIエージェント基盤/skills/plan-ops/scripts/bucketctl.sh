#!/usr/bin/env bash
# 互換CLI。詳細な遷移・容量・終了記録の検証は bucketctl_core.py が一元化する。
set -euo pipefail
SELFDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SELFDIR/bucketctl_core.py" "$@"
