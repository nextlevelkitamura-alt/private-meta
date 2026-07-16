#!/usr/bin/env bash
# daily-notion-sync / session-table.sh — 当日デイリーの2節（session-board源）を
# Notionの表A「動いているエージェント」・表B「終わったこと」の2 DBへ upsert/archive する。
# 設計正本: ../../../my-brain/areas/ai運用/plans/active/2026-07-06-デイリーNotion表反映/plan.md
# 旧 renderer/notion-lanes.sh（N3b・cockpitレーン実況向け）の upsert/archive/schema冪等パターンを
# 踏襲する（データ源をorca ps→デイリーMDのparse-daily.shへ作り替え）。
#
# データ源: parse-daily.sh（board.pyのLINE_RE・入れ子構造と同型の解析）。
#
# 置き場所（2026-07-07変更・ローカルmdが日付ごとに1ファイルなのに合わせる）: 表A・表Bは
# 「Personal OS」直下に固定で置かず、**その日の日付タイトルのページ**（例:"2026-07-07"・
# 旧N1 notion-push.shが作っていた日付ページと同じ命名）を毎日find-or-createし、その直下に
# その日専用の表A/表Bを新規作成する。1ページ開けばその日の全部が見える、というユーザー要望。
#   - 日付ページの検索は全体検索（`notion_search_title`）でよい（日付文字列はほぼ衝突しない・
#     旧N1が同名ページを既に作っていればそれを再利用し2つの表を追加するだけ＝害が無い）。
#   - 表A/表Bは全日「動いているエージェント」「終わったこと」という同名タイトルになるため、
#     全体検索は使わない（別の日のDBを誤って再利用してしまう）。日付ページ直下の子ブロック
#     一覧だけを見る `find_child_database_id`（スコープ付き検索）で照合する。
#   - 状態キャッシュ（state/notion-*-database-id 等）は `.date` サイドカーで「どの日に対して
#     有効か」を持ち、日付が変わったら無条件でキャッシュを捨てて再解決させる
#     （`ensure_fresh_for_today`）。日付ページが新規作成だったとわかっている回（`date_page_is_new`）
#     は、その日の子DBがまだ存在しないと確定しているため子ブロック検索そのものをskipする。
#
# 表A「動いているエージェント」: 1行=1セッション。
#   upsertキー=キー列（board.pyの s:key、"s:"プレフィックスを除いた値）。完全一致のみで照合する。
#   デイリーから消えたキー（board.py finish で行削除された場合）は archive。
#
# 表B「終わったこと」: 1行=1成果（時刻付き子）。既に書かれた内容は変化しない追記専用ログのため、
#   upsertキー=repo|親タスク|時刻|成果 の連結（plan.md方針）。既存キーが見つかれば何もしない
#   （更新の必要な列が無い＝キー自体が全列を構成するため。同一キーでのPATCH呼び出しを省く）。
#
# archiveに0件ガードを設けない理由（2026-07-07変更）: 表A/表Bが日付ページ配下・日ごとに新規
# 作成される設計になったことで、「日付をまたいだ瞬間に前日分の実在行を誤って0件とみなし全archive
# してしまう」という旧設計の事故経路（renderer notion-lanes.shの空スナップショット誤archive
# 防止と同種の懸念）が構造的に無くなった（前日のDBはそもそも今日のsession-table.shが一切
# 触らない・新しい日は必ず空のDBから始まる）。日中の正当な0件（例: 稼働中セッションが1つも
# 無い瞬間）はそのままarchiveして問題ない（実際に0件という真実を反映するだけのため）。
# デイリーMD自体の読み取りはboard.pyのatomic rename書き込み（os.replace）により、読み取り中に
# 壊れた/中途半端な内容を拾うことも無い。
#
# フェイルセーフ・secret規律はrenderer由来のN1/N3bと同一（既定=警告1行+exit 0・トークンは変数保持
# のみ）。**SESSION_TABLE_STRICT=1**の時だけ、warn_exit0が警告を出したうえで非0終了する
# （sync.shがこれを検知して signature 更新をブロックし、次回tickへ自動リトライさせるため）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/_paths.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/notion-common.sh"

