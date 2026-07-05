#!/usr/bin/env bash
# renderer / tests / notion-lanes-tests.sh — notion-lanes.sh（N3b・Notionレーン実況DBupsert）の
# テストスイート。実API・実トークン・実キーチェーン・実orca CLIには一切触れない。
# - security find-generic-password は NOTION_SECURITY_CMD でstub（成功/失敗を切り替え）に差し替える。
# - curl は NOTION_CURL_CMD で fixtures/notion-curl-stub.py（Notion API のJSON状態を模したstub。
#   NOTION_STUB_STATE_FILE に永続化）に差し替える。
# - orca worktree ps は ORCA_PS_CMD で `cat <fixture.json>` に差し替える。
# 列再設計v2（統合program plan.md 方針5e）: タイトル=状態のみ・計画/種別列・閉じたレーンはarchive・
# 旧形式フォールバック照合の撤去を検証する。
# 実スモーク（実API・実トークン・実orca）はこのスイートの対象外（マージ後に指揮官が行う）。
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
  d="$(mktemp -d "${TMPDIR:-/tmp}/notion-lanes-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

notion_lanes_bin() { printf '%s/loops-registry/loops/renderer/scripts/notion-lanes.sh' "$1"; }

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

# 稼働中lane1(claude+codex)＋レーン2(claude・人間確認待ち)の2レーン3エージェントfixture。
# 両レーンとも ~/orca/workspaces 配下（種別=worktree）・同じrepoA配下（repo導出のテスト用）。
# displayNameはどちらもbranchと異なる（計画列にそのまま出るケース）。
write_two_lane_fixture() {
  local out="$1"
  cat > "$out" <<'EOF'
{
  "result": {
    "totalCount": 2,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane1",
        "displayName": "統合設計子04a(子04a)",
        "branch": "refs/heads/x",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "working", "lastAssistantMessage": "実装中です。\n段階: 実装"},
          {"agentType": "codex", "state": "idle", "lastAssistantMessage": "レビュー待機中"}
        ]
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/lane2",
        "displayName": "レーン2(子02)",
        "branch": "refs/heads/y",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "working", "lastAssistantMessage": "確認をお願いします。人間確認待ちです。"}
        ]
      }
    ]
  }
}
EOF
}

# ============================================================
# lt1: secret規律（固定トークンが標準出力・標準エラーのどこにも一切現れない）
# ============================================================
lt1_secret_never_leaks() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  token="NOTION-LANES-TEST-TOKEN-MARKER-1a2b3c4"
  make_security_ok "$security_stub" "$token"
  conf="$workdir/notion-push.conf"; write_conf "$conf" ""
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"

  bin="$(notion_lanes_bin "$workdir")"
  out="$(ORCA_PS_CMD="cat $orca_json" \
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
# lt2: ガード（トークン取得失敗→警告1行のみ・exit 0・curlは一切呼ばれない）
# ============================================================
lt2_guard_no_token() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-fail.sh"
  make_security_fail "$security_stub"
  stub_log="$workdir/stub-log.txt"

  bin="$(notion_lanes_bin "$workdir")"
  out="$(ORCA_PS_CMD="cat $orca_json" \
    NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"
  rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-lanes: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "トークン" || { echo "警告文にトークン取得失敗の言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "トークン取得失敗にもかかわらずcurl(stub)が呼ばれた: $(cat "$stub_log")"; return 1; }

  return 0
)

# ============================================================
# lt3: DB自動作成＋stateキャッシュ＋レーン行upsert冪等（2回連続実行で行数・作成回数が変わらない）
# ============================================================
lt3_upsert_idempotent_no_duplicate_rows() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt3"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -qF "レーン=2 エージェント=3" || { echo "1回目: レーン=2 エージェント=3でない: $out1"; return 1; }

  createdb_count1="$(grep -c '^create-db:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createdb_count1" -eq 1 ] || { echo "1回目のDB作成回数が1でない: $createdb_count1"; return 1; }
  createrow_count1="$(grep -c '^create-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createrow_count1" -eq 3 ] || { echo "1回目の行作成回数が3(レーン2+サマリ1)でない: $createrow_count1"; return 1; }

  active_rows1="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_rows1" -eq 3 ] || { echo "1回目のアクティブ行数が3でない: $active_rows1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "レーン=2 エージェント=3" || { echo "2回目: レーン=2 エージェント=3でない: $out2"; return 1; }

  createdb_count2="$(grep -c '^create-db:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createdb_count2" -eq 1 ] || { echo "2回目実行後もDB作成は1回のままであるべき(stateキャッシュ)が: $createdb_count2"; return 1; }
  createrow_count2="$(grep -c '^create-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$createrow_count2" -eq 3 ] || { echo "2回目実行後も行作成は3回のままであるべき(重複作成防止・更新のみのはず)が: $createrow_count2"; return 1; }

  active_rows2="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_rows2" -eq 3 ] || { echo "2回連続実行後もアクティブ行数は3のはず(重複)が: $active_rows2"; return 1; }

  return 0
)

