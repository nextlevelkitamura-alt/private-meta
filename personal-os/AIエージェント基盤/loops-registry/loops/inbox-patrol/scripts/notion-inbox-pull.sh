#!/usr/bin/env bash
# inbox-patrol / notion-inbox-pull.sh — Notion「依頼インボックス」DBの立案済行をローカル当日デイリーへ
# 取り込む一方向pull（統合program N2。2026-07-09 デイリー運用刷新 子06で renderer/scripts から移設。
# 共有Notionライブラリ notion-common.sh / notion_helper.py の正本は renderer/scripts のまま参照する）。
# usage: notion-inbox-pull.sh [daily_file_path]
#   省略時: _paths.sh の daily_file_for、実行時点のJST当日。
#
# 処理: DB「依頼インボックス」（状態select: 空白=下書き/立案済/回収済み/起案済み。回収済み→起案済み
# は notify-drafted.sh が起案完了時にPATCHする）の「状態=立案済」行を取得し、ローカル当日デイリーの
# 「## 依頼インボックス」節末尾へ「- <依頼テキスト>」を追記した上で、該当Notion行の状態を
# 「回収済み」に更新する。状態が空白の行は下書きとして回収しない（人間が「立案済」へ切り替えた
# 行だけが回収対象。旧「新規」選択肢は廃止・残存行の整理は人間が1回行う）。行の作成はしない
# （作成はユーザーがスマホのNotionから直接行う。統合program plan.md 方針6）。
#
# 二重取り込み防止: 取り込んだNotion行idを state/notion-inbox-pulled-ids（gitignore・追記のみ）に
# 記録する。ローカルへの追記は「未記録のidの回だけ」行う。追記→state記録→Notion状態patch、の順で
# 進めるため、途中で失敗しても（=warn_exit0で即終了しても）ローカルに二重追記される経路は無い
# （記録前に失敗すれば次回まるごとリトライ、記録後にNotion patchだけ失敗しても次回はpatchの
# リトライだけを行い再追記はしない）。
#
# 出所マップ（子06追加）: 新規取り込み時に「id<TAB>依頼テキスト」を state/notion-inbox-origin-ids へ
# 追記する。起案完了時に notify-drafted.sh がこのマップで該当Notion行を逆引きし、状態=起案済み＋
# 計画パスをPATCHする（マップに無い行＝デイリー直書き/kickoff行はPC通知のみ）。
#
# auto:マーカー不可侵: 「## 依頼インボックス」節（マーカー無しの人間節）の末尾にだけ追記する。
# auto:*:begin/end のどの区画にも触れない（該当セクション自体を経由しない。マーカー内側の
# 読み書きは daily-digest/scripts/get-marker-block.sh / set-marker-block.sh 専用という契約は
# ここでも維持し、本スクリプトはそれらを一切呼ばない＝マーカー区画には触れようがない）。
#
# フェイルセーフ・secret規律はN1(notion-push.sh)と同一（警告1行+exit 0・トークンは変数保持のみ）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
RENDERER_SCRIPTS="$(cd "$SCRIPT_DIR/../../renderer/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"
# shellcheck source=/dev/null
source "$RENDERER_SCRIPTS/notion-common.sh"

HELPER="$RENDERER_SCRIPTS/notion_helper.py"
CONF_FILE="${NOTION_PUSH_CONF:-$SCRIPT_DIR/../../renderer/notion-push.conf}"
# STATE_DIR 既定は本loop配下 inbox-patrol/state（gitignore済み）。移設前は renderer/state だった。
# 旧 state（notion-inbox-pulled-ids）を引き継ぐ場合は人間が有効化時にコピーする（loop.md 有効化手順）。
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
INBOX_DB_STATE_FILE="$STATE_DIR/notion-inbox-database-id"
PULLED_STATE_FILE="$STATE_DIR/notion-inbox-pulled-ids"
ORIGIN_STATE_FILE="$STATE_DIR/notion-inbox-origin-ids"
KEYCHAIN_SERVICE="${NOTION_PUSH_KEYCHAIN_SERVICE:-notion-personal-os}"
INBOX_HEADING="## 依頼インボックス"

warn_exit0() {
  echo "notion-inbox-pull: 警告: $1" >&2
  exit 0
}

daily_file="${1:-}"
if [ -z "$daily_file" ]; then
  date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  daily_file="$(daily_file_for "$date_str")"
fi
[ -f "$daily_file" ] || warn_exit0 "デイリーファイルが無いためpullをskip: $daily_file"

# --- secret取得（値は変数に保持するのみ。以降どの出力にも絶対に出さない） ---
notion_fetch_token "$KEYCHAIN_SERVICE" || warn_exit0 "Notionトークン取得失敗（キーチェーン未設定の可能性。security find-generic-password -s $KEYCHAIN_SERVICE を人間が登録する）"

work="$(mktemp -d "${TMPDIR:-/tmp}/notion-inbox-pull.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

# --- parent page（Personal OS）解決。N1/N3がすでに発見済みならそのキャッシュをそのまま使う ---
notion_resolve_parent_id "$CONF_FILE" "$STATE_DIR" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(親ページ解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 3 ]; then
  warn_exit0 "conf未設定かつ「Personal OS」ページのsearchが不発（notion-push.confのNOTION_PARENT_PAGE_IDを人間が設定する）"
fi

