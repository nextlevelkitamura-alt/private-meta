#!/usr/bin/env bash
# inbox-patrol / inbox-tick.sh — 依頼インボックスの60秒tick（2026-07-09 デイリー運用刷新 子06で
# renderer/scripts から移設。呼び出し口の契約は従来どおり本スクリプト1本）。
# usage: inbox-tick.sh
#
# 1tick = (1) notion-inbox-pull.sh: Notion「立案済」行を当日デイリーへ回収（常時実行。AIを起動
#             しない読み書きのみ・冪等はpage id記録が担う）
#         (2) patrol.sh: デイリー未処理行のheadless起案（有効化フラグがある時のみ。
#             排他・冪等はpatrol.sh内蔵のmkdirロックと行クレームが担う）
#
# 呼び出し元: 独立plist `../com.kitamura.inbox-tick.plist`（StartInterval 60・draft未ロード・
# 有効化は人間ゲート）。旧経路（renderer lanes-sync.sh の毎分tick相乗り）は renderer 停止中
# （2026-07-04）のため休止。両方が同時に動いても patrol.sh の mkdirロックと pull の id記録で
# 二重処理はしないが、運用上は同時に有効化しない（loop.md参照）。
#
# patrol有効化ゲート（launchctlに代わる第2の人間ゲート）: patrolはheadless AI起案（費用・自律実行）を
# 伴うため、フラグファイル $INBOX_PATROL_ENABLED_FILE（既定 ../state/inbox-patrol-enabled）が
# 存在する時だけ呼ぶ。有効化=人間が touch、停止=人間が rm（中身は見ない・存在だけが状態）。
# ※ 移設に伴い既定の置き場は renderer/state から inbox-patrol/state へ変わった（loop.md の
#   有効化手順参照。旧フラグは未設置だったため実移行物は無い）。
#
# フェイルセーフ: 各ステップの失敗は警告1行で吸収し常にexit 0（呼び出し元の本流に影響させない。
# 次のtickが60秒後に来るのでリトライはtick周期に任せる）。secretは扱わない（pull側がkeychain参照）。
# ログ規律: 何も起きなかった定常tick（立案済0件）は無音にする（毎分実行なのでlaunchdログを
# 1日1440行のノイズで埋めない）。
# INBOX_TICK_DISABLED: 非空ならtick全体をskip（呼び出し元テストがtick無しの不変条件を
# 検証するための切り離し口。運用の停止手段ではない＝patrolの停止はフラグファイルrm）。
set -uo pipefail
[ -n "${INBOX_TICK_DISABLED:-}" ] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
ENABLED_FILE="${INBOX_PATROL_ENABLED_FILE:-$STATE_DIR/inbox-patrol-enabled}"
PATROL="$SCRIPT_DIR/patrol.sh"

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