# ============================================================
# lt4: 状態語(タイトル=状態のみ・worktree名は含まない)・計画列・作業内容・要注意の機械判定。
#      行の照合はフォルダーパス列(key)で行う。
# ============================================================
lt4_title_plan_and_attention_by_key() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt4"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

lane2 = rows["/Users/x/orca/workspaces/repoA/lane2"]
title2 = "".join(t["text"]["content"] for t in lane2["レーン名"]["title"])
assert title2 == "🔔確認待ち", title2  # worktree名を含まない・状態のみ
assert (lane2["要注意"].get("select") or {}).get("name") == "人間確認待ち", lane2["要注意"]
assert (lane2["段階"].get("select") or {}).get("name") == "人間確認待ち", lane2["段階"]
work2 = "".join(t["text"]["content"] for t in lane2["作業内容"]["rich_text"])
assert work2 == "確認待ち", work2
assert lane2["並び順"].get("number") == 0, lane2["並び順"]
plan2 = "".join(t["text"]["content"] for t in lane2["計画"]["rich_text"])
assert plan2 == "レーン2(子02)", plan2
assert (lane2["種別"].get("select") or {}).get("name") == "worktree", lane2["種別"]

lane1 = rows["/Users/x/orca/workspaces/repoA/lane1"]
title1 = "".join(t["text"]["content"] for t in lane1["レーン名"]["title"])
assert title1 == "▶実装中", title1
assert (lane1["要注意"].get("select") or {}).get("name") == "なし", lane1["要注意"]
assert (lane1["段階"].get("select") or {}).get("name") == "実装", lane1["段階"]
work1 = "".join(t["text"]["content"] for t in lane1["作業内容"]["rich_text"])
assert work1 == "実装中", work1
assert lane1["並び順"].get("number") == 1, lane1["並び順"]
panes = "".join(t["text"]["content"] for t in lane1["ペイン"]["rich_text"])
assert panes == "claude=working／codex=idle", panes
assert (lane1["repo"].get("select") or {}).get("name") == "repoA", lane1["repo"]
plan1 = "".join(t["text"]["content"] for t in lane1["計画"]["rich_text"])
assert plan1 == "統合設計子04a(子04a)", plan1
assert (lane1["種別"].get("select") or {}).get("name") == "worktree", lane1["種別"]

# パス列（フォルダーパス列を「パス」表示列として兼用。別列は無い）
path1 = "".join(t["text"]["content"] for t in lane1["フォルダーパス"]["rich_text"])
assert path1 == "/Users/x/orca/workspaces/repoA/lane1", path1

print("OK")
PY
  [ $? -eq 0 ] || { echo "プロパティ検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt5: 閉じたレーンの行archive（down済み表示の廃止・統合program plan.md 方針5e）。
#      1回目=2レーン→2回目=lane1がorca psから消える→lane1の行はarchived:trueになり
#      プロパティは直前の値のまま保持される（部分パッチではなく無変更）。レーン2はそのまま
#      更新され続ける。3回目=同じ状態で再実行→archive済み行は再度archive対象にならず
#      アクティブ行数・archive呼び出し回数とも増えない（冪等）。
# ============================================================
lt5_closed_lane_archived_and_idempotent() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt5"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  # lane1がorca psから消える（down）。レーン2は残る。
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 1,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane2",
        "displayName": "レーン2(子02)",
        "branch": "refs/heads/y",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "working", "lastAssistantMessage": "確認をお願いします。人間確認待ちです。"}
        ]
      }
    ]
  }
}
EOF

  out2="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "レーン=1 エージェント=1 アーカイブ=1" || { echo "2回目: レーン=1 エージェント=1 アーカイブ=1でない: $out2"; return 1; }

  archiverow_count2="$(grep -c '^archive-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$archiverow_count2" -eq 1 ] || { echo "2回目のarchive-row呼び出しが1でない: $archiverow_count2"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = r

lane1 = rows["/Users/x/orca/workspaces/repoA/lane1"]
assert lane1.get("archived") is True, lane1  # archiveされている（down済み表示ではない）
p1 = lane1["properties"]
title1 = "".join(t["text"]["content"] for t in p1["レーン名"]["title"])
assert title1 == "▶実装中", title1  # archive時にプロパティは書き換えない（直前の値のまま）
panes1 = "".join(t["text"]["content"] for t in p1["ペイン"]["rich_text"])
assert panes1 == "claude=working／codex=idle", panes1

lane2 = rows["/Users/x/orca/workspaces/repoA/lane2"]
assert lane2.get("archived") is False, lane2
assert (lane2["properties"]["要注意"].get("select") or {}).get("name") == "人間確認待ち", lane2["properties"]["要注意"]

active_count = sum(1 for r in s.get("db_rows", {}).values() if not r.get("archived"))
assert active_count == 2, active_count  # レーン2・サマリ の2行のみアクティブ（lane1はarchive済み）

print("OK")
PY
  [ $? -eq 0 ] || { echo "archive後の状態検証に失敗"; return 1; }

  # 3回目: 同じ状態(lane1不在)で再実行→archive済みのlane1はquery結果から除外されるため
  # 再度archive対象にならない・アクティブ行数/archive-row呼び出し回数とも増えない(冪等)。
  out3="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc3=$?
  [ "$rc3" -eq 0 ] || { echo "3回目exit非0 ($rc3): $out3"; return 1; }
  printf '%s' "$out3" | grep -qF "レーン=1 エージェント=1 アーカイブ=0" || { echo "3回目: アーカイブ=0でない(冪等でない): $out3"; return 1; }

  archiverow_count3="$(grep -c '^archive-row:' "$stub_log" 2>/dev/null || echo 0)"
  [ "$archiverow_count3" -eq 1 ] || { echo "3回目実行後もarchive-row呼び出し累計は1のままのはずが: $archiverow_count3"; return 1; }

  active_count3="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_count3" -eq 2 ] || { echo "3回目実行後もアクティブ行数は2のはずが: $active_count3"; return 1; }

  return 0
)

