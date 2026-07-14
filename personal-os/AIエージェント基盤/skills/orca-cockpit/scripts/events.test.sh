#!/usr/bin/env bash
# orca-cockpit / cockpit.sh の段階イベント記録（_log_event / cmd_send --stage / cmd_down）のテスト。
# 実orca CLIは叩かない: orcaをシェル関数でスタブしてからcockpit.shをsourceする
# （sourceすると末尾のmain "$@"が走るため、helpサブコマンドを明示して無害化する）。
# 実デイリー・実HOME配下には一切書き込まない（COCKPIT_EVENTS_FILEは全テストでmktemp配下に上書き）。
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COCKPIT_SH="$HERE/cockpit.sh"

pass=0
fail=0

assert_eq(){ # <label> <actual> <expected>
  if [ "$2" = "$3" ]; then
    pass=$((pass+1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail+1)); printf '[FAIL] %s: expected [%s] got [%s]\n' "$1" "$3" "$2"
  fi
}

assert_contains(){ # <label> <haystack> <needle>
  if printf '%s' "$2" | grep -qF "$3"; then
    pass=$((pass+1)); printf '[PASS] %s\n' "$1"
  else
    fail=$((fail+1)); printf '[FAIL] %s: expected to contain [%s]\n  got: %s\n' "$1" "$3" "$2"
  fi
}

# orca CLIのスタブ（シェル関数）。need()のcommand -vはシェル関数も検出するため実CLI不要。
STUB_SEND_FAIL=0
STUB_RM_FAIL=0
orca() {
  case "$1 $2" in
    "terminal send") [ "$STUB_SEND_FAIL" = "1" ] && return 1; return 0 ;;
    "terminal stop") return 0 ;;
    "worktree rm")   [ "$STUB_RM_FAIL" = "1" ] && return 1; printf '{"ok":true}'; return 0 ;;
    *) return 0 ;;
  esac
}

# cockpit.sh をsource（末尾main "$@"はhelpサブコマンドを明示して無害化・出力は捨てる）。
# これでcmd_send/cmd_down/_log_event等の関数がこのシェルに定義される。
source "$COCKPIT_SH" help >/dev/null 2>&1

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/cockpit-events-test.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

json_get() { # <file> <line-number(1-based)> <key>  … pythonでJSONL1行の1フィールドを取り出す
  python3 -c "
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    lines = [l for l in f if l.strip()]
line = json.loads(lines[int(sys.argv[2]) - 1])
v = line.get(sys.argv[3])
print('' if v is None else v)
" "$1" "$2" "$3"
}

# ============================================================
# (a) _log_event: 1行=妥当なJSON。event=up・stage/terminalはnullで記録される。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/a-events.jsonl"
_log_event up "RepoX" "branchX" "/fake/wt-a" "" ""
out="$(json_get "$COCKPIT_EVENTS_FILE" 1 event)"
assert_eq "(a) event=up" "$out" "up"
assert_eq "(a) repo記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 repo)" "RepoX"
assert_eq "(a) branch記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 branch)" "branchX"
assert_eq "(a) worktree記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 worktree)" "/fake/wt-a"
assert_eq "(a) terminalはnull" "$(json_get "$COCKPIT_EVENTS_FILE" 1 terminal)" ""
assert_eq "(a) stageはnull" "$(json_get "$COCKPIT_EVENTS_FILE" 1 stage)" ""
# owner(先行部品①)は第7引数。6引数の既存呼び出しではnull（後方互換）。
assert_eq "(a) owner無指定はnull(後方互換)" "$(json_get "$COCKPIT_EVENTS_FILE" 1 owner)" ""
ts="$(json_get "$COCKPIT_EVENTS_FILE" 1 ts)"
case "$ts" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z) pass=$((pass+1)); printf '[PASS] %s\n' "(a) ts形式" ;;
  *) fail=$((fail+1)); printf '[FAIL] %s: ts=%s\n' "(a) ts形式" "$ts" ;;
esac

# ============================================================
# (b) cmd_send --stage無し: stage=null・terminal/promptは記録される。本文推測はしない。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/b-events.jsonl"
cmd_send --terminal "term-1" --prompt "実装して" >/dev/null
assert_eq "(b) event=send" "$(json_get "$COCKPIT_EVENTS_FILE" 1 event)" "send"
assert_eq "(b) terminal記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 terminal)" "term-1"
assert_eq "(b) --stage無しはnull" "$(json_get "$COCKPIT_EVENTS_FILE" 1 stage)" ""

# ============================================================
# (c) cmd_send --stage付き: 呼び出し元が明示した文字列がそのまま記録される（語彙検証なし）。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/c-events.jsonl"
cmd_send --terminal "term-2" --prompt "レビューして" --stage "実装レビュー" --worktree "/fake/wt-c" --repo "RepoC" --branch "branchC" >/dev/null
assert_eq "(c) stage記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 stage)" "実装レビュー"
assert_eq "(c) worktree記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 worktree)" "/fake/wt-c"
# GLOBAL_AGENTS.md §7の語彙に無い任意文字列でも検証せずそのまま記録される（機構は判断しない）ことの確認。
cmd_send --terminal "term-2" --prompt "x" --stage "でたらめな段階名" >/dev/null
assert_eq "(c) 未知の語彙も無検証でそのまま記録" "$(json_get "$COCKPIT_EVENTS_FILE" 2 stage)" "でたらめな段階名"

