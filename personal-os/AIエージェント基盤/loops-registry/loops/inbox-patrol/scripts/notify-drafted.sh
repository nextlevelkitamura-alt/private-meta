#!/usr/bin/env bash
# inbox-patrol / notify-drafted.sh — 起案完了（→計画作成済み）の通知（2026-07-09 子06新設）。
# usage: notify-drafted.sh <daily_file> <orig_line>
#   orig_line = クレーム前の元の1行（行頭 "- " を含む原文）。patrol.sh が AI 成功後に1行につき1回呼ぶ。
#
# 処理:
#   1. デイリーを読み直し、orig_line に「→計画作成済み(<パス>)」が付いた行を探して計画パスを抽出する。
#      付いていない（サクッと判定・人間が文言変更済み等）場合は何もせず exit 0（無通知）。
#   2. PC通知: osascript display notification（watch-keeper/keeper.sh の notify() と同じ argv 方式＝
#      AppleScript文字列への埋め込みを避ける）。INBOX_NOTIFY_CMD で差し替え可（テストはstub。
#      "title" "body" の2引数で呼ばれる）。
#   3. Notion PATCH: 出所マップ state/notion-inbox-origin-ids（notion-inbox-pull.sh が pull 時に
#      「id<TAB>依頼テキスト」で追記）で該当Notion行を逆引きし、状態=起案済み＋計画パスを
#      マージPATCHする（PATCH /pages/{id} は properties 部のみ＝renderer notion_helper.py の
#      マージPATCHと同じ流儀）。マップに無い行（デイリー直書き・kickoff行）はPC通知のみ。
#      「計画パス」プロパティと「起案済み」選択肢が旧DBに無い場合に備え、初回のみDBスキーマを
#      冪等PATCHする（state/notion-inbox-schema-planpath マーカーで1回きり。selectのoptionsは
#      置き換え挙動のため、既存の 立案済/回収済み を必ず含めた全量で送る）。
#
# フェイルセーフ: 通知は起案の成否と独立のベストエフォート。引数不足以外は常に exit 0
# （警告1行のみ。patrol.sh 側も || で吸収する）。
# secret規律: NOTION_TOKEN は notion-common.sh の変数保持のみ。標準出力・ログ・通知本文に出さない。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_SCRIPTS="$(cd "$SCRIPT_DIR/../../renderer/scripts" && pwd)"

FINAL_MARKER='→計画作成済み('
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
ORIGIN_STATE_FILE="$STATE_DIR/notion-inbox-origin-ids"
INBOX_DB_STATE_FILE="$STATE_DIR/notion-inbox-database-id"
SCHEMA_MARKER_FILE="$STATE_DIR/notion-inbox-schema-planpath"
KEYCHAIN_SERVICE="${NOTION_PUSH_KEYCHAIN_SERVICE:-notion-personal-os}"

warn_exit0() {
  echo "notify-drafted: 警告: $1" >&2
  exit 0
}

