#!/usr/bin/env bash
# renderer / tests / notion-inbox-pull-tests.sh — notion-inbox-pull.sh（N2・Notion依頼インボックスpull）
# のテストスイート。実API・実トークン・実キーチェーン・実デイリーには一切触れない。
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
TEMPLATE="$RENDERER_DIR/templates/デイリー.md"

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
  d="$(mktemp -d "${TMPDIR:-/tmp}/notion-inbox-pull-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest" "$d/loops-registry/loops/inbox-patrol"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  # 2026-07-09 デイリー運用刷新 子06: notion-inbox-pull.sh は inbox-patrol/scripts へ移設
  # （notion-common.sh 等の共有ライブラリは renderer/scripts の正本を相対参照するため両方を複製する）
  cp -R "$LOOPS_DIR/inbox-patrol/scripts" "$d/loops-registry/loops/inbox-patrol/scripts"
  printf '%s' "$d"
}

notion_inbox_pull_bin() { printf '%s/loops-registry/loops/inbox-patrol/scripts/notion-inbox-pull.sh' "$1"; }

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

# テンプレからプレースホルダを埋めた当日デイリーを作る（ensure-daily.shと同じ置換規則）。
make_daily() {
  local out="$1" date_str="$2"
  local y="${date_str%%-*}"
  sed -e "s/<YYYY-MM-DD>/$date_str/g" -e "s/<曜>/月/g" -e "s/<YYYY>/$y/g" "$TEMPLATE" > "$out"
}

# stub_stateへ依頼インボックスDBの行を1件直接注入する（DB作成APIを経由せず状態だけ用意する軽量経路）。
seed_inbox_row() {
  local stub_state="$1" db_id="$2" row_id="$3" text="$4" status="$5"
  python3 - "$stub_state" "$db_id" "$row_id" "$text" "$status" <<'PY'
import json, sys, os
path, db_id, row_id, text, status = sys.argv[1:6]
if os.path.exists(path):
    state = json.load(open(path, encoding="utf-8"))
else:
    state = {"parent_id": "parent-fixture-id", "pages": {}, "children_of": {}, "databases": {}, "db_rows": {}}
state.setdefault("databases", {})[db_id] = {"title": "依頼インボックス", "parent_page_id": "parent-fixture-id", "archived": False}
state.setdefault("db_rows", {})[row_id] = {
    "db_id": db_id,
    "properties": {
        "依頼": {"title": [{"type": "text", "text": {"content": text}}]},
        "状態": {"select": {"name": status}},
    },
    "archived": False,
}
json.dump(state, open(path, "w", encoding="utf-8"), ensure_ascii=False)
PY
}

# "## 依頼インボックス" 節の中身以外を出す（見出し行自体は残す）。全auto:*マーカーはこの節の
# 外側にあるため、この関数の出力が前後で一致すれば「依頼インボックス節以外は一切変化していない」
# （＝auto:マーカー不可侵を含む）ことの直接証拠になる。
snapshot_outside_inbox() {
  awk '
    /^## 依頼インボックス/ { insection = 1; print; next }
    insection && /^## / { insection = 0 }
    insection { next }
    { print }
  ' "$1"
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
# it1: secret規律（固定トークンが標準出力・標準エラーのどこにも一切現れない）
# ============================================================
it1_secret_never_leaks() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"

  db_id="inbox-db-fixture"
  stub_state="$workdir/stub-state.json"
  seed_inbox_row "$stub_state" "$db_id" "row-1" "依頼テキストA" "立案済"

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  mkdir -p "$state_dir"
  printf '%s' "$db_id" > "$state_dir/notion-inbox-database-id"

  security_stub="$workdir/security-ok.sh"
  token="NOTION-INBOX-TEST-TOKEN-MARKER-3e2d1c0"
  make_security_ok "$security_stub" "$token"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_inbox_pull_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "$token" && { echo "トークンが出力に漏洩した: $out"; return 1; }
  grep -qF "$token" "$stub_state" 2>/dev/null && { echo "トークンがstub状態ファイルに漏洩した"; return 1; }
  grep -qF "$token" "$daily" && { echo "トークンがデイリーに漏洩した"; return 1; }

  return 0
)

