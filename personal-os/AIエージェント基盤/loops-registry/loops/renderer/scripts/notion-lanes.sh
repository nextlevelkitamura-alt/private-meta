#!/usr/bin/env bash
# renderer / notion-lanes.sh — cockpitレーン実況をNotionの「レーン実況」DBへupsertする（統合program N3b）。
# usage: notion-lanes.sh
#
# データ源: orca-ps-snapshot.sh（auto:board-now/auto:board-waitと同一。ORCA_PS_CMD経由の
# `orca worktree ps --json`）＋ cockpit-stage-lookup.sh（build-board-now.shと共有する
# COCKPIT_EVENTS_FILE段階lookup）。第2の収集実装は作らない（既存収集ロジックの純粋な再利用）。
#
# 列再設計v2（統合program plan.md 方針5e・2026-07-03朝ユーザー裁定）:
#   ①レーン名(title)＝状態のみ（絵文字+状態語。例 "✅完了"／"▶実装中"／"🔔確認待ち"／"⏸待機中"。
#     worktree名は含めない）。
#   ②計画(rich_text)＝orca-ps-snapshot.shのdisplayName（cockpitの--titleが入る）。非cockpit
#     worktree（displayName未設定）や、displayNameがbranch名と同じ（cockpitがdisplayNameを
#     明示設定しなかった既定値）の場合は"-"。
#   ③repo(select)：既存のまま（worktree親ディレクトリ名から導出。全行必ず埋める）。
#   ④種別(select)＝worktree／mainの2値。パスが～/orca/workspaces配下または.claude/worktrees配下
#     ならworktree、それ以外（repoルート直下等）はmain。
#   ⑤フォルダーパス(rich_text)＝upsertキーであると同時に「パス」表示列を兼ねる（別列を増やさない）。
#
# upsertキー: worktreeの絶対パスを専用列「フォルダーパス」に書き込み、これを唯一の正キーとして
# 行を特定する（完全一致のみ。旧形式タイトルからのフォールバック照合は撤去済み＝全行が
# キー化済みの前提。キー列が空の行は遺物として次回同期でarchiveされる）。
#
# 作業内容（rich_text・機械判定。全行に必ず何か入る）: 優先順位は
#   (1) エージェントが1体も居ない → 「エージェント無し(worktree回収対象候補)」
#   (2) 全agentがdoneかつ直近メッセージが *_PASS（レビューPASSマーカー） → 「レビューPASS・マージ/回収待ち」
#   (3) それ以外（稼働中） → 段階語（実装中／レビュー中／修正中／確認待ち／完了／稼働中／待機中）
#   （down済み値は廃止。閉じたレーンは行ごとarchiveするため作業内容を書き換える必要が無い）。
#   上記いずれの場合も、cockpit段階イベントの管轄(owner)がそのレーンに有れば末尾へ
#   「／管轄:X」をテキスト追記する（先行部品①・owner-view-read）。新規プロパティは作らない
#   （notion_helper.pyのschema=11プロパティ不変）。owner無し（旧イベント含む）のレーンは不変。
#
# repo（select・全行必ず埋める）: 種別(kind)によって導出方法が異なる（実反映で発見・
# 差し戻し修正: 従来は種別を無視して常に親ディレクトリ名を拾っていたため、種別=mainの行が
# 実データで repo=kitamuranaohiro(実パス~/Private)・repo=LP(…/nextlevel-career-site)・
# repo=personal-os(…/AIエージェント基盤)のような誤値になっていた）。
#   - kind=main: パス自身のbasename（そのフォルダ自身の名前。例 Private・AIエージェント基盤）。
#   - kind=worktreeかつ.claude/worktrees配下: .claudeの2階層上のrepoフォルダ名
#     （従来はrepo=worktreesになっていた）。
#   - kind=worktreeかつ～/orca/workspaces/<repo>/<branch>形式: 従来どおり<repo>部
#     （＝親ディレクトリのbasename）。
# 空/"."/"/"など不明瞭な結果になった場合はworktree自身のbasenameへフォールバックする（空にしない）。
#
# 並び順（number）: -1=■サマリ／0=人間の出番（人間確認待ち・agentエラー・段階=完了・
# 全agent done＝いずれか）／1=稼働中（段階が実装系/修正系、またはagentが1体以上working）／
# 2=それ以外（idle・no-agent）。状態絵文字は並び順から一意に決まる（0=🔔／1=▶／2=⏸）。
#
# 閉じたレーン・遺物行（統合program plan.md 方針5e）: 前回まで存在し今回のorca psに居ない
# レーン、およびフォルダーパス列が空の遺物行（旧形式・移行漏れ）は、行ごとPATCH /pages/{id}
# archived:true でarchiveする（down済み表示はしない。計画ボード(N3)と同じ挙動に統一）。
#
# 空スナップショットの誤アーカイブ防止（差し戻し修正・High）: orca-ps-snapshot.shが
# 「exit 0だがworktrees空」を返すと（orca CLIの一時的な不調等）、今回マッチする行が
# ■サマリしか無くなり、それまでアクティブだった全レーン行がarchive対象に落ちてしまう事故
# 経路があった。`state/notion-lanes-last-lane-count` に前回のレーン数を記録し、今回の
# レーン数が0の時は「前回も0だった時（＝2回連続で確認できた時）だけ」アーカイブを実行する
# （初回の0検出はアーカイブをskipして警告するだけに留める）。レーンが1本以上生きている
# 通常時の個別archiveはこのガードの影響を受けない（現在のレーン数が0の時だけ働く）。
#
# サマリ行: title「■サマリ」固定キーで「稼働エージェント数: N体／レーンM本」を作業内容へ書く。
#
# 判断メモ（データ制約による簡略化）:
#   - 「ペイン」は agentType=state のペアを「／」区切りで並べるのみで「実装/レビュー」等の
#     役割ラベルは付けない。orca-ps-snapshot.shの出力はagents配列をpath,agent_typeの辞書順で
#     ソート済みで起動順を保持していないため、役割を位置から推測すると誤りうる。
#   - 「要注意」の停滞判定はcockpit-supervisor/watch.shの画面シグネチャ検知が正本であり、
#     このレンダラの既存収集データには停滞シグナルが無いため自動upsertは「停滞」を設定しない
#     （DBのselect選択肢としては用意する）。
#
# DBスキーマの冪等追加: 既存DB（プロパティ追加より前に作られたもの）に新プロパティが無い
# 可能性があるため、毎回 PATCH /v1/databases/{id} でプロパティ定義を再送する（Notionは
# 名前でマージするため、既にあれば同一定義の上書き=無害・無ければ追加。プロパティは増殖しない）。
#
# フェイルセーフ・secret規律はN1(notion-push.sh)と同一（既定=警告1行+exit 0・トークンは変数保持
# のみ）。**LANES_STRICT=1**の時だけは例外（差し戻し修正・High）: このスクリプトは全ての失敗を
# warn_exit0一箇所（token取得・parent page解決・DB解決/作成・スキーマPATCH・行一覧query・行の
# create/update・行のarchive PATCH等）に集約しているため、LANES_STRICT=1の時はwarn_exit0が
# 警告を出したうえで**非0で終了**する（既定=LANES_STRICT未設定時はexit 0のまま・render.sh本流の
# フェイルセーフは不変）。呼び出し元のlanes-sync.shはLANES_STRICT=1でこのスクリプトを呼び、
# 非0終了を検知した時だけsignature保存をブロックする（=API失敗が実際に次回リトライへつながる。
# 従来はwarn_exit0が常にexit 0だったため、lanes-sync.sh側の失敗検知が実際のAPI失敗では機能しない
# 欠陥があった）。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/notion-common.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cockpit-stage-lookup.sh"

