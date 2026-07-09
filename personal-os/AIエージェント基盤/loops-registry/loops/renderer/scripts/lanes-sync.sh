#!/usr/bin/env bash
# renderer / lanes-sync.sh — cockpitレーンの変化を毎分検知し、変化時のみ auto:board-now(ローカル区画)
# と notion-lanes.sh(N3b)を実行する差分駆動sync（統合program plan.md 方針5c・2026-07-03ユーザー要望）。
# usage: lanes-sync.sh
#
# 変化検知: orca-ps-snapshot.sh（auto:board-now/auto:board-wait/notion-lanes.shと同一の既存収集
# ロジック。第2の収集実装は作らない）＋ cockpit-stage-lookup.sh（build-board-now.sh/notion-lanes.shと
# 共有する段階lookup）から、レーン集合・agent種別/state・lastAssistantMessage最終行・段階を
# 正規化した文字列を作り、sha256でハッシュ化する。前回値（state/notion-lanes-sync-signature・
# 既存のstate置き場と同じgit非管理の流儀）と比較し、**同じなら何もせずAPI呼び出しゼロでexit 0**。
#
# 変化時のみ:
#   (a) build-board-now.sh の出力を当日デイリーの auto:board-now マーカーへ適用する
#       （render.shのapply()と同じ流儀。set-marker-block.sh経由。デイリー未生成は日次サイクル上の
#       正常なタイミング差として警告のみでこのステップだけskipし、(b)は継続する＝ローカル区画と
#       Notion pushは互いに独立）。
#   (b) notion-lanes.sh（N3b）を **LANES_STRICT=1** を付けて実行する。
#   **(a)のbuilder/適用失敗、または(b)の失敗が無い時だけ**signatureを更新する（差し戻し修正・
#   High・2026-07-03: 従来は成否に関わらず無条件にsignatureを更新していたため、notion-lanes.sh側の
#   一時的な失敗（アーカイブPATCH失敗を含む）が次の実際の状態変化まで恒久的に隠れ、リトライされ
#   なくなっていた。失敗時はsignature未更新のまま警告+exit 0し、次の毎分実行が「変化あり」として
#   自動的に再試行する）。デイリー未生成そのものは失敗扱いにしない（従来どおりsignatureを進める）。
#   **LANES_STRICT=1の理由**（差し戻し修正・High・2巡目）: notion-lanes.shは既定でフェイルセーフの
#   ため内部のAPI失敗をwarn_exit0で常にexit 0へ握りつぶす（render.sh本流はこの挙動が必要）。
#   LANES_STRICT無しで呼ぶと(b)の失敗が終了コードに一切現れず、上記のsignature非保存が実際の
#   API失敗（archive PATCH失敗等）では機能しなかった。lanes-syncからの呼び出しにだけ
#   LANES_STRICT=1を付けることで、notion-lanes.sh自身のフェイルセーフ設計は変えずに
#   失敗検知だけを有効化する。
#
# 起動: launchd com.kitamura.lanes-sync.plist（StartInterval 60・このディレクトリが正本・
# ドラフト。人間がbootstrap/symlink登録するまで無効。手順は loop.md 参照）。
# イベント駆動（cockpit up/send/down・23:30締めのrender.sh）は従来どおり併存する
# （lanes-syncはrender.shの全工程(goal/log/done/align/board-wait/board-plans/N1/N2/N3)を
# 一切呼ばない・auto:board-nowとnotion-lanes.shだけの軽量loop）。
#
# フェイルセーフ: 多重起動防止（mkdirによる簡易ロック。stale判定=300秒超で自己修復）。
# orca-ps-snapshot.sh失敗・signature計算失敗は警告1行+exit 0で吸収する（このloopが人間の作業や
# render.sh本体に影響しないため）。build-board-now.sh失敗・notion-lanes.sh失敗も警告1行+exit 0で
# 吸収するが、上記のとおりsignatureは更新しない（自動リトライのため）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cockpit-stage-lookup.sh"

STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
SIGNATURE_FILE="$STATE_DIR/notion-lanes-sync-signature"
LOCK_DIR="${LANES_SYNC_LOCK_DIR:-$STATE_DIR/notion-lanes-sync.lock}"
LOCK_STALE_SECONDS=300

warn_exit0() {
  echo "lanes-sync: 警告: $1" >&2
  exit 0
}

mkdir -p "$STATE_DIR" 2>/dev/null || warn_exit0 "state保存先の作成に失敗: $STATE_DIR"

