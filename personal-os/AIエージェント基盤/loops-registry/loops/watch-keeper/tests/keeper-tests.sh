#!/usr/bin/env bash
# watch-keeper / tests / keeper-tests.sh — マーカー検知・seen除外・エラーstate検知・watch不在検知・
# 通知stub発火・冪等性(同一入力2回で通知1回)・PARSE_ERR・KEEPER_AUTOPILOTの分岐を検証する。
# 実orca CLI・実osascript・実HOME書込・実launchd・実claudeは一切使わない（すべてfixture/stub）。
# 終了コードで全体の合否を表す（0=全PASS／非0=1件以上FAIL）。
#
# 後始末の安全性（inbox-patrol/tests/run-tests.shと同じ方針）: テスト全体で使う専用ルート TEST_ROOT を
# mktemp -d で1個だけ作り、全ての一時ファイル・ディレクトリはこの配下にしか作らない。safe_rm_rf() が
# TEST_ROOT配下であることを確認してから TEST_ROOT 1個だけを rm -rf する。
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$TESTS_DIR/.." && pwd)"
KEEPER_SH="$LOOP_DIR/scripts/keeper.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/watch-keeper-tests.XXXXXX")" || { echo "TEST_ROOT作成に失敗" >&2; exit 1; }
[ -d "$TEST_ROOT" ] || { echo "TEST_ROOT作成に失敗（ディレクトリが存在しない）: $TEST_ROOT" >&2; exit 1; }

