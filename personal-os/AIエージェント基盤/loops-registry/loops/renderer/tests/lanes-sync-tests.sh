#!/usr/bin/env bash
# renderer / tests / lanes-sync-tests.sh — lanes-sync.sh（統合program plan.md 方針5c・レーン実況の
# 毎分差分駆動sync）のテストスイート。実API・実トークン・実キーチェーン・実orca CLI・実HOME書込は
# 一切行わない。
# - security find-generic-password は NOTION_SECURITY_CMD でstub（成功/失敗を切り替え）に差し替える。
# - curl は NOTION_CURL_CMD で fixtures/notion-curl-stub.py に差し替える。
# - orca worktree ps は ORCA_PS_CMD で `cat <fixture.json>` に差し替える。
set -uo pipefail

# 依頼インボックスtick（マルチ指揮官体制program子03の相乗り）はコアテストでは切り離す。
# st1/st3等の「無変化ならAPI呼び出しゼロ・無音」はlanes-sync本流の不変条件であり、
# 毎分必ずqueryするpull（tick側）とは独立に検証する。相乗り配線そのものは st11 が
# INBOX_TICK_DISABLED を外して検証する。
export INBOX_TICK_DISABLED=1
# 統合見張りtick（子06フェーズ1）も同様にコアテストでは切り離す（keeper-tick→keeper.sh→実orca ps/
# 実osascriptの副作用をコアテストへ持ち込まない）。相乗り配線と1分二重通知ガードは
# renderer/tests/keeper-tick-tests.sh が独立に検証する。
export KEEPER_TICK_DISABLED=1

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
  d="$(mktemp -d "${TMPDIR:-/tmp}/lanes-sync-test.XXXXXX")"
  workdirs+=("$d")
  mkdir -p "$d/loops-registry/loops/renderer" "$d/loops-registry/loops/daily-digest"
  cp -R "$RENDERER_DIR/scripts" "$d/loops-registry/loops/renderer/scripts"
  cp -R "$RENDERER_DIR/templates" "$d/loops-registry/loops/renderer/templates"
  cp -R "$LOOPS_DIR/daily-digest/scripts" "$d/loops-registry/loops/daily-digest/scripts"
  printf '%s' "$d"
}

lanes_sync_bin() { printf '%s/loops-registry/loops/renderer/scripts/lanes-sync.sh' "$1"; }

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

make_daily() {
  local out="$1" date_str="$2"
  local y="${date_str%%-*}"
  sed -e "s/<YYYY-MM-DD>/$date_str/g" -e "s/<曜>/月/g" -e "s/<YYYY>/$y/g" "$TEMPLATE" > "$out"
}

write_one_lane_fixture() {
  local out="$1" state="${2:-working}" lastline="${3:-実装中です}"
  cat > "$out" <<EOF
{
  "result": {
    "totalCount": 1,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane1",
        "displayName": "レーンA(子01)",
        "branch": "refs/heads/x",
        "status": "in-progress",
        "agents": [
          {"agentType": "claude", "state": "$state", "lastAssistantMessage": "$lastline"}
        ]
      }
    ]
  }
}
EOF
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
# st1: 無変化なら2回目はNotion push(notion-lanes.sh)が呼ばれない（stub_logへ追記が一切無い）。
#      出力も無し（exit 0のみ）。
# ============================================================
st1_no_change_no_push() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st1"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  env_common=(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub"
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -qF "sync実行" || { echo "1回目(変化あり初回)でsync実行されていない: $out1"; return 1; }
  [ -s "$stub_log" ] || { echo "1回目でNotion push相当のstub呼び出しが無い"; return 1; }

  log_lines_before="$(wc -l < "$stub_log" | tr -d ' ')"

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  [ -z "$out2" ] || { echo "2回目(無変化)で出力があった(何もしないはず): [$out2]"; return 1; }

  log_lines_after="$(wc -l < "$stub_log" | tr -d ' ')"
  [ "$log_lines_before" -eq "$log_lines_after" ] || { echo "2回目(無変化)でstub呼び出しが増えた(API呼び出しが起きた): before=$log_lines_before after=$log_lines_after"; return 1; }

  return 0
)