# --- 共有psスナップショット（子06フェーズ2・親計画方針1）: orca worktree ps を毎tick 1回だけ取得し、
#     keeper-tick（KEEPER_PS_CMD）と自身の変化検知（orca-ps-snapshot.sh=ORCA_PS_CMD）で共有する
#     （従来は keeper と lanes-sync が各1回＝毎分2回読み → 1回に統合）。ORCA_PS_CMD/KEEPER_PS_CMD は
#     どちらも既存の差替knobで、対象スクリプトを一切変更せず env の向き先だけを差し替える。
#     取得失敗/空なら export せず、各自が自前で ps を読む従来動作へフォールバック（フェイルセーフ）。
#     取得元は既存の ORCA_PS_CMD があればそれを尊重（テスト/呼び出し側が注入済みなら上書きしない・
#     本番は launchd が未設定なので実 orca を1回読む）。SENTINEL_PS_CMD は最優先の明示差替knob。 ---
SENTINEL_PS_CMD="${SENTINEL_PS_CMD:-${ORCA_PS_CMD:-orca worktree ps --json}}"
PS_SNAPSHOT="$(mktemp "${TMPDIR:-/tmp}/lanes-ps.XXXXXX" 2>/dev/null || true)"
trap 'rm -f "$PS_SNAPSHOT" 2>/dev/null || true' EXIT
if [ -n "$PS_SNAPSHOT" ] && $SENTINEL_PS_CMD > "$PS_SNAPSHOT" 2>/dev/null && [ -s "$PS_SNAPSHOT" ]; then
  export ORCA_PS_CMD="cat $PS_SNAPSHOT"
  export KEEPER_PS_CMD="cat $PS_SNAPSHOT"
else
  rm -f "$PS_SNAPSHOT" 2>/dev/null || true
  PS_SNAPSHOT=""
fi

# --- 依頼インボックスtick（子03相乗り・毎分）: pull＋patrol(有効化時のみ)を inbox-tick.sh 1本で
#     駆動する。配置はロック取得前＝lanes-sync本流の排他に関与しない・無変化の早期exitより前なので
#     毎分必ず走る。同期呼び出しにする理由: バックグラウンド(&)はlaunchdのプロセスグループkill
#     （AbandonProcessGroup既定false）で親exit時に途中終了し得るため。tick自身は常にexit 0の
#     フェイルセーフで、失敗はtick内で警告吸収済み（本流を止めない）。
#     2026-07-09 デイリー運用刷新 子06: inbox-tick.sh は inbox-patrol/scripts へ移設し、独立plist
#     （com.kitamura.inbox-tick・60秒・draft未ロード）が正規の呼び出し元になった。この相乗り呼び出しは
#     lanes-sync再開時の互換のため残す（パスのみ更新。両方が動いてもpatrolのmkdirロックとpullのid記録で
#     二重処理はしないが、運用上はどちらか一方だけを有効化する）。 ---
"$SCRIPT_DIR/../../inbox-patrol/scripts/inbox-tick.sh" || true

# --- 統合見張りtick（子06フェーズ1・毎分）: watch-keeper/keeper.sh のWAKE/error/watch不在検知を
#     keeper-tick.sh 1本で相乗り駆動する（inbox-tickと同型・plistを増やさない）。keeper.shの
#     seen.txt完全一致ガードで5分周期でも1分周期でも二重通知しない。ロック取得・無変化早期exitより
#     前に置き毎分必ず走らせる。同期呼び出し・常にexit 0のフェイルセーフ（失敗はtick内で警告吸収済み・
#     本流を止めない）。統合見張り（子06フェーズ2でのsentinel統合）時はこの1行を移す。 ---
"$SCRIPT_DIR/keeper-tick.sh" || true

