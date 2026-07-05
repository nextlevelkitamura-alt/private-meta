#!/usr/bin/env bash
# renderer / keeper-tick.sh — 統合見張りの毎分tick入口（マルチ指揮官体制program 子06フェーズ1）。
# usage: keeper-tick.sh
#
# 1tick = watch-keeper/scripts/keeper.sh をワンショット起動する。keeper.sh は
#   `orca worktree ps --json` を1回読み、レーンのWAKEマーカー(_DONE/REVIEW_RESULT/人間確認待ち)・
#   agentのerror state・watch.sh不在 を検知して macOS通知＋state/alerts.jsonl に記録する。
#   同じ(lane,最終行)は keeper.sh の state/seen.txt 完全一致ガードで再通知しない
#   ＝5分周期でも1分周期でも二重通知しない（周期非依存の冪等）。
#
# keeper.sh のロジックは改変しない（tick入口を足すだけ）。子06フェーズ1のスコープは「1分化」のみで、
# 1回の `orca worktree ps` スナップショットを lanes-sync と共有する統合（親計画方針1）はフェーズ2。
#
# 呼び出し口の契約（子06裁定・plistを増やさない）: 呼び出し元は本スクリプト1本だけを呼ぶ。
# 現在は lanes-sync.sh の毎分tickへ相乗り（inbox-tick.sh の隣）。将来 sentinel へ統合する時は
# 呼び出し元の1行を移すだけでよい（本スクリプトは呼び出し元を知らない＝lanes-syncにも独立plistにも
# 固く結合しない）。
#
# フェイルセーフ: keeper.sh の失敗は警告1行で吸収し常にexit 0（呼び出し元の本流に影響させない。
# 次のtickが60秒後に来る）。費用・自律実行を伴う監督起動は keeper.sh 側 KEEPER_AUTOPILOT=1
# （既定OFF）でのみ動く＝毎分化しても既定では費用が増えない（通知・alerts追記のみ）。
# ログ規律: 検知が無い定常tickは keeper.sh 側が無音（毎分実行なのでlaunchdログをノイズで埋めない）。
# KEEPER_TICK_DISABLED: 非空ならtick全体をskip（lanes-syncコアのテストがtick無しの不変条件を
# 検証するための切り離し口。運用の停止手段ではない＝keeperの停止はplistのbootout=人間ゲート）。
set -uo pipefail
[ -n "${KEEPER_TICK_DISABLED:-}" ] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEEPER="$SCRIPT_DIR/../../watch-keeper/scripts/keeper.sh"

if [ -x "$KEEPER" ]; then
  if ! "$KEEPER"; then
    echo "keeper-tick: 警告: keeper.sh が失敗した（次tickで再試行）" >&2
  fi
else
  echo "keeper-tick: 警告: keeper.sh が見つからない: $KEEPER" >&2
fi
exit 0
