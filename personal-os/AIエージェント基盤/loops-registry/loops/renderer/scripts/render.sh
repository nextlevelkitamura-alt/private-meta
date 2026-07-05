#!/usr/bin/env bash
# renderer / render.sh — 統合デイリーレンダラ v1 のエントリポイント。
# usage: render.sh [YYYY-MM-DD] [--final]
#   YYYY-MM-DD  省略時は実行時点のJST当日。
#   --final     23:30 締めの最終レンダであることを示す（処理内容は同じ・ログに残すだけ）。
#
# 処理順: (a) 当日デイリーが無ければテンプレから生成 (b) auto:goal (c) auto:log 欠落分バックフィル
#         (d) auto:done (e) auto:align (f) auto:board-now (g) auto:board-wait (h) auto:board-plans。
# マーカー内側の読み書きは daily-digest/scripts/get-marker-block.sh / set-marker-block.sh のみで行う。
# マーカーが無いファイルにはマーカーを足さない（skip・警告のみ）。マーカー外の人間行は一切変更しない。
# 非AI・非乱数で決定的。同一入力での2回連続実行は差分ゼロ（冪等）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"

: "${DAILY_TEMPLATE:=$SCRIPT_DIR/../templates/デイリー.md}"

final=0
date_str=""
for arg in "$@"; do
  case "$arg" in
    --final) final=1 ;;
    -*) echo "不明なオプション: $arg" >&2; exit 2 ;;
    *) date_str="$arg" ;;
  esac
done
[ -n "$date_str" ] || date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"

daily_file="$(daily_file_for "$date_str")"
set_marker="$DAILY_DIGEST_SCRIPTS/set-marker-block.sh"

if [ "$final" -eq 1 ]; then
  echo "締めの最終レンダ: $date_str"
fi

# (a) 当日デイリーが無ければテンプレから生成（既存ファイルは触らない）
"$SCRIPT_DIR/ensure-daily.sh" "$daily_file" "$date_str" "$DAILY_TEMPLATE"

if [ ! -f "$daily_file" ]; then
  echo "デイリーファイルが無く生成もできなかった（テンプレ未整備の可能性）: $daily_file" >&2
  exit 0
fi

apply() {
  local key="$1" content="$2" rc=0
  "$set_marker" "$daily_file" "$key" "$content" || rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "警告: auto:${key} マーカーが無いためスキップ: $daily_file" >&2
    return 0
  fi
  return "$rc"
}

status=0
work="$(mktemp -d "${TMPDIR:-/tmp}/renderer.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# builder（stdoutへ本文を出すスクリプト）を実行し、成功時だけapplyする。
# builderが失敗（非0終了）した場合はapplyをスキップし、マーカー内容を保持したまま警告のみ出す
# （空ファイルで置換してマーカー内容を消してしまわないため）。builderが成功して出力が空なのは
# 正当な「空で置換」（例: 当日記録0件）として扱い、これは維持する。
build_and_apply() {
  local key="$1" builder_label="$2" out_file="$3"; shift 3
  if "$@" > "$out_file"; then
    apply "$key" "$out_file" || status=1
  else
    echo "警告: ${builder_label} が失敗したため auto:${key} の更新をスキップ（既存内容を保持）: $daily_file" >&2
    status=1
  fi
}

# (b) auto:goal
build_and_apply goal "build-goal.sh" "$work/goal.txt" "$SCRIPT_DIR/build-goal.sh" "$date_str"

# (b2) auto:tomorrow-carry（前日デイリーの「## 明日へ」を逆算直後＝## 今日のTODO直前へ朝転記。
#      自己完結・冪等。前日が無い/空なら区画を作らず、既存の古い区画は除去する。マーカー外は不変）
"$SCRIPT_DIR/carry-tomorrow.sh" "$daily_file" "$date_str" || status=1

# (c) auto:log 欠落分バックフィル（自己完結。自ら set-marker-block.sh を呼ぶ）
"$SCRIPT_DIR/claude-backfill.sh" "$daily_file" "$date_str" || status=1

# (d) auto:done
build_and_apply done "build-done.sh" "$work/done.txt" "$SCRIPT_DIR/build-done.sh" "$daily_file" "$date_str"

# (e) auto:align
build_and_apply align "build-align.sh" "$work/align.txt" "$SCRIPT_DIR/build-align.sh" "$daily_file" "$date_str"

# (f) auto:board-now（cockpitレーン実況。orca worktree ps由来）
build_and_apply board-now "build-board-now.sh" "$work/board-now.txt" "$SCRIPT_DIR/build-board-now.sh"

# (g) auto:board-wait（人間確認待ち・着手可能・未紐付け）
build_and_apply board-wait "build-board-wait.sh" "$work/board-wait.txt" "$SCRIPT_DIR/build-board-wait.sh" "$daily_file"

# (h) auto:board-plans（全領域activeの計画一覧）
build_and_apply board-plans "build-board-plans.sh" "$work/board-plans.txt" "$SCRIPT_DIR/build-board-plans.sh"

# (i) Notion依頼インボックスpull（N2・先。ベストエフォート。失敗しても render.sh 自体の
#     成否($status)には影響させない。push/boardより先に走らせ、当日中に取り込んだ依頼が
#     同じレンダで auto:board-* へも反映され得るようにする）
"$SCRIPT_DIR/notion-inbox-pull.sh" "$daily_file" || true

# (j) Notion一方向push（N1・ベストエフォート。失敗しても render.sh 自体の成否($status)には影響させない）
"$SCRIPT_DIR/notion-push.sh" "$daily_file" || true

# (k) Notion計画ボードupsert（N3・後。ベストエフォート。失敗しても render.sh 自体の成否($status)には
#     影響させない）
"$SCRIPT_DIR/notion-board.sh" || true

# (l) Notionレーン実況upsert（N3b・最後。ベストエフォート。失敗しても render.sh 自体の成否($status)
#     には影響させない）
"$SCRIPT_DIR/notion-lanes.sh" || true

exit "$status"