HELPER="$SCRIPT_DIR/notion_helper.py"
CONF_FILE="${NOTION_PUSH_CONF:-$SCRIPT_DIR/../notion-push.conf}"
STATE_DIR="${NOTION_PUSH_STATE_DIR:-$SCRIPT_DIR/../state}"
LANES_DB_STATE_FILE="$STATE_DIR/notion-lanes-database-id"
LAST_LANE_COUNT_FILE="$STATE_DIR/notion-lanes-last-lane-count"
KEYCHAIN_SERVICE="${NOTION_PUSH_KEYCHAIN_SERVICE:-notion-personal-os}"
SUMMARY_TITLE="■サマリ"

warn_exit0() {
  echo "notion-lanes: 警告: $1" >&2
  if [ "${LANES_STRICT:-0}" = "1" ]; then
    exit 1
  fi
  exit 0
}

# --- secret取得（値は変数に保持するのみ。以降どの出力にも絶対に出さない） ---
notion_fetch_token "$KEYCHAIN_SERVICE" || warn_exit0 "Notionトークン取得失敗（キーチェーン未設定の可能性。security find-generic-password -s $KEYCHAIN_SERVICE を人間が登録する）"

work="$(mktemp -d "${TMPDIR:-/tmp}/notion-lanes.XXXXXX")" || warn_exit0 "一時ディレクトリ作成に失敗"
trap 'rm -rf "$work"' EXIT

