#!/usr/bin/env bash
# daily-notion-sync / tests / run-tests.sh — parse-daily.sh・session-table.sh・sync.sh の
# テストスイート。実API・実トークン・実キーチェーンには一切触れない。
# - security find-generic-password は NOTION_SECURITY_CMD でstub（成功/失敗を切り替え）に差し替える。
# - curl は NOTION_CURL_CMD で fixtures/notion-curl-stub.py（renderer由来のNotion API状態stub。
#   NOTION_STUB_STATE_FILE に永続化）に差し替える。
# board.pyとの行フォーマット整合は t4（実board.pyを起動してparse-daily.shへ通す回帰テスト）で守る。
#
# 注意（GOAL_BASEの意味がboard.pyと_paths.shで異なる）: board.py の GOAL_BASE は
# 「デイリーフォルダ自体」を指す（値に直接 y/m/d.md を続ける）。一方このloopの _paths.sh の
# GOAL_BASE は「ゴールフォルダ」を指し、daily_file_for() が /デイリー/ を後から足す。
# t4 はこの差を吸収するため、board.py には末尾に「デイリー」を含む値を渡す。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$TESTS_DIR/.." && pwd)"
SCRIPTS_DIR="$LOOP_DIR/scripts"
FIXTURES_DIR="$TESTS_DIR/fixtures"
STUB_PY="$FIXTURES_DIR/notion-curl-stub.py"
BOARD_PY="$LOOP_DIR/../../../hooks-registry/hooks/session-board/board.py"

TODAY="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"

pass_count=0
fail_count=0
fail_names=()
workdirs=()

cleanup_all() {
  local d
  for d in "${workdirs[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
trap cleanup_all EXIT

# --- ヘルパ ---

new_workdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/daily-notion-sync-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/scripts" "$d/goal" "$d/state"
  cp -R "$SCRIPTS_DIR/." "$d/scripts/"
  printf '%s' "$d"
}

make_security_ok() {
  local path="$1" token="$2"
  cat > "$path" <<EOF
#!/usr/bin/env bash
printf '%s' '$token'
EOF
  chmod +x "$path"
}

make_security_fail() {
  local path="$1"
  cat > "$path" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$path"
}

write_daily() {
  local path="$1" content="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$content" > "$path"
}

# daily_path_for <workdir> <YYYY-MM-DD> : そのworkdirの_paths.shが実際に解決するデイリーパスを
# 出す（テスト側でパス組み立てロジックを二重実装しない。本物のdaily_file_for()を呼ぶ）。
daily_path_for() {
  local d="$1" date="$2"
  GOAL_BASE="$d/goal" bash -c 'source "$1/scripts/_paths.sh" && daily_file_for "$2"' _ "$d" "$date"
}

run_test() {
  local name="$1"
  echo "=== $name ==="
  if "$name"; then
    echo "PASS: $name"
    pass_count=$((pass_count + 1))
  else
    echo "FAIL: $name"
    fail_count=$((fail_count + 1))
    fail_names+=("$name")
  fi
  echo
}

# ============================================================
# t1: parse-daily.sh sessions — 正常系のTSV抽出（board.pyのLINE_RE同型）
# ============================================================
t1_parse_sessions_ok() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | テスト要約 | 🟢動作中 <!-- s:key001 -->
- 10:15 | focusmap | レビュー | 別の要約 | ⏸停止・確認待ち <!-- s:key002 -->

## 終わったこと
"
  out="$("$d/scripts/parse-daily.sh" sessions "$daily")"
  expected="09:00	Private	実装	テスト要約	🟢動作中	key001
10:15	focusmap	レビュー	別の要約	⏸停止・確認待ち	key002"
  [ "$out" = "$expected" ]
)

# ============================================================
# t2: parse-daily.sh done — 入れ子構造(### repo ＞ - 親 ＞ 子)の抽出
# ============================================================
t2_parse_done_nested() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント

## 終わったこと
### Private
- 検証タスク
  - 17:19 hooks-registryへ再編完了
  - 16:54 symlink窓露出
### focusmap
- UI修正
  - 11:00 ボタン色修正完了
"
  out="$("$d/scripts/parse-daily.sh" done "$daily")"
  expected="Private	検証タスク	17:19	hooks-registryへ再編完了
Private	検証タスク	16:54	symlink窓露出
focusmap	UI修正	11:00	ボタン色修正完了"
  [ "$out" = "$expected" ]
)

