#!/usr/bin/env bash
# renderer / tests / notion-push-tests.sh — notion-push.sh（N1・Notion一方向push）のテストスイート。
# 実API・実トークン・実キーチェーン・実デイリーには一切触らない。
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
  d="$(mktemp -d "${TMPDIR:-/tmp}/notion-push-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$RENDERER_DIR/templates" "$d/loops-registry/loops/renderer/templates"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

notion_push_bin() { printf '%s/loops-registry/loops/renderer/scripts/notion-push.sh' "$1"; }
render_bin() { printf '%s/loops-registry/loops/renderer/scripts/render.sh' "$1"; }

# security find-generic-password の成功stub（固定トークンを返す）。
make_security_ok() {
  local path="$1" token="$2"
  cat > "$path" <<EOF
#!/usr/bin/env bash
printf '%s' '$token'
EOF
  chmod +x "$path"
}

# security find-generic-password の失敗stub（キーチェーン未登録を模す）。
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
# nt1: secret規律（固定トークンが標準出力・標準エラーのどこにも一切現れない）
# ============================================================
nt1_secret_never_leaks() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  printf '# 見出し\n- 箇条書き\n- [ ] TODO\n本文\n' > "$daily"

  security_stub="$workdir/security-ok.sh"
  token="NOTION-TEST-TOKEN-MARKER-9f8e7d21"
  make_security_ok "$security_stub" "$token"

  conf="$workdir/notion-push.conf"
  write_conf "$conf" ""

  state_dir="$workdir/state"
  stub_state="$workdir/stub-state.json"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_push_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" \
    NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "$token" && { echo "トークンが出力に漏洩した: $out"; return 1; }
  grep -qF "$token" "$stub_state" 2>/dev/null && { echo "トークンがstub状態ファイルに漏洩した"; return 1; }

  return 0
)

# ============================================================
# nt2: ガード（トークン取得失敗→警告1行のみ・exit 0・curlは一切呼ばれない）
# ============================================================
nt2_guard_no_token() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  printf '本文のみ\n' > "$daily"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"

  stub_log="$workdir/stub-log.txt"
  bin="$(notion_push_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-push: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "トークン" || { echo "警告文にトークン取得失敗の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "トークン取得失敗にもかかわらずcurl(stub)が呼ばれた: $(cat "$stub_log")"; return 1; }

  return 0
)

# ============================================================
# nt3: ガード（conf未設定かつsearch不発→警告1行のみ・exit 0・state未保存）
# ============================================================
nt3_guard_search_miss() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-02.md"
  printf '本文のみ\n' > "$daily"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt3"

  conf="$workdir/notion-push.conf"
  write_conf "$conf" ""
  state_dir="$workdir/state"
  stub_state="$workdir/stub-state.json"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_push_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" \
    NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    NOTION_STUB_SEARCH_MISS=1 \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-push: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "search" || { echo "警告文にsearch不発の言及が無い: $out"; return 1; }
  [ ! -f "$state_dir/notion-parent-page-id" ] || { echo "search不発にもかかわらずparent state が保存された"; return 1; }

  return 0
)

# ============================================================
# nt4: parent page id 自動発見＋stateキャッシュ（2回目以降はsearchを呼ばない）
# ============================================================
nt4_id_auto_discovery_and_cache() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-03.md"
  printf '本文のみ\n' > "$daily"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt4"

  conf="$workdir/notion-push.conf"
  write_conf "$conf" ""
  state_dir="$workdir/state"
  stub_state="$workdir/stub-state.json"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_push_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  [ -f "$state_dir/notion-parent-page-id" ] || { echo "1回目でparent stateが保存されていない"; return 1; }
  search_count1="$(grep -c '^search$' "$stub_log" 2>/dev/null || echo 0)"
  [ "$search_count1" -eq 1 ] || { echo "1回目のsearch呼び出し回数が1でない: $search_count1"; return 1; }
  create_count1="$(grep -c '^create:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$create_count1" -eq 1 ] || { echo "1回目のページ作成回数が1でない: $create_count1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  search_count2="$(grep -c '^search$' "$stub_log" 2>/dev/null || echo 0)"
  [ "$search_count2" -eq 1 ] || { echo "2回目実行後もsearch呼び出しが1回のままであるべき(stateキャッシュ)が: $search_count2"; return 1; }
  create_count2="$(grep -c '^create:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$create_count2" -eq 1 ] || { echo "2回目実行後もページ作成は1回のままであるべき(重複作成防止)が: $create_count2"; return 1; }

  return 0
)

