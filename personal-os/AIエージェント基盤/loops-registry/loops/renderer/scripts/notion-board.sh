#!/usr/bin/env bash
# renderer / notion-board.sh — active計画一覧をNotionの「計画ボード」DBへupsertする（統合program N3）。
# usage: notion-board.sh
#
# データ源: plan-scan.sh（AREAS_BASE配下・auto:board-plansと同一ロジック）が出す "plan"/"program" 行
# （単発plan.md・program.md本体。子計画マップの子行は対象外＝行のキーは「計画名」＝plan.md/program.md
# 単位で、第2の状態正本を作らない）。行は 計画名 をキーにupsertする（同名衝突は既知の軽微な制限。
# plan-scanの「計画名」自体が唯一のキーという仕様前提のため個別対応しない）。
#
# 判断メモ（状態select列について）: plan.md/program.mdは「状態:」フィールドを持たない
# （areas/AGENTS.md §3.2＝フォルダのバケットが正本）。plan-scan.shはactiveバケットしか走査しない
# ため、この一覧に載る行の状態は構造的に常に "active" になる。これを別ロジックで推測・分類する
# （例: cockpit実況からの実行中/未着手判定）ことは「同じ情報源から取る。第2の状態正本を作らない」
# という指示に反するため行わない。状態selectは "active" 固定値として書く。
#
# 消えた計画のアーカイブ: Notion DB上の既存行を毎回全件query（archived行はquery結果に出ない前提の
# Notion仕様に依拠）し、今回のactive一覧のタイトルと突き合わせて、一致しなかった既存行を
# archived:true にする。差分専用の別state（第2の状態正本）は持たない。
#
# フェイルセーフ・secret規律はN1(notion-push.sh)と同一（警告1行+exit 0・トークンは変数保持のみ）。
# HTTP/secret差し替えはNOTION_CURL_CMD/NOTION_SECURITY_CMD（N1と共用の環境変数名）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/notion-common.sh"

HELPER="$SCRIPT_DIR/notion_helper.py"
CONF_FILE="${NOTION_PUSH_CONF:-$SCRIPT_DIR/../notion-push.conf}"
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
BOARD_DB_STATE_FILE="$STATE_DIR/notion-board-database-id"
KEYCHAIN_SERVICE="${NOTION_PUSH_KEYCHAIN_SERVICE:-notion-personal-os}"

warn_exit0() {
  echo "notion-board: 警告: $1" >&2
  exit 0
}

# --- secret取得（値は変数に保持するのみ。以降どの出力にも絶対に出さない） ---
notion_fetch_token "$KEYCHAIN_SERVICE" || warn_exit0 "Notionトークン取得失敗（キーチェーン未設定の可能性。security find-generic-password -s $KEYCHAIN_SERVICE を人間が登録する）"

work="$(mktemp -d "${TMPDIR:-/tmp}/notion-board.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

# --- parent page（Personal OS）解決。N1がすでに発見済みならそのキャッシュをそのまま使う ---
notion_resolve_parent_id "$CONF_FILE" "$STATE_DIR" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(親ページ解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 3 ]; then
  warn_exit0 "conf未設定かつ「Personal OS」ページのsearchが不発（notion-push.confのNOTION_PARENT_PAGE_IDを人間が設定する）"
fi

# --- 計画ボードDB解決（state → search → 無ければ作成） ---
db_create_body="$work/board-db-create-body.json"
python3 "$HELPER" board-db-create-payload --parent "$parent_id" > "$db_create_body" || warn_exit0 "DB作成payloadの構築に失敗"
notion_resolve_database_id "計画ボード" "$BOARD_DB_STATE_FILE" "$db_create_body" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(計画ボードDB解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 4 ]; then
  warn_exit0 "Notion API呼び出しに失敗(計画ボードDB作成, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 5 ]; then
  warn_exit0 "計画ボードDB作成のレスポンスからidが取得できない"
fi

# --- データ源: plan-scan.sh（AREAS_BASE配下。auto:board-plansと同一ロジック・同一情報源） ---
plans="$("$SCRIPT_DIR/plan-scan.sh")" || warn_exit0 "plan-scan.sh が失敗した（計画ボードの更新に必要なデータが取得できない）"

extract_category() {
  awk '
    NR==1 {
      n = split($0, parts, "／")
      for (i = 1; i <= n; i++) {
        f = parts[i]
        gsub(/^[ \t]+|[ \t]+$/, "", f)
        if (index(f, "分類:") == 1) {
          v = substr(f, index(f, ":") + 1)
          gsub(/^[ \t]+|[ \t]+$/, "", v)
          print v
          exit
        }
      }
    }
  ' "$1"
}