# ============================================================
# st2: 変化がある時はNotion push(notion-lanes.sh)が呼ばれ、ローカルauto:board-nowも更新される。
# ============================================================
st2_change_triggers_push_and_local_board_now() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st2"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  out="$(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }

  grep -q '^create-row:' "$stub_log" || { echo "Notion pushが呼ばれていない(create-row無し): $(cat "$stub_log")"; return 1; }
  grep -qF "レーンA(子01)" "$daily" || { echo "ローカルauto:board-nowが更新されていない"; return 1; }
  grep -qE '^<!-- auto:board-now:begin' "$daily" || { echo "auto:board-nowマーカーが消えた"; return 1; }

  [ -f "$state_dir/notion-lanes-sync-signature" ] || { echo "signatureファイルが保存されていない"; return 1; }

  return 0
)

# ============================================================
# st3: シグネチャ安定性（同じfixtureで3回連続実行しても、変化するのは1回目だけ。
#      2回目・3回目はどちらもAPI呼び出しゼロ・出力ゼロのまま）。
# ============================================================
st3_signature_stable_across_repeated_runs() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st3"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  env_common=(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub"
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  env "${env_common[@]}" "$bin" >/dev/null 2>&1
  sig1="$(cat "$state_dir/notion-lanes-sync-signature")"
  log_count1="$(wc -l < "$stub_log" | tr -d ' ')"

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"
  [ -z "$out2" ] || { echo "2回目で出力があった: [$out2]"; return 1; }
  sig2="$(cat "$state_dir/notion-lanes-sync-signature")"
  [ "$sig1" = "$sig2" ] || { echo "同一入力なのにsignatureが変化した: $sig1 -> $sig2"; return 1; }

  out3="$(env "${env_common[@]}" "$bin" 2>&1)"
  [ -z "$out3" ] || { echo "3回目で出力があった: [$out3]"; return 1; }

  log_count3="$(wc -l < "$stub_log" | tr -d ' ')"
  [ "$log_count1" -eq "$log_count3" ] || { echo "2回目・3回目でstub呼び出しが増えた: 1回目後=$log_count1 3回目後=$log_count3"; return 1; }

  return 0
)

# ============================================================
# st4: ガード（orca-ps-snapshot.sh失敗＝orca CLI不在等→警告1行のみ・exit 0。curlは呼ばれない）
# ============================================================
st4_guard_orca_ps_failure() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st4"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  out="$(GOAL_BASE="$goal_base" ORCA_PS_CMD="false" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  warn_lines="$(printf '%s\n' "$out" | grep -c "lanes-sync: 警告")"
  [ "$warn_lines" -eq 1 ] || { echo "警告行が1行でない($warn_lines行): $out"; return 1; }
  printf '%s' "$out" | grep -q "orca-ps-snapshot.sh" || { echo "警告文にorca-ps-snapshot.shの言及が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "orca ps失敗にもかかわらずcurl(stub)が呼ばれた"; return 1; }

  return 0
)

# ============================================================
# st5: 多重起動防止（ロックディレクトリが新しいまま存在→警告1行のみ・exit 0でskip。
#      board-now更新もNotion pushも一切行われない）
# ============================================================
st5_lock_prevents_concurrent_run() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"
  before_daily="$(cat "$daily")"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st5"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; mkdir -p "$state_dir"
  stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  lock_dir="$workdir/lock-dir"
  mkdir "$lock_dir"

  out="$(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_LOG_FILE="$stub_log" LANES_SYNC_LOCK_DIR="$lock_dir" \
    "$bin" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -q "ロック中" || { echo "ロック中の警告文が無い: $out"; return 1; }
  [ ! -s "$stub_log" ] || { echo "ロック中にもかかわらずcurl(stub)が呼ばれた"; return 1; }
  after_daily="$(cat "$daily")"
  [ "$before_daily" = "$after_daily" ] || { echo "ロック中にもかかわらずデイリーが変化した"; return 1; }
  [ -d "$lock_dir" ] || { echo "他プロセスのロックを誤って消してしまった"; return 1; }

  return 0
)

# ============================================================
# st6: 古いロック（301秒超）は自己修復して通常実行される。
# ============================================================
st6_stale_lock_self_heals() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st6"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; mkdir -p "$state_dir"
  stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  lock_dir="$workdir/lock-dir"
  mkdir "$lock_dir"
  touch -t "$(date -v-400S '+%Y%m%d%H%M.%S' 2>/dev/null || date -d '400 seconds ago' '+%Y%m%d%H%M.%S')" "$lock_dir" 2>/dev/null || true

  out="$(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" LANES_SYNC_LOCK_DIR="$lock_dir" \
    "$bin" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -qF "sync実行" || { echo "古いロックなのに通常実行されなかった: $out"; return 1; }
  [ -s "$stub_log" ] || { echo "古いロック自己修復後もNotion pushが呼ばれていない"; return 1; }

  return 0
)

