#!/usr/bin/env bash
# renderer / inbox-tick.sh — 依頼インボックスの毎分tick（マルチ指揮官体制program 子03）。
# usage: inbox-tick.sh
#
# 1tick = (1) notion-inbox-pull.sh: Notion「立案済」行を当日デイリーへ回収（常時実行。AIを起動
#             しない読み書きのみ・冪等はpage id記録が担う）
#         (2) inbox-patrol/scripts/patrol.sh: デイリー未処理行のheadless起案（有効化フラグが
#             ある時のみ。排他・冪等はpatrol.sh内蔵のmkdirロックと行クレームが担う）
#
# 呼び出し口の契約（子03裁定・plistを増やさない）: 呼び出し元は本スクリプト1本だけを呼ぶ。
# 現在は lanes-sync.sh の毎分tickへ相乗り。統合見張り（子06）が来たら、呼び出し元の1行を
# sentinel側へ移すだけで載せ替えられる（本スクリプトは呼び出し元を知らない＝独立plistにも
# lanes-syncにも固く結合しない）。
#
# patrol有効化ゲート（launchctlに代わる人間ゲート）: patrolはheadless AI起案（費用・自律実行）を
# 伴うため、フラグファイル $INBOX_PATROL_ENABLED_FILE（既定 ../state/inbox-patrol-enabled）が
# 存在する時だけ呼ぶ。有効化=人間が touch、停止=人間が rm（中身は見ない・存在だけが状態）。
#
# フェイルセーフ: 各ステップの失敗は警告1行で吸収し常にexit 0（呼び出し元の本流に影響させない。
# 次のtickが60秒後に来るのでリトライはtick周期に任せる）。secretは扱わない（pull側がkeychain参照）。
# ログ規律: 何も起きなかった定常tick（立案済0件）は無音にする（毎分実行なのでlaunchdログを
# 1日1440行のノイズで埋めない。lanes-syncの「無変化なら無音でexit 0」と同じ流儀）。
# INBOX_TICK_DISABLED: 非空ならtick全体をskip（lanes-syncコアのテストがtick無しの不変条件を
# 検証するための切り離し口。運用の停止手段ではない＝patrolの停止はフラグファイルrm）。
set -uo pipefail
[ -n "${INBOX_TICK_DISABLED:-}" ] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
ENABLED_FILE="${INBOX_PATROL_ENABLED_FILE:-$STATE_DIR/inbox-patrol-enabled}"
PATROL="$SCRIPT_DIR/../../inbox-patrol/scripts/patrol.sh"

pull_out="$("$SCRIPT_DIR/notion-inbox-pull.sh" 2>&1)"
pull_rc=$?
if [ "$pull_rc" -ne 0 ]; then
  echo "inbox-tick: 警告: notion-inbox-pull.sh が失敗した（次tickで再試行）" >&2
fi
case "$pull_out" in
  "notion-inbox-pull: 完了 (立案済0件)") : ;;
  "") : ;;
  *) printf '%s\n' "$pull_out" ;;
esac

if [ -f "$ENABLED_FILE" ]; then
  if [ -x "$PATROL" ]; then
    if ! "$PATROL"; then
      echo "inbox-tick: 警告: patrol.sh が失敗またはロック中（次tickで再試行）" >&2
    fi
  else
    echo "inbox-tick: 警告: patrol.sh が見つからない: $PATROL" >&2
  fi
fi
exit 0