# ============================================================
# nt5: 全置換の冪等性（既存の古いブロックがarchiveされ、新ブロックが再append。
#       2回連続実行しても最終的なアクティブブロック構成(type+content)は変わらない）
# ============================================================
nt5_full_replace_idempotent() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-04.md"
  cat > "$daily" <<'EOF'
# 見出し1
## 見出し2
- 箇条書きA
- [ ] 未完了TODO
- [x] 完了TODO
本文行
EOF

  parent_id="parent-fixture-id"
  page_id="page-existing-nt5"
  stale1="block-stale-1"
  stale2="block-stale-2"
  stub_state="$workdir/stub-state.json"
  cat > "$stub_state" <<EOF
{
  "parent_id": "$parent_id",
  "pages": {
    "$page_id": {"is_page": true, "title": "2026-07-04", "archived": false},
    "$stale1": {"is_page": false, "type": "paragraph", "archived": false, "content": {}},
    "$stale2": {"is_page": false, "type": "paragraph", "archived": false, "content": {}}
  },
  "children_of": {
    "$parent_id": ["$page_id"],
    "$page_id": ["$stale1", "$stale2"]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt5"
  conf="$workdir/notion-push.conf"
  write_conf "$conf" "$parent_id"
  state_dir="$workdir/state"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_push_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  snapshot1="$(python3 - "$stub_state" "$page_id" <<'PY'
import json, sys
state = json.load(open(sys.argv[1], encoding="utf-8"))
page_id = sys.argv[2]
active = []
for bid in state.get("children_of", {}).get(page_id, []):
    b = state["pages"].get(bid, {})
    if b.get("archived"):
        continue
    active.append(json.dumps({"type": b.get("type"), "content": b.get("content")}, sort_keys=True))
active.sort()
print(len(active))
for a in active:
    print(a)
PY
)"
  archived1="$(python3 -c "import json; s=json.load(open('$stub_state', encoding='utf-8')); print(1 if s['pages']['$stale1']['archived'] and s['pages']['$stale2']['archived'] else 0)")"
  [ "$archived1" -eq 1 ] || { echo "1回目実行後、既存の古いブロックがarchiveされていない"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }

  snapshot2="$(python3 - "$stub_state" "$page_id" <<'PY'
import json, sys
state = json.load(open(sys.argv[1], encoding="utf-8"))
page_id = sys.argv[2]
active = []
for bid in state.get("children_of", {}).get(page_id, []):
    b = state["pages"].get(bid, {})
    if b.get("archived"):
        continue
    active.append(json.dumps({"type": b.get("type"), "content": b.get("content")}, sort_keys=True))
active.sort()
print(len(active))
for a in active:
    print(a)
PY
)"

  [ "$snapshot1" = "$snapshot2" ] || { echo "2回連続実行でアクティブブロック構成が変化した(冪等でない):"; diff <(printf '%s' "$snapshot1") <(printf '%s' "$snapshot2"); return 1; }

  count_line="$(printf '%s\n' "$snapshot1" | head -1)"
  [ "$count_line" -eq 6 ] || { echo "アクティブブロック数が期待(6)と異なる: $count_line"; return 1; }

  return 0
)

