#!/usr/bin/env bash
# renderer / notion-push.sh — 当日デイリーMD全文をNotionの当日子ページへ全置換push（統合program N1・一方向）。
# usage: notion-push.sh [daily_file_path]
#   省略時: レンダラと同じ解決（_paths.sh の daily_file_for、実行時点のJST当日）。
#
# 全置換 = 当日子ページ（親ページ「Personal OS」配下・タイトル=YYYY-MM-DD）の既存子ブロックを
# 全archiveしてから、MD全文を素朴変換したブロックを再appendする。同じ入力なら同じページ状態（冪等）。
#
# フェイルセーフ（最重要）: デイリー不在・トークン取得失敗・parent page未解決（conf未設定かつ
# search不発）・Notion API呼び出し失敗のどの場合も、警告1行のみを stderr に出して exit 0 する。
# レンダラ本体（render.sh）の成否には絶対に影響させない（`set -e` を使わず、各ステップの失敗を
# 明示チェックして即 warn_exit0 する設計）。
#
# secret規律（最重要）: NOTION_TOKENは `security find-generic-password` で取得し変数に保持するのみ。
# echo・ログ・エラーメッセージ・コミットに値を絶対に出さない。stderr/stdoutに出す文言は
# すべて固定文字列＋トークン以外の値（status code・パス等）のみで構成する。
#
# Notion API v1（Notion-Version: 2022-06-28）をcurl（通信）＋python3（notion_helper.py・JSON変換。
# 新規依存なし）で叩く。curl/security呼び出しコマンドは NOTION_CURL_CMD / NOTION_SECURITY_CMD で
# 差し替え可能（テスト用スタブに差し替える。ORCA_PS_CMDと同じ方式）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_paths.sh"

HELPER="$SCRIPT_DIR/notion_helper.py"
CONF_FILE="${NOTION_PUSH_CONF:-$SCRIPT_DIR/../notion-push.conf}"
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
PARENT_STATE_FILE="$STATE_DIR/notion-parent-page-id"
KEYCHAIN_SERVICE="${NOTION_PUSH_KEYCHAIN_SERVICE:-notion-personal-os}"
NOTION_API="${NOTION_PUSH_API_BASE:-https://api.notion.com/v1}"
NOTION_VERSION="2022-06-28"

warn_exit0() {
  echo "notion-push: 警告: $1" >&2
  exit 0
}

daily_file="${1:-}"
if [ -z "$daily_file" ]; then
  date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  daily_file="$(daily_file_for "$date_str")"
else
  date_str="$(basename "$daily_file" .md)"
fi
[ -f "$daily_file" ] || warn_exit0 "デイリーファイルが無いためpushをskip: $daily_file"

page_title="$date_str"

# --- secret取得（値は変数に保持するのみ。以降どの出力にも絶対に出さない） ---
NOTION_TOKEN="$(${NOTION_SECURITY_CMD:-security} find-generic-password -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)"
token_rc=$?
[ "$token_rc" -eq 0 ] && [ -n "$NOTION_TOKEN" ] || warn_exit0 "Notionトークン取得失敗（キーチェーン未設定の可能性。security find-generic-password -s $KEYCHAIN_SERVICE を人間が登録する）"

# --- parent page id 解決（conf → state キャッシュ → search API の順） ---
parent_id=""
if [ -f "$CONF_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CONF_FILE"
fi
parent_id="${NOTION_PARENT_PAGE_ID:-}"

if [ -z "$parent_id" ] && [ -f "$PARENT_STATE_FILE" ]; then
  parent_id="$(cat "$PARENT_STATE_FILE" 2>/dev/null || true)"
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/notion-push.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

HTTP_STATUS=""
HTTP_BODY_FILE=""
http_call() {
  # http_call <method> <path_with_query> [body_file] — 成功時0・非2xxや通信失敗時1を返す。
  # HTTP_STATUS / HTTP_BODY_FILE に結果を残す（呼び出し側が直後に読む前提。次のhttp_callで上書きされる）。
  local method="$1" path="$2" body_file="${3:-}"
  local resp_file status rc
  resp_file="$(mktemp "$work/resp.XXXXXX")" || return 1
  local curl_args=(-sS -o "$resp_file" -w '%{http_code}' --max-time 20 -X "$method" "$NOTION_API$path"
    -H "Authorization: Bearer $NOTION_TOKEN"
    -H "Notion-Version: $NOTION_VERSION"
    -H "Content-Type: application/json")
  [ -n "$body_file" ] && curl_args+=(--data-binary "@$body_file")
  status="$(${NOTION_CURL_CMD:-curl} "${curl_args[@]}" 2>/dev/null)"
  rc=$?
  HTTP_STATUS="$status"
  HTTP_BODY_FILE="$resp_file"
  [ "$rc" -eq 0 ] || return 1
  case "$status" in
    2??) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -z "$parent_id" ]; then
  search_body="$work/search-body.json"
  cat > "$search_body" <<'EOF'
{"query":"Personal OS","filter":{"property":"object","value":"page"},"page_size":10}
EOF
  http_call POST "/search" "$search_body" || warn_exit0 "Notion検索APIの呼び出しに失敗(status=${HTTP_STATUS:-?})"
  parent_id="$(python3 "$HELPER" find-title-id --title "Personal OS" < "$HTTP_BODY_FILE")" || parent_id=""
  [ -n "$parent_id" ] || warn_exit0 "conf未設定かつ「Personal OS」ページのsearchが不発（notion-push.confのNOTION_PARENT_PAGE_IDを人間が設定する）"
  mkdir -p "$STATE_DIR" || warn_exit0 "state保存先の作成に失敗: $STATE_DIR"
  printf '%s' "$parent_id" > "$PARENT_STATE_FILE"
