#!/usr/bin/env bash
# renderer / tests / notion-common-tests.sh — notion-common.sh（N2/N3/N3b共有のsecret取得・HTTP呼び出し・
# 親ページ/DB解決）のテストスイート。特に notion_resolve_parent_id / notion_resolve_database_id の
# /search 全ページ走査（差し戻し修正: 従来はpage_size:10の単発呼び出しで打ち切っており、2ページ目
# 以降にある既存の親ページ/DBを見逃して重複作成していた。N1の当日ページ探索と同型のバグ）を検証する。
# 実API・実トークン・実キーチェーンには一切触れない。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERER_DIR="$(cd "$TESTS_DIR/.." && pwd)"
LOOPS_DIR="$(cd "$RENDERER_DIR/.." && pwd)"
FIXTURES_DIR="$TESTS_DIR/fixtures"
STUB_PY="$FIXTURES_DIR/notion-curl-stub.py"

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

new_workdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/notion-common-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

write_conf() {
  local path="$1" parent_id="${2:-}"
  printf 'NOTION_PARENT_PAGE_ID=%s\n' "$parent_id" > "$path"
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
# ct1: notion_resolve_parent_id が /search の2ページ目にある既存「Personal OS」ページを
#      見逃さず解決する（1ページ目=fillerのみ150件、本物は2ページ目）。新規作成は一切しない。
# ============================================================
ct1_parent_search_finds_page2_result() (
  set -uo pipefail
  workdir="$(new_workdir)"
  common_sh="$workdir/loops-registry/loops/renderer/scripts/notion-common.sh"
  helper="$workdir/loops-registry/loops/renderer/scripts/notion_helper.py"

  stub_state="$workdir/stub-state.json"
  python3 -c "
import json
state = {'parent_id': 'personal-os-real-id', 'pages': {}, 'children_of': {}, 'databases': {}, 'db_rows': {}, 'search_page_fillers': 150}
json.dump(state, open('$stub_state', 'w', encoding='utf-8'))
"

  conf="$workdir/notion-push.conf"; write_conf "$conf" ""
  state_dir="$workdir/state"
  stub_log="$workdir/stub-log.txt"

  export NOTION_CURL_CMD="python3 $STUB_PY"
  export NOTION_STUB_STATE_FILE="$stub_state"
  export NOTION_STUB_LOG_FILE="$stub_log"

  work="$workdir/work"; mkdir -p "$work"
  NOTION_TOKEN="fake-token-for-test"
  # shellcheck source=/dev/null
  source "$common_sh"

  notion_resolve_parent_id "$conf" "$state_dir" "$helper"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "resolve失敗 (rc=$rc, status=${HTTP_STATUS:-?})"; return 1; }
  [ "$parent_id" = "personal-os-real-id" ] || { echo "parent_idが期待値と異なる: $parent_id"; return 1; }

  search_count="$(grep -c '^search$' "$stub_log" 2>/dev/null)"; search_count="${search_count:-0}"
  [ "$search_count" -ge 2 ] || { echo "search呼び出しが2回未満(全ページ走査されていない疑い): $search_count"; return 1; }

  create_count="$(grep -c '^create:' "$stub_log" 2>/dev/null)"; create_count="${create_count:-0}"
  [ "$create_count" -eq 0 ] || { echo "2ページ目に既存ページがあるのに新規作成された(重複作成バグの再発): $create_count"; return 1; }

  [ -f "$state_dir/notion-parent-page-id" ] || { echo "parent stateが保存されていない"; return 1; }
  [ "$(cat "$state_dir/notion-parent-page-id")" = "personal-os-real-id" ] || { echo "保存されたparent idが不一致"; return 1; }

  return 0
)

# ============================================================
# ct2: notion_resolve_database_id が /search の2ページ目にある既存DBを見逃さず解決する
#      （1ページ目=fillerのみ150件、本物は2ページ目）。新規作成は一切しない。
# ============================================================
ct2_database_search_finds_page2_result() (
  set -uo pipefail
  workdir="$(new_workdir)"
  common_sh="$workdir/loops-registry/loops/renderer/scripts/notion-common.sh"
  helper="$workdir/loops-registry/loops/renderer/scripts/notion_helper.py"

  stub_state="$workdir/stub-state.json"
  python3 -c "
import json
state = {
    'parent_id': 'parent-fixture-id', 'pages': {}, 'children_of': {},
    'databases': {'db-real-target': {'title': '計画ボード', 'parent_page_id': 'parent-fixture-id', 'archived': False}},
    'db_rows': {}, 'search_db_fillers': 150,
}
json.dump(state, open('$stub_state', 'w', encoding='utf-8'))
"

  state_dir="$workdir/state"; mkdir -p "$state_dir"
  db_state_file="$state_dir/notion-board-database-id"
  stub_log="$workdir/stub-log.txt"

  export NOTION_CURL_CMD="python3 $STUB_PY"
  export NOTION_STUB_STATE_FILE="$stub_state"
  export NOTION_STUB_LOG_FILE="$stub_log"

  work="$workdir/work"; mkdir -p "$work"
  NOTION_TOKEN="fake-token-for-test"
  # shellcheck source=/dev/null
  source "$common_sh"

  create_payload="$workdir/create-payload.json"
  python3 "$helper" board-db-create-payload --parent parent-fixture-id > "$create_payload"

  notion_resolve_database_id "計画ボード" "$db_state_file" "$create_payload" "$helper"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "resolve失敗 (rc=$rc, status=${HTTP_STATUS:-?})"; return 1; }
  [ "$database_id" = "db-real-target" ] || { echo "database_idが期待値と異なる(=新規作成された疑い): $database_id"; return 1; }

  search_count="$(grep -c '^search$' "$stub_log" 2>/dev/null)"; search_count="${search_count:-0}"
  [ "$search_count" -ge 2 ] || { echo "search呼び出しが2回未満(全ページ走査されていない疑い): $search_count"; return 1; }

  createdb_count="$(grep -c '^create-db:' "$stub_log" 2>/dev/null)"; createdb_count="${createdb_count:-0}"
  [ "$createdb_count" -eq 0 ] || { echo "2ページ目に既存DBがあるのに新規作成された(重複作成バグの再発): $createdb_count"; return 1; }

  [ -f "$db_state_file" ] || { echo "DB stateが保存されていない"; return 1; }
  [ "$(cat "$db_state_file")" = "db-real-target" ] || { echo "保存されたdatabase idが不一致"; return 1; }

  return 0
)