# ============================================================
# nt6: MD→ブロック変換単体（heading/bulleted_list_item/to_do/paragraphの素朴変換）
# ============================================================
nt6_md_conversion_unit() (
  set -uo pipefail
  helper="$RENDERER_DIR/scripts/notion_helper.py"
  input="$(cat <<'EOF'
# 見出し1
## 見出し2
### 見出し3
#### 見出し4はheading_3にclampされる

- 箇条書き
- [ ] 未完了TODO
- [x] 完了TODO小文字
- [X] 完了TODO大文字
<!-- コメント行はparagraphへ素朴変換 -->
ただの本文
EOF
)"

  out="$(printf '%s' "$input" | python3 "$helper" md-to-batches)"
  batch_lines="$(printf '%s\n' "$out" | grep -c .)"
  [ "$batch_lines" -eq 1 ] || { echo "バッチ行数が1でない: $batch_lines"; return 1; }

  python3 - "$out" <<'PY'
import json, sys
blocks = json.loads(sys.argv[1])

def rt(b, key):
    return "".join(t["text"]["content"] for t in b[key]["rich_text"])

assert blocks[0]["type"] == "heading_1" and rt(blocks[0], "heading_1") == "見出し1", blocks[0]
assert blocks[1]["type"] == "heading_2" and rt(blocks[1], "heading_2") == "見出し2", blocks[1]
assert blocks[2]["type"] == "heading_3" and rt(blocks[2], "heading_3") == "見出し3", blocks[2]
assert blocks[3]["type"] == "heading_3", blocks[3]  # #### はheading_3にclamp
assert rt(blocks[3], "heading_3") == "見出し4はheading_3にclampされる", blocks[3]

assert blocks[4]["type"] == "bulleted_list_item" and rt(blocks[4], "bulleted_list_item") == "箇条書き", blocks[4]

assert blocks[5]["type"] == "to_do" and blocks[5]["to_do"]["checked"] is False, blocks[5]
assert rt(blocks[5], "to_do") == "未完了TODO", blocks[5]

assert blocks[6]["type"] == "to_do" and blocks[6]["to_do"]["checked"] is True, blocks[6]
assert rt(blocks[6], "to_do") == "完了TODO小文字", blocks[6]

assert blocks[7]["type"] == "to_do" and blocks[7]["to_do"]["checked"] is True, blocks[7]
assert rt(blocks[7], "to_do") == "完了TODO大文字", blocks[7]

assert blocks[8]["type"] == "paragraph", blocks[8]
assert rt(blocks[8], "paragraph") == "<!-- コメント行はparagraphへ素朴変換 -->", blocks[8]

assert blocks[9]["type"] == "paragraph" and rt(blocks[9], "paragraph") == "ただの本文", blocks[9]

assert len(blocks) == 10, len(blocks)
print("OK")
PY
  rc=$?
  [ "$rc" -eq 0 ] || { echo "変換結果の検証に失敗"; return 1; }
  return 0
)

# ============================================================
# nt7: 変換の上限処理（rich_text 2000字/ブロック分割・100ブロック/リクエスト分割）
# ============================================================
nt7_conversion_limits() (
  set -uo pipefail
  helper="$RENDERER_DIR/scripts/notion_helper.py"

  # (a) 2500字の1行 → rich_textが2000字+500字の2要素に分割される
  long_line="$(python3 -c "print('あ' * 2500)")"
  out_a="$(printf '%s\n' "$long_line" | python3 "$helper" md-to-batches)"
  python3 - "$out_a" <<'PY'
import json, sys
blocks = json.loads(sys.argv[1])
assert len(blocks) == 1, blocks
rt = blocks[0]["paragraph"]["rich_text"]
assert len(rt) == 2, rt
assert len(rt[0]["text"]["content"]) == 2000, len(rt[0]["text"]["content"])
assert len(rt[1]["text"]["content"]) == 500, len(rt[1]["text"]["content"])
print("OK")
PY
  [ $? -eq 0 ] || { echo "(a) rich_text 2000字分割の検証に失敗"; return 1; }

  # (b) 150行の箇条書き → 100ブロック/リクエストで2バッチ(100+50)に分割される
  many="$(python3 -c "print('\n'.join('- item%d' % i for i in range(150)))")"
  out_b="$(printf '%s\n' "$many" | python3 "$helper" md-to-batches)"
  batch_count="$(printf '%s\n' "$out_b" | grep -c .)"
  [ "$batch_count" -eq 2 ] || { echo "(b) バッチ数が2でない: $batch_count"; return 1; }

  first_len="$(printf '%s\n' "$out_b" | sed -n '1p' | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  second_len="$(printf '%s\n' "$out_b" | sed -n '2p' | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
  [ "$first_len" -eq 100 ] || { echo "(b) 1バッチ目が100ブロックでない: $first_len"; return 1; }
  [ "$second_len" -eq 50 ] || { echo "(b) 2バッチ目が50ブロックでない: $second_len"; return 1; }

  return 0
)

# ============================================================
# nt8: ガード（デイリーファイル不在→警告1行のみ・exit 0。security/curlすら呼ばれない）
# ============================================================
nt8_guard_missing_daily_file() (
  set -uo pipefail
  workdir="$(new_workdir)"
  missing="$workdir/no-such-daily/2099-01-01.md"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_push_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" "$missing" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-push: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "デイリーファイルが無い" || { echo "警告文にファイル不在の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "デイリー不在にもかかわらずcurl(stub)が呼ばれた"; return 1; }

  return 0
)

