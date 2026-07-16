#!/usr/bin/env bash
# daily-notion-sync / sync.sh — 当日デイリーの2節（session-board源）の変化を30秒ごとに検知し、
# 変化があった時だけ session-table.sh（Notion表A/表Bへのupsert/archive）を実行する差分駆動sync。
# 設計正本: ../../../my-brain/areas/ai運用/plans/active/2026-07-06-デイリーNotion表反映/plan.md
# 旧 renderer/lanes-sync.sh（統合program plan.md 方針5c）のsignature差分検知＋mkdirロック方式を
# 踏襲する。cockpit固有の相乗り処理（inbox-tick/keeper-tick等）はこのloopには持ち込まない
# （このloopはNotionミラーだけが責務・ローカルMD運用には一切書き込まない）。
#
# 変化検知: parse-daily.sh sessions/done の出力（既にTSVへ正規化済み）を連結してsha256化し、
# 前回値（state/notion-session-table-sync-signature）と比較する。同じなら**Notion API呼び出し
# ゼロ**でexit 0。
#
# 変化時のみ session-table.sh を **SESSION_TABLE_STRICT=1** を付けて実行する（session-table.sh
# は既定でフェイルセーフのため内部のAPI失敗をwarn_exit0で常にexit 0へ握りつぶす。STRICT=1の時だけ
# 警告を出したうえで非0終了するため、sync.sh側の失敗検知が実際のAPI失敗で機能する）。
# **成功した時だけ**signatureを更新する（失敗時は次回30秒tickが「変化あり」として自動的に
# 再試行する。差分が実際には無いのに永久にリトライされ続けることはない＝次回tickで再度同じ
# signatureを計算し、session-table.sh再実行が成功すればその時点で更新される）。
#
# 起動: launchd com.kitamura.daily-notion-sync.plist（StartInterval 30・このディレクトリが正本・
# draft。人間がbootstrap/symlink登録するまで無効。手順は loop.md 参照）。
#
# フェイルセーフ: 多重起動防止（mkdirによる簡易ロック。stale判定=300秒超で自己修復）。
# 解析失敗は「0件」と区別して非0終了し、session-table.sh・archive・signature更新へ
# 進まない。signature計算失敗は従来どおり警告1行+exit 0で吸収する。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_paths.sh"

STATE_DIR="${NOTION_SYNC_STATE_DIR:-$SCRIPT_DIR/../state}"
SIGNATURE_FILE="$STATE_DIR/notion-session-table-sync-signature"
LOCK_DIR="${SESSION_TABLE_SYNC_LOCK_DIR:-$STATE_DIR/notion-session-table-sync.lock}"
LOCK_STALE_SECONDS=300

warn_exit0() {
  echo "sync: 警告: $1" >&2
  exit 0
}

fail_closed() {
  echo "sync: 解析失敗: $1（Notion同期・archive・signature更新を中止）" >&2
  exit 1
}

mkdir -p "$STATE_DIR" 2>/dev/null || warn_exit0 "state保存先の作成に失敗: $STATE_DIR"

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
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

# --- データ源: 当日デイリーの2節（未生成なら空文字列として扱う＝parse-daily.shが0件を返す） ---
date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
daily_file="$(daily_file_for "$date_str")"

sessions_content="$("$SCRIPT_DIR/parse-daily.sh" sessions "$daily_file")" || fail_closed "parse-daily.sh(sessions)"
done_content="$("$SCRIPT_DIR/parse-daily.sh" done "$daily_file")" || fail_closed "parse-daily.sh(done)"

signature_input="$sessions_content
---
$done_content"
signature="$(printf '%s' "$signature_input" | shasum -a 256 2>/dev/null | awk '{print $1}')"
[ -n "$signature" ] || warn_exit0 "signature計算に失敗した（shasumコマンド不在の可能性）"

previous_signature=""
[ -f "$SIGNATURE_FILE" ] && previous_signature="$(cat "$SIGNATURE_FILE" 2>/dev/null || true)"

if [ "$signature" = "$previous_signature" ]; then
  exit 0
fi

# --- 変化あり: session-table.sh（Notion表A/表Bへのupsert/archive）をSTRICT付きで実行。
#     失敗時はsignatureを更新しない（次回30秒tickで自動リトライされる）。 ---
if SESSION_TABLE_STRICT=1 "$SCRIPT_DIR/session-table.sh"; then
  printf '%s' "$signature" > "$SIGNATURE_FILE"
  echo "sync: 完了（変化検知・sync実行）"
else
  echo "sync: 警告: session-table.shが失敗した(シグネチャ未更新・次回tickで自動リトライ)" >&2
fi
exit 0
