#!/usr/bin/env bash
# renderer / notion-common.sh — N1(notion-push.sh)と同型のsecret取得・HTTP呼び出し・
# 親ページ(Personal OS)解決ロジックを N3(notion-board.sh)・N2(notion-inbox-pull.sh)で共有する。
# source専用（単体実行しない・shebangはshellcheck向け）。notion-push.sh自体は変更しない
# （既存12テストの回帰リスクを避けるため。N1は本ファイルを使わず従来どおり自己完結のまま）。
#
# secret規律: NOTION_TOKENは呼び出し元スクリプトのグローバル変数として保持するのみ。
# echo・ログ・エラーメッセージ・コミットに値を絶対に出さない（N1と同一規律）。
# curl/security呼び出しは NOTION_CURL_CMD / NOTION_SECURITY_CMD でテスト用stubに差し替え可能
# （N1と同じ方式・同じ環境変数名）。

NOTION_API="${NOTION_PUSH_API_BASE:-https://api.notion.com/v1}"
NOTION_VERSION="2022-06-28"

# notion_fetch_token <keychain_service>
#   成功時: グローバル NOTION_TOKEN を設定し0を返す。失敗時: 1を返す（値はどこにも出さない）。
notion_fetch_token() {
  local service="$1"
  NOTION_TOKEN="$(${NOTION_SECURITY_CMD:-security} find-generic-password -s "$service" -w 2>/dev/null)"
  local rc=$?
  [ "$rc" -eq 0 ] && [ -n "$NOTION_TOKEN" ]
}

# notion_http_call <method> <path_with_query> [body_file]
#   呼び出し元が作業ディレクトリ $work を用意している前提（mktemp -d 済み）。
#   成功(2xx)時0、それ以外1を返す。HTTP_STATUS / HTTP_BODY_FILE に結果を残す
#   （次の notion_http_call 呼び出しで上書きされる。呼び出し側は直後に読む前提）。
notion_http_call() {
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

# notion_search_title <title> <object_type: page|database> <helper_py>
#   /search を has_more/next_cursor で全ページ走査し（DB行クエリ・ブロック一覧と同じ流儀）、
#   object_typeかつタイトルが title と完全一致する最初の1件のidを stdout へ出す。
#   差し戻し修正: 従来は page_size:10 の単発呼び出しで打ち切っており、2ページ目以降にある
#   既存の親ページ/DBを見逃して重複作成する不具合があった（N1の当日ページ探索と同型のバグ。
#   レビュアーがstubで再現）。
#   戻り値: HTTP呼び出し自体が失敗した場合のみ非0（$HTTP_STATUSに結果が残る）。
#   見つからなかった場合は0を返し、何も出力しない（「search成功・0件」と「search失敗」を区別する
#   ため、呼び出し側は出力の有無で判定する）。
notion_search_title() {
  local title="$1" object_type="$2" helper="$3"
  local finder="find-title-id"
  [ "$object_type" = "database" ] && finder="find-db-id"

  local cursor="" found=""
  while :; do
    local search_body
    search_body="$(mktemp "$work/search-body.XXXXXX")" || return 1
    python3 -c '
import json, sys
title, object_type, cursor = sys.argv[1], sys.argv[2], sys.argv[3]
payload = {"query": title, "filter": {"property": "object", "value": object_type}, "page_size": 100}
if cursor:
    payload["start_cursor"] = cursor
print(json.dumps(payload, ensure_ascii=False))
' "$title" "$object_type" "$cursor" > "$search_body"

    notion_http_call POST "/search" "$search_body" || return 1
    found="$(python3 "$helper" "$finder" --title "$title" < "$HTTP_BODY_FILE")" || found=""
    if [ -n "$found" ]; then
      printf '%s' "$found"
      return 0
    fi

    local cursor_info has_more next_cursor
    cursor_info="$(python3 "$helper" page-cursor < "$HTTP_BODY_FILE")"
    has_more="${cursor_info%%$'\t'*}"
    next_cursor="${cursor_info#*$'\t'}"
    if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
      cursor="$next_cursor"
    else
      break
    fi
  done
  return 0
}

# notion_resolve_parent_id <conf_file> <state_dir> <helper_py>
#   conf → state キャッシュ → search API(タイトル"Personal OS"・全ページ走査) の順で解決する
#   （N1と同一ロジック・同一のキャッシュファイル $state_dir/notion-parent-page-id を共有するため、
#   N1がすでに発見済みのparent idをN2/N3/N3bも再利用できる＝第2の状態正本を作らない）。
#   成功時: グローバル parent_id を設定し0を返す（新規発見時は state_dir へ保存する）。
#   失敗時: 非0を返す（2=search呼び出し自体の失敗／3=search不発）。呼び出し側が
#   $HTTP_STATUS 等を見て自分のプレフィックスで警告文言を組み立てる（メッセージ出力はしない）。
notion_resolve_parent_id() {
  local conf_file="$1" state_dir="$2" helper="$3"
  local parent_state_file="$state_dir/notion-parent-page-id"

  parent_id=""
  if [ -f "$conf_file" ]; then
    # shellcheck source=/dev/null
    source "$conf_file"
  fi
  parent_id="${NOTION_PARENT_PAGE_ID:-}"

  if [ -z "$parent_id" ] && [ -f "$parent_state_file" ]; then
    parent_id="$(cat "$parent_state_file" 2>/dev/null || true)"
  fi

  [ -n "$parent_id" ] && return 0

  parent_id="$(notion_search_title "Personal OS" page "$helper")" || return 2
  [ -n "$parent_id" ] || return 3

  mkdir -p "$state_dir" || return 2
  printf '%s' "$parent_id" > "$parent_state_file"
  return 0
}

# notion_resolve_database_id <title> <state_file> <create_payload_json_file>
#   state キャッシュ → search API(object=database・タイトル完全一致・全ページ走査) → 無ければ作成、
#   の順で解決する。
#   成功時: グローバル database_id を設定し0を返す（新規発見・新規作成時は state_file へ保存する）。
#   失敗時: 非0を返す（2=search呼び出し失敗／4=作成呼び出し失敗／5=作成レスポンスからid取得失敗）。
notion_resolve_database_id() {
  local title="$1" state_file="$2" create_payload_file="$3" helper="$4"

  database_id=""
  if [ -f "$state_file" ]; then
    database_id="$(cat "$state_file" 2>/dev/null || true)"
  fi
  [ -n "$database_id" ] && return 0

  database_id="$(notion_search_title "$title" database "$helper")" || return 2

  if [ -z "$database_id" ]; then
    notion_http_call POST "/databases" "$create_payload_file" || return 4
    database_id="$(python3 "$helper" extract-id < "$HTTP_BODY_FILE")" || database_id=""
    [ -n "$database_id" ] || return 5
  fi

  mkdir -p "$(dirname "$state_file")" || return 2
  printf '%s' "$database_id" > "$state_file"
  return 0
}
