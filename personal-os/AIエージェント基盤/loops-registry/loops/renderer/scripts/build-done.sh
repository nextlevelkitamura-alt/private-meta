#!/usr/bin/env bash
# renderer / build-done — auto:done マーカーへ差し込む本文を決定的順序で連結する。
# (1) Claude分（auto:log行から） (2) Codex分（session_index.jsonlから・時刻昇順） (3) 当日doneカード。
#
# 部品（claude-log-bullets.sh / codex-pull.sh / collect-done-cards.sh）の失敗は握りつぶさず、
# このスクリプト自体も非0で終了する。render.sh側は builder（このスクリプト）が非0終了した場合
# apply をスキップし auto:done の既存内容を保持する（空ファイルで上書きしない）ため、ここで
# 失敗を吸収して常に exit 0 してしまうと、その防御が発動せず auto:done が部分/空データで
# 上書きされてしまう（実測で確認された不具合）。
# 部品が「成功して0件・空出力」なのは正当な空置換として区別し、そのまま通す（冪等性は壊さない）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"

daily_file="${1:?usage: build-done.sh <daily-file> <YYYY-MM-DD>}"
date_str="${2:?date required}"

status=0

claude_bullets=""
if ! claude_bullets="$("$SCRIPT_DIR/claude-log-bullets.sh" "$daily_file")"; then
  echo "警告: claude-log-bullets.sh が失敗した（auto:doneのClaude分をスキップ）" >&2
  status=1
fi

codex_bullets=""
if ! codex_bullets="$("$SCRIPT_DIR/codex-pull.sh" "$date_str")"; then
  echo "警告: codex-pull.sh が失敗した（auto:doneのCodex分をスキップ）" >&2
  status=1
fi

done_cards=""
if ! done_cards="$("$DAILY_DIGEST_SCRIPTS/collect-done-cards.sh" "$date_str")"; then
  echo "警告: collect-done-cards.sh が失敗した（auto:doneのdoneカード分をスキップ）" >&2
  status=1
fi

[ -n "$claude_bullets" ] && printf '%s\n' "$claude_bullets"
[ -n "$codex_bullets" ] && printf '%s\n' "$codex_bullets"
[ -n "$done_cards" ] && printf '%s\n' "$done_cards"

exit "$status"