# --- parent page（Personal OS）解決。N1/N2/N3がすでに発見済みならそのキャッシュをそのまま使う ---
notion_resolve_parent_id "$CONF_FILE" "$STATE_DIR" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(親ページ解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 3 ]; then
  warn_exit0 "conf未設定かつ「Personal OS」ページのsearchが不発（notion-push.confのNOTION_PARENT_PAGE_IDを人間が設定する）"
fi

# --- レーン実況DB解決（state → search → 無ければ作成） ---
db_create_body="$work/lanes-db-create-body.json"
python3 "$HELPER" lanes-db-create-payload --parent "$parent_id" > "$db_create_body" || warn_exit0 "DB作成payloadの構築に失敗"
notion_resolve_database_id "レーン実況" "$LANES_DB_STATE_FILE" "$db_create_body" "$HELPER"
rc=$?
if [ "$rc" -eq 2 ]; then
  warn_exit0 "Notion検索APIの呼び出しに失敗(レーン実況DB解決, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 4 ]; then
  warn_exit0 "Notion API呼び出しに失敗(レーン実況DB作成, status=${HTTP_STATUS:-?})"
elif [ "$rc" -eq 5 ]; then
  warn_exit0 "レーン実況DB作成のレスポンスからidが取得できない"
fi

# --- DBスキーマの冪等追加（新プロパティが無い旧DBにも追加する） ---
schema_body="$work/lanes-db-schema-body.json"
python3 "$HELPER" lanes-db-schema-payload > "$schema_body" || warn_exit0 "DBスキーマpayloadの構築に失敗"
notion_http_call PATCH "/databases/$database_id" "$schema_body" || warn_exit0 "Notion API呼び出しに失敗(DBスキーマ追加, status=${HTTP_STATUS:-?})"

# --- データ源: orca-ps-snapshot.sh（auto:board-now/auto:board-waitと同一情報源） ---
snapshot=""
if ! snapshot="$("$SCRIPT_DIR/orca-ps-snapshot.sh")"; then
  warn_exit0 "orca-ps-snapshot.sh が失敗した（レーン実況の更新に必要なデータが取得できない）"
fi

STAGE_MAP="$(cockpit_latest_stage_by_worktree)"
OWNER_MAP="$(cockpit_latest_owner_by_worktree)"

updated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# lastAssistantMessage最終行が段階語彙・完了/合否マーカーかどうかを判定する
# （build-board-now.shのis_marker_lineと同一基準。会話本文はここに一致しない限り使わない）。
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

