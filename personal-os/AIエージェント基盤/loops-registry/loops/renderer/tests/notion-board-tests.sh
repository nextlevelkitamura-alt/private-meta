#!/usr/bin/env bash
# renderer / tests / notion-board-tests.sh — notion-board.sh（N3・Notion計画ボードupsert）のテストスイート。
# 実API・実トークン・実キーチェーン・実AREAS_BASEには一切触れない。
# - security find-generic-password は NOTION_SECURITY_CMD でstub（成功/失敗を切り替え）に差し替える。
# - curl は NOTION_CURL_CMD で fixtures/notion-curl-stub.py（Notion API のJSON状態を模したstub。
#   NOTION_STUB_STATE_FILE に永続化）に差し替える。
# 実スモーク（実API・実トークン）はこのスイートの対象外（マージ後に指揮官が行う）。
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

# --- ヘルパ ---

new_workdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/notion-board-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

notion_board_bin() { printf '%s/loops-registry/loops/renderer/scripts/notion-board.sh' "$1"; }

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

write_conf() {
  local path="$1" parent_id="${2:-}"
  printf 'NOTION_PARENT_PAGE_ID=%s\n' "$parent_id" > "$path"
}

# plan.md 単発fixtureを1本置く。
write_plan_fixture() {
  local areas_base="$1" area="$2" dirname="$3" title="$4" category="$5" priority="$6" next="$7"
  local dir="$areas_base/$area/plans/active/$dirname"
  mkdir -p "$dir"
  {
    printf '分類: %s ／ 種別: 既存改善' "$category"
    [ -n "$priority" ] && printf ' ／ 優先: %s' "$priority"
    printf '\n'
    [ -n "$next" ] && printf '次: %s\n' "$next"
    printf '\n# %s\n\n## 目的\n\nテスト用。\n\n## 現状\n\nなし。\n\n## 方針\n\nなし。\n\n## 完了条件（レビュー項目）\n\n- [ ] ダミー\n' "$title"
  } > "$dir/plan.md"
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
# bt1: secret規律（固定トークンが標準出力・標準エラーのどこにも一切現れない）
# ============================================================
bt1_secret_never_leaks() (
  set -uo pipefail
  workdir="$(new_workdir)"
  areas_base="$workdir/areas-base"
  write_plan_fixture "$areas_base" "work" "2026-01-01-テスト計画" "テスト計画" "repo" "" ""

  security_stub="$workdir/security-ok.sh"
  token="NOTION-BOARD-TEST-TOKEN-MARKER-7c6b5a4"
  make_security_ok "$security_stub" "$token"
  conf="$workdir/notion-push.conf"; write_conf "$conf" ""
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"

  bin="$(notion_board_bin "$workdir")"
  out="$(AREAS_BASE="$areas_base" \
    NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "$token" && { echo "トークンが出力に漏洩した: $out"; return 1; }
  grep -qF "$token" "$stub_state" 2>/dev/null && { echo "トークンがstub状態ファイルに漏洩した"; return 1; }

  return 0
)

# ============================================================
# bt2: ガード（トークン取得失敗→警告1行のみ・exit 0・curlは一切呼ばれない）
# ============================================================
bt2_guard_no_token() (
  set -uo pipefail
  workdir="$(new_workdir)"
  areas_base="$workdir/areas-base"
  write_plan_fixture "$areas_base" "work" "2026-01-01-テスト計画" "テスト計画" "repo" "" ""

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_board_bin "$workdir")"
  out="$(AREAS_BASE="$areas_base" \
    NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-board: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "トークン" || { echo "警告文にトークン取得失敗の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "トークン取得失敗にもかかわらずcurl(stub)が呼ばれた: $(cat "$stub_log")"; return 1; }

  return 0
)