# ============================================================
# st7: デイリー未生成でもNotion push（notion-lanes.sh）は継続する（ローカルboard-now更新だけ
#      警告付きでskipする。互いに独立していることの確認）。
# ============================================================
st7_missing_daily_still_pushes_to_notion() (
  set -uo pipefail
  workdir="$(new_workdir)"
  goal_base="$workdir/data/goal-base"
  mkdir -p "$goal_base"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st7"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  out="$(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub" \
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" \
    "$bin" 2>&1)"; rc=$?

  [ "$rc" -eq 0 ] || { echo "exit非0 ($rc): $out"; return 1; }
  printf '%s' "$out" | grep -q "デイリーが無いため" || { echo "デイリー未生成の警告が無い: $out"; return 1; }
  grep -q '^create-row:' "$stub_log" || { echo "デイリー未生成でもNotion pushは継続するはずが呼ばれていない: $(cat "$stub_log")"; return 1; }

  return 0
)

# ============================================================
# st8: 差し戻し修正（Medium）の再現テスト。orca psに存在しないworktree向けの段階イベントが
#      COCKPIT_EVENTS_FILEへ1行追記されただけでは、signatureは変化せず2回目syncはAPI呼び出し
#      ゼロのままである（無関係なイベントを積分に含めていた旧実装は偽の変化検知を起こしていた）。
# ============================================================
st8_unrelated_worktree_event_does_not_trigger_sync() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  events_file="$workdir/events.jsonl"
  : > "$events_file"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st8"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  env_common=(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub"
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" COCKPIT_EVENTS_FILE="$events_file")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -qF "sync実行" || { echo "1回目(変化あり初回)でsync実行されていない: $out1"; return 1; }
  log_lines_before="$(wc -l < "$stub_log" | tr -d ' ')"

  # orca psには居ないworktree向けの段階イベントを1行追記する（レーンA自身の状態は無変化のまま）。
  cat >> "$events_file" <<'EOF'
{"ts":"2026-07-03T09:00:00Z","repo":"other-repo","branch":"x","worktree":"/Users/x/orca/workspaces/other-repo/unrelated-lane","terminal":"t1","event":"send","stage":"実装"}
EOF

  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  [ -z "$out2" ] || { echo "無関係worktree向けイベント追記だけで2回目にsyncが実行された(偽の変化検知): [$out2]"; return 1; }

  log_lines_after="$(wc -l < "$stub_log" | tr -d ' ')"
  [ "$log_lines_before" -eq "$log_lines_after" ] || { echo "無関係イベント追記後にstub呼び出しが増えた(API呼び出しが起きた): before=$log_lines_before after=$log_lines_after"; return 1; }

  return 0
)