# ============================================================
# lt6: サマリ行（■サマリ固定タイトル・稼働エージェント数／レーン本数が作業内容に入る）
# ============================================================
lt6_summary_row_content() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt6"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
found = None
for r in s.get("db_rows", {}).values():
    title = "".join(t["text"]["content"] for t in r["properties"]["レーン名"]["title"])
    if title == "■サマリ":
        found = r
        break
assert found is not None, "■サマリ行が無い"
work = "".join(t["text"]["content"] for t in found["properties"]["作業内容"]["rich_text"])
assert work == "稼働エージェント数: 3体／レーン2本", work
plan = "".join(t["text"]["content"] for t in found["properties"]["計画"]["rich_text"])
assert plan == "-", plan
assert (found["properties"]["種別"].get("select") or {}) == {}, found["properties"]["種別"]
print("OK")
PY
  [ $? -eq 0 ] || { echo "サマリ行検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt7: ガード（orca-ps-snapshot.sh失敗＝orca CLI不在等→警告1行のみ・exit 0）
# ============================================================
lt7_guard_orca_ps_failure() (
  set -uo pipefail
  workdir="$(new_workdir)"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt7"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="false" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "notion-lanes: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "orca-ps-snapshot.sh" || { echo "警告文にorca-ps-snapshot.shの言及が無い: $out"; return 1; }

  return 0
)

# ============================================================
# lt8: repo導出・種別(worktree)・計画列と並び順の3バケット（0=人間の出番〔要注意=人間確認待ち〕／
#      1=稼働中〔段階=実装〕／2=それ以外〔idle〕）を3レーンで一括検証する。
#      行の照合はフォルダーパス列(key)で行う。
# ============================================================
lt8_repo_kind_and_sort_order_buckets() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 3,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane-working",
        "displayName": "作業中レーン(子01)",
        "branch": "refs/heads/a",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "working", "lastAssistantMessage": "実装中です。\n段階: 実装"}
        ]
      },
      {
        "path": "/Users/x/orca/workspaces/repoB/lane-idle",
        "displayName": "アイドルレーン(子02)",
        "branch": "refs/heads/b",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "idle", "lastAssistantMessage": "待機中"}
        ]
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/lane-human",
        "displayName": "人間待ちレーン(子03)",
        "branch": "refs/heads/c",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "working", "lastAssistantMessage": "人間確認待ちです。"}
        ]
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt8"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

working = rows["/Users/x/orca/workspaces/repoA/lane-working"]
assert working["並び順"].get("number") == 1, working["並び順"]
assert (working["repo"].get("select") or {}).get("name") == "repoA", working["repo"]
assert (working["種別"].get("select") or {}).get("name") == "worktree", working["種別"]
title_w = "".join(t["text"]["content"] for t in working["レーン名"]["title"])
assert title_w == "▶実装中", title_w
plan_w = "".join(t["text"]["content"] for t in working["計画"]["rich_text"])
assert plan_w == "作業中レーン(子01)", plan_w

idle = rows["/Users/x/orca/workspaces/repoB/lane-idle"]
assert idle["並び順"].get("number") == 2, idle["並び順"]
assert (idle["repo"].get("select") or {}).get("name") == "repoB", idle["repo"]
title_i = "".join(t["text"]["content"] for t in idle["レーン名"]["title"])
assert title_i == "⏸待機中", title_i

human = rows["/Users/x/orca/workspaces/repoA/lane-human"]
assert human["並び順"].get("number") == 0, human["並び順"]
assert (human["repo"].get("select") or {}).get("name") == "repoA", human["repo"]
title_h = "".join(t["text"]["content"] for t in human["レーン名"]["title"])
assert title_h == "🔔確認待ち", title_h

summary = rows["■サマリ"]
assert summary["並び順"].get("number") == -1, summary["並び順"]