# --- 依頼インボックスDB解決（state → search → 無ければ作成） ---
db_create_body="$work/inbox-db-create-body.json"
python3 "$HELPER" inbox-db-create-payload --parent "$parent_id" > "$db_create_body" || warn_exit0 "DB作成payloadの構築に失敗"
notion_resolve_database_id "依頼インボックス" "$INBOX_DB_STATE_FILE" "$db_create_body" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(依頼インボックスDB解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 4 ]; then
  warn_exit0 "Notion API呼び出しに失敗(依頼インボックスDB作成, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 5 ]; then
  warn_exit0 "依頼インボックスDB作成のレスポンスからidが取得できない"
fi

# --- 「状態=立案済」行を全件query（サーバ側filter。状態が空白の下書き行はこの条件に一致しない
#     ＝回収されない） ---
target_rows="$work/new-rows.tsv"
: > "$target_rows"
cursor=""
while :; do
  if [ -n "$cursor" ]; then
    query_body_src="{\"page_size\":100,\"start_cursor\":\"$cursor\",\"filter\":{\"property\":\"状態\",\"select\":{\"equals\":\"立案済\"}}}"
  else
    query_body_src='{"page_size":100,"filter":{"property":"状態","select":{"equals":"立案済"}}}'
  fi
  query_body="$work/query-body.json"
  printf '%s' "$query_body_src" > "$query_body"
  notion_http_call POST "/databases/$database_id/query" "$query_body" || warn_exit0 "Notion API呼び出しに失敗(依頼インボックス行一覧, status=${HTTP_STATUS:-?})"
  python3 "$HELPER" list-db-rows < "$HTTP_BODY_FILE" >> "$target_rows"

  cursor_info="$(python3 "$HELPER" page-cursor < "$HTTP_BODY_FILE")"
  has_more="${cursor_info%%$'\t'*}"
  next_cursor="${cursor_info#*$'\t'}"
  if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
    cursor="$next_cursor"
  else
    break
  fi
done

if [ ! -s "$target_rows" ]; then
  echo "notion-inbox-pull: 完了 (立案済0件)"
  exit 0
fi

mkdir -p "$STATE_DIR" || warn_exit0 "state保存先の作成に失敗: $STATE_DIR"
[ -f "$PULLED_STATE_FILE" ] || : > "$PULLED_STATE_FILE"

# --- 未取り込み(state未記録)分だけを追記対象にする。既に取り込み済み(state記録済み)だが
#     Notion側の状態patchが前回失敗して「立案済」のまま残っている行は、再追記せずpatchだけ retry する ---
to_append="$work/to-append.txt"
: > "$to_append"
fresh_ids="$work/fresh-ids.txt"
: > "$fresh_ids"
fresh_origins="$work/fresh-origins.tsv"
: > "$fresh_origins"

while IFS=$'\t' read -r row_id row_text; do
  [ -n "$row_id" ] || continue
  grep -qxF "$row_id" "$PULLED_STATE_FILE" && continue
  printf -- '- %s\n' "$row_text" >> "$to_append"
  echo "$row_id" >> "$fresh_ids"
  printf '%s\t%s\n' "$row_id" "$row_text" >> "$fresh_origins"
done < "$target_rows"

if [ -s "$to_append" ]; then
  grep -qF "$INBOX_HEADING" "$daily_file" || warn_exit0 "「$INBOX_HEADING」節が無いため追記をskip: $daily_file"

  tmp="$work/daily.tmp"
  # 見出し行の同定は index()+length() による完全一致判定にする（$0 == heading の素朴な文字列比較
  # は、macOS標準awk(onetrueawk)で長さの異なる多バイト文字列同士を誤って等しいと判定するバグが
  # 実測で確認されたため使わない。index()ベースの一致判定はこの環境で正しく動くことを確認済み）。
  awk -v contentfile="$to_append" -v heading="$INBOX_HEADING" '
    BEGIN {
      n = 0
      while ((getline line < contentfile) > 0) { n++; content[n] = line }
      close(contentfile)
      hlen = length(heading)
    }
    (index($0, heading) == 1 && length($0) == hlen) { print; insection = 1; next }
    insection && /^## / {
      for (i = 1; i <= n; i++) print content[i]
      insection = 0
      print
      next
    }
    { print }
    END {
      if (insection) {
        for (i = 1; i <= n; i++) print content[i]
      }
    }
  ' "$daily_file" > "$tmp" || warn_exit0 "デイリーへの追記に失敗: $daily_file"
  mv "$tmp" "$daily_file" || warn_exit0 "デイリーの更新反映に失敗: $daily_file"

  while IFS= read -r fresh_id; do
    [ -n "$fresh_id" ] || continue
    echo "$fresh_id" >> "$PULLED_STATE_FILE"
  done < "$fresh_ids"

  # 出所マップ（id<TAB>依頼テキスト）。notify-drafted.sh が起案完了時の逆引きに使う（追記のみ）。
  cat "$fresh_origins" >> "$ORIGIN_STATE_FILE" || warn_exit0 "出所マップの記録に失敗: $ORIGIN_STATE_FILE"
fi

# --- 各行の状態を「回収済み」に更新（新規追記分・retry分の両方） ---
status_body="$work/status-update-body.json"
printf '{"properties":{"状態":{"select":{"name":"回収済み"}}}}' > "$status_body"
updated_count=0
while IFS=$'\t' read -r row_id row_text; do
  [ -n "$row_id" ] || continue
  notion_http_call PATCH "/pages/$row_id" "$status_body" || warn_exit0 "Notion API呼び出しに失敗(状態更新, status=${HTTP_STATUS:-?})"
  updated_count=$((updated_count + 1))
done < "$target_rows"

echo "notion-inbox-pull: 完了 (回収=${updated_count})"
exit 0