[ $# -ge 2 ] || { echo "usage: notify-drafted.sh <daily_file> <orig_line>" >&2; exit 2; }
daily_file="$1"
orig_line="$2"
[ -f "$daily_file" ] || warn_exit0 "デイリーファイルが無い: $daily_file"

# --- 1. 計画パス抽出（LC_ALL=C: macOS標準awkのUTF-8ロケール==誤判定バグ回避。patrol.sh 同様） ---
# orig_line + " →計画作成済み(" で始まる最初の行から、マーカー直後〜最初の ")" までを取り出す。
plan_path="$(LC_ALL=C awk -v orig="$orig_line" -v marker=" ${FINAL_MARKER}" '
  BEGIN { prefix = orig marker; plen = length(prefix) }
  index($0, prefix) == 1 {
    rest = substr($0, plen + 1)
    p = index(rest, ")")
    if (p > 0) { print substr(rest, 1, p - 1); exit }
  }
' "$daily_file")"
[ -n "$plan_path" ] || exit 0   # 起案されていない（サクッと判定等）＝無通知で正常終了

body="${orig_line#- }"

# --- 2. PC通知（1起案=patrol.shからの1呼び出し=1回だけ） ---
notify_title="inbox-patrol: 計画を起案"
notify_body="${body} → ${plan_path}"
if [ -n "${INBOX_NOTIFY_CMD:-}" ]; then
  "$INBOX_NOTIFY_CMD" "$notify_title" "$notify_body" \
    || echo "notify-drafted: 警告: PC通知コマンドが失敗した（続行）" >&2
else
  osascript -e 'on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run' "$notify_title" "$notify_body" >/dev/null 2>&1 \
    || echo "notify-drafted: 警告: osascript通知が失敗した（続行）" >&2
fi

# --- 3. Notion行PATCH（出所マップに一致する行がある場合のみ。無ければここで正常終了） ---
[ -f "$ORIGIN_STATE_FILE" ] || exit 0
row_ids="$(LC_ALL=C awk -F '\t' -v t="$body" 'NF >= 2 { v = substr($0, index($0, "\t") + 1); if (v == t) print $1 }' "$ORIGIN_STATE_FILE")"
[ -n "$row_ids" ] || exit 0

# shellcheck source=/dev/null
source "$RENDERER_SCRIPTS/notion-common.sh"
notion_fetch_token "$KEYCHAIN_SERVICE" || warn_exit0 "Notionトークン取得失敗（PC通知は送信済み。行PATCHのみ未実施）"

work="$(mktemp -d "${TMPDIR:-/tmp}/notify-drafted.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

# 3a. DBスキーマの冪等PATCH（初回のみ）: 「起案済み」選択肢＋「計画パス」rich_textを足す。
#     optionsは置き換え挙動（notion_helper.py の実測メモ）のため既存選択肢を全量含めて送る。
if [ ! -f "$SCHEMA_MARKER_FILE" ] && [ -f "$INBOX_DB_STATE_FILE" ]; then
  database_id="$(cat "$INBOX_DB_STATE_FILE" 2>/dev/null || true)"
  if [ -n "$database_id" ]; then
    schema_body="$work/schema-body.json"
    printf '%s' '{"properties":{"状態":{"select":{"options":[{"name":"立案済"},{"name":"回収済み"},{"name":"起案済み"}]}},"計画パス":{"rich_text":{}}}}' > "$schema_body"
    if notion_http_call PATCH "/databases/$database_id" "$schema_body"; then
      mkdir -p "$STATE_DIR" 2>/dev/null || true
      : > "$SCHEMA_MARKER_FILE" 2>/dev/null \
        || echo "notify-drafted: 警告: スキーママーカーの記録に失敗（次回もPATCHする・冪等なので実害なし）" >&2
    else
      echo "notify-drafted: 警告: DBスキーマPATCHに失敗(status=${HTTP_STATUS:-?})。行PATCHは試行する" >&2
    fi
  fi
fi

# 3b. 行PATCH: 状態=起案済み ＋ 計画パス（同一テキストの行が複数あれば全てPATCH＝重複起票の統合と整合）。
row_body="$work/row-body.json"
python3 - "$plan_path" > "$row_body" <<'PY' || warn_exit0 "行PATCH payloadの構築に失敗"
import json, sys
plan_path = sys.argv[1]
payload = {"properties": {
    "状態": {"select": {"name": "起案済み"}},
    "計画パス": {"rich_text": [{"type": "text", "text": {"content": plan_path}}]},
}}
print(json.dumps(payload, ensure_ascii=False))
PY

patched=0
while IFS= read -r row_id; do
  [ -n "$row_id" ] || continue
  if notion_http_call PATCH "/pages/$row_id" "$row_body"; then
    patched=$((patched + 1))
  else
    echo "notify-drafted: 警告: Notion行PATCHに失敗(id=${row_id}, status=${HTTP_STATUS:-?})" >&2
  fi
done <<< "$row_ids"

echo "notify-drafted: 完了 (Notion行PATCH=${patched}件)"
exit 0