# ============================================================
# nt9: レンダラ後段への結線（render.sh末尾から起動・notion側が失敗してもrender.sh自体はexit 0で
#       通常通り当日デイリーを生成する。render.sh本体の成否に影響しないことを実証する）
# ============================================================
nt9_render_wiring_does_not_affect_render_status() (
  set -uo pipefail
  workdir="$(new_workdir)"
  GOAL_BASE="$workdir/data/goal-base"
  AIJOBS_BASE="$workdir/data/ai-jobs"
  CLAUDE_PROJECTS_BASE="$workdir/data/claude-projects"
  CODEX_INDEX="$workdir/data/codex/session_index.jsonl"
  CODEX_SESSIONS_BASE="$workdir/data/codex/sessions"
  AREAS_BASE="$workdir/data/areas-base"
  DAILY_TEMPLATE="$RENDERER_DIR/templates/デイリー.md"
  ORCA_PS_CMD='printf %s "{\"result\":{\"totalCount\":0,\"worktrees\":[]}}"'
  export GOAL_BASE AIJOBS_BASE CLAUDE_PROJECTS_BASE CODEX_INDEX CODEX_SESSIONS_BASE AREAS_BASE DAILY_TEMPLATE ORCA_PS_CMD
  mkdir -p "$GOAL_BASE/年間計画" "$AREAS_BASE"
  cp "$FIXTURES_DIR/yearly-plan-2026.md" "$GOAL_BASE/年間計画/2026.md"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  export NOTION_SECURITY_CMD="$security_stub"
  export NOTION_PUSH_STATE_DIR="$workdir/notion-state"

  render="$(render_bin "$workdir")"
  daily="$GOAL_BASE/デイリー/2026/07/2026-07-05.md"

  out="$("$render" 2026-07-05 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "render.shがexit非0になった(notion-push失敗が波及した疑い) ($rc): $out"; return 1; }
  [ -f "$daily" ] || { echo "デイリーが生成されていない"; return 1; }
  printf '%s\n' "$out" | grep -q "notion-push: 警告" || { echo "notion-push.shが呼ばれた形跡(警告)が無い: $out"; return 1; }
  grep -qE '^## 逆算' "$daily" || { echo "render.sh本体の生成物が壊れている"; return 1; }

  return 0
)