# ============================================================
# st9: 差し戻し修正（High・2巡目）。notion-lanes.shは既定でフェイルセーフ(warn_exit0が常に
#      exit 0)のため、実際のAPI失敗（archive PATCH失敗）はLANES_STRICT無しでは終了コードに
#      現れない。lanes-sync.shがLANES_STRICT=1を付けて呼ぶことで、実際のarchive PATCH失敗
#      （NOTION_STUB_FAIL_ARCHIVE=1・実stub API 400）でもnotion-lanes.shが非0終了し、
#      シグネチャが保存されず、状態が無変化のままでも次回実行でarchiveが自動的に再試行される
#      ことを、実際のnotion-lanes.sh(スタブ差し替え無し)を通して検証する。
# ============================================================
st9_failed_notion_lanes_does_not_save_signature_and_retries() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  # 2レーン(lane1・lane2)で開始する。lane2だけが後で消えてarchive対象になる
  # （lane_count>=1を保つことで「空スナップショットの誤アーカイブ防止ガード」には触れず、
  # 通常の個別archive経路そのものの失敗を検証する）。
  orca_json="$workdir/orca-ps.json"
  cat > "$orca_json" <<'EOF'
{
  "result": {
    "totalCount": 2,
    "worktrees": [
      {
        "path": "/Users/x/orca/workspaces/repoA/lane1",
        "displayName": "レーンA(子01)",
        "branch": "refs/heads/x",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "working", "lastAssistantMessage": "実装中です"}]
      },
      {
        "path": "/Users/x/orca/workspaces/repoA/lane2",
        "displayName": "レーンB(子02)",
        "branch": "refs/heads/y",
        "status": "in-progress",
        "agents": [{"agentType": "claude", "state": "working", "lastAssistantMessage": "実装中です"}]
      }
    ]
  }
}
EOF

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st9"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  env_common=(GOAL_BASE="$goal_base" NOTION_SECURITY_CMD="$security_stub"
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env ORCA_PS_CMD="cat $orca_json" "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  sig1="$(cat "$state_dir/notion-lanes-sync-signature" 2>/dev/null || true)"
  [ -n "$sig1" ] || { echo "1回目でsignatureが保存されていない"; return 1; }

  # lane2がorca psから消える(=archive対象)。archive PATCHを実stubで人為的に失敗(API 400)させる。
  cat > "$orca_json" <<'EOF'
{"result":{"totalCount":1,"worktrees":[{"path":"/Users/x/orca/workspaces/repoA/lane1","displayName":"レーンA(子01)","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"実装中です"}]}]}}
EOF

  out2="$(env ORCA_PS_CMD="cat $orca_json" NOTION_STUB_FAIL_ARCHIVE=1 "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目(lanes-sync.sh自体)がexit非0になった(常にexit 0のはず): $rc2 $out2"; return 1; }
  printf '%s' "$out2" | grep -q "notion-lanes.shが失敗した" || { echo "2回目でnotion-lanes.sh失敗(archive PATCH失敗)の警告が無い: $out2"; return 1; }

  sig2="$(cat "$state_dir/notion-lanes-sync-signature" 2>/dev/null || true)"
  [ "$sig1" = "$sig2" ] || { echo "archive PATCH失敗にもかかわらずsignatureが更新された: $sig1 -> $sig2"; return 1; }

  archivefail_count1="$(grep -c '^archive-row-fail:' "$stub_log" 2>/dev/null)"; archivefail_count1="${archivefail_count1:-0}"
  [ "$archivefail_count1" -ge 1 ] || { echo "archive-row-fail(stub)が記録されていない(=LANES_STRICTが正しく渡っていない疑い): $(cat "$stub_log")"; return 1; }

  # 状態は無変化(lane2消滅のまま)で3回目を実行。前回signatureが保存されていないので
  # 「変化あり」として再度notion-lanes.shが呼ばれ、archiveが自動的に再試行されるはず。
  out3="$(env ORCA_PS_CMD="cat $orca_json" NOTION_STUB_FAIL_ARCHIVE=1 "${env_common[@]}" "$bin" 2>&1)"; rc3=$?
  [ "$rc3" -eq 0 ] || { echo "3回目exit非0 ($rc3): $out3"; return 1; }
  printf '%s' "$out3" | grep -q "notion-lanes.shが失敗した" || { echo "3回目でリトライされていない(警告が出ていない): $out3"; return 1; }
  archivefail_count2="$(grep -c '^archive-row-fail:' "$stub_log" 2>/dev/null)"; archivefail_count2="${archivefail_count2:-0}"
  [ "$archivefail_count2" -gt "$archivefail_count1" ] || { echo "3回目でarchiveが再試行されていない: before=$archivefail_count1 after=$archivefail_count2"; return 1; }

  sig3="$(cat "$state_dir/notion-lanes-sync-signature" 2>/dev/null || true)"
  [ "$sig1" = "$sig3" ] || { echo "3回目もsignatureが更新されるべきでない: $sig1 -> $sig3"; return 1; }

  return 0
)

# ============================================================
# st10: 差し戻し修正（High）。ローカルboard更新（build-board-now.sh）が失敗した時も、
#       notion-lanes.sh自体は成功していてもシグネチャは保存されない（次回リトライされる）。
# ============================================================
st10_failed_local_board_update_does_not_save_signature() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  # build-board-now.sh を人為的に失敗させる（notion-lanes.sh自体は実stub(成功)のまま）。
  build_board_now_sh="$workdir/loops-registry/loops/renderer/scripts/build-board-now.sh"
  cat > "$build_board_now_sh" <<'EOF'
#!/usr/bin/env bash
echo "stub: 人為的な失敗" >&2
exit 1
EOF
  chmod +x "$build_board_now_sh"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st10"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  env_common=(GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" NOTION_SECURITY_CMD="$security_stub"
    NOTION_CURL_CMD="python3 $STUB_PY" NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir"
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log")

  out1="$(env "${env_common[@]}" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "1回目exit非0 ($rc1): $out1"; return 1; }
  printf '%s' "$out1" | grep -q "build-board-now.shが失敗した" || { echo "1回目でbuild-board-now.sh失敗の警告が無い: $out1"; return 1; }
  grep -q '^create-row:' "$stub_log" || { echo "notion-lanes.sh自体は成功して呼ばれているはずが呼ばれていない: $(cat "$stub_log")"; return 1; }
  [ ! -f "$state_dir/notion-lanes-sync-signature" ] || { echo "ローカルboard更新失敗にもかかわらずsignatureが保存された"; return 1; }

  log_lines_before="$(wc -l < "$stub_log" | tr -d ' ')"

  # 状態は無変化のまま2回目を実行→再度notion-lanes.shが呼ばれる(=自動リトライ)はず。
  out2="$(env "${env_common[@]}" "$bin" 2>&1)"; rc2=$?
  [ "$rc2" -eq 0 ] || { echo "2回目exit非0 ($rc2): $out2"; return 1; }
  printf '%s' "$out2" | grep -q "build-board-now.shが失敗した" || { echo "2回目でリトライされていない(警告が出ていない): $out2"; return 1; }
  log_lines_after="$(wc -l < "$stub_log" | tr -d ' ')"
  [ "$log_lines_after" -gt "$log_lines_before" ] || { echo "2回目でnotion-lanes.shが再度呼ばれていない(リトライされていない): before=$log_lines_before after=$log_lines_after"; return 1; }
  [ ! -f "$state_dir/notion-lanes-sync-signature" ] || { echo "2回目もsignatureが保存されるべきでない"; return 1; }

  return 0
)

# ============================================================
# st11: 依頼インボックスtick相乗り（子03）: lanes-sync 1回の実行で inbox-tick.sh 経由の
#       notion-inbox-pull.sh が走る（stub状態に「依頼インボックス」DBが解決/作成される）。
#       定常tick（立案済0件）はstdoutに何も出さない（毎分ノイズ防止）。
# ============================================================
st11_inbox_tick_piggyback() (
  set -uo pipefail
  workdir="$(new_workdir)"
  today="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"
  goal_base="$workdir/data/goal-base"
  daily="$goal_base/デイリー/${today%%-*}/${today#*-}"
  daily="${daily%-*}/$today.md"
  mkdir -p "$(dirname "$daily")"
  make_daily "$daily" "$today"

  orca_json="$workdir/orca-ps.json"
  write_one_lane_fixture "$orca_json"

  security_stub="$workdir/security-ok.sh"
  make_security_ok "$security_stub" "fake-token-st11"
  conf="$workdir/notion-push.conf"; write_conf "$conf" "parent-fixture-id"
  state_dir="$workdir/state"; stub_state="$workdir/stub-state.json"; stub_log="$workdir/stub-log.txt"
  bin="$(lanes_sync_bin "$workdir")"

  out1="$(env INBOX_TICK_DISABLED= GOAL_BASE="$goal_base" ORCA_PS_CMD="cat $orca_json" \
    NOTION_SECURITY_CMD="$security_stub" NOTION_CURL_CMD="python3 $STUB_PY" \
    NOTION_PUSH_CONF="$conf" NOTION_PUSH_STATE_DIR="$state_dir" \
    NOTION_STUB_STATE_FILE="$stub_state" NOTION_STUB_LOG_FILE="$stub_log" "$bin" 2>&1)"; rc1=$?
  [ "$rc1" -eq 0 ] || { echo "exit非0 ($rc1): $out1"; return 1; }

  python3 - "$stub_state" <<'CHK'
import json, sys
s = json.load(open(sys.argv[1], encoding="utf-8"))
titles = [ (d or {}).get("title") for d in (s.get("databases") or {}).values() ]
sys.exit(0 if "依頼インボックス" in titles else 1)
CHK
  [ $? -eq 0 ] || { echo "pullが走っていない(stub状態に依頼インボックスDBが無い)"; return 1; }

  printf '%s' "$out1" | grep -qF "notion-inbox-pull" && { echo "定常tick(立案済0件)なのにpullの出力が漏れた: [$out1]"; return 1; }
  return 0
)

# ============================================================
run_test st1_no_change_no_push
run_test st2_change_triggers_push_and_local_board_now
run_test st3_signature_stable_across_repeated_runs
run_test st4_guard_orca_ps_failure
run_test st5_lock_prevents_concurrent_run
run_test st6_stale_lock_self_heals
run_test st7_missing_daily_still_pushes_to_notion
run_test st8_unrelated_worktree_event_does_not_trigger_sync
run_test st9_failed_notion_lanes_does_not_save_signature_and_retries
run_test st10_failed_local_board_update_does_not_save_signature
run_test st11_inbox_tick_piggyback

echo "============================================"
echo "PASS: $pass_count  FAIL: $fail_count"
if [ "$fail_count" -gt 0 ]; then
  echo "失敗したテスト: ${fail_names[*]}"
  exit 1
fi
exit 0