# ============================================================
# t3: parse-daily.sh — ファイル未生成なら空・exit 0（sessions/doneとも）
# ============================================================
t3_parse_missing_file() (
  set -uo pipefail
  d="$(new_workdir)"
  out_s="$("$d/scripts/parse-daily.sh" sessions "$d/goal/no-such-file.md")"; rc_s=$?
  out_d="$("$d/scripts/parse-daily.sh" done "$d/goal/no-such-file.md")"; rc_d=$?
  [ -z "$out_s" ] && [ "$rc_s" -eq 0 ] && [ -z "$out_d" ] && [ "$rc_d" -eq 0 ]
)

# ============================================================
# t4: parse-daily.sh — 実board.pyが書いた実物との整合（フォーマット同期の回帰ガード）
# ============================================================
t4_parse_matches_real_board_py() (
  set -uo pipefail
  [ -f "$BOARD_PY" ] || return 0
  d="$(new_workdir)"
  GOAL_BASE="$d/goal/デイリー" SESSION_BOARD_DATE="$TODAY" python3 "$BOARD_PY" add --key realkey01 --repo テストrepo --type 実装 --summary "本物のboard.py整合テスト" >/dev/null
  GOAL_BASE="$d/goal/デイリー" SESSION_BOARD_DATE="$TODAY" python3 "$BOARD_PY" log --key realkey01 --repo テストrepo --parent 検証 --entry "成果テスト" >/dev/null
  daily="$(daily_path_for "$d" "$TODAY")"
  [ -f "$daily" ] || return 1
  sessions_out="$("$d/scripts/parse-daily.sh" sessions "$daily")"
  done_out="$("$d/scripts/parse-daily.sh" done "$daily")"
  printf '%s' "$sessions_out" | grep -qF "	テストrepo	実装	本物のboard.py整合テスト	🟢動作中	realkey01" &&
  printf '%s' "$done_out" | grep -qF "テストrepo	検証	" &&
  printf '%s' "$done_out" | grep -qF "成果テスト"
)

# ============================================================
# t5: session-table.sh — secret規律（固定トークンが標準出力・標準エラーのどこにも現れない）
# ============================================================
t5_secret_never_leaks() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | 秘密テスト | 🟢動作中 <!-- s:secretkey -->

## 終わったこと
"
  token="DAILY-NOTION-SYNC-TEST-TOKEN-MARKER-9f8e7d"
  make_security_ok "$d/security-ok.sh" "$token"

  out="$(GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/session-table.sh" 2>&1)"

  ! printf '%s' "$out" | grep -qF "$token"
)

# ============================================================
# t6: session-table.sh — 新規作成→2回目実行で重複ゼロ（冪等性）
# ============================================================
t6_idempotent_two_runs() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | 冪等テスト | 🟢動作中 <!-- s:idem001 -->

## 終わったこと
### Private
- タスク
  - 08:00 成果1
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  run_st() {
    GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/session-table.sh"
  }
  run_st >/dev/null || return 1
  run_st >/dev/null || return 1
  row_count="$(python3 -c "
import json
s = json.load(open('$d/stub-state.json', encoding='utf-8'))
print(len(s.get('db_rows', {})))
")"
  [ "$row_count" -eq 2 ]
)

# ============================================================
# t7: session-table.sh — 行削除でarchive・状態変化で更新・新規成果で追加・既存成果は不変
# ============================================================
t7_upsert_and_archive() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | セッションA | 🟢動作中 <!-- s:aaa -->
- 10:00 | Private | 実装 | セッションB | 🟢動作中 <!-- s:bbb -->

## 終わったこと
### Private
- タスク
  - 08:00 成果1
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  run_st() {
    GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/session-table.sh"
  }
  run_st >/dev/null || return 1

  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | セッションA・更新済み | ⏸停止・確認待ち <!-- s:aaa -->

## 終わったこと
### Private
- タスク
  - 09:30 成果2
  - 08:00 成果1
"
  run_st >/dev/null || return 1

  python3 -c "
import json
s = json.load(open('$d/stub-state.json', encoding='utf-8'))
rows = s.get('db_rows', {})
def title_of(r):
    for k in ('内容', '成果'):
        p = r['properties'].get(k)
        if p:
            return ''.join(t['text']['content'] for t in p.get('title', []))
    return None
