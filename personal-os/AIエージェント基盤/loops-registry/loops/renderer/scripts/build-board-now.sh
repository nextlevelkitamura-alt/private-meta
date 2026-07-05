#!/usr/bin/env bash
# renderer / build-board-now — auto:board-now マーカーへ差し込む「今やっていること」本文を組み立てる。
# orca worktree ps のレーン実況（worktree名・agent種別・state）を描画し、lastAssistantMessage最終行が
# 段階語彙／完了・合否マーカーに一致する場合だけそれも表示する（会話本文をそのまま出さない・noise/
# 機微情報の非漏洩）。
#
# orca-ps-snapshot.sh の失敗（orca CLI不在・実行失敗・JSON不正）は握りつぶさず非0で終了する
# （render.sh側の『builder失敗→applyスキップ・既存内容保持』防御に乗せるため）。
#
# cockpit段階イベント（cockpit.shのup/send/downがCOCKPIT_EVENTS_FILEへ追記するJSONL）から、
# レーン(worktree path)ごとの最新段階を拾って行末に併記する。同じイベントの最新管轄(owner)も
# 「イベント段階:」の隣に「管轄:」として併記する。イベントファイルが無い/壊れていても
# 従来表示のまま動く（このaugmentationはbest-effortであり、orca-ps-snapshot.shとは異なり
# 失敗を非0伝播しない＝後方互換。ownerが無い/nullの旧イベントは「管轄:」を出さない）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cockpit-stage-lookup.sh"

# bash 3.2（macOS既定・連想配列非対応）互換のため、path\tstage / path\towner の複数行文字列を
# 線形lookupする（cockpit_latest_stage_by_worktree / cockpit_lookup_stage / cockpit_latest_owner_by_worktree /
# cockpit_lookup_owner は cockpit-stage-lookup.sh の共有実装。notion-lanes.sh・N3bも同じ実装を使う。
# 第2の収集実装を作らない）。
STAGE_MAP="$(cockpit_latest_stage_by_worktree)"
_lookup_stage() { cockpit_lookup_stage "$STAGE_MAP" "$1"; } # <worktree path>
OWNER_MAP="$(cockpit_latest_owner_by_worktree)"
_lookup_owner() { cockpit_lookup_owner "$OWNER_MAP" "$1"; } # <worktree path>

snapshot=""
if ! snapshot="$("$SCRIPT_DIR/orca-ps-snapshot.sh")"; then
  echo "警告: orca-ps-snapshot.sh が失敗した（auto:board-nowの更新に必要なデータが取得できない）" >&2
  exit 1
fi

if [ -z "$snapshot" ]; then
  echo "- [auto] 稼働中のcockpitレーンなし。"
  exit 0
fi

# lastAssistantMessage最終行が段階語彙・完了/合否マーカーかどうかを判定する。
# 生の会話文はここに一致しない限り表示しない。
is_marker_line() {
  local line="$1"
  [ -n "$line" ] || return 1
  case "$line" in
    段階:*) return 0 ;;
    *人間確認待ち*) return 0 ;;
    *_DONE|*_PASS|*_FAIL) return 0 ;;
    REVIEW*) return 0 ;;
  esac
  return 1
}

while IFS='|' read -r path worktree display branch wstatus agent_type state lastline; do
  [ -n "$path" ] || continue
  label="${display:-$worktree}"
  event_stage="$(_lookup_stage "$path")"
  event_owner="$(_lookup_owner "$path")"
  if [ -z "$agent_type" ]; then
    line="- [auto] ${label}（${worktree}） ／ エージェント無し（worktree状態:${wstatus:-不明}）"
    [ -n "$event_stage" ] && line="${line} ／ イベント段階:${event_stage}"
    [ -n "$event_owner" ] && line="${line} ／ 管轄:${event_owner}"
    echo "$line"
    continue
  fi
  line="- [auto] ${label}（${worktree}） ／ ${agent_type}:${state:-不明}"
  if is_marker_line "$lastline"; then
    line="${line} ／ ${lastline}"
  fi
  [ -n "$event_stage" ] && line="${line} ／ イベント段階:${event_stage}"
  [ -n "$event_owner" ] && line="${line} ／ 管轄:${event_owner}"
  echo "$line"
done <<< "$snapshot"