HELPER="$SCRIPT_DIR/notion_helper.py"
CONF_FILE="${NOTION_SYNC_CONF:-$SCRIPT_DIR/../notion.conf}"
STATE_DIR="${NOTION_SYNC_STATE_DIR:-$SCRIPT_DIR/../state}"
DATE_PAGE_STATE_FILE="$STATE_DIR/notion-date-page-id"
SESSIONS_DB_STATE_FILE="$STATE_DIR/notion-sessions-database-id"
DONE_DB_STATE_FILE="$STATE_DIR/notion-done-database-id"
KEYCHAIN_SERVICE="${NOTION_SYNC_KEYCHAIN_SERVICE:-notion-personal-os}"

warn_exit0() {
  echo "session-table: 警告: $1" >&2
  if [ "${SESSION_TABLE_STRICT:-0}" = "1" ]; then
    exit 1
  fi
  exit 0
}

fail_parse() {
  echo "session-table: 解析失敗: $1（Notion API呼び出し前に中止）" >&2
  exit 1
}

# ensure_fresh_for_today <state_file> <today> : state_fileの中身が「今日」のものでなければ
# 捨てる（次のresolve処理が新規解決するよう仕向ける）。有効日は state_file の隣の .date が持つ。
ensure_fresh_for_today() {
  local state_file="$1" today="$2" sidecar="${1}.date" stored_date=""
  [ -f "$sidecar" ] && stored_date="$(cat "$sidecar" 2>/dev/null || true)"
  if [ "$stored_date" != "$today" ]; then
    rm -f "$state_file" 2>/dev/null || true
    mkdir -p "$(dirname "$sidecar")" 2>/dev/null || true
    printf '%s' "$today" > "$sidecar"
  fi
}