# --- 既存行を全件query（archived行はNotion仕様上query結果に出ない）。
#     list-lane-rowsで id / フォルダーパス値(key) を得る。 ---
existing_lane_rows="$work/existing-lane-rows.tsv"
: > "$existing_lane_rows"
cursor=""
while :; do
  if [ -n "$cursor" ]; then
    query_body_src="{\"page_size\":100,\"start_cursor\":\"$cursor\"}"
  else
    query_body_src='{"page_size":100}'
  fi
  query_body="$work/query-body.json"
  printf '%s' "$query_body_src" > "$query_body"
  notion_http_call POST "/databases/$database_id/query" "$query_body" || warn_exit0 "Notion API呼び出しに失敗(レーン実況行一覧, status=${HTTP_STATUS:-?})"
  python3 "$HELPER" list-lane-rows < "$HTTP_BODY_FILE" >> "$existing_lane_rows"

  cursor_info="$(python3 "$HELPER" page-cursor < "$HTTP_BODY_FILE")"
  has_more="${cursor_info%%$'\t'*}"
  next_cursor="${cursor_info#*$'\t'}"
  if [ "$has_more" = "true" ] && [ -n "$next_cursor" ]; then
    cursor="$next_cursor"
  else
    break
  fi
done

# resolve_lane_existing_id <key(フォルダーパスに書く値)> : keyの完全一致だけで既存行idを探す
# （旧形式行のフォールバック照合は撤去済み。全行がキー化済みの前提。キー列が空の行は
# resolve対象にならず、次段のarchiveで遺物として片付く）。index()+length()で完全一致判定する
# （macOS標準awk(onetrueawk)が長さの異なる多バイト文字列同士の==を誤判定するバグの回避）。
resolve_lane_existing_id() {
  local key="$1" id
  id="$(awk -F'\t' -v k="$key" 'BEGIN{kl=length(k)} (k!="" && index($2,k)==1 && length($2)==kl){print $1; exit}' "$existing_lane_rows")"
  printf '%s' "$id"
}