# ============================================================
# nt10: 既定パス解決（引数省略時はレンダラと同じ daily_file_for(JST当日) に解決される）
# ============================================================
nt10_default_path_resolution_matches_renderer() (
  set -uo pipefail
  workdir="$(new_workdir)"
  GOAL_BASE="$workdir/data/goal-base"
  export GOAL_BASE
  # shellcheck source=/dev/null
  source "$workdir/loops-registry/loops/daily-digest/scripts/_paths.sh"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  daily="$(daily_file_for "$today")"
  mkdir -p "$(dirname "$daily")"
  printf '本文\n' > "$daily"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt10"
  conf="$workdir/notion-push.conf"
  write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  stub_state="$workdir/stub-state.json"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_push_bin "$workdir")"
  out="$(GOAL_BASE="$GOAL_BASE" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "完了 ($today)" || { echo "既定解決の当日タイトルでpushされていない: $out"; return 1; }
  grep -q "create:$today:" "$stub_log" 2>/dev/null || { echo "stub側で当日タイトルのページ作成が記録されていない: $(cat "$stub_log" 2>/dev/null)"; return 1; }

  return 0
)

# ============================================================
# nt11: ガード（Notion API呼び出し自体の失敗＝非2xx→警告1行のみ・exit 0。
#       トークン取得・parent id解決は成功した後の失敗経路を検証する）
# ============================================================
nt11_guard_api_failure() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-06.md"
  printf '本文\n' > "$daily"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt11"
  conf="$workdir/notion-push.conf"
  write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_push_bin "$workdir")"
  out="$(NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    NOTION_STUB_FORCE_STATUS=500 \
    "$bin" "$daily" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-push: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "status=500" || { echo "警告文にstatus=500の言及が無い: $out"; return 1; }

  return 0
)

# ============================================================
# nt12: 当日ページ探索のページネーション（親配下が101件超でも既存当日ページを見逃さず、
#       重複作成しない。差し戻し1回目・指摘1の回帰テスト。修正前は1ページ目(100件)のみ走査していたため、
#       101件目以降にある既存当日ページを見逃し、2回目実行時に重複作成していた
#       （レビューでのstub再現: run1_create=1, run2_create=2）。
# ============================================================
nt12_day_page_pagination_prevents_duplicate() (
  set -uo pipefail
  workdir="$(new_workdir)"
  daily="$workdir/2026-07-07.md"
  printf '本文\n' > "$daily"

  parent_id="parent-fixture-id"
  stub_state="$workdir/stub-state.json"
  # 親配下にfillerページ100件を事前配置する。当日ページはまだ無い状態から始める
  # （run1でindex100=101件目として作られ、page_size=100の1ページ目には収まらない位置になる）。
  python3 - "$stub_state" "$parent_id" <<'PY'
import json, sys
state_path, parent_id = sys.argv[1], sys.argv[2]
pages = {}
children = []
for i in range(100):
    pid = "filler-page-%03d" % i
    pages[pid] = {"is_page": True, "title": "filler-%03d" % i, "archived": False}
    children.append(pid)
state = {"parent_id": parent_id, "pages": pages, "children_of": {parent_id: children}}
json.dump(state, open(state_path, "w", encoding="utf-8"))
PY

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-nt12"
  conf="$workdir/notion-push.conf"
  write_conf "$conf" "$parent_id"
  state_dir="$workdir/state"
  stub_log="$workdir/stub-log.txt"
  bin="$(notion_push_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  create_count1="$(grep -c '^create:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$create_count1" -eq 1 ] || { echo "1回目のページ作成回数が1でない: $create_count1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" "$daily" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  create_count2="$(grep -c '^create:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$create_count2" -eq 1 ] || { echo "親配下101件超で2回目に重複作成した(create回数=$create_count2、1のはず。当日ページ探索がページネーション追従できていない疑い)"; return 1; }

  return 0
)

# ============================================================
run_test nt1_secret_never_leaks
run_test nt2_guard_no_token
run_test nt3_guard_search_miss
run_test nt4_id_auto_discovery_and_cache
run_test nt5_full_replace_idempotent
run_test nt6_md_conversion_unit
run_test nt7_conversion_limits
run_test nt8_guard_missing_daily_file
run_test nt9_render_wiring_does_not_affect_render_status
run_test nt10_default_path_resolution_matches_renderer
run_test nt11_guard_api_failure
run_test nt12_day_page_pagination_prevents_duplicate

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