# --- 多重起動防止（mkdirはOS側でアトミック。launchd StartIntervalは前回runの終了を待たないため、
#     前回が長引いた場合の重複起動を防ぐ。ロックが古い(300秒超)まま残っていれば自己修復して奪う） ---
if [ -d "$LOCK_DIR" ]; then
  lock_mtime="$(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0)"
  now_ts="$(date +%s)"
  lock_age=$((now_ts - lock_mtime))
  if [ "$lock_age" -gt "$LOCK_STALE_SECONDS" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
fi
mkdir "$LOCK_DIR" 2>/dev/null || warn_exit0 "前回runがロック中のためskip（多重起動防止）: $LOCK_DIR"

work="$(mktemp -d "${TMPDIR:-/tmp}/lanes-sync.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true; rm -rf "$work"; rm -f "$PS_SNAPSHOT" 2>/dev/null || true' EXIT

# --- データ源: orca-ps-snapshot.sh + cockpit-stage-lookup.sh（既存収集ロジックの再利用） ---
snapshot=""
if ! snapshot="$("$SCRIPT_DIR/orca-ps-snapshot.sh")"; then
  warn_exit0 "orca-ps-snapshot.sh が失敗した（レーン変化検知に必要なデータが取得できない）"
fi

# --- 段階イベントは「現在orca psに実在するworktree」の分だけをsignatureに含める。
#     差し戻し修正（Medium）: 従来はCOCKPIT_EVENTS_FILE由来の段階を無条件に全部含めていたため、
#     orca psにもう存在しないworktree（別セッション・過去の残骸等）向けのイベントが1行増えるだけで
#     signatureが変化し、実際のレーン表示は何も変わらないのに偽の変化検知→不要なNotion API呼び出しが
#     発生していた（再現済み）。現在のsnapshotに含まれるworktree pathの集合との積に限定する
#     （grep -qxF による完全一致判定。awk連想配列は使わない＝onetrueawkの多バイト文字列比較バグの
#     再発を避けるため安全側に倒す）。 ---
active_paths_file="$work/active-paths.txt"
printf '%s\n' "$snapshot" | awk -F'|' '{ print $1 }' | sort -u > "$active_paths_file"

stage_map="$(cockpit_latest_stage_by_worktree)"
stage_map_filtered=""
if [ -n "$stage_map" ]; then
  while IFS=$'\t' read -r ev_path ev_stage; do
    [ -n "$ev_path" ] || continue
    if grep -qxF "$ev_path" "$active_paths_file"; then
      stage_map_filtered="${stage_map_filtered}${ev_path}	${ev_stage}
"
    fi
  done <<< "$stage_map"
fi
stage_map_sorted="$(printf '%s\n' "$stage_map_filtered" | sort)"

signature_input="$snapshot
---
$stage_map_sorted"
signature="$(printf '%s' "$signature_input" | shasum -a 256 2>/dev/null | awk '{print $1}')"
[ -n "$signature" ] || warn_exit0 "signature計算に失敗した（shasumコマンド不在の可能性）"

previous_signature=""
[ -f "$SIGNATURE_FILE" ] && previous_signature="$(cat "$SIGNATURE_FILE" 2>/dev/null || true)"

if [ "$signature" = "$previous_signature" ]; then
  exit 0
fi

# --- (a) ローカルboard区画（auto:board-now）を更新する。デイリー未生成ならこのステップだけ
#     警告してskipし、(b)のNotion pushは継続する（互いに独立。デイリー未生成は日次サイクル上
#     ありうる正常なタイミング差であり実際の失敗ではないため local_board_ok は下げない）。
#     builder失敗・適用失敗は実際の失敗として local_board_ok を下げ、シグネチャ保存をブロックする
#     （差し戻し修正・High: 従来はこの結果に関わらずシグネチャを保存しており、失敗が次の実際の
#     状態変化まで恒久的に隠れてしまっていた） ---
local_board_ok=1
date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
daily_file="$(daily_file_for "$date_str")"
if [ -f "$daily_file" ]; then
  board_now_out="$work/board-now.txt"
  if "$SCRIPT_DIR/build-board-now.sh" > "$board_now_out" 2>"$work/build-board-now.err"; then
    set_marker="$DAILY_DIGEST_SCRIPTS/set-marker-block.sh"
    if ! "$set_marker" "$daily_file" board-now "$board_now_out" >/dev/null 2>&1; then
      echo "lanes-sync: 警告: auto:board-nowの適用に失敗した(シグネチャ未更新・次回リトライ)" >&2
      local_board_ok=0
    fi
  else
    echo "lanes-sync: 警告: build-board-now.shが失敗した(auto:board-now更新をskip・シグネチャ未更新・次回リトライ)" >&2
    local_board_ok=0
  fi
else
  echo "lanes-sync: 警告: 当日デイリーが無いためauto:board-now更新をskip(継続): $daily_file" >&2
fi

# --- (b) Notionレーン実況upsert（N3b）。失敗（アーカイブPATCH失敗を含む）時はシグネチャを
#     進めない（差し戻し修正・High: 従来は || true で成否を握りつぶし無条件にシグネチャを
#     保存していたため、この失敗が次の実際の変化まで恒久的にリトライされなくなっていた）。
#     notion-lanes.shは既定でwarn_exit0が常にexit 0を返すフェイルセーフ設計のため、
#     **LANES_STRICT=1**を付けて呼ぶ（差し戻し修正・High・2巡目: これを付けないとAPI失敗が
#     終了コードに現れず、直前の修正が実際の失敗で機能しなかった）。render.sh本流が呼ぶ
#     notion-lanes.shにはLANES_STRICTを付けない＝そちらのフェイルセーフ（常にexit 0）は不変。 ---
notion_lanes_ok=1
if ! LANES_STRICT=1 "$SCRIPT_DIR/notion-lanes.sh"; then
  echo "lanes-sync: 警告: notion-lanes.shが失敗した(シグネチャ未更新・次回リトライ)" >&2
  notion_lanes_ok=0
fi

if [ "$local_board_ok" -eq 1 ] && [ "$notion_lanes_ok" -eq 1 ]; then
  printf '%s' "$signature" > "$SIGNATURE_FILE"
  echo "lanes-sync: 完了（変化検知・sync実行）"
else
  echo "lanes-sync: 警告: 一部処理が失敗したためシグネチャを更新しない(次回の毎分実行で自動リトライされる)" >&2
fi
exit 0