# ============================================================
# it2: ガード（トークン取得失敗→警告1行のみ・exit 0・curlは一切呼ばれない・デイリー不変）
# ============================================================
it2_guard_no_token() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"
  before="$(cat "$daily")"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_inbox_pull_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-inbox-pull: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "トークン" || { echo "警告文にトークン取得失敗の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "トークン取得失敗にもかかわらずcurl(stub)が呼ばれた: $(cat "$stub_log")"; return 1; }

  after="$(cat "$daily")"
  [ "$before" = "$after" ] || { echo "デイリーが変化した"; return 1; }

  return 0
)

# ============================================================
# it3: ガード（デイリーファイル不在→警告1行のみ・exit 0。security/curlすら呼ばれない）
# ============================================================
it3_guard_missing_daily_file() (
  set -uo pipefail
  workdir="$(new_workdir)"
  missing="$workdir/no-such-daily/2099-01-01.md"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_inbox_pull_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$missing" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-inbox-pull: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "デイリーファイルが無い" || { echo "警告文にファイル不在の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "デイリー不在にもかかわらずcurl(stub)が呼ばれた"; return 1; }

  return 0
)

# ============================================================
# it4: 二重取り込み防止（1回目で1件pull→ローカル追記+Notion側「回収済み」化。2回目実行は
#      立案済0件で何も追記しない＝行の重複なし）
# ============================================================
it4_no_duplicate_pull() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"

  db_id="inbox-db-fixture"
  stub_state="$workdir/stub-state.json"
  seed_inbox_row "$stub_state" "$db_id" "row-dup-1" "依頼テキストDUP" "立案済"

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  mkdir -p "$state_dir"
  printf '%s' "$db_id" > "$state_dir/notion-inbox-database-id"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-it4"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_inbox_pull_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -qF "回収=1" || { echo "1回目: 回収=1でない: $out1"; return 1; }

  count1="$(grep -cF "依頼テキストDUP" "$daily")"
  [ "$count1" -eq 1 ] || { echo "1回目後の出現回数が1でない: $count1"; return 1; }

  status1="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(s['db_rows']['row-dup-1']['properties']['状態']['select']['name'])")"
  [ "$status1" = "回収済み" ] || { echo "1回目後にNotion側の状態が回収済みになっていない: $status1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "立案済0件" || { echo "2回目: 立案済0件でない(状態=立案済のqueryで再ヒットした疑い): $out2"; return 1; }

  count2="$(grep -cF "依頼テキストDUP" "$daily")"
  [ "$count2" -eq 1 ] || { echo "2回連続実行で出現回数が変化した(重複取り込み): $count2"; return 1; }

  return 0
)

# ============================================================
# it5: auto:マーカー不可侵（pull後も「## 依頼インボックス」節の外側は1バイトも変わらない。
#      節の中には新規テキストが正しく追記される）
# ============================================================
it5_auto_marker_untouched() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"

  # マーカー外の人間行（TODO・今日終わったこと）にも手書き内容を入れておく（不可侵の検証対象を増やす）。
  awk '
    /^## 今日のTODO/ { print; getline; print "- [ ] 買い物（人間TODO）"; next }
    { print }
  ' "$daily" > "$daily.tmp" && mv "$daily.tmp" "$daily"

  before_outside="$(snapshot_outside_inbox "$daily")"

  db_id="inbox-db-fixture"
  stub_state="$workdir/stub-state.json"
  seed_inbox_row "$stub_state" "$db_id" "row-marker-1" "マーカー不可侵確認用の依頼" "立案済"

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  mkdir -p "$state_dir"
  printf '%s' "$db_id" > "$state_dir/notion-inbox-database-id"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-it5"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_inbox_pull_bin "$workdir")"

  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  after_outside="$(snapshot_outside_inbox "$daily")"
  [ "$before_outside" = "$after_outside" ] || {
    echo "依頼インボックス節の外側が変化した(マーカー不可侵違反の疑い):"
    diff <(printf '%s' "$before_outside") <(printf '%s' "$after_outside") || true
    return 1
  }

  grep -qF -- "- マーカー不可侵確認用の依頼" "$daily" || { echo "依頼インボックス節に新規テキストが追記されていない"; return 1; }
  grep -qF "買い物（人間TODO）" "$daily" || { echo "無関係な人間TODO行が消えた"; return 1; }

  local key
  for key in goal align done log board-now board-wait board-plans; do
    grep -qE "^<!-- auto:${key}:begin" "$daily" || { echo "auto:${key} beginマーカーが消えた"; return 1; }
    grep -qE "^<!-- auto:${key}:end -->" "$daily" || { echo "auto:${key} endマーカーが消えた"; return 1; }
  done

  return 0
)