# ============================================================
# bt3: DB自動作成＋stateキャッシュ（2回目以降はsearch/作成を呼ばない）＋行upsert冪等
#      （2回連続実行で行数・作成回数が変わらない＝重複行が生まれない）
# ============================================================
bt3_upsert_idempotent_no_duplicate_rows() (
  set -uo pipefail
  workdir="$(new_workdir)"
  areas_base="$workdir/areas-base"
  write_plan_fixture "$areas_base" "work" "2026-01-01-計画A" "計画A" "repo" "◎" "次の一手A"
  write_plan_fixture "$areas_base" "ai運用" "2026-01-01-計画B" "計画B" "loop" "" "次の一手B"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-bt3"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_board_bin "$workdir")"

  env_common=(AREAS_BASE="$areas_base" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -qF "行=2" || { echo "1回目: 行=2でない: $out1"; return 1; }

  createdb_count1="$(grep -c '^create-db:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createdb_count1" -eq 1 ] || { echo "1回目のDB作成回数が1でない: $createdb_count1"; return 1; }
  createrow_count1="$(grep -c '^create-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createrow_count1" -eq 2 ] || { echo "1回目の行作成回数が2でない: $createrow_count1"; return 1; }

  active_rows1="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_rows1" -eq 2 ] || { echo "1回目のアクティブ行数が2でない: $active_rows1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "行=2" || { echo "2回目: 行=2でない: $out2"; return 1; }

  createdb_count2="$(grep -c '^create-db:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createdb_count2" -eq 1 ] || { echo "2回目実行後もDB作成は1回のままであるべき(stateキャッシュ)が: $createdb_count2"; return 1; }
  createrow_count2="$(grep -c '^create-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createrow_count2" -eq 2 ] || { echo "2回目実行後も行作成は2回のままであるべき(重複作成防止・更新のみのはず)が: $createrow_count2"; return 1; }
  updaterow_count2="$(grep -c '^update-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$updaterow_count2" -eq 2 ] || { echo "2回目は2行とも更新(update-row)されるはずが: $updaterow_count2"; return 1; }

  active_rows2="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_rows2" -eq 2 ] || { echo "2回連続実行後もアクティブ行数は2のはず(重複)が: $active_rows2"; return 1; }

  return 0
)

# ============================================================
# bt4: 消えた計画のアーカイブ（1回目=2計画→2回目=1計画に減る→消えた側の行がarchived:trueになる。
#      残った側の行は archived のまま変化しない）
# ============================================================
bt4_stale_plan_row_archived() (
  set -uo pipefail
  workdir="$(new_workdir)"
  areas_base="$workdir/areas-base"
  write_plan_fixture "$areas_base" "work" "2026-01-01-計画A" "計画A" "repo" "◎" "次A"
  write_plan_fixture "$areas_base" "ai運用" "2026-01-01-計画B" "計画B" "loop" "" "次B"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-bt4"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_board_bin "$workdir")"

  env_common=(AREAS_BASE="$areas_base" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  # 計画Aのフォルダを削除する（=area側で計画が消えた状況を模す。plans/active配下から除外）。
  rm -rf "$areas_base/work/plans/active/2026-01-01-計画A"

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "行=1" || { echo "2回目: 行=1でない(計画Aが消えたはず): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "アーカイブ=1" || { echo "2回目: アーカイブ=1でない: $out2"; return 1; }

  archived_titles="$(python3 -c "
import json
s = json.load(open('$stub_state', encoding='utf-8'))
for r in s.get('db_rows', {}).values():
    if r.get('archived'):
        title_prop = r['properties'].get('計画名', {})
        parts = title_prop.get('title', [])
        print(''.join(t.get('text', {}).get('content', '') for t in parts))
")"
  printf '%s' "$archived_titles" | grep -qF "計画A" || { echo "計画Aの行がarchivedになっていない: $archived_titles"; return 1; }
  printf '%s' "$archived_titles" | grep -qF "計画B" && { echo "計画Bの行が誤ってarchivedになった: $archived_titles"; return 1; }

  active_count="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_count" -eq 1 ] || { echo "アクティブ行数が1でない: $active_count"; return 1; }

  return 0
)

# ============================================================
# bt5: 分類・優先・次の一手が正しく行プロパティへ反映される（plan.md冒頭ヘッダ解析の検証）
# ============================================================
bt5_fields_extracted_correctly() (
  set -uo pipefail
  workdir="$(new_workdir)"
  areas_base="$workdir/areas-base"
  write_plan_fixture "$areas_base" "work" "2026-01-01-フィールド確認計画" "フィールド確認計画" "skill" "○" "次の一手はこれ"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-bt5"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_board_bin "$workdir")"

  out="$(AREAS_BASE="$areas_base" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = [r for r in s.get("db_rows", {}).values() if not r.get("archived")]
assert len(rows) == 1, rows
p = rows[0]["properties"]
title = "".join(t["text"]["content"] for t in p["計画名"]["title"])
assert title == "フィールド確認計画", p
assert p["状態"]["select"]["name"] == "active", p
assert p["優先"]["select"]["name"] == "○", p
assert p["分類"]["select"]["name"] == "skill", p
next_text = "".join(t["text"]["content"] for t in p["次の一手"]["rich_text"])
assert next_text == "次の一手はこれ", p
print("OK")
PY
  [ $? -eq 0 ] || { echo "プロパティ検証に失敗"; return 1; }

  return 0
)

# ============================================================
run_test bt1_secret_never_leaks
run_test bt2_guard_no_token
run_test bt3_upsert_idempotent_no_duplicate_rows
run_test bt4_stale_plan_row_archived
run_test bt5_fields_extracted_correctly

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