# find_child_database_id <parent_block_id> <title> : parent_block_id直下の子ブロックを全ページ
# 走査し、type=child_databaseかつタイトル完全一致の最初の1件のidをstdoutへ出す（全体検索では
# 日付をまたいで同名DBを誤って再利用し得るため、日付ページ直下だけに限定する）。
# 見つからなければ何も出さない。HTTP呼び出し自体の失敗時のみ非0を返す。
find_child_database_id() {
  local parent_block_id="$1" title="$2"
  local cursor="" found="" url cursor_info has_more next_cursor
  while :; do
    url="/blocks/$parent_block_id/children?page_size=100"
    [ -n "$cursor" ] && url="$url&start_cursor=$cursor"
    notion_http_call GET "$url" || return 1
    found="$(python3 "$HELPER" find-child-database-id --title "$title" < "$HTTP_BODY_FILE")" || found=""
    if [ -n "$found" ]; then
      printf '%s' "$found"
      return 0
    fi
    cursor_info="$(python3 "$HELPER" page-cursor < "$HTTP_BODY_FILE")"
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

# resolve_or_create_child_database <title> <state_file> <create_payload_file> :
#   .dateサイドカーで日付ガード済みのstate_fileを見て、無ければ date_page_id 配下だけを
#   探し（date_page_is_new=1の回は探すまでもなく無いとわかっているのでskip）、無ければ作る。
#   成功時はグローバル database_id を設定し0を返す。失敗時は非0（2=検索失敗／4=作成失敗／
#   5=作成レスポンスからid取得失敗）。
resolve_or_create_child_database() {
  local title="$1" state_file="$2" create_payload_file="$3"
  database_id=""
  [ -f "$state_file" ] && database_id="$(cat "$state_file" 2>/dev/null || true)"
  [ -n "$database_id" ] && return 0

  if [ "$date_page_is_new" -ne 1 ]; then
    database_id="$(find_child_database_id "$date_page_id" "$title")" || return 2
  fi
  if [ -z "$database_id" ]; then
    notion_http_call POST "/databases" "$create_payload_file" || return 4
    database_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || database_id=""
    [ -n "$database_id" ] || return 5
  fi
  mkdir -p "$(dirname "$state_file")" 2>/dev/null || true
  printf '%s' "$database_id" > "$state_file"
  return 0
}

# query_all_rows <db_id> <list_subcommand> <out_tsv> : id\tキー値 をoutへ追記（全ページ走査）。
query_all_rows() {
  local db_id="$1" list_cmd="$2" out="$3"
  : > "$out"
  local cursor="" query_body query_body_src cursor_info has_more next_cursor
  query_body="$work/query-body.json"
  while :; do
    if [ -n "$cursor" ]; then
      query_body_src="{\"page_size\":100,\"start_cursor\":\"$cursor\"}"
    else
      query_body_src='{"page_size":100}'
    fi
    printf '%s' "$query_body_src" > "$query_body"
    notion_http_call POST "/databases/$db_id/query" "$query_body" || return 1
    python3 "$HELPER" "$list_cmd" < "$HTTP_BODY_FILE" >> "$out"
    cursor_info="$(python3 "$HELPER" page-cursor < "$HTTP_BODY_FILE")"
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

# resolve_existing_id <rows_tsv(id\tkey)> <key> : キー完全一致のみで既存行idを探す
# （index()+length()判定。macOS標準awk(onetrueawk)が多バイト文字列の==を誤判定するバグの回避。
# notion-lanes.shのresolve_lane_existing_idと同一手法）。
resolve_existing_id() {
  local rows_file="$1" key="$2" id
  id="$(awk -F'\t' -v k="$key" 'BEGIN{kl=length(k)} (k!="" && index($2,k)==1 && length($2)==kl){print $1; exit}' "$rows_file")"
  printf '%s' "$id"
}

# ============================================================
# 表A upsert
# ============================================================
upsert_session_row() {
  local existing_id="$1" time_="$2" repo="$3" type_="$4" summary="$5" state="$6" key="$7"
  if [ -n "$existing_id" ]; then
    local body="$work/session-row-update-body.json"
    python3 "$HELPER" session-row-update-payload --summary "$summary" --state "$state" --type "$type_" --time "$time_" --repo "$repo" --key "$key" > "$body" || warn_exit0 "表A行更新payloadの構築に失敗: $key"
    notion_http_call PATCH "/pages/$existing_id" "$body" || warn_exit0 "Notion API呼び出しに失敗(表A行更新, status=${HTTP_STATUS:-?})"
    echo "$existing_id" >> "$matched_session_ids"
  else
    local body="$work/session-row-create-body.json"
    python3 "$HELPER" session-row-create-payload --db "$sessions_db_id" --summary "$summary" --state "$state" --type "$type_" --time "$time_" --repo "$repo" --key "$key" > "$body" || warn_exit0 "表A行作成payloadの構築に失敗: $key"
    notion_http_call POST "/pages" "$body" || warn_exit0 "Notion API呼び出しに失敗(表A行作成, status=${HTTP_STATUS:-?})"
    local new_id
    new_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || warn_exit0 "表A行作成のレスポンスからidが取得できない: $key"
    echo "$new_id" >> "$matched_session_ids"
  fi
}

# ============================================================
# 表B upsert（既存キー一致は不変ログなので何もしない・新規のみ作成）
# ============================================================
create_done_row() {
  local repo="$1" parent="$2" time_="$3" entry="$4" key="$5"
  local body="$work/done-row-create-body.json"
  python3 "$HELPER" done-row-create-payload --db "$done_db_id" --entry "$entry" --time "$time_" --repo "$repo" --parent "$parent" --key "$key" > "$body" || warn_exit0 "表B行作成payloadの構築に失敗: $key"
  notion_http_call POST "/pages" "$body" || warn_exit0 "Notion API呼び出しに失敗(表B行作成, status=${HTTP_STATUS:-?})"
  local new_id
  new_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || warn_exit0 "表B行作成のレスポンスからidが取得できない: $key"
  echo "$new_id" >> "$matched_done_ids"
}

# ============================================================
# メインフロー
# ============================================================

work="$(mktemp -d "${TMPDIR:-/tmp}/session-table.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
daily_file="$(daily_file_for "$date_str")"

# --- 最初に入力を解析。未知形式ならsecret取得やNotion APIより前にfail-closed ---
sessions_tsv="$work/sessions.tsv"
"$SCRIPT_DIR/parse-daily.sh" sessions "$daily_file" > "$sessions_tsv" || fail_parse "parse-daily.sh(sessions)"
done_tsv="$work/done.tsv"
"$SCRIPT_DIR/parse-daily.sh" done "$daily_file" > "$done_tsv" || fail_parse "parse-daily.sh(done)"

# --- secret取得（値は変数に保持するのみ。以降どの出力にも絶対に出さない） ---
notion_fetch_token "$KEYCHAIN_SERVICE" || warn_exit0 "Notionトークン取得失敗（キーチェーン未設定の可能性。security find-generic-password -s $KEYCHAIN_SERVICE を人間が登録する）"

# --- parent page（Personal OS）解決。renderer(N1/N2/N3)が発見済みならそのキャッシュを共有する ---
notion_resolve_parent_id "$CONF_FILE" "$STATE_DIR" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(親ページ解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 3 ]; then
  warn_exit0 "conf未設定かつ「Personal OS」ページのsearchが不発（notion.confのNOTION_PARENT_PAGE_IDを人間が設定する）"
fi

# --- 日付ページ解決（state → 全体search → 無ければ作成）。表A/表Bはこの直下に作る ---
ensure_fresh_for_today "$DATE_PAGE_STATE_FILE" "$date_str"
date_page_id=""
[ -f "$DATE_PAGE_STATE_FILE" ] && date_page_id="$(cat "$DATE_PAGE_STATE_FILE" 2>/dev/null || true)"
date_page_is_new=0
if [ -z "$date_page_id" ]; then
  date_page_id="$(notion_search_title "$date_str" page "$HELPER")" || warn_exit0 "Notion検索APIの呼び出しに失敗(日付ページ解決, status=${HTTP_STATUS:-?})"
  if [ -z "$date_page_id" ]; then
    date_page_create_body="$work/date-page-create-body.json"
    python3 "$HELPER" page-create-payload --parent "$parent_id" --title "$date_str" > "$date_page_create_body" || warn_exit0 "日付ページ作成payloadの構築に失敗"
    notion_http_call POST "/pages" "$date_page_create_body" || warn_exit0 "Notion API呼び出しに失敗(日付ページ作成, status=${HTTP_STATUS:-?})"
    date_page_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || warn_exit0 "日付ページ作成のレスポンスからidが取得できない"
    date_page_is_new=1
  fi
  mkdir -p "$(dirname "$DATE_PAGE_STATE_FILE")" 2>/dev/null || true
  printf '%s' "$date_page_id" > "$DATE_PAGE_STATE_FILE"
fi

# --- 表A DB解決（日付ページ配下・state→scoped検索→無ければ作成）＋ スキーマ冪等追加 ---
ensure_fresh_for_today "$SESSIONS_DB_STATE_FILE" "$date_str"
sessions_db_create_body="$work/sessions-db-create-body.json"
python3 "$HELPER" sessions-db-create-payload --parent "$date_page_id" > "$sessions_db_create_body" || warn_exit0 "表A DB作成payloadの構築に失敗"
resolve_or_create_child_database "動いているエージェント" "$SESSIONS_DB_STATE_FILE" "$sessions_db_create_body"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion API呼び出しに失敗(表A DB検索, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 4 ]; then
  warn_exit0 "Notion API呼び出しに失敗(表A DB作成, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 5 ]; then
  warn_exit0 "表A DB作成のレスポンスからidが取得できない"
fi
sessions_db_id="$database_id"

sessions_schema_body="$work/sessions-db-schema-body.json"
python3 "$HELPER" sessions-db-schema-payload > "$sessions_schema_body" || warn_exit0 "表A DBスキーマpayloadの構築に失敗"
notion_http_call PATCH "/databases/$sessions_db_id" "$sessions_schema_body" || warn_exit0 "Notion API呼び出しに失敗(表A DBスキーマ追加, status=${HTTP_STATUS:-?})"

# --- 表B DB解決（日付ページ配下・state→scoped検索→無ければ作成）＋ スキーマ冪等追加 ---
ensure_fresh_for_today "$DONE_DB_STATE_FILE" "$date_str"
done_db_create_body="$work/done-db-create-body.json"
python3 "$HELPER" done-db-create-payload --parent "$date_page_id" > "$done_db_create_body" || warn_exit0 "表B DB作成payloadの構築に失敗"
resolve_or_create_child_database "終わったこと" "$DONE_DB_STATE_FILE" "$done_db_create_body"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion API呼び出しに失敗(表B DB検索, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 4 ]; then
  warn_exit0 "Notion API呼び出しに失敗(表B DB作成, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 5 ]; then
  warn_exit0 "表B DB作成のレスポンスからidが取得できない"
fi
done_db_id="$database_id"

done_schema_body="$work/done-db-schema-body.json"
python3 "$HELPER" done-db-schema-payload > "$done_schema_body" || warn_exit0 "表B DBスキーマpayloadの構築に失敗"
notion_http_call PATCH "/databases/$done_db_id" "$done_schema_body" || warn_exit0 "Notion API呼び出しに失敗(表B DBスキーマ追加, status=${HTTP_STATUS:-?})"

# --- 既存行の全件query（archived行はNotion仕様上query結果に出ない） ---
existing_session_rows="$work/existing-session-rows.tsv"
query_all_rows "$sessions_db_id" "list-session-rows" "$existing_session_rows" || warn_exit0 "Notion API呼び出しに失敗(表A行一覧, status=${HTTP_STATUS:-?})"
existing_done_rows="$work/existing-done-rows.tsv"
query_all_rows "$done_db_id" "list-done-rows" "$existing_done_rows" || warn_exit0 "Notion API呼び出しに失敗(表B行一覧, status=${HTTP_STATUS:-?})"

matched_session_ids="$work/matched-session-ids.txt"
: > "$matched_session_ids"
session_count=0
if [ -s "$sessions_tsv" ]; then
  while IFS=$'\t' read -r time_ repo type_ summary state key; do
    [ -n "$key" ] || continue
    session_count=$((session_count + 1))
    existing_id="$(resolve_existing_id "$existing_session_rows" "$key")"
    upsert_session_row "$existing_id" "$time_" "$repo" "$type_" "$summary" "$state" "$key"
  done < "$sessions_tsv"
fi

sort -u "$matched_session_ids" > "$work/matched-session-ids.sorted"
cut -f1 "$existing_session_rows" | sort -u > "$work/existing-session-ids.sorted"
comm -23 "$work/existing-session-ids.sorted" "$work/matched-session-ids.sorted" > "$work/archive-session-ids.txt"

archived_session_count=0
if [ -s "$work/archive-session-ids.txt" ]; then
  archive_body="$work/row-archive-body.json"
  printf '%s' '{"archived":true}' > "$archive_body"
  while IFS= read -r archive_id; do
    [ -n "$archive_id" ] || continue
    notion_http_call PATCH "/pages/$archive_id" "$archive_body" || warn_exit0 "Notion API呼び出しに失敗(表A行アーカイブ, status=${HTTP_STATUS:-?}): $archive_id"
    archived_session_count=$((archived_session_count + 1))
  done < "$work/archive-session-ids.txt"
fi

matched_done_ids="$work/matched-done-ids.txt"
: > "$matched_done_ids"
done_count=0
if [ -s "$done_tsv" ]; then
  while IFS=$'\t' read -r repo parent time_ entry; do
    [ -n "$entry" ] || continue
    done_count=$((done_count + 1))
    key="${repo}|${parent}|${time_}|${entry}"
    existing_id="$(resolve_existing_id "$existing_done_rows" "$key")"
    if [ -n "$existing_id" ]; then
      echo "$existing_id" >> "$matched_done_ids"
    else
      create_done_row "$repo" "$parent" "$time_" "$entry" "$key"
    fi
  done < "$done_tsv"
fi

sort -u "$matched_done_ids" > "$work/matched-done-ids.sorted"
cut -f1 "$existing_done_rows" | sort -u > "$work/existing-done-ids.sorted"
comm -23 "$work/existing-done-ids.sorted" "$work/matched-done-ids.sorted" > "$work/archive-done-ids.txt"

archived_done_count=0
if [ -s "$work/archive-done-ids.txt" ]; then
  archive_body2="$work/row-archive-body2.json"
  printf '%s' '{"archived":true}' > "$archive_body2"
  while IFS= read -r archive_id; do
    [ -n "$archive_id" ] || continue
    notion_http_call PATCH "/pages/$archive_id" "$archive_body2" || warn_exit0 "Notion API呼び出しに失敗(表B行アーカイブ, status=${HTTP_STATUS:-?}): $archive_id"
    archived_done_count=$((archived_done_count + 1))
  done < "$work/archive-done-ids.txt"
fi

date_page_new_label=""
[ "$date_page_is_new" -eq 1 ] && date_page_new_label="新規"
echo "session-table: 完了 (日付ページ=${date_str}${date_page_new_label} 表A行=${session_count} archive=${archived_session_count} / 表B行=${done_count} archive=${archived_done_count})"
exit 0