# ============================================================
# it6: 複数新規行の一括取り込み（順序維持・全件追記・全件「回収済み」化）
# ============================================================
it6_multiple_new_rows() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"

  db_id="inbox-db-fixture"
  stub_state="$workdir/stub-state.json"
  seed_inbox_row "$stub_state" "$db_id" "row-m1" "依頼M1" "立案済"
  seed_inbox_row "$stub_state" "$db_id" "row-m2" "依頼M2" "立案済"
  seed_inbox_row "$stub_state" "$db_id" "row-m3-already-done" "依頼M3済み" "回収済み"

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  mkdir -p "$state_dir"
  printf '%s' "$db_id" > "$state_dir/notion-inbox-database-id"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-it6"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_inbox_pull_bin "$workdir")"

  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "回収=2" || { echo "回収=2でない(既に回収済みの行を誤ってカウントした疑い): $out"; return 1; }

  grep -qF -- "- 依頼M1" "$daily" || { echo "依頼M1が追記されていない"; return 1; }
  grep -qF -- "- 依頼M2" "$daily" || { echo "依頼M2が追記されていない"; return 1; }
  grep -qF "依頼M3済み" "$daily" && { echo "既に回収済みだった行が誤って追記された"; return 1; }

  status_m1="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(s['db_rows']['row-m1']['properties']['状態']['select']['name'])")"
  status_m2="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(s['db_rows']['row-m2']['properties']['状態']['select']['name'])")"
  [ "$status_m1" = "回収済み" ] || { echo "row-m1が回収済みになっていない: $status_m1"; return 1; }
  [ "$status_m2" = "回収済み" ] || { echo "row-m2が回収済みになっていない: $status_m2"; return 1; }

  return 0
)

# ============================================================
# it7: 部分失敗からの復旧（ローカル追記+state記録済みだがNotion側patchが前回失敗して「新規」の
#      まま残っている行→再実行時に再追記はせずpatchだけリトライする＝ローカル重複が発生しない）
# ============================================================
it7_retry_patch_without_reappend() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  make_daily "$daily" "2026-07-02"

  # 依頼インボックス節へあらかじめ手動で1件追記しておく（＝前回runでローカル追記だけ成功しNotion
  # patchが失敗した状況を模す）。
  awk '
    /^## 依頼インボックス/ { print; print "- 依頼RETRY"; next }
    { print }
  ' "$daily" > "$daily.tmp" && mv "$daily.tmp" "$daily"

  db_id="inbox-db-fixture"
  stub_state="$workdir/stub-state.json"
  seed_inbox_row "$stub_state" "$db_id" "row-retry-1" "依頼RETRY" "立案済"

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  mkdir -p "$state_dir"
  printf '%s' "$db_id" > "$state_dir/notion-inbox-database-id"
  # 前回runで既にローカル追記・dedup記録は完了していた状況を再現する。
  printf 'row-retry-1\n' > "$state_dir/notion-inbox-pulled-ids"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-it7"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_inbox_pull_bin "$workdir")"

  out="$(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "回収=1" || { echo "回収=1でない(retry対象がqueryされていない疑い): $out"; return 1; }

  count="$(grep -cF "依頼RETRY" "$daily")"
  [ "$count" -eq 1 ] || { echo "既にdedup記録済みなのに再追記された(出現回数=$count)"; return 1; }

  status="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(s['db_rows']['row-retry-1']['properties']['状態']['select']['name'])")"
  [ "$status" = "回収済み" ] || { echo "retry patchが行われず状態が回収済みになっていない: $status"; return 1; }

  return 0
)

# ============================================================
run_test it1_secret_never_leaks
run_test it2_guard_no_token
run_test it3_guard_missing_daily_file
run_test it4_no_duplicate_pull
run_test it5_auto_marker_untouched
run_test it6_multiple_new_rows
run_test it7_retry_patch_without_reappend

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