# repo_for_path <worktree path> <kind> : repoの導出は種別(kind)によって異なる（実反映で発見・
# 差し戻し修正。従来は種別を無視して常に親ディレクトリ名を拾っていたため、種別=mainの行が
# 実データで repo=kitamuranaohiro(実パス~/Private) のような「パスの1つ上のフォルダ名」の
# 誤値になっていた）。
#   - kind=main: そのフォルダ自身のbasename（例 Private・AIエージェント基盤・
#     nextlevel-career-site）。mainはworktreeではなくrepoチェックアウトそのものなので、
#     フォルダ名自体がrepo名である。
#   - kind=worktree かつ .claude/worktrees配下: "/.claude/worktrees/"より前の部分の
#     basename（.claudeの2階層上のrepoフォルダ名。例 nextlevel-career-site）。従来は
#     親ディレクトリ名(=worktrees)を拾ってしまっていた。
#   - kind=worktree かつ ~/orca/workspaces/<repo>/<branch>形式: 従来どおり親ディレクトリの
#     basename（<repo>部）。
# 空/"."/"/"など不明瞭な結果はworktree自身のbasenameへフォールバックする（全行必ず埋める・
# 空にしない）。
repo_for_path() {
  local p="${1%/}" kind="$2" r
  case "$kind" in
    main)
      r="$(basename "$p")"
      ;;
    *)
      case "$p" in
        */.claude/worktrees/*) r="$(basename "${p%%/.claude/worktrees/*}")" ;;
        *) r="$(basename "$(dirname "$p")")" ;;
      esac
      ;;
  esac
  case "$r" in
    ""|"."|"/") r="$(basename "$p")" ;;
  esac
  printf '%s' "$r"
}

# kind_for_path <worktree path> : ～/orca/workspaces配下または.claude/worktrees配下ならworktree、
# それ以外（repoルート直下等）はmainとする（統合program plan.md 方針5e）。
kind_for_path() {
  local p="$1"
  case "$p" in
    */orca/workspaces/*) printf 'worktree' ;;
    */.claude/worktrees/*) printf 'worktree' ;;
    *) printf 'main' ;;
  esac
}

# plan_for <displayName> <branch> : cockpitの--titleが入ったdisplayNameをそのまま「計画」列に
# 使う。displayNameが空（非cockpit worktree）、またはbranch名と同じ（cockpitがdisplayNameを
# 明示設定しなかった既定値）の場合は"-"にする（統合program plan.md 方針5e）。
plan_for() {
  local display="$1" branch="$2"
  if [ -z "$display" ] || [ "$display" = "$branch" ]; then
    printf '%s' '-'
  else
    printf '%s' "$display"
  fi
}

matched_ids="$work/matched-ids.txt"
: > "$matched_ids"

# upsert_lane_row <existing_id(空なら新規)> <key> <display_title> <work> <stage> <panes>
#                 <attention> <repo> <sort_order> <plan> <kind>
upsert_lane_row() {
  local existing_id="$1" key="$2" display_title="$3" work_content="$4" stage="$5" panes="$6"
  local attention="$7" repo="$8" sort_order="$9" plan="${10}" kind="${11}"

  if [ -n "$existing_id" ]; then
    local update_body="$work/row-update-body.json"
    python3 "$HELPER" lane-row-update-payload --title "$display_title" --work "$work_content" --stage "$stage" --panes "$panes" --attention "$attention" --updated "$updated_at" --repo "$repo" --sort-order "$sort_order" --key "$key" --plan "$plan" --kind "$kind" > "$update_body" || warn_exit0 "行更新payloadの構築に失敗: $display_title"
    notion_http_call PATCH "/pages/$existing_id" "$update_body" || warn_exit0 "Notion API呼び出しに失敗(行更新, status=${HTTP_STATUS:-?})"
    echo "$existing_id" >> "$matched_ids"
  else
    local create_body="$work/row-create-body.json"
    python3 "$HELPER" lane-row-create-payload --db "$database_id" --title "$display_title" --work "$work_content" --stage "$stage" --panes "$panes" --attention "$attention" --updated "$updated_at" --repo "$repo" --sort-order "$sort_order" --key "$key" --plan "$plan" --kind "$kind" > "$create_body" || warn_exit0 "行作成payloadの構築に失敗: $display_title"
    notion_http_call POST "/pages" "$create_body" || warn_exit0 "Notion API呼び出しに失敗(行作成, status=${HTTP_STATUS:-?})"
    local new_id
    new_id="$(python3 "$HELPER" extract-id < "$HTTP_BODY_FILE")" || warn_exit0 "行作成のレスポンスからidが取得できない: $display_title"
    echo "$new_id" >> "$matched_ids"
  fi
}

# --- snapshot（path×agent一件=1行）をレーン(path)単位に集約する ---
lane_paths="$work/lane-paths.txt"
: > "$lane_paths"
if [ -n "$snapshot" ]; then
  printf '%s\n' "$snapshot" | awk -F'|' '{ print $1 }' | awk '!seen[$0]++' > "$lane_paths"
fi

lane_count=0
agent_count=0

if [ -s "$lane_paths" ]; then
  while IFS= read -r lane_path; do
    [ -n "$lane_path" ] || continue
    lane_count=$((lane_count + 1))

    lane_owner="$(cockpit_lookup_owner "$OWNER_MAP" "$lane_path")"
    worktree=""
    display=""
    lane_branch=""
    panes=""
    stage=""
    attention="なし"
    has_agent=0
    lane_agent_count=0
    lane_done_count=0
    any_working=0
    saw_pass=0

    while IFS='|' read -r path wt disp branch wstatus agent_type state lastline; do
      [ "$path" = "$lane_path" ] || continue
      [ -n "$worktree" ] || worktree="$wt"
      [ -n "$display" ] || display="$disp"
      [ -n "$lane_branch" ] || lane_branch="$branch"

      event_stage="$(cockpit_lookup_stage "$STAGE_MAP" "$path")"

      if [ -z "$agent_type" ]; then
        [ -n "$panes" ] || panes="エージェント無し（worktree状態:${wstatus:-不明}）"
        [ -n "$event_stage" ] && [ -z "$stage" ] && stage="$event_stage"
        continue
      fi

      has_agent=1
      agent_count=$((agent_count + 1))
      lane_agent_count=$((lane_agent_count + 1))
      [ "$state" = "done" ] && lane_done_count=$((lane_done_count + 1))
      [ "$state" = "working" ] && any_working=1
      panes="${panes:+${panes}／}${agent_type}=${state:-不明}"

      case "$lastline" in *_PASS) saw_pass=1 ;; esac

      if [ -n "$event_stage" ]; then
        stage="$event_stage"
      elif [ -z "$stage" ] && is_marker_line "$lastline"; then
        case "$lastline" in
          *人間確認待ち*) stage="人間確認待ち" ;;
          *_FAIL) stage="修正" ;;
          *_DONE|*_PASS) stage="完了" ;;
          段階:*) stage="${lastline#段階:}"; stage="${stage# }" ;;
        esac
      fi

      if [ -n "$lastline" ] && printf '%s' "$lastline" | grep -qF "人間確認待ち"; then
        attention="人間確認待ち"
      elif [ "$attention" = "なし" ] && printf '%s' "$lastline" | grep -qE '_FAIL$'; then
        attention="エラー"
      fi
    done <<< "$snapshot"

    [ "$has_agent" -eq 1 ] || panes="${panes:-エージェント無し}"

    # --- 並び順（統合program plan.md 方針5d） ---
    all_done=0
    [ "$has_agent" -eq 1 ] && [ "$lane_agent_count" -eq "$lane_done_count" ] && all_done=1
    stage_working_bucket=0
    case "$stage" in 実装*|修正*) stage_working_bucket=1 ;; esac
    stage_done_bucket=0
    case "$stage" in 完了*) stage_done_bucket=1 ;; esac

    sort_order=2
    if [ "$attention" = "人間確認待ち" ] || [ "$attention" = "エラー" ] || [ "$stage_done_bucket" -eq 1 ] || [ "$all_done" -eq 1 ]; then
      sort_order=0
    elif [ "$stage_working_bucket" -eq 1 ] || [ "$any_working" -eq 1 ]; then
      sort_order=1
    fi
    case "$sort_order" in
      0) emoji="🔔" ;;
      1) emoji="▶" ;;
      *) emoji="⏸" ;;
    esac

    # --- 状態語(タイトル用)・作業内容の機械判定（統合program plan.md 方針5d追補・2026-07-03） ---
    stage_word_text=""
    case "$stage" in
      実装レビュー*) stage_word_text="レビュー中" ;;
      実装*) stage_word_text="実装中" ;;
      修正*) stage_word_text="修正中" ;;
      完了*) stage_word_text="完了" ;;
      人間確認待ち*) stage_word_text="確認待ち" ;;
    esac

    if [ "$has_agent" -eq 0 ]; then
      status_word="エージェント無し"
      work_content="エージェント無し(worktree回収対象候補)"
    elif [ "$all_done" -eq 1 ] && [ "$saw_pass" -eq 1 ]; then
      status_word="完了"
      work_content="レビューPASS・マージ/回収待ち"
    elif [ "$attention" = "エラー" ]; then
      status_word="エラー"
      work_content="${stage_word_text:-エラー}"
    elif [ "$attention" = "人間確認待ち" ]; then
      status_word="確認待ち"
      work_content="${stage_word_text:-確認待ち}"
    elif [ -n "$stage_word_text" ]; then
      status_word="$stage_word_text"
      work_content="$stage_word_text"
    elif [ "$sort_order" -eq 1 ]; then
      status_word="稼働中"
      work_content="稼働中"
    else
      status_word="待機中"
      work_content="待機中"
    fi

    # cockpit段階イベントの管轄(owner)を作業内容へテキスト反映する（先行部品①・新規プロパティは
    # 作らない=notion_helper.pyのschema不変。owner無しレーンは不変のまま＝後方互換）。
    [ -n "$lane_owner" ] && work_content="${work_content}／管轄:${lane_owner}"

    kind="$(kind_for_path "$lane_path")"
    repo="$(repo_for_path "$lane_path" "$kind")"
    plan="$(plan_for "$display" "$lane_branch")"
    display_title="${emoji}${status_word}"

    existing_id="$(resolve_lane_existing_id "$lane_path")"
    upsert_lane_row "$existing_id" "$lane_path" "$display_title" "$work_content" "$stage" "$panes" "$attention" "$repo" "$sort_order" "$plan" "$kind"
  done < "$lane_paths"
fi

# --- サマリ行（固定タイトル■サマリ。稼働エージェント数／レーン本数。並び順=-1で最上段固定。
#     repo/計画は「全行必ず埋める」に合わせプレースホルダ"-"を入れる。種別はレーンではないためnull） ---
summary_text="稼働エージェント数: ${agent_count}体／レーン${lane_count}本"
summary_existing_id="$(resolve_lane_existing_id "$SUMMARY_TITLE")"
upsert_lane_row "$summary_existing_id" "$SUMMARY_TITLE" "$SUMMARY_TITLE" "$summary_text" "" "" "なし" "-" "-1" "-" ""

# --- 閉じたレーン・遺物行のarchive（統合program plan.md 方針5e）: 前回まで存在し今回
#     matched_idsに含まれない行（＝orca psから消えたレーン、またはフォルダーパス列が空の
#     遺物行=旧形式・移行漏れ）は、行ごとPATCH /pages/{id} archived:true でarchiveする
#     （down済み表示はしない。計画ボード(N3)と同じ挙動に統一）。
#
#     空スナップショット誤アーカイブ防止（差し戻し修正・High）: 今回のレーン数(lane_count)が
#     0の場合、前回のレーン数（state/notion-lanes-last-lane-count）も0だった時だけ
#     アーカイブを実行する。前回が1本以上だった場合は「orca psが一時的に空を返しただけ」の
#     可能性を疑い、今回はアーカイブを一切skipして警告するに留める（次回も0が続けば
#     2回連続で確認できたとみなしアーカイブする）。 ---
previous_lane_count=""
[ -f "$LAST_LANE_COUNT_FILE" ] && previous_lane_count="$(cat "$LAST_LANE_COUNT_FILE" 2>/dev/null || true)"

skip_archive_for_empty_snapshot=0
if [ "$lane_count" -eq 0 ] && [ "$previous_lane_count" != "0" ]; then
  skip_archive_for_empty_snapshot=1
  echo "notion-lanes: 警告: orca psが0レーンを返した(前回のレーン数:${previous_lane_count:-不明})。一時的な不調による誤検知の可能性があるためアーカイブを今回はskipする(次回も0なら実行される)" >&2
fi

sort -u "$matched_ids" > "$work/matched-ids.sorted"
cut -f1 "$existing_lane_rows" | sort -u > "$work/existing-ids.sorted"
comm -23 "$work/existing-ids.sorted" "$work/matched-ids.sorted" > "$work/archive-ids.txt"

archived_count=0
if [ "$skip_archive_for_empty_snapshot" -eq 0 ] && [ -s "$work/archive-ids.txt" ]; then
  archive_body="$work/row-archive-body.json"
  printf '%s' '{"archived":true}' > "$archive_body"
  while IFS= read -r archive_id; do
    [ -n "$archive_id" ] || continue
    notion_http_call PATCH "/pages/$archive_id" "$archive_body" || warn_exit0 "Notion API呼び出しに失敗(行アーカイブ, status=${HTTP_STATUS:-?}): $archive_id"
    archived_count=$((archived_count + 1))
  done < "$work/archive-ids.txt"
fi

mkdir -p "$(dirname "$LAST_LANE_COUNT_FILE")" 2>/dev/null || true
printf '%s' "$lane_count" > "$LAST_LANE_COUNT_FILE"

echo "notion-lanes: 完了 (レーン=${lane_count} エージェント=${agent_count} アーカイブ=${archived_count})"
exit 0
