#!/usr/bin/env bash
# renderer / build-align — auto:align マーカーへ差し込む集計本文を決定的に組み立てる（AIを呼ばない）。
#
# build-done.sh と同じ方針: 部品（claude-log-bullets.sh / codex-pull.sh / collect-done-cards.sh）の
# 失敗は握りつぶさず、このスクリプト自体も非0で終了する（render.sh側の『builder失敗→applyスキップ・
# 既存内容保持』防御に乗せるため）。部品が成功して0件なのは正当な集計結果として区別し、そのまま通す。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"

daily_file="${1:?usage: build-align.sh <daily-file> <YYYY-MM-DD>}"
date_str="${2:?date required}"

status=0

claude_bullets=""
if ! claude_bullets="$("$SCRIPT_DIR/claude-log-bullets.sh" "$daily_file")"; then
  echo "警告: claude-log-bullets.sh が失敗した（auto:alignの対話ログ集計をスキップ）" >&2
  status=1
fi

codex_bullets=""
if ! codex_bullets="$("$SCRIPT_DIR/codex-pull.sh" "$date_str")"; then
  echo "警告: codex-pull.sh が失敗した（auto:alignのCodex集計をスキップ）" >&2
  status=1
fi

done_cards=""
if ! done_cards="$("$DAILY_DIGEST_SCRIPTS/collect-done-cards.sh" "$date_str")"; then
  echo "警告: collect-done-cards.sh が失敗した（auto:alignのdoneカード集計をスキップ）" >&2
  status=1
fi

log_count=0
[ -n "$claude_bullets" ] && log_count="$(printf '%s\n' "$claude_bullets" | grep -c '^- \[auto\] 対話セッション' || true)"
codex_count=0
[ -n "$codex_bullets" ] && codex_count="$(printf '%s\n' "$codex_bullets" | grep -c '^- \[auto\] Codexセッション' || true)"
done_count=0
[ -n "$done_cards" ] && done_count="$(printf '%s\n' "$done_cards" | grep -c . || true)"

echo "- [auto] 集計（${date_str}）: 対話ログ ${log_count} 件／Codex ${codex_count} 件／ai-jobs done ${done_count} 件。年間/3年目標との整合は上の各行で人間が判定する（このloopは件数集計のみの補助）。"
if [ "$log_count" -eq 0 ] && [ "$codex_count" -eq 0 ] && [ "$done_count" -eq 0 ]; then
  echo "- [auto] 当日の自動記録（対話ログ・Codex・done カード）は無し。"
fi

exit "$status"