fi

# --- 当日子ページの解決（親ページ配下をタイトル一致で探す・cursorで全件追従。無ければ新規作成） ---
# 親ページ配下の子が100件超（約100日分超の運用）でもcursor追従で全ページ走査するため、
# 既存の当日ページを見逃して重複作成することはない（差し戻し1回目・指摘1の修正）。
page_id=""
cursor=""
while :; do
  if [ -n "$cursor" ]; then
    list_path="/blocks/$parent_id/children?page_size=100&start_cursor=$cursor"
  else
    list_path="/blocks/$parent_id/children?page_size=100"
  fi
  http_call GET "$list_path" || warn_exit0 "Notion API呼び出しに失敗(当日ページ探索, status=${HTTP_STATUS:-?})"
  listing_body="$HTTP_BODY_FILE"

  page_id="$(python3 "$HELPER" find-title-id --title "$page_title" < "$listing_body")" || page_id=""
  [ -n "$page_id" ] && break

  cursor_info="$(python3 "$HELPER" page-cursor < "$listing_body")"
  has_more="${cursor_info%%$'\t'*}"
  next_cursor="${cursor_info#*$'\t'}"
  if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
    cursor="$next_cursor"
  else
    break
  fi
done

if [ -z "$page_id" ]; then
  create_body="$work/create-body.json"
  python3 "$HELPER" page-create-payload --parent "$parent_id" --title "$page_title" > "$create_body" || warn_exit0 "ページ作成payloadの構築に失敗"
  http_call POST "/pages" "$create_body" || warn_exit0 "Notion API呼び出しに失敗(当日ページ作成, status=${HTTP_STATUS:-?})"
  page_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || page_id=""
  [ -n "$page_id" ] || warn_exit0 "当日ページ作成のレスポンスからidが取得できない"
fi

# --- 既存子ブロックの全archive（全置換の削除フェーズ。cursorで全ページ追従する） ---
cursor=""
while :; do
  if [ -n "$cursor" ]; then
    list_path="/blocks/$page_id/children?page_size=100&start_cursor=$cursor"
  else
    list_path="/blocks/$page_id/children?page_size=100"
  fi
  http_call GET "$list_path" || warn_exit0 "Notion API呼び出しに失敗(既存ブロック一覧, status=${HTTP_STATUS:-?})"
  listing_body="$HTTP_BODY_FILE"

  ids="$(python3 "$HELPER" list-ids < "$listing_body")"
  if [ -n "$ids" ]; then
    while IFS= read -r block_id; do
      [ -n "$block_id" ] || continue
      archive_body="$work/archive-body.json"
      printf '{"archived":true}' > "$archive_body"
      http_call PATCH "/blocks/$block_id" "$archive_body" || warn_exit0 "Notion API呼び出しに失敗(既存ブロック削除, status=${HTTP_STATUS:-?})"
    done <<< "$ids"
  fi

  cursor_info="$(python3 "$HELPER" page-cursor < "$listing_body")"
  has_more="${cursor_info%%$'\t'*}"
  next_cursor="${cursor_info#*$'\t'}"
  if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
    cursor="$next_cursor"
  else
    break
  fi
done

# --- MD全文→ブロック変換＆append（全置換の追記フェーズ。100ブロック/リクエスト上限で分割） ---
batches_file="$work/batches.jsonl"
python3 "$HELPER" md-to-batches < "$daily_file" > "$batches_file" || warn_exit0 "MD→ブロック変換に失敗"

if [ -s "$batches_file" ]; then
  while IFS= read -r batch_json; do
    [ -n "$batch_json" ] || continue
    append_body="$work/append-body.json"
    printf '{"children":%s}' "$batch_json" > "$append_body"
    http_call PATCH "/blocks/$page_id/children" "$append_body" || warn_exit0 "Notion API呼び出しに失敗(ブロック追加, status=${HTTP_STATUS:-?})"
  done < "$batches_file"
fi

echo "notion-push: 完了 ($page_title)"
exit 0