safe_rm_rf() {
  local target="$1"
  case "${TEST_ROOT:-}" in
    ""|"/"|"/tmp"|"$HOME"|"$HOME/")
      echo "警告: TEST_ROOTが危険な値のため削除をスキップ: target=[$target] TEST_ROOT=[${TEST_ROOT:-}]" >&2
      return 1
      ;;
  esac
  case "$target" in
    "$TEST_ROOT"|"$TEST_ROOT"/*) ;;
    *)
      echo "警告: 削除対象がTEST_ROOT配下でないためスキップ: target=[$target] TEST_ROOT=[$TEST_ROOT]" >&2
      return 1
      ;;
  esac
  rm -rf -- "$target"
}

cleanup_all() { safe_rm_rf "$TEST_ROOT"; }
trap cleanup_all EXIT

pass_count=0
fail_count=0
fail_names=()

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

# --- ヘルパ ---

# $1=本文（JSON）を書いたfixtureファイルパスを返す。
new_fixture() {
  local body="$1" d f
  d="$(mktemp -d "$TEST_ROOT/fixture.XXXXXX")"
  f="$d/ps.json"
  printf '%s' "$body" > "$f"
  printf '%s' "$f"
}

# 通知呼び出しを1行ずつ「title<TAB>body」で$1に記録するstubを作り、そのパスを返す。実osascriptは呼ばない。
new_notify_stub() {
  local log="$1" d stub
  d="$(mktemp -d "$TEST_ROOT/notify.XXXXXX")"
  stub="$d/notify-stub.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
printf '%s\t%s\n' "\$1" "\$2" >> "$log"
STUB
  chmod +x "$stub"
  printf '%s' "$stub"
}

# autopilot呼び出しを1行ずつ「lane|kind|line」で$1に記録するstubを作り、そのパスを返す。実claudeは呼ばない。
new_autopilot_stub() {
  local log="$1" d stub
  d="$(mktemp -d "$TEST_ROOT/autopilot.XXXXXX")"
  stub="$d/autopilot-stub.sh"
  cat > "$stub" <<STUB
#!/usr/bin/env bash
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >> "$log"
STUB
  chmod +x "$stub"
  printf '%s' "$stub"
}

# keeper.shを1回実行する。$1=fixture json path, $2=state dir, $3=notify log path,
# $4=pgrepコマンド(既定 "echo 1"=watch稼働中), $5=KEEPER_AUTOPILOT(既定0), $6=autopilot log path(空なら未設定)
run_keeper() {
  local ps_json="$1" state_dir="$2" notify_log="$3" pgrep_cmd="${4:-echo 1}" autopilot="${5:-0}" autopilot_log="${6:-}"
  local notify_stub autopilot_stub=""
  notify_stub="$(new_notify_stub "$notify_log")"
  if [ -n "$autopilot_log" ]; then
    autopilot_stub="$(new_autopilot_stub "$autopilot_log")"
  fi
  # 出所なし検知(NO_ORIGIN)用events.jsonl: 呼び出し元が指定すればそれ、無ければ非存在パス既定
  # （events.jsonl不在時keeperはNO_ORIGINをスキップ＝既存テストは無影響のまま）。NO_ORIGINテストだけ
  # COCKPIT_EVENTS_FILE を実在ファイルに差し替えて検証する。
  local events_file="${COCKPIT_EVENTS_FILE:-$state_dir/no-events.jsonl}"
  # ペイン台帳(panes.jsonl・玉A)も既定は非存在パス（実state/panes.jsonlを読まない＝密閉）。
  local panes_file="${COCKPIT_PANES_FILE:-$state_dir/no-panes.jsonl}"
  KEEPER_PS_CMD="cat $ps_json" \
  KEEPER_STATE_DIR="$state_dir" \
  KEEPER_NOTIFY_CMD="$notify_stub" \
  KEEPER_PGREP_CMD="$pgrep_cmd" \
  KEEPER_AUTOPILOT="$autopilot" \
  KEEPER_AUTOPILOT_CMD="$autopilot_stub" \
  COCKPIT_EVENTS_FILE="$events_file" \
  COCKPIT_PANES_FILE="$panes_file" \
  "$KEEPER_SH"
}

new_state_dir() { mktemp -d "$TEST_ROOT/state.XXXXXX"; }

count_lines() {
  local f="$1"
  [ -f "$f" ] || { echo 0; return; }
  wc -l < "$f" | tr -d ' '
}

# alerts.jsonlのN行目(1始まり)の"line"フィールドを原文のまま標準出力へ返す(json.loadで復元・再加工しない)。
json_line_field() {
  local file="$1" n="$2"
  python3 -c '
import json, sys
path, n = sys.argv[1], int(sys.argv[2])
with open(path, "r", encoding="utf-8") as f:
    lines = [l for l in f.read().splitlines() if l.strip()]
obj = json.loads(lines[n - 1])
sys.stdout.write(obj["line"])
' "$file" "$n"
}

# --- fixture本文 ---

FIX_DONE='{"result":{"worktrees":[{"path":"/fake/wt/impl-lane","displayName":"impl","branch":"refs/heads/x","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"実装完了しました。\nIMPL_DONE"}]}]}}'

FIX_REVIEW_PASS='{"result":{"worktrees":[{"path":"/fake/wt/review-lane","displayName":"review","branch":"refs/heads/y","status":"in-progress","agents":[{"agentType":"codex","state":"working","lastAssistantMessage":"レビューしました。\nREVIEW_RESULT: PASS"}]}]}}'

FIX_GATE='{"result":{"worktrees":[{"path":"/fake/wt/gate-lane","displayName":"gate","branch":"refs/heads/z","status":"in-progress","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"設計を進めています。\n段階: 人間確認待ち"}]}]}}'

FIX_ERROR='{"result":{"worktrees":[{"path":"/fake/wt/err-lane","displayName":"err","branch":"refs/heads/e","status":"in-progress","agents":[{"agentType":"codex","state":"crashed","lastAssistantMessage":"予期しないエラーが発生しました"}]}]}}'

FIX_NO_LANES='{"result":{"worktrees":[{"path":"/fake/wt/idle","displayName":"idle","branch":"refs/heads/idle","status":"idle","agents":[]}]}}'

FIX_EMPTY_WORKTREES='{"result":{"worktrees":[]}}'

FIX_BAD_JSON='not json at all'

# 差し戻し1回目回帰: 同一レーン内に「|」を含む行と「/」を含む行(それ以外は同一)の2エージェントを置く。
# 旧実装はpython側sanitize()が両方とも"|"→"/"に潰していたため、この2行は同一の(lane,line)キーへ
# 収束し、2件目の通知がseen.txtの完全一致判定で誤って抑止されていた（レビュアー再現バグ）。
FIX_PIPE_VS_SLASH='{"result":{"worktrees":[{"path":"/fake/wt/collide-lane","displayName":"collide","branch":"refs/heads/c","status":"in-progress","agents":[{"agentType":"claude","state":"crashed","lastAssistantMessage":"設定ファイル a|b が壊れています"},{"agentType":"codex","state":"crashed","lastAssistantMessage":"設定ファイル a/b が壊れています"}]}]}}'

# 差し戻し1回目回帰: 引用符(")・バッククォート・$・パイプを含む行。argv経由の通知呼び出し・
# python3 json.dumpsでのalerts記録のいずれも、シェル文字列結合を経由しないため元来壊れないはずだが、
# 判定ロジック側(旧sanitize())が別経路で内容を破壊していなかったことも合わせて検証する。
FIX_SPECIAL_CHARS='{"result":{"worktrees":[{"path":"/fake/wt/special-lane","displayName":"special","branch":"refs/heads/s","status":"in-progress","agents":[{"agentType":"claude","state":"failed","lastAssistantMessage":"エラー: `whoami` と $HOME と \"quoted\" と a|b"}]}]}}'

# --- テスト ---

test_done_marker_detected_and_notified() {
  local ps state notify
  ps="$(new_fixture "$FIX_DONE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_1.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "DONE_MARKER"' "$state/alerts.jsonl" || { echo "alerts.jsonlにDONE_MARKERが無い"; return 1; }
  grep -q '"lane": "impl-lane"' "$state/alerts.jsonl" || { echo "alerts.jsonlにlane=impl-laneが無い"; return 1; }
  [ -f "$notify" ] || { echo "notify stubが呼ばれていない"; return 1; }
  grep -qF "DONE_MARKER" "$notify" || { echo "通知本文にDONE_MARKERが無い"; return 1; }
}

test_review_pass_marker_detected() {
  local ps state notify
  ps="$(new_fixture "$FIX_REVIEW_PASS")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_2.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -qF "REVIEW_RESULT: PASS" "$state/alerts.jsonl" || { echo "REVIEW_RESULT: PASSが検知されていない"; return 1; }
}

test_human_gate_detected() {
  local ps state notify
  ps="$(new_fixture "$FIX_GATE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_3.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "HUMAN_GATE"' "$state/alerts.jsonl" || { echo "HUMAN_GATEが検知されていない"; return 1; }
  grep -q '"lane": "gate-lane"' "$state/alerts.jsonl" || { echo "lane=gate-laneが無い"; return 1; }
}

test_agent_error_state_detected() {
  local ps state notify
  ps="$(new_fixture "$FIX_ERROR")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_4.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "AGENT_ERROR"' "$state/alerts.jsonl" || { echo "AGENT_ERRORが検知されていない"; return 1; }
  grep -q '"lane": "err-lane"' "$state/alerts.jsonl" || { echo "lane=err-laneが無い"; return 1; }
}

test_watch_missing_detected_when_lane_active() {
  local ps state notify
  ps="$(new_fixture "$FIX_NO_LANES")"
  # このfixtureはagentを持たない(=稼働レーン0)ため、まずレーンありのfixtureで確認する
  ps="$(new_fixture "$FIX_GATE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_5.log"
  # watch.shプロセス不在をシミュレート(pgrep相当のstubが何も出力しない)
  run_keeper "$ps" "$state" "$notify" "true" || return 1
  grep -q '"kind": "WATCH_MISSING"' "$state/alerts.jsonl" || { echo "WATCH_MISSINGが検知されていない"; return 1; }
  grep -q '"lane": "ALL"' "$state/alerts.jsonl" || { echo "WATCH_MISSINGのlaneがALLでない"; return 1; }
}

test_watch_missing_not_detected_when_no_active_lanes() {
  local ps state notify
  ps="$(new_fixture "$FIX_NO_LANES")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_6.log"
  run_keeper "$ps" "$state" "$notify" "true" || return 1
  if [ -f "$state/alerts.jsonl" ] && [ -s "$state/alerts.jsonl" ]; then
    echo "稼働レーン0なのにWATCH_MISSINGが誤検知された: $(cat "$state/alerts.jsonl")"
    return 1
  fi
  return 0
}

test_watch_missing_not_detected_when_watch_present() {
  local ps state notify
  ps="$(new_fixture "$FIX_GATE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_7.log"
  run_keeper "$ps" "$state" "$notify" "echo 12345" || return 1
  if grep -q '"kind": "WATCH_MISSING"' "$state/alerts.jsonl" 2>/dev/null; then
    echo "watch.sh稼働中なのにWATCH_MISSINGが誤検知された"
    return 1
  fi
  return 0
}

test_seen_dedup_no_renotify_on_second_run() {
  local ps state notify
  ps="$(new_fixture "$FIX_DONE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_8.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  local n
  n="$(count_lines "$notify")"
  [ "$n" -eq 1 ] || { echo "2回実行後の通知回数が1でない: $n"; return 1; }
}

test_idempotent_same_input_twice_alerts_and_notify() {
  local ps state notify
  ps="$(new_fixture "$FIX_ERROR")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_9.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  local alert_lines notify_lines
  alert_lines="$(count_lines "$state/alerts.jsonl")"
  notify_lines="$(count_lines "$notify")"
  [ "$alert_lines" -eq 1 ] || { echo "同一入力2回実行後のalerts行数が1でない: $alert_lines"; return 1; }
  [ "$notify_lines" -eq 1 ] || { echo "同一入力2回実行後の通知回数が1でない: $notify_lines"; return 1; }
}

test_different_lane_after_dedup_still_notifies() {
  local ps1 ps2 state notify
  ps1="$(new_fixture "$FIX_DONE")"
  ps2="$(new_fixture "$FIX_GATE")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_10.log"
  run_keeper "$ps1" "$state" "$notify" "echo 1" || return 1
  run_keeper "$ps2" "$state" "$notify" "echo 1" || return 1
  local n
  n="$(count_lines "$notify")"
  [ "$n" -eq 2 ] || { echo "異なるlane/lineの検知後の通知回数が2でない: $n"; return 1; }
}

test_parse_err_graceful_no_crash_no_alert() {
  local ps state notify rc
  ps="$(new_fixture "$FIX_BAD_JSON")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_11.log"
  run_keeper "$ps" "$state" "$notify" "echo 1"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "不正JSON入力でexit非0: $rc"; return 1; }
  if [ -f "$state/alerts.jsonl" ] && [ -s "$state/alerts.jsonl" ]; then
    echo "不正JSON入力なのにalertsが書かれた"
    return 1
  fi
  [ -f "$notify" ] && { echo "不正JSON入力なのに通知が呼ばれた"; return 1; }
  return 0
}

test_autopilot_off_by_default_no_invoke() {
  local ps state notify autolog
  ps="$(new_fixture "$FIX_ERROR")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_12.log"
  autolog="$TEST_ROOT/autopilot_$$_12.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" "0" "$autolog" || return 1
  [ -f "$autolog" ] && { echo "KEEPER_AUTOPILOT=0なのにautopilotが起動された"; return 1; }
  return 0
}

test_autopilot_on_invokes_stub_for_new_detection() {
  local ps state notify autolog
  ps="$(new_fixture "$FIX_ERROR")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_13.log"
  autolog="$TEST_ROOT/autopilot_$$_13.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" "1" "$autolog" || return 1
  [ -f "$autolog" ] || { echo "KEEPER_AUTOPILOT=1なのにautopilotが起動されなかった"; return 1; }
  grep -qF "err-lane|AGENT_ERROR" "$autolog" || { echo "autopilot呼び出し引数が想定と異なる: $(cat "$autolog" 2>/dev/null)"; return 1; }
}

test_autopilot_not_reinvoked_on_dedup() {
  local ps state notify autolog
  ps="$(new_fixture "$FIX_ERROR")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_14.log"
  autolog="$TEST_ROOT/autopilot_$$_14.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" "1" "$autolog" || return 1
  run_keeper "$ps" "$state" "$notify" "echo 1" "1" "$autolog" || return 1
  local n
  n="$(count_lines "$autolog")"
  [ "$n" -eq 1 ] || { echo "既知の検知でautopilotが再起動された回数: $n"; return 1; }
}

test_multiple_kinds_in_one_run_both_recorded() {
  local body ps state notify
  body='{"result":{"worktrees":[{"path":"/fake/wt/multi-lane","displayName":"multi","branch":"refs/heads/m","status":"in-progress","agents":[{"agentType":"claude","state":"crashed","lastAssistantMessage":"エラー発生"},{"agentType":"codex","state":"working","lastAssistantMessage":"完了。\nMULTI_DONE"}]}]}}'
  ps="$(new_fixture "$body")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_15.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "AGENT_ERROR"' "$state/alerts.jsonl" || { echo "同一レーン内のAGENT_ERRORが検知されていない"; return 1; }
  grep -q '"kind": "DONE_MARKER"' "$state/alerts.jsonl" || { echo "同一レーン内のDONE_MARKERが検知されていない"; return 1; }
  local n
  n="$(count_lines "$notify")"
  [ "$n" -eq 2 ] || { echo "1レーン2種検知の通知回数が2でない: $n"; return 1; }
}

# 差し戻し1回目回帰1: 「|」と「/」だけが違う2行は別物として扱われ、両方通知される
# （旧sanitize()はどちらも"/"へ潰していたため、2件目がseen.txtで誤って抑止されていた）。
# 併せてalerts.jsonlに原文（"|"を含む行・"/"を含む行それぞれ）が変換されずに保たれることも検証する。
test_pipe_vs_slash_lines_both_notify_and_preserve_raw() {
  local ps state notify n line1 line2
  ps="$(new_fixture "$FIX_PIPE_VS_SLASH")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_16.log"
  run_keeper "$ps" "$state" "$notify" "echo 1" || return 1

  n="$(count_lines "$notify")"
  [ "$n" -eq 2 ] || { echo "「|」/「/」違いの2行での通知回数が2でない(=衝突により抑止された可能性): $n"; return 1; }

  n="$(count_lines "$state/alerts.jsonl")"
  [ "$n" -eq 2 ] || { echo "「|」/「/」違いの2行でのalerts行数が2でない: $n"; return 1; }

  line1="$(json_line_field "$state/alerts.jsonl" 1)"
  line2="$(json_line_field "$state/alerts.jsonl" 2)"
  if [ "$line1" = "$line2" ]; then
    echo "alerts.jsonlの2行が同一内容に潰れている(旧sanitize()の再発): [$line1]"
    return 1
  fi
  case "$line1$line2" in
    *'設定ファイル a|b が壊れています'*) ;;
    *) echo "「|」を含む原文が見つからない: line1=[$line1] line2=[$line2]"; return 1 ;;
  esac
  case "$line1$line2" in
    *'設定ファイル a/b が壊れています'*) ;;
    *) echo "「/」を含む原文が見つからない: line1=[$line1] line2=[$line2]"; return 1 ;;
  esac
}

# 差し戻し1回目回帰2: 引用符/バッククォート/$/パイプを含む行でも通知コマンド(stub呼び出し)が壊れず、
# alerts.jsonl・通知本文の両方に原文がそのまま(無変換で)渡ること。
test_special_chars_do_not_break_notify_and_preserve_raw() {
  local ps state notify rc expected got_alert_line got_notify_body
  expected='エラー: `whoami` と $HOME と "quoted" と a|b'
  ps="$(new_fixture "$FIX_SPECIAL_CHARS")"
  state="$(new_state_dir)"
  notify="$TEST_ROOT/notify_$$_17.log"
  run_keeper "$ps" "$state" "$notify" "echo 1"
  rc=$?
  [ "$rc" -eq 0 ] || { echo "記号入り行でkeeper.shが非0終了(exit=$rc)"; return 1; }
  [ -f "$notify" ] || { echo "記号入り行で通知stubが呼ばれていない"; return 1; }

  got_alert_line="$(json_line_field "$state/alerts.jsonl" 1)"
  [ "$got_alert_line" = "$expected" ] || {
    echo "alerts.jsonlのlineが原文と不一致: got=[$got_alert_line] want=[$expected]"
    return 1
  }

  got_notify_body="$(cut -f2 "$notify")"
  [ "$got_notify_body" = "AGENT_ERROR: $expected" ] || {
    echo "通知本文が原文と不一致: got=[$got_notify_body] want=[AGENT_ERROR: $expected]"
    return 1
  }
}

# --- レーン停滞検知(子06フェーズ2)用fixture・非workingのagent（マーカー/errorでない=停滞のみを分離） ---
FIX_STALL='{"result":{"worktrees":[{"path":"/fake/wt/stall-lane","displayName":"stall","branch":"refs/heads/st","status":"idle","agents":[{"agentType":"claude","state":"done","lastAssistantMessage":"待機しています"}]}]}}'
FIX_STALL_WORKING='{"result":{"worktrees":[{"path":"/fake/wt/stall-lane","displayName":"stall","branch":"refs/heads/st","status":"working","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"作業中です"}]}]}}'

# 停滞: 閾値未満(dur<STALL_SECONDS)ではSTALL検知しない。
test_stall_not_before_threshold() {
  local ps state notify
  ps="$(new_fixture "$FIX_STALL")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_st1.log"
  KEEPER_NOW=1000 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "STALL"' "$state/alerts.jsonl"; then
    echo "閾値未満なのにSTALL検知した: $(cat "$state/alerts.jsonl")"; return 1
  fi
  return 0
}

# 停滞: 停滞開始をseed→閾値超の次tickでSTALL検知（lane=stall-lane）。
test_stall_fires_after_threshold() {
  local ps state notify
  ps="$(new_fixture "$FIX_STALL")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_st2.log"
  KEEPER_NOW=1000 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  KEEPER_NOW=1700 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "STALL"' "$state/alerts.jsonl" || { echo "閾値超でSTALLが検知されない"; return 1; }
  grep -q '"lane": "stall-lane"' "$state/alerts.jsonl" || { echo "STALLのlaneがstall-laneでない"; return 1; }
}

# 停滞: working復帰でタイマーがクリアされ、再停滞は新エピソード（直後は閾値未満で誤検知しない）。
test_stall_resume_clears_timer() {
  local ps ps_w state notify
  ps="$(new_fixture "$FIX_STALL")"; ps_w="$(new_fixture "$FIX_STALL_WORKING")"
  state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_st3.log"
  KEEPER_NOW=1000 KEEPER_STALL_SECONDS=600 run_keeper "$ps"   "$state" "$notify" "echo 1" || return 1
  KEEPER_NOW=1300 KEEPER_STALL_SECONDS=600 run_keeper "$ps_w" "$state" "$notify" "echo 1" || return 1
  KEEPER_NOW=1400 KEEPER_STALL_SECONDS=600 run_keeper "$ps"   "$state" "$notify" "echo 1" || return 1
  if grep -q '"kind": "STALL"' "$state/alerts.jsonl" 2>/dev/null; then
    echo "working復帰でクリアされず誤検知した: $(cat "$state/alerts.jsonl")"; return 1
  fi
  return 0
}

# 停滞: 一度検知したエピソードは（停滞開始が同じ＝seenキー安定で）毎tick再通知しない。
test_stall_seen_no_refire() {
  local ps state notify n
  ps="$(new_fixture "$FIX_STALL")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_st4.log"
  KEEPER_NOW=1000 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  KEEPER_NOW=1700 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  KEEPER_NOW=1760 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  n="$(count_lines "$notify")"
  [ "$n" -eq 1 ] || { echo "停滞の再通知が起きた(通知回数): $n"; return 1; }
}

# --- 出所なしレーン検知(子06フェーズ2・裁定1=events.jsonl結合キー)用fixture ---
# Focusmap型: 非main・agent稼働中・マーカー/errorでない（出所なしのみを分離）。
FIX_NO_ORIGIN='{"result":{"worktrees":[{"path":"/fake/wt/focusmap","isMainWorktree":false,"displayName":"focusmap","branch":"refs/heads/f","status":"working","agents":[{"agentType":"codex","state":"working","lastAssistantMessage":"作業中"}]}]}}'
# 司令部main worktree: is_main=true（出所なし対象外）。
FIX_MAIN_NO_ORIGIN='{"result":{"worktrees":[{"path":"/fake/wt/main","isMainWorktree":true,"displayName":"main","branch":"refs/heads/main","status":"working","agents":[{"agentType":"claude","state":"working","lastAssistantMessage":"作業中"}]}]}}'

# events.jsonl にup/send記録が無い（＝出所なし）→ NO_ORIGIN検知（Focusmap実例の再現）。
test_no_origin_detected_when_no_events() {
  local ps state notify events
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_no1.log"
  events="$TEST_ROOT/events_$$_no1.jsonl"; : > "$events"   # 空events=出所なし
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl" || { echo "events無しなのにNO_ORIGIN未検知"; return 1; }
  grep -q '"lane": "focusmap"' "$state/alerts.jsonl" || { echo "NO_ORIGINのlaneがfocusmapでない"; return 1; }
}

# events.jsonl に当該worktreeのupイベントがある → NO_ORIGIN検知しない。
test_no_origin_not_detected_when_up_event_exists() {
  local ps state notify events
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_no2.log"
  events="$TEST_ROOT/events_$$_no2.jsonl"
  printf '%s\n' '{"ts":"2026-07-03T00:00:00Z","repo":"R","branch":"f","worktree":"/fake/wt/focusmap","terminal":null,"event":"up","stage":null,"owner":null}' > "$events"
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl"; then
    echo "up記録があるのにNO_ORIGIN誤検知した: $(cat "$state/alerts.jsonl")"; return 1
  fi
  return 0
}

# 司令部main worktree（is_main）は出所なし対象外（up記録が無くても検知しない）。
test_no_origin_main_worktree_not_flagged() {
  local ps state notify events
  ps="$(new_fixture "$FIX_MAIN_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_no3.log"
  events="$TEST_ROOT/events_$$_no3.jsonl"; : > "$events"
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl"; then
    echo "main worktreeがNO_ORIGINに誤検知された"; return 1
  fi
  return 0
}

# レビュー差し戻し1回帰: events.jsonlが存在するが読めない(read失敗)時は、空集合として全レーンを
# 誤検知せず、NO_ORIGIN判定自体をスキップする(保守側・誤WAKEしない)。
test_no_origin_skipped_when_events_unreadable() {
  [ "$(id -u)" = "0" ] && { echo "root環境のためskip(chmod000が効かない)"; return 0; }
  local ps state notify events
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_no5.log"
  events="$TEST_ROOT/events_$$_no5.jsonl"
  printf '%s\n' '{"event":"send","worktree":"/other/wt"}' > "$events"; chmod 000 "$events"
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1"; local rc=$?
  chmod 644 "$events" 2>/dev/null || true
  [ "$rc" -eq 0 ] || { echo "read失敗fixtureでkeeperが非0終了: $rc"; return 1; }
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl"; then
    echo "events読取失敗なのにNO_ORIGIN誤検知した(保守側スキップが効いていない)"; return 1
  fi
  return 0
}

# 一度検知した出所なしレーンは（lane/line安定で）2回目以降再通知しない。
test_no_origin_seen_no_refire() {
  local ps state notify events n
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_no4.log"
  events="$TEST_ROOT/events_$$_no4.jsonl"; : > "$events"
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  COCKPIT_EVENTS_FILE="$events" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  n="$(count_lines "$notify")"
  [ "$n" -eq 1 ] || { echo "NO_ORIGINが再通知された(通知回数): $n"; return 1; }
}

# --- ペイン台帳(panes.jsonl・子06フェーズ2b・采配9玉A)用テスト ---

# events由来originは無いが、panes.jsonl台帳に当該worktreeがある(spawn起動)→ NO_ORIGIN検知しない。
test_no_origin_not_detected_when_in_panes() {
  local ps state notify events panes
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_pa1.log"
  events="$TEST_ROOT/events_$$_pa1.jsonl"; : > "$events"   # events空=events由来originなし
  panes="$TEST_ROOT/panes_$$_pa1.jsonl"
  printf '%s\n' '{"ts":"2026-07-03T00:00:00Z","handle":"term_x","worktree":"/fake/wt/focusmap","role":"impl","owner":"中間指揮官9","model":"claude-sonnet-5","prompt":"/p"}' > "$panes"
  COCKPIT_EVENTS_FILE="$events" COCKPIT_PANES_FILE="$panes" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl"; then
    echo "台帳(panes)にあるspawnレーンがNO_ORIGIN誤検知された: $(cat "$state/alerts.jsonl")"; return 1
  fi
  return 0
}

# レビュー差し戻し回帰: panes.jsonlの壊れた行(不正JSON/非文字列worktree)の後に有効な台帳行があっても、
# 有効行を落とさずoriginへ合流する(best-effortのper-line skip)。旧実装は壊れた行で全体中断していた。
test_no_origin_panes_best_effort_skips_bad_line() {
  local ps state notify events panes
  ps="$(new_fixture "$FIX_NO_ORIGIN")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_pa3.log"
  events="$TEST_ROOT/events_$$_pa3.jsonl"; : > "$events"
  panes="$TEST_ROOT/panes_$$_pa3.jsonl"
  { printf '%s\n' 'これはJSONではない'
    printf '%s\n' '{"worktree": 12345, "owner": 999}'
    printf '%s\n' '{"ts":"t","handle":"h","worktree":"/fake/wt/focusmap","role":"impl","owner":"中間指揮官9","model":"m","prompt":"/p"}'
  } > "$panes"
  COCKPIT_EVENTS_FILE="$events" COCKPIT_PANES_FILE="$panes" run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  if [ -f "$state/alerts.jsonl" ] && grep -q '"kind": "NO_ORIGIN"' "$state/alerts.jsonl"; then
    echo "壊れた行の後の有効台帳行が失われfocusmapが誤NO_ORIGINになった: $(cat "$state/alerts.jsonl")"; return 1
  fi
  return 0
}

# 停滞レーンが台帳(panes.jsonl)にあれば、STALLのWAKE行に owner が付く（どの指揮官のレーンか）。
test_stall_line_includes_panes_owner() {
  local ps state notify panes
  ps="$(new_fixture "$FIX_STALL")"; state="$(new_state_dir)"; notify="$TEST_ROOT/notify_$$_pa2.log"
  panes="$TEST_ROOT/panes_$$_pa2.jsonl"
  printf '%s\n' '{"ts":"2026-07-03T00:00:00Z","handle":"term_y","worktree":"/fake/wt/stall-lane","role":"impl","owner":"中間指揮官9","model":"m","prompt":"/p"}' > "$panes"
  COCKPIT_PANES_FILE="$panes" KEEPER_NOW=1000 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  COCKPIT_PANES_FILE="$panes" KEEPER_NOW=1700 KEEPER_STALL_SECONDS=600 run_keeper "$ps" "$state" "$notify" "echo 1" || return 1
  grep -q '"kind": "STALL"' "$state/alerts.jsonl" || { echo "STALL未検知"; return 1; }
  grep -qF "台帳owner:中間指揮官9" "$state/alerts.jsonl" || { echo "STALL行に台帳ownerが付いていない: $(cat "$state/alerts.jsonl")"; return 1; }
}

# --- 実行 ---

run_test test_done_marker_detected_and_notified
run_test test_review_pass_marker_detected
run_test test_human_gate_detected
run_test test_agent_error_state_detected
run_test test_watch_missing_detected_when_lane_active
run_test test_watch_missing_not_detected_when_no_active_lanes
run_test test_watch_missing_not_detected_when_watch_present
run_test test_seen_dedup_no_renotify_on_second_run
run_test test_idempotent_same_input_twice_alerts_and_notify
run_test test_different_lane_after_dedup_still_notifies
run_test test_parse_err_graceful_no_crash_no_alert
run_test test_autopilot_off_by_default_no_invoke
run_test test_autopilot_on_invokes_stub_for_new_detection
run_test test_autopilot_not_reinvoked_on_dedup
run_test test_multiple_kinds_in_one_run_both_recorded
run_test test_pipe_vs_slash_lines_both_notify_and_preserve_raw
run_test test_special_chars_do_not_break_notify_and_preserve_raw
run_test test_stall_not_before_threshold
run_test test_stall_fires_after_threshold
run_test test_stall_resume_clears_timer
run_test test_stall_seen_no_refire
run_test test_no_origin_detected_when_no_events
run_test test_no_origin_not_detected_when_up_event_exists
run_test test_no_origin_main_worktree_not_flagged
run_test test_no_origin_skipped_when_events_unreadable
run_test test_no_origin_seen_no_refire
run_test test_no_origin_not_detected_when_in_panes
run_test test_no_origin_panes_best_effort_skips_bad_line
run_test test_stall_line_includes_panes_owner

echo "=================================="
echo "PASS: $pass_count / $((pass_count + fail_count))"
if [ "$fail_count" -gt 0 ]; then
  echo "FAILED: ${fail_names[*]}"
  exit 1
fi
exit 0