# ============================================================
# (c2) owner(先行部品①): --owner指定はそのまま記録・無指定はnull。stageとowner両立も確認。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/c2-events.jsonl"
cmd_send --terminal "term-o" --prompt "x" --stage "実装" --owner "中間指揮官1" >/dev/null
assert_eq "(c2) owner記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 owner)" "中間指揮官1"
assert_eq "(c2) stageとowner両立" "$(json_get "$COCKPIT_EVENTS_FILE" 1 stage)" "実装"
cmd_send --terminal "term-o" --prompt "y" --stage "実装" >/dev/null
assert_eq "(c2) --owner無指定はnull" "$(json_get "$COCKPIT_EVENTS_FILE" 2 owner)" ""
# _log_event直呼びの7引数（up）でもownerが載る。
COCKPIT_EVENTS_FILE="$WORKDIR/c2b-events.jsonl"
_log_event up "RepoO" "branchO" "/fake/wt-o" "" "" "全体管理者"
assert_eq "(c2b) up直呼びowner記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 owner)" "全体管理者"

# ============================================================
# (d) cmd_down: event=downで記録される（--worktree指定時）。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/d-events.jsonl"
cmd_down --worktree "/fake/wt-d" >/dev/null
assert_eq "(d) event=down" "$(json_get "$COCKPIT_EVENTS_FILE" 1 event)" "down"
assert_eq "(d) worktree記録" "$(json_get "$COCKPIT_EVENTS_FILE" 1 worktree)" "/fake/wt-d"

# ============================================================
# (e) 追記の冪等性: 複数回の追記で行が増えるだけ・既存行の内容は変化しない（追記のみ・全置換しない）。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/e-events.jsonl"
cmd_send --terminal "t" --prompt "1回目" --stage "計画" >/dev/null
line1_before="$(sed -n '1p' "$COCKPIT_EVENTS_FILE")"
cmd_send --terminal "t" --prompt "2回目" --stage "実装" >/dev/null
cmd_send --terminal "t" --prompt "3回目" --stage "実装レビュー" >/dev/null
line1_after="$(sed -n '1p' "$COCKPIT_EVENTS_FILE")"
line_count="$(grep -c . "$COCKPIT_EVENTS_FILE")"
assert_eq "(e) 3回追記で3行" "$line_count" "3"
assert_eq "(e) 既存行は不変(追記のみ)" "$line1_after" "$line1_before"
assert_eq "(e) 3行目の段階" "$(json_get "$COCKPIT_EVENTS_FILE" 3 stage)" "実装レビュー"

# ============================================================
# (f) 送信失敗時はイベントを記録しない（成功パスのみ記録）。
# ============================================================
COCKPIT_EVENTS_FILE="$WORKDIR/f-events.jsonl"
STUB_SEND_FAIL=1
cmd_send --terminal "t" --prompt "失敗するはず" --stage "実装" >/dev/null 2>&1
STUB_SEND_FAIL=0
if [ -f "$COCKPIT_EVENTS_FILE" ] && [ -s "$COCKPIT_EVENTS_FILE" ]; then
  fail=$((fail+1)); printf '[FAIL] %s: 送信失敗なのにイベントが記録された\n' "(f) 送信失敗時は非記録"
else
  pass=$((pass+1)); printf '[PASS] %s\n' "(f) 送信失敗時は非記録"
fi

# ============================================================
# (g) 既定パス: 環境変数未指定時、COCKPIT_EVENTS_FILEはこのrepo内
# skills/orca-cockpit/state/events.jsonl を指す（実書き込みはしない・値の検証のみ）。
# ============================================================
expected_default="$(cd "$HERE/.." && pwd)/state/events.jsonl"
(
  unset COCKPIT_EVENTS_FILE
  source "$COCKPIT_SH" help >/dev/null 2>&1
  # COCKPIT_EVENTS_FILEは "$SCRIPT_DIR/../state/events.jsonl" の文字列のまま（未canonicalize）。
  # stateディレクトリが未作成でもcd不要でパス正規化できるようnormpathで比較する
  # （ファイル・ディレクトリの実在は前提にしない）。
  resolved="$(python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$COCKPIT_EVENTS_FILE")"
  [ "$resolved" = "$expected_default" ]
)
if [ $? -eq 0 ]; then
  pass=$((pass+1)); printf '[PASS] %s\n' "(g) 既定パスがrepo内state/events.jsonlを指す"
else
  fail=$((fail+1)); printf '[FAIL] %s: expected [%s]\n' "(g) 既定パスがrepo内state/events.jsonlを指す" "$expected_default"
fi

printf '\n合計: %d pass / %d fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