print("OK")
PY
  [ $? -eq 0 ] || { echo "repo/並び順/タイトルの検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt9: DBスキーマの冪等追加（PATCH /databases/{id}が毎回呼ばれる・2回実行してもプロパティが
#      増殖しない＝11プロパティのまま。列再設計v2で「計画」「種別」を追加した分を含む）。
# ============================================================
lt9_db_schema_patch_is_idempotent() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt9"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  schema_count1="$(grep -c '^update-db-schema:' "$stub_log" 2>/dev/null)"; schema_count1="${schema_count1:-0}"
  [ "$schema_count1" -eq 1 ] || { echo "1回目のスキーマ追加呼び出しが1でない: $schema_count1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  schema_count2="$(grep -c '^update-db-schema:' "$stub_log" 2>/dev/null)"; schema_count2="${schema_count2:-0}"
  [ "$schema_count2" -eq 2 ] || { echo "2回目実行後のスキーマ追加呼び出し累計が2でない(冪等に毎回呼ばれるはず): $schema_count2"; return 1; }

  prop_count="$(python3 -c "
import json
s = json.load(open('$stub_state', encoding='utf-8'))
db = list(s.get('databases', {}).values())[0]
print(len(db.get('schema_properties', {})))
")"
  [ "$prop_count" -eq 11 ] || { echo "スキーマのプロパティ数が11でない(増殖の疑い): $prop_count"; return 1; }

  return 0
)

# ============================================================
# lt10: タイトル変化で行が増殖しない（状態遷移の直接検証）。1回目=working(▶実装中)→
#       2回目=done+レビューPASS(🔔完了)。同じフォルダーパスなので行数は変わらず、タイトルだけが
#       新しい状態語に更新される（worktree名は元々含まれない）。
# ============================================================
lt10_title_change_does_not_duplicate_row() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{"result":{"totalCount":1,"worktrees":[{"path":"/Users/x/orca/workspaces/repoA/lane1","displayName":"レーンA(子01)","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"実装中です。\n段階: 実装"}]}]}}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt10"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  rows1="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(len(s.get('db_rows',{})))")"
  [ "$rows1" -eq 2 ] || { echo "1回目の行数が2(レーン+サマリ)でない: $rows1"; return 1; }

  cat > "$orca_json" <<'EOF'
{"result":{"totalCount":1,"worktrees":[{"path":"/Users/x/orca/workspaces/repoA/lane1","displayName":"レーンA(子01)","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"done","lastAssistantMessage":"レビューが完了しました。REVIEW_PASS"}]}]}}
EOF
  out2="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = s.get("db_rows", {})
assert len(rows) == 2, ("行数が増殖した(2のはず): %d" % len(rows))
for r in rows.values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    if key == "/Users/x/orca/workspaces/repoA/lane1":
        title = "".join(t["text"]["content"] for t in p["レーン名"]["title"])
        assert title == "🔔完了", title
        work = "".join(t["text"]["content"] for t in p["作業内容"]["rich_text"])
        assert work == "レビューPASS・マージ/回収待ち", work
print("OK")
PY
  [ $? -eq 0 ] || { echo "状態遷移後の検証に失敗"; return 1; }

  createrow_count="$(grep -c '^create-row:' "$stub_log" 2>/dev/null)"; createrow_count="${createrow_count:-0}"
  [ "$createrow_count" -eq 2 ] || { echo "create-row回数が2のままであるべき(2回目は更新のみ)が: $createrow_count"; return 1; }

  return 0
)

# ============================================================
# lt11: 遺物行（フォルダーパス列が空・旧形式時代に作られた行）のarchive。旧形式フォールバック照合は
#       撤去済みのため、遺物行は移行されず単純にarchiveされ、実在するレーンには新規行が作られる
#       （統合program plan.md 方針5e・追補要件7）。
# ============================================================
lt11_artifact_row_empty_key_gets_archived() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{"result":{"totalCount":1,"worktrees":[{"path":"/Users/x/orca/workspaces/repoA/real-lane","displayName":"実在レーン(子01)","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"実装中"}]}]}}
EOF

  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; mkdir -p "$state_dir"
  stub_state="$workdir/stub-state.json"
  db_id="lanes-db-legacy-lt11"
  python3 -c "
import json
state = {
    'parent_id': 'parent-fixture-id', 'pages': {}, 'children_of': {},
    'databases': {'$db_id': {'title': 'レーン実況', 'parent_page_id': 'parent-fixture-id', 'archived': False}},
    'db_rows': {
        'row-legacy-1': {
            'db_id': '$db_id',
            'properties': {
                'レーン名': {'title': [{'type': 'text', 'text': {'content': '▶ レガシー計画(子01)'}}]},
                '作業内容': {'rich_text': [{'type': 'text', 'text': {'content': '旧作業内容メモ'}}]},
                '段階': {'select': {'name': '実装'}},
                'ペイン': {'rich_text': [{'type': 'text', 'text': {'content': 'claude=working'}}]},
                '要注意': {'select': {'name': 'なし'}},
            },
            'archived': False,
        }
    },
}
json.dump(state, open('$stub_state', 'w', encoding='utf-8'))
"
  printf '%s' "$db_id" > "$state_dir/notion-lanes-database-id"

  stub_log="$workdir/stub-log.txt"
  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt11"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  # 遺物行は移行されず、実在レーン用に新規行が作られる（サマリ含め2回作成）。
  createrow_count="$(grep -c '^create-row:' "$stub_log" 2>/dev/null)"; createrow_count="${createrow_count:-0}"
  [ "$createrow_count" -eq 2 ] || { echo "実在レーン+サマリの新規作成が2回でない(遺物行が誤って再利用された疑い): $createrow_count"; return 1; }

  archiverow_count="$(grep -c '^archive-row:' "$stub_log" 2>/dev/null)"; archiverow_count="${archiverow_count:-0}"
  [ "$archiverow_count" -eq 1 ] || { echo "遺物行のarchive呼び出しが1でない: $archiverow_count"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = s.get("db_rows", {})
assert len(rows) == 3, ("行数が3(遺物行+実在レーン+サマリ)でない: %d" % len(rows))
legacy = rows.get("row-legacy-1")
assert legacy is not None, "遺物行(row-legacy-1)が消えた"
assert legacy.get("archived") is True, "遺物行がarchiveされていない"

active = {k: v for k, v in rows.items() if not v.get("archived")}
assert len(active) == 2, ("アクティブ行数が2(実在レーン+サマリ)でない: %d" % len(active))
found_real = False
for r in active.values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    if key == "/Users/x/orca/workspaces/repoA/real-lane":
        found_real = True
assert found_real, "実在レーンの行が正しいキーで見つからない"
print("OK")
PY
  [ $? -eq 0 ] || { echo "遺物行archive後の検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt12: 作業内容の機械判定3パターン（no-agent／all-done+PASS／稼働中の段階語）を
#       1フィクスチャで一括検証する（archiveはlt5で別途検証済み）。
# ============================================================
lt12_work_content_rule_variants() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 3,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/no-agent-lane",
        "displayName": "no-agentレーン",
        "branch": "refs/heads/a",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/pass-lane",
        "displayName": "PASSレーン",
        "branch": "refs/heads/b",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "done", "lastAssistantMessage": "実装完了です"},
          {"agentType": "codex", "state": "done", "lastAssistantMessage": "レビューが完了しました。REVIEW_PASS"}
        ]
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/review-lane",
        "displayName": "レビュー中レーン",
        "branch": "refs/heads/c",
        "status": "in-progress",
        "agents": [
          {"agentType": "codex", "state": "working", "lastAssistantMessage": "レビュー中です。\n段階: 実装レビュー"}
        ]
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt12"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

no_agent = rows["/Users/x/orca/workspaces/repoA/no-agent-lane"]
work_na = "".join(t["text"]["content"] for t in no_agent["作業内容"]["rich_text"])
assert work_na == "エージェント無し(worktree回収対象候補)", work_na

pass_lane = rows["/Users/x/orca/workspaces/repoA/pass-lane"]
work_pass = "".join(t["text"]["content"] for t in pass_lane["作業内容"]["rich_text"])
assert work_pass == "レビューPASS・マージ/回収待ち", work_pass

review_lane = rows["/Users/x/orca/workspaces/repoA/review-lane"]
work_review = "".join(t["text"]["content"] for t in review_lane["作業内容"]["rich_text"])
assert work_review == "レビュー中", work_review
title_review = "".join(t["text"]["content"] for t in review_lane["レーン名"]["title"])
assert title_review == "▶レビュー中", title_review

print("OK")
PY
  [ $? -eq 0 ] || { echo "作業内容の機械判定検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt13: repo列が全レーン行で必ず埋まる（通常パス・repo導出が不明瞭になる縮退パスの両方）。
#       サマリ行はプレースホルダ"-"で埋まる。
# ============================================================
lt13_repo_filled_for_all_rows() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 2,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/normal-lane",
        "displayName": "通常レーン",
        "branch": "refs/heads/a",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "working", "lastAssistantMessage": "作業中"}]
      },
      {
        "path": "/degenerate-lane",
        "displayName": "縮退パスレーン",
        "branch": "refs/heads/b",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "working", "lastAssistantMessage": "作業中"}]
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt13"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    title = "".join(t["text"]["content"] for t in p["レーン名"]["title"])
    repo = (p["repo"].get("select") or {}).get("name")
    assert repo, ("repoが空/未設定の行がある: title=%r repo=%r" % (title, repo))

rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

normal = rows["/Users/x/orca/workspaces/repoA/normal-lane"]
assert (normal["repo"].get("select") or {}).get("name") == "repoA", normal["repo"]

degenerate = rows["/degenerate-lane"]
# dirname("/degenerate-lane")="/" -> basename("/")="/" は不明瞭なのでworktree自身のbasenameへ
# フォールバックする（"degenerate-lane"になるはず。空にはならない）。
assert (degenerate["repo"].get("select") or {}).get("name") == "degenerate-lane", degenerate["repo"]

summary = rows["■サマリ"]
assert (summary["repo"].get("select") or {}).get("name") == "-", summary["repo"]

print("OK")
PY
  [ $? -eq 0 ] || { echo "repo全行検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt14: 同じbasenameのレーンが別repoに存在しても、フォルダーパス列の完全一致だけで正しく
#       区別される（旧形式フォールバック照合が無いため、そもそもクロスマッチの余地が無い
#       ことの回帰確認）。2回連続実行でも行が増殖しないこと（冪等）も併せて検証する。
# ============================================================
lt14_same_basename_different_repo_no_cross_match() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 2,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane1",
        "displayName": "repoAのlane1(子01)",
        "branch": "refs/heads/a",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "working", "lastAssistantMessage": "実装中です。\n段階: 実装"}]
      },
      {
        "path": "/Users/x/orca/workspaces/repoB/lane1",
        "displayName": "repoBのlane1(子02)",
        "branch": "refs/heads/b",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "idle", "lastAssistantMessage": "待機中"}]
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt14"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }

  createrow_count="$(grep -c '^create-row:' "$stub_log" 2>/dev/null)"; createrow_count="${createrow_count:-0}"
  [ "$createrow_count" -eq 3 ] || { echo "create-row回数が3(repoA+repoB+サマリ)のままであるべき(2回目は更新のみ)が: $createrow_count"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

assert len(rows) == 3, ("行数が3(repoA+repoB+サマリ)でない: %d" % len(rows))

a = rows["/Users/x/orca/workspaces/repoA/lane1"]
assert (a["repo"].get("select") or {}).get("name") == "repoA", a["repo"]

b = rows["/Users/x/orca/workspaces/repoB/lane1"]
assert (b["repo"].get("select") or {}).get("name") == "repoB", b["repo"]

print("OK")
PY
  [ $? -eq 0 ] || { echo "クロスマッチ回帰確認に失敗"; return 1; }

  return 0
)

# ============================================================
# lt15: 計画・種別列の導出パターン（統合program plan.md 方針5e）。
#       (a) cockpitでタイトル設定済みworktree→計画=displayName・種別=worktree
#       (b) 非cockpit worktree（displayName=branch名の既定値）→計画="-"・種別=worktree
#       (c) .claude/worktrees配下→種別=worktree
#       (d) repoルート直下（main）・displayName空→計画="-"・種別=main
# ============================================================
lt15_plan_and_kind_derivation_variants() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 4,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/titled-lane",
        "displayName": "いい感じの計画名",
        "branch": "refs/heads/feat-x",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/untitled-lane",
        "displayName": "feat-y",
        "branch": "refs/heads/feat-y",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/x/.claude/worktrees/some-worktree",
        "displayName": "別の計画",
        "branch": "refs/heads/dev",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/x/repos/mainrepo",
        "displayName": "",
        "branch": "refs/heads/main",
        "status": "in-progress",
        "agents": []
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt15"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

titled = rows["/Users/x/orca/workspaces/repoA/titled-lane"]
plan_t = "".join(t["text"]["content"] for t in titled["計画"]["rich_text"])
assert plan_t == "いい感じの計画名", plan_t
assert (titled["種別"].get("select") or {}).get("name") == "worktree", titled["種別"]

untitled = rows["/Users/x/orca/workspaces/repoA/untitled-lane"]
plan_u = "".join(t["text"]["content"] for t in untitled["計画"]["rich_text"])
assert plan_u == "-", plan_u  # displayNameがbranch名と同じ＝非cockpit既定値
assert (untitled["種別"].get("select") or {}).get("name") == "worktree", untitled["種別"]

claude_wt = rows["/Users/x/.claude/worktrees/some-worktree"]
plan_c = "".join(t["text"]["content"] for t in claude_wt["計画"]["rich_text"])
assert plan_c == "別の計画", plan_c
assert (claude_wt["種別"].get("select") or {}).get("name") == "worktree", claude_wt["種別"]

main_repo = rows["/Users/x/repos/mainrepo"]
plan_m = "".join(t["text"]["content"] for t in main_repo["計画"]["rich_text"])
assert plan_m == "-", plan_m  # displayNameが空＝非cockpit worktree
assert (main_repo["種別"].get("select") or {}).get("name") == "main", main_repo["種別"]

print("OK")
PY
  [ $? -eq 0 ] || { echo "計画/種別の導出検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt16: 空スナップショット誤アーカイブ防止（差し戻し修正・High）。orca-ps-snapshot.shが
#       「exit 0だがworktrees空」を突然返しても1回目はアーカイブされず既存行は無傷のまま。
#       2回連続で空が確認された時だけ本当にアーカイブされる。レーンが1本以上残っている
#       通常時の個別archiveはこのガードの影響を受けない（lt5で別途検証済み）。
# ============================================================
lt16_empty_snapshot_guard_prevents_mass_archive() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt16"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  active_before="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_before" -eq 3 ] || { echo "前提崩れ: 1回目のアクティブ行数が3でない: $active_before"; return 1; }

  # orca psが突然0レーンを返す（orca CLIの一時的な不調を模す）。
  empty_json="$workdir/orca-ps-empty.json"
  printf '%s' '{"result":{"totalCount":0,"worktrees":[]}}' > "$empty_json"

  out2="$(env ORCA_PS_CMD="cat $empty_json" "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目(空1回目)exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -q "アーカイブを今回はskipする" || { echo "2回目(空1回目)でskip警告が出ていない: $out2"; return 1; }
  printf '%s' "$out2" | grep -qF "アーカイブ=0" || { echo "2回目(空1回目)でアーカイブ=0でない: $out2"; return 1; }

  active_after_first_empty="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_after_first_empty" -eq 3 ] || { echo "空1回目で既存行がarchiveされた(誤検知): $active_after_first_empty"; return 1; }

  archiverow_count_after_first_empty="$(grep -c '^archive-row:' "$stub_log" 2>/dev/null)"; archiverow_count_after_first_empty="${archiverow_count_after_first_empty:-0}"
  [ "$archiverow_count_after_first_empty" -eq 0 ] || { echo "空1回目でarchive-rowが呼ばれた(誤検知): $archiverow_count_after_first_empty"; return 1; }

  # 2回連続で空が確認されたので、今度は本当にアーカイブが実行される。
  out3="$(env ORCA_PS_CMD="cat $empty_json" "${env_common[@]}" "$bin" 2>&1)"; rc3=$?
  [ "$rc3" -eq 0 ] || { echo "3回目(空2回目)exit非0 ($rc3): $out3"; return 1; }
  printf '%s' "$out3" | grep -qF "アーカイブ=2" || { echo "3回目(空2回目)でアーカイブ=2でない(2レーン分掃除されるはず): $out3"; return 1; }

  active_after_second_empty="$(python3 -c "import json; s=json.load(open('$stub_state',encoding='utf-8')); print(sum(1 for r in s.get('db_rows',{}).values() if not r.get('archived')))")"
  [ "$active_after_second_empty" -eq 1 ] || { echo "2回連続空後もアクティブ行が1(サマリのみ)になっていない: $active_after_second_empty"; return 1; }

  return 0
)

# ============================================================
# lt17: 差し戻し修正（High・2巡目）。archive PATCH失敗時、既定モード(LANES_STRICT未設定)は
#       従来どおり警告+exit 0（render.sh本流のフェイルセーフを壊さない）。LANES_STRICT=1の
#       時だけ非0で終了する（lanes-sync.shのsignature非保存/リトライ判定が実際のAPI失敗で
#       機能するようにするための切り替え）。
# ============================================================
lt17_strict_mode_archive_failure_exit_code() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt17"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  env_common=(NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY"
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }

  # lane1がorca psから消える(=archive対象)。archive PATCHを実stubで人為的に失敗(API 400)させる。
  cat > "$orca_json" <<'EOF'
{"result":{"totalCount":1,"worktrees":[{"path":"/Users/x/orca/workspaces/repoA/lane2","displayName":"レーン2(子02)","branch":"refs/heads/y","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"確認をお願いします。人間確認待ちです。"}]}]}}
EOF

  # 既定モード(LANES_STRICT未設定): 従来どおり警告+exit 0。
  out_default="$(env ORCA_PS_CMD="cat $orca_json" NOTION_STUB_FAIL_ARCHIVE=1 "${env_common[@]}" "$bin" 2>&1)"; rc_default=$?
  [ "$rc_default" -eq 0 ] || { echo "既定モードでexit非0になった(render本流のフェイルセーフが壊れた): $rc_default $out_default"; return 1; }
  printf '%s' "$out_default" | grep -q "notion-lanes: 警告" || { echo "既定モードで警告が出ていない: $out_default"; return 1; }
  printf '%s' "$out_default" | grep -q "行アーカイブ" || { echo "既定モードでarchive PATCH失敗の警告文になっていない: $out_default"; return 1; }

  # strictモード(LANES_STRICT=1): 非0で終了する。
  out_strict="$(env ORCA_PS_CMD="cat $orca_json" NOTION_STUB_FAIL_ARCHIVE=1 LANES_STRICT=1 "${env_common[@]}" "$bin" 2>&1)"; rc_strict=$?
  [ "$rc_strict" -ne 0 ] || { echo "strictモードなのにexit 0だった: $out_strict"; return 1; }
  printf '%s' "$out_strict" | grep -q "notion-lanes: 警告" || { echo "strictモードで警告が出ていない: $out_strict"; return 1; }
  printf '%s' "$out_strict" | grep -q "行アーカイブ" || { echo "strictモードでarchive PATCH失敗の警告文になっていない: $out_strict"; return 1; }

  return 0
)

# ============================================================
# lt18: repo列導出の追加修正（実反映で発見・機能は正常）。種別=mainの行はrepoをパス自身の
#       basenameにする（従来は親ディレクトリ名を拾っていたため、実データで
#       repo=kitamuranaohiro(実パス~/Private)・repo=LP(…/nextlevel-career-site)・
#       repo=personal-os(…/AIエージェント基盤)のような誤値になっていた）。種別=worktreeで
#       .claude/worktrees配下のパスは、.claudeの2階層上のrepoフォルダ名をrepoにする
#       （従来はrepo=worktreesになっていた）。実パス4パターンで検証する。
# ============================================================
lt18_repo_derivation_main_and_claude_worktrees() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 4,
    "worktrees": [
      {
        "path": "/Users/kitamuranaohiro/Private",
        "displayName": "",
        "branch": "refs/heads/main",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/kitamuranaohiro/W dev/LP/nextlevel-career-site",
        "displayName": "",
        "branch": "refs/heads/main",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤",
        "displayName": "",
        "branch": "refs/heads/main",
        "status": "in-progress",
        "agents": []
      },
      {
        "path": "/Users/kitamuranaohiro/W dev/LP/nextlevel-career-site/.claude/worktrees/some-branch",
        "displayName": "作業中(子01)",
        "branch": "refs/heads/some-branch",
        "status": "in-progress",
        "agents": []
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt18"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

private = rows["/Users/kitamuranaohiro/Private"]
assert (private["種別"].get("select") or {}).get("name") == "main", private["種別"]
assert (private["repo"].get("select") or {}).get("name") == "Private", private["repo"]

lp = rows["/Users/kitamuranaohiro/W dev/LP/nextlevel-career-site"]
assert (lp["種別"].get("select") or {}).get("name") == "main", lp["種別"]
assert (lp["repo"].get("select") or {}).get("name") == "nextlevel-career-site", lp["repo"]

aiagent = rows["/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤"]
assert (aiagent["種別"].get("select") or {}).get("name") == "main", aiagent["種別"]
assert (aiagent["repo"].get("select") or {}).get("name") == "AIエージェント基盤", aiagent["repo"]

claude_wt = rows["/Users/kitamuranaohiro/W dev/LP/nextlevel-career-site/.claude/worktrees/some-branch"]
assert (claude_wt["種別"].get("select") or {}).get("name") == "worktree", claude_wt["種別"]
assert (claude_wt["repo"].get("select") or {}).get("name") == "nextlevel-career-site", claude_wt["repo"]

print("OK")
PY
  [ $? -eq 0 ] || { echo "repo導出(main/.claude worktrees)の検証に失敗"; return 1; }

  return 0
)

# ============================================================
# lt19: cockpit管轄イベント(owner)を作業内容(rich_text)へテキスト反映する（owner-view-read・
#       先行部品①はf2d5f7bで実装済み）。新規プロパティは作らない(schema=既存11プロパティ不変)。
#       owner有りのレーンだけ「／管轄:X」が末尾に付き、ownerイベントが無いレーンは不変のまま。
# ============================================================
lt19_owner_reflected_in_work_content() (
  set -uo pipefail
  workdir="$(new_workdir)"
  orca_json="$workdir/orca-ps.json"
  write_two_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-lt19"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(notion_lanes_bin "$workdir")"

  events_file="$workdir/cockpit-events.jsonl"
  cat > "$events_file" <<'EOF'
{"ts":"2026-07-02T01:00:00Z","repo":"repoA","branch":"x","worktree":"/Users/x/orca/workspaces/repoA/lane1","terminal":"t1","event":"send","stage":null,"owner":"中間指揮官1"}
EOF

  out="$(ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    COCKPIT_EVENTS_FILE="$events_file" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  python3 - "$stub_state" <<'PY'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
rows = {}
for r in s.get("db_rows", {}).values():
    p = r["properties"]
    key = "".join(t["text"]["content"] for t in p["フォルダーパス"]["rich_text"])
    rows[key] = p

lane1 = rows["/Users/x/orca/workspaces/repoA/lane1"]
work1 = "".join(t["text"]["content"] for t in lane1["作業内容"]["rich_text"])
assert work1 == "実装中／管轄:中間指揮官1", work1

lane2 = rows["/Users/x/orca/workspaces/repoA/lane2"]
work2 = "".join(t["text"]["content"] for t in lane2["作業内容"]["rich_text"])
assert work2 == "確認待ち", work2  # ownerイベントが無いレーンは不変

print("OK")
PY
  [ $? -eq 0 ] || { echo "owner反映の検証に失敗"; return 1; }

  return 0
)

# ============================================================
run_test lt1_secret_never_leaks
run_test lt2_guard_no_token
run_test lt3_upsert_idempotent_no_duplicate_rows
run_test lt4_title_plan_and_attention_by_key
run_test lt5_closed_lane_archived_and_idempotent
run_test lt6_summary_row_content
run_test lt7_guard_orca_ps_failure
run_test lt8_repo_kind_and_sort_order_buckets
run_test lt9_db_schema_patch_is_idempotent
run_test lt10_title_change_does_not_duplicate_row
run_test lt11_artifact_row_empty_key_gets_archived
run_test lt12_work_content_rule_variants
run_test lt13_repo_filled_for_all_rows
run_test lt14_same_basename_different_repo_no_cross_match
run_test lt15_plan_and_kind_derivation_variants
run_test lt16_empty_snapshot_guard_prevents_mass_archive
run_test lt17_strict_mode_archive_failure_exit_code
run_test lt18_repo_derivation_main_and_claude_worktrees
run_test lt19_owner_reflected_in_work_content

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