# ============================================================
# ct3: notion_resolve_database_id が全ページ走査してもどこにも見つからない場合、無限ループせず
#      正しく新規作成へフォールバックする（fillerのみ150件・本物は存在しない）。
# ============================================================
ct3_database_search_all_pages_miss_then_creates() (
  set -uo pipefail
  workdir="$(new_workdir)"
  common_sh="$workdir/loops-registry/loops/renderer/scripts/notion-common.sh"
  helper="$workdir/loops-registry/loops/renderer/scripts/notion_helper.py"

  stub_state="$workdir/stub-state.json"
  python3 -c "
import json
state = {'parent_id': 'parent-fixture-id', 'pages': {}, 'children_of': {}, 'databases': {}, 'db_rows': {}, 'search_db_fillers': 150}
json.dump(state, open('$stub_state', 'w', encoding='utf-8'))
"

  state_dir="$workdir/state"; mkdir -p "$state_dir"
  db_state_file="$state_dir/notion-board-database-id"
  stub_log="$workdir/stub-log.txt"

  export NOTION_CURL_CMD="python3 $STUB_PY"
  export NOTION_STUB_STATE_FILE="$stub_state"
  export NOTION_STUB_LOG_FILE="$stub_log"

  work="$workdir/work"; mkdir -p "$work"
  NOTION_TOKEN="fake-token-for-test"
  # shellcheck source=/dev/null
  source "$common_sh"

  create_payload="$workdir/create-payload.json"
  python3 "$helper" board-db-create-payload --parent parent-fixture-id > "$create_payload"

  notion_resolve_database_id "計画ボード" "$db_state_file" "$create_payload" "$helper"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "resolve失敗 (rc=$rc, status=${HTTP_STATUS:-?})"; return 1; }
  [ -n "$database_id" ] || { echo "database_idが空"; return 1; }

  search_count="$(grep -c '^search$' "$stub_log" 2>/dev/null)"; search_count="${search_count:-0}"
  [ "$search_count" -eq 2 ] || { echo "search呼び出し回数が2でない(全ページ走査後に停止していない): $search_count"; return 1; }

  createdb_count="$(grep -c '^create-db:' "$stub_log" 2>/dev/null)"; createdb_count="${createdb_count:-0}"
  [ "$createdb_count" -eq 1 ] || { echo "全ページ未発見のはずが新規作成されていない(または複数回作成): $createdb_count"; return 1; }

  return 0
)

# ============================================================
# ct4: notion_resolve_parent_id が全ページ走査してもどこにも見つからない場合、無限ループせず
#      非0(search不発=3)を返す（fillerのみ150件・本物は存在しない）。
# ============================================================
ct4_parent_search_all_pages_miss_returns_3() (
  set -uo pipefail
  workdir="$(new_workdir)"
  common_sh="$workdir/loops-registry/loops/renderer/scripts/notion-common.sh"
  helper="$workdir/loops-registry/loops/renderer/scripts/notion_helper.py"

  stub_state="$workdir/stub-state.json"
  python3 -c "
import json
state = {'parent_id': 'unrelated-id', 'pages': {}, 'children_of': {}, 'databases': {}, 'db_rows': {}, 'search_page_fillers': 150}
json.dump(state, open('$stub_state', 'w', encoding='utf-8'))
"

  conf="$workdir/notion-push.conf"; write_conf "$conf" ""
  state_dir="$workdir/state"
  stub_log="$workdir/stub-log.txt"

  export NOTION_STUB_SEARCH_MISS=1
  export NOTION_CURL_CMD="python3 $STUB_PY"
  export NOTION_STUB_STATE_FILE="$stub_state"
  export NOTION_STUB_LOG_FILE="$stub_log"

  work="$workdir/work"; mkdir -p "$work"
  NOTION_TOKEN="fake-token-for-test"
  # shellcheck source=/dev/null
  source "$common_sh"

  notion_resolve_parent_id "$conf" "$state_dir" "$helper"
  rc=$?
  unset NOTION_STUB_SEARCH_MISS
  [ "$rc" -eq 3 ] || { echo "search不発時の戻り値が3でない: rc=$rc"; return 1; }
  [ ! -f "$state_dir/notion-parent-page-id" ] || { echo "search不発にもかかわらずparent stateが保存された"; return 1; }

  return 0
)

# ============================================================
run_test ct1_parent_search_finds_page2_result
run_test ct2_database_search_finds_page2_result
run_test ct3_database_search_all_pages_miss_then_creates
run_test ct4_parent_search_all_pages_miss_returns_3

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
