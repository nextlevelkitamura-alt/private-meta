#!/usr/bin/env bash
# daily-digest / run.sh — launchd `com.kitamura.daily-digest`（12:30/18:30/23:30 JST）のエントリポイント。
# 生成ロジックの正本は renderer（../../renderer/scripts）に一本化した。このファイルは
# plistのコマンドパス互換を保ったまま render.sh（＋digest.sh）へ委譲する薄いラッパ。
#
# usage: run.sh [YYYY-MM-DD] [--snapshot]
#   引数無し（従来どおり）: 23:30の「締めの最終レンダ」= render.sh --final + digest.sh。
#   --snapshot            : 12:30/18:30向け。--final無しの通常レンダ + digest.shのみ。
#
# digest.sh はベストエフォート機能（LLM要約）のため、その失敗はrun.sh全体の成否
# （終了コード）に影響させない。render.sh の成否だけをrun.shの終了コードにする
# （--final時の従来動作を維持）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_SCRIPTS="$(cd "$SCRIPT_DIR/../../renderer/scripts" && pwd)"
RENDERER_SCRIPT="$RENDERER_SCRIPTS/render.sh"
DIGEST_SCRIPT="$RENDERER_SCRIPTS/digest.sh"

snapshot=0
date_str=""
for arg in "$@"; do
  case "$arg" in
    --snapshot) snapshot=1 ;;
    -*) echo "不明なオプション: $arg" >&2; exit 2 ;;
    *) date_str="$arg" ;;
  esac
done

render_args=()
[ -n "$date_str" ] && render_args+=("$date_str")
[ "$snapshot" -eq 1 ] || render_args+=(--final)

status=0
"$RENDERER_SCRIPT" ${render_args[@]+"${render_args[@]}"} || status=$?

digest_args=()
[ -n "$date_str" ] && digest_args+=("$date_str")
"$DIGEST_SCRIPT" ${digest_args[@]+"${digest_args[@]}"} || true

exit "$status"