# 「次の一手」正本: plan.md/program.md冒頭の「次:」行（areas/AGENTS.md §2-2）。
# H1見出し（"# "）に達するまでに見つからなければ空（program.mdは通常ここが空。
# 次の一手は子計画マップ側の各子が持つため。合成・集約はしない＝第2の状態正本を作らない）。
extract_next() {
  awk '
    /^# / { exit }
    /^次:/ { sub(/^次:[ \t]*/, ""); print; exit }
  ' "$1"
}

# --- 既存行を全件query（archived行はNotion仕様上query結果に出ない） ---
existing_rows="$work/existing-rows.tsv"
: > "$existing_rows"
cursor=""
while :; do
  if [ -n "$cursor" ]; then
    query_body_src="{\"page_size\":100,\"start_cursor\":\"$cursor\"}"
  else
    query_body_src='{"page_size":100}'
  fi
  query_body="$work/query-body.json"
  printf '%s' "$query_body_src" > "$query_body"
  notion_http_call POST "/databases/$database_id/query" "$query_body" || warn_exit0 "Notion API呼び出しに失敗(計画ボード行一覧, status=${HTTP_STATUS:-?})"
  python3 "$HELPER" list-db-rows < "$HTTP_BODY_FILE" >> "$existing_rows"

  cursor_info="$(python3 "$HELPER" page-cursor < "$HTTP_BODY_FILE")"
  has_more="${cursor_info%%$'\t'*}"
  next_cursor="${cursor_info#*$'\t'}"
  if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
    cursor="$next_cursor"
  else
    break
  fi
done

matched_ids="$work/matched-ids.txt"
: > "$matched_ids"

upsert_row() {
  local area="$1" priority="$2" title="$3" path="$4"
  local category next existing_id
  category="$(extract_category "$path")"
  next="$(extract_next "$path")"

  # タイトル一致判定は index()+length() による完全一致にする（$2==t の素朴な文字列比較は、
  # macOS標準awk(onetrueawk)で長さの異なる多バイト文字列同士を誤って等しいと判定するバグが
  # 実測で確認されたため使わない。index()ベースの一致判定はこの環境で正しく動くことを確認済み）。
  existing_id="$(awk -F'\t' -v t="$title" 'BEGIN{tlen=length(t)} (index($2,t)==1 && length($2)==tlen){print $1; exit}' "$existing_rows")"

  if [ -n "$existing_id" ]; then
    local update_body="$work/row-update-body.json"
    python3 "$HELPER" board-row-update-payload --title "$title" --status active --priority "$priority" --category "$category" --next "$next" > "$update_body" || warn_exit0 "行更新payloadの構築に失敗: $title"
    notion_http_call PATCH "/pages/$existing_id" "$update_body" || warn_exit0 "Notion API呼び出しに失敗(行更新, status=${HTTP_STATUS:-?})"
    echo "$existing_id" >> "$matched_ids"
  else
    local create_body="$work/row-create-body.json"
    python3 "$HELPER" board-row-create-payload --db "$database_id" --title "$title" --status active --priority "$priority" --category "$category" --next "$next" > "$create_body" || warn_exit0 "行作成payloadの構築に失敗: $title"
    notion_http_call POST "/pages" "$create_body" || warn_exit0 "Notion API呼び出しに失敗(行作成, status=${HTTP_STATUS:-?})"
    local new_id
    new_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || warn_exit0 "行作成のレスポンスからidが取得できない: $title"
    echo "$new_id" >> "$matched_ids"
  fi
}

row_count=0
if [ -n "$plans" ]; then
  while IFS='|' read -r kind a b c d; do
    case "$kind" in
      plan|program)
        upsert_row "$a" "$b" "$c" "$d"
        row_count=$((row_count + 1))
        ;;
      *) : ;;
    esac
  done <<< "$plans"
fi

# --- 消えた計画のアーカイブ（既存行のうち今回一致しなかったものをarchived:trueにする） ---
sort -u "$matched_ids" > "$work/matched-ids.sorted"
cut -f1 "$existing_rows" | sort -u > "$work/existing-ids.sorted"
stale_ids="$work/stale-ids.txt"
comm -23 "$work/existing-ids.sorted" "$work/matched-ids.sorted" > "$stale_ids"

archived_count=0
if [ -s "$stale_ids" ]; then
  while IFS= read -r stale_id; do
    [ -n "$stale_id" ] || continue
    archive_body="$work/row-archive-body.json"
    printf '{"archived":true}' > "$archive_body"
    notion_http_call PATCH "/pages/$stale_id" "$archive_body" || warn_exit0 "Notion API呼び出しに失敗(行アーカイブ, status=${HTTP_STATUS:-?})"
    archived_count=$((archived_count + 1))
  done < "$stale_ids"
fi

echo "notion-board: 完了 (行=${row_count} アーカイブ=${archived_count})"
exit 0