by_title = {title_of(r): r for r in rows.values()}
assert by_title.get('セッションA・更新済み') and not by_title['セッションA・更新済み']['archived'], 'aaa should survive updated'
assert by_title['セッションA・更新済み']['properties']['状態']['select']['name'] == '⏸停止・確認待ち', 'aaa state should update'
assert by_title.get('セッションB') and by_title['セッションB']['archived'], 'bbb should be archived'
assert by_title.get('成果1') and not by_title['成果1']['archived'], '成果1 should survive untouched'
assert by_title.get('成果2') and not by_title['成果2']['archived'], '成果2 should be created'
print('ok')
" | grep -q "^ok$"
)

# ============================================================
# t8: session-table.sh — 0件ガード（1回目は誤archive防止でskip・2回連続で実行）
# ============================================================
t8_zero_count_guard() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | ガードテスト | 🟢動作中 <!-- s:guard001 -->

## 終わったこと
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  run_st() {
    GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/session-table.sh"
  }
  run_st >/dev/null || return 1

  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント

## 終わったこと
"
  run_st >/dev/null || return 1
  alive1="$(python3 -c "
import json
s = json.load(open('$d/stub-state.json', encoding='utf-8'))
print(sum(1 for r in s.get('db_rows', {}).values() if not r['archived']))
")"
  [ "$alive1" -eq 1 ] || { echo "1回目0件でarchiveされてしまった: alive=$alive1" >&2; return 1; }

  run_st >/dev/null || return 1
  alive2="$(python3 -c "
import json
s = json.load(open('$d/stub-state.json', encoding='utf-8'))
print(sum(1 for r in s.get('db_rows', {}).values() if not r['archived']))
")"
  [ "$alive2" -eq 0 ]
)

# ============================================================
# t9: sync.sh — 無変化なら Notion API 呼び出しゼロ
# ============================================================
t9_sync_no_change_zero_api_calls() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | sync検証 | 🟢動作中 <!-- s:syncchk -->

## 終わったこと
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  run_sync() {
    GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/sync.sh"
  }
  run_sync >/dev/null || return 1
  : > "$d/stub-log.txt"
  run_sync >/dev/null || return 1
  [ ! -s "$d/stub-log.txt" ]
)

# ============================================================
# t10: sync.sh — 失敗時(STRICT伝播)はsignature未更新・次回tickで自動リトライされる
# ============================================================
t10_sync_failure_keeps_signature_for_retry() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント
- 09:00 | Private | 実装 | リトライ検証 | 🟢動作中 <!-- s:retrychk -->

## 終わったこと
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  make_security_fail "$d/security-fail.sh"
  sig_file="$d/state/notion-session-table-sync-signature"

  GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-fail.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/sync.sh" >/dev/null 2>&1
  sync_rc=$?
  [ "$sync_rc" -eq 0 ] || return 1
  [ ! -f "$sig_file" ] || return 1

  GOAL_BASE="$d/goal" \
    NOTION_SYNC_CONF="$d/notion-empty.conf" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_STATE_FILE="$d/stub-state.json" \
    NOTION_STUB_LOG_FILE="$d/stub-log.txt" \
    "$d/scripts/sync.sh" >/dev/null 2>&1
  [ -f "$sig_file" ]
)

# ============================================================
# t11: sync.sh — ロック中は多重起動せずexit 0
# ============================================================
t11_sync_lock_prevents_concurrent_run() (
  set -uo pipefail
  d="$(new_workdir)"
  daily="$(daily_path_for "$d" "$TODAY")"
  write_daily "$daily" "# デイリー $TODAY

## 動いているエージェント

## 終わったこと
"
  make_security_ok "$d/security-ok.sh" "FAKE-TOKEN"
  mkdir -p "$d/state/notion-session-table-sync.lock"
  out="$(GOAL_BASE="$d/goal" \
    NOTION_SYNC_STATE_DIR="$d/state" \
    NOTION_SECURITY_CMD="$d/security-ok.sh" \
    "$d/scripts/sync.sh" 2>&1)"
  rc=$?
  rmdir "$d/state/notion-session-table-sync.lock" 2>/dev/null || true
  [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF "ロック中"
)

# ============================================================
run_test t1_parse_sessions_ok
run_test t2_parse_done_nested
run_test t3_parse_missing_file
run_test t4_parse_matches_real_board_py
run_test t5_secret_never_leaks
run_test t6_idempotent_two_runs
run_test t7_upsert_and_archive
run_test t8_zero_count_guard
run_test t9_sync_no_change_zero_api_calls
run_test t10_sync_failure_keeps_signature_for_retry
run_test t11_sync_lock_prevents_concurrent_run

echo "============================================================"
echo "結果: PASS=$pass_count FAIL=$fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
