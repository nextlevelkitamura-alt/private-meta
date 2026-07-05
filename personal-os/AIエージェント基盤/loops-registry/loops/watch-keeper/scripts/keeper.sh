#!/usr/bin/env bash
# watch-keeper / keeper.sh — launchdから5分毎に起動される純bashワンショット判定。
# `orca worktree ps --json` を1回読み、agent持ちworktree(=cockpitレーン)について次を検知する:
#   (a) いずれかのagentのlastAssistantMessage最終行が、完了/レビューマーカー(_DONE系・REVIEW_RESULT:)
#       または人間確認待ちゲート(段階:...人間確認待ち)にfullmatch
#       （判定正規表現は ../../../skills/orca-cockpit/scripts/watch.sh の DONE_RE / is_gate を正本とし、
#       同一ロジックをここに転用する。watch.shは複製しない＝ロジックのみ同一に保つ）
#   (b) いずれかのagentのstateがerror/failed/crashed
#   (c) 稼働レーン(agent持ちworktree)が1本以上あるのにwatch.shプロセスが0本(pgrep -f watch.sh)
#   (d) レーン(agent持ちworktree)がworkingを1体も持たない(idle/waiting)状態でKEEPER_STALL_SECONDS
#       (既定600=10分)超継続(子06フェーズ2・裁定10分)。継続はstate/stall-since.tsvで追跡・時刻は
#       KEEPER_NOW(既定 date +%s)で注入可能。working復帰でタイマークリア。
#   (e) アクティブagentレーン(非main)のうちevents.jsonl(COCKPIT_EVENTS_FILE)にup/send記録が無いもの
#       =出所なしレーン(cockpit経由でない直起動・子06フェーズ2・裁定1)。events.jsonl無い時はスキップ。
# フェーズ2b(采配9玉A): ペイン台帳panes.jsonl(COCKPIT_PANES_FILE)を読み、(e)のoriginへ台帳のworktreeを
#   合流(spawn起動レーンを出所ありに)＋(d)の停滞WAKEに台帳のownerを付す(どの指揮官のレーンか)。
# 検知したらmacOS通知(osascript display notification)とstate/alerts.jsonlへ1行追記(ts/lane/kind/line)。
# 同じ(lane,最終行)はstate/seen.txtに完全一致で記録し再通知しない。
# ワンショット監督起動(claude -p)はKEEPER_AUTOPILOT=1の時のみ（既定OFF=通知のみ）。
# 判断はしない（grepと状態突合・watch.shのpoll/優先度は持たない一発判定）。
# 実行時間の実測はloop.md参照。
#
# 差し戻し1回目対応（内容非破壊の転送）: 検知したlane/lineの原文は一切変換しない。python判定→bashの
# 内部受け渡しは、値そのものを"|"等の区切り文字で結合せず base64 でエンコードして運ぶ（区切り文字と
# 衝突しうる文字を潰す旧sanitize()は廃止）。bash側でも lane/kind/line は常に別々の配列（parallel array）
# に保持し、1本の文字列へ再結合してから再分割することはしない。seen.txtのキーもpython3 json.dumps([lane,line])
# による曖昧さの無い表現を使う（"lane|line"のような単純結合は、lane/lineどちらかに区切り文字が
# 含まれると衝突しうるため使わない）。通知(osascript)・alerts.jsonl(json.dumps)は元々argv経由で
# 値を渡していたため元来この問題の影響を受けない。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# unquoted展開＝複数語コマンドの差替を許す（watch.shのWATCH_PS_CMD/WATCH_TERMS_CMDと同じ方式）。
KEEPER_PS_CMD="${KEEPER_PS_CMD:-orca worktree ps --json}"
KEEPER_PGREP_CMD="${KEEPER_PGREP_CMD:-pgrep -f watch.sh}"
STATE_DIR="${KEEPER_STATE_DIR:-$LOOP_DIR/state}"
AUTOPILOT="${KEEPER_AUTOPILOT:-0}"

log(){ printf '[keeper] %s\n' "$*" >&2; }

mkdir -p "$STATE_DIR" 2>/dev/null || { log "state dir作成に失敗: $STATE_DIR"; exit 1; }
ALERTS_FILE="$STATE_DIR/alerts.jsonl"
SEEN_FILE="$STATE_DIR/seen.txt"
touch "$ALERTS_FILE" "$SEEN_FILE" 2>/dev/null || { log "state file作成に失敗: $STATE_DIR"; exit 1; }

# ==== 判定（stdin=`orca worktree ps --json`相当）====
# DONE_RE / is_gate は orca-cockpit/scripts/watch.sh の PY_JUDGE と同一ロジック。
# 出力: 1行目 "LANES <稼働レーン数>"、以降 "DETECT <kind> <base64(lane)> <base64(line)>" を0件以上
# （空白区切り。lane/lineはbase64のため空白・改行・区切り文字を一切含まず、原文を無変換で運べる）。
# パース失敗/非objectは "PARSE_ERR" の1行のみ。
KEEPER_JUDGE=$(cat <<'PYEOF'
import sys, json, os, re, base64

DONE_RE = re.compile(r'[A-Z][A-Z0-9_]*_DONE|REVIEW_RESULT: (?:PASS|FAIL)')

def b64(text):
    return base64.b64encode((text or "").encode("utf-8")).decode("ascii")

def last_line(msg):
    ls = (msg or "").rstrip().splitlines()
    return (ls[-1] if ls else "").strip()

def is_gate(line):
    return line.startswith("段階:") and "人間確認待ち" in line and len(line) <= 30

def is_done(line):
    return bool(DONE_RE.fullmatch(line))

try:
    d = json.load(sys.stdin)
    if not isinstance(d, dict):
        raise ValueError("not an object")
except Exception:
    print("PARSE_ERR")
    sys.exit(0)

worktrees = ((d.get('result') or {}).get('worktrees')) or []
lane_count = 0
rows = []
lane_states = []
for w in worktrees:
    if not isinstance(w, dict):
        continue
    path = w.get('path') or ''
    if not path:
        continue
    agents = [a for a in (w.get('agents') or []) if isinstance(a, dict) and a.get('agentType')]
    if not agents:
        continue
    lane_count += 1
    lane = os.path.basename(path.rstrip('/')) or path
    working = 1 if any((a.get('state') or '').strip() == 'working' for a in agents) else 0
    is_main = 1 if w.get('isMainWorktree') else 0
    lane_states.append((path, lane, working, is_main))
    for a in agents:
        line = last_line(a.get('lastAssistantMessage'))
        state = (a.get('state') or '').strip()
        if is_done(line):
            rows.append((lane, 'DONE_MARKER', line))
        if is_gate(line):
            rows.append((lane, 'HUMAN_GATE', line))
        if state in ('error', 'failed', 'crashed'):
            rows.append((lane, 'AGENT_ERROR', line or ('state:' + state)))

print('LANES %d' % lane_count)
for lane, kind, line in rows:
    print('DETECT %s %s %s' % (kind, b64(lane), b64(line)))
# レーン停滞/出所なし検知(子06フェーズ2)用: agent持ちレーンごとに working=1/0・is_main=1/0 を出す
# (pathがstate追跡/events突合キー。is_main=司令部main worktree=出所なし検知の対象外)。
for path, lane, working, is_main in lane_states:
    print('LANE %s %s %d %d' % (b64(path), b64(lane), working, is_main))
PYEOF
)

PS_OUT="$($KEEPER_PS_CMD 2>/dev/null)"
if [ -z "$PS_OUT" ]; then
  log "orca ps 出力が空・orca不在の可能性のためスキップ"
  exit 0
fi

JUDGE_OUT="$(printf '%s' "$PS_OUT" | python3 -c "$KEEPER_JUDGE")"
if [ -z "$JUDGE_OUT" ] || [ "$JUDGE_OUT" = "PARSE_ERR" ]; then
  log "PARSE_ERR: ps結果を読めず・今回はスキップ"
  exit 0
fi

# base64文字列(引数1個)を原文に戻す。python3固定（base64 CLIのdecodeフラグはGNU/BSDで揺れがあるため使わない）。
b64decode() {
  python3 -c 'import sys, base64
sys.stdout.write(base64.b64decode(sys.argv[1]).decode("utf-8"))' "$1"
}

LANE_COUNT=0
DET_LANE=()
DET_KIND=()
DET_LINE=()
LANE_PATHB=()   # レーンpath(base64)=停滞追跡/events突合キー
LANE_LANEB=()   # レーン表示名(base64)
LANE_WORKING=() # 1=workingのagentあり / 0=非working(idle/waiting)
LANE_ISMAIN=()  # 1=司令部main worktree（出所なし検知の対象外）
while IFS=' ' read -r tag f1 f2 f3 f4; do
  [ -z "${tag:-}" ] && continue
  case "$tag" in
    LANES) LANE_COUNT="$f1" ;;
    DETECT)
      DET_KIND+=("$f1")
      DET_LANE+=("$(b64decode "$f2")")
      DET_LINE+=("$(b64decode "$f3")")
      ;;
    LANE)
      LANE_PATHB+=("$f1")
      LANE_LANEB+=("$f2")
      LANE_WORKING+=("$f3")
      LANE_ISMAIN+=("${f4:-0}")
      ;;
  esac
done <<< "$JUDGE_OUT"

# 優先度(c): 稼働レーンが1本以上あるのにwatch.shプロセスが0本
# （bash側で直接組み立てる合成検知。python判定を経由しないためbase64往復は不要）
WATCH_COUNT="$($KEEPER_PGREP_CMD 2>/dev/null | grep -c . 2>/dev/null)"
WATCH_COUNT="${WATCH_COUNT:-0}"
if [ "$LANE_COUNT" -ge 1 ] && [ "$WATCH_COUNT" -eq 0 ]; then
  DET_KIND+=("WATCH_MISSING")
  DET_LANE+=("ALL")
  DET_LINE+=("稼働レーン${LANE_COUNT}本・watch.shプロセス0本")
fi

# ==== ペイン台帳(panes.jsonl)読み（子06フェーズ2b・采配9玉A）====
# spawn(cockpit.sh)が書く台帳 state/panes.jsonl から worktree→owner を得て、(1)出所なし検知のoriginに
# 台帳のworktreeを合流（spawn起動レーンを出所ありにする） (2)停滞検知のWAKEに owner を付す（どの指揮官の
# レーンか）。handle列はspawn書式が不安定(dict-repr/plain混在)のため使わず、一貫する worktree/owner のみ使う。
# 読取失敗は空台帳扱い＝events由来の検知は維持（保守側で機能低下のみ・新規誤検知はしない）。
PANES_FILE="${COCKPIT_PANES_FILE:-$SCRIPT_DIR/../../../../skills/orca-cockpit/state/panes.jsonl}"
PANES_MAP=""   # 各行 "b64(worktree)\tb64(owner/role)"
if [ -f "$PANES_FILE" ]; then
  PANES_MAP="$(python3 - "$PANES_FILE" 2>/dev/null <<'PY' || true
import sys, json, base64
def b64(t): return base64.b64encode((t or '').encode('utf-8')).decode('ascii')
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        for raw in f:
            # 1行ずつ全処理をtryで囲む＝壊れた行(不正JSON・非文字列フィールド)で以降の有効行を落とさない
            # best-effort（レビュー差し戻し: フィールド抽出もper-line tryへ入れる）。
            try:
                raw = raw.strip()
                if not raw:
                    continue
                ev = json.loads(raw)
                if not isinstance(ev, dict):
                    continue
                wt = ev.get('worktree')
                if not isinstance(wt, str) or not wt:
                    continue
                owner = ev.get('owner'); owner = owner.strip() if isinstance(owner, str) else ''
                role = ev.get('role'); role = role.strip() if isinstance(role, str) else ''
                label = (owner + ('/' + role if role else '')) if owner else role
                print('%s\t%s' % (b64(wt), b64(label or '-')))
            except Exception:
                continue
except Exception:
    pass
PY
)"
fi
# 台帳のworktree集合(b64・重複除去)。events由来originへ合流させる。
PANES_ORIGIN_B64="$(printf '%s\n' "$PANES_MAP" | awk -F'\t' '$1!=""{print $1}' | sort -u)"
# b64(worktree) → owner/role ラベル(distinct・カンマ結合・decode済み)。無ければ空。
_panes_owner_for(){ # <b64 worktree>
  [ -n "$PANES_MAP" ] || return 0
  local ob dec out=""
  while IFS= read -r ob; do
    [ -n "$ob" ] || continue
    dec="$(b64decode "$ob")"
    [ "$dec" = "-" ] && continue
    case ",$out," in *",$dec,"*) : ;; *) out="${out:+$out,}$dec" ;; esac
  done <<< "$(printf '%s\n' "$PANES_MAP" | awk -F'\t' -v k="$1" '$1==k && $2!=""{print $2}')"
  printf '%s' "$out"
}

# ==== レーン停滞検知（子06フェーズ2・裁定=idle/waiting 10分超）====
# 各レーン(agent持ちworktree)が working を1体も持たない(=idle/waiting)状態の継続時間を
# state/stall-since.tsv（path(b64)\t停滞開始epoch・追記でなく毎回再構築）で追跡し、閾値超で1回だけ
# WAKEに載せる（seenキーが停滞開始時刻ベースで安定＝毎分の再通知はしない）。working復帰でタイマーは
# クリアされ、再停滞で新しいエピソードとして再度検知できる。司令部(main Private)worktreeのレーン停滞は
# 中間指揮官ペイン停滞の集約プロキシも兼ねる（per-ペイン識別はorca titleがタスク由来のため範囲外）。
STALL_SECONDS="${KEEPER_STALL_SECONDS:-600}"
NOW="${KEEPER_NOW:-$(date +%s)}"
STALL_FILE="$STATE_DIR/stall-since.tsv"
touch "$STALL_FILE" 2>/dev/null || true
STALL_NEW="$(mktemp "${TMPDIR:-/tmp}/keeper-stall.XXXXXX" 2>/dev/null || true)"
if [ -n "$STALL_NEW" ]; then
  ln_n="${#LANE_PATHB[@]}"; ln_i=0
  while [ "$ln_i" -lt "$ln_n" ]; do
    pb="${LANE_PATHB[$ln_i]}"; wk="${LANE_WORKING[$ln_i]}"
    if [ "$wk" = "0" ]; then
      # 既存の停滞開始を維持（無ければ今）。awkは base64(ASCII)の完全一致のみ＝多バイト非関与で安全。
      since="$(awk -F'\t' -v k="$pb" '$1==k{print $2; exit}' "$STALL_FILE" 2>/dev/null)"
      [ -n "$since" ] || since="$NOW"
      printf '%s\t%s\n' "$pb" "$since" >> "$STALL_NEW"
      dur=$((NOW - since))
      if [ "$dur" -ge "$STALL_SECONDS" ]; then
        stall_lane="$(b64decode "${LANE_LANEB[$ln_i]}")"
        since_hm="$(date -r "$since" '+%H:%M' 2>/dev/null || printf 'epoch:%s' "$since")"
        stall_line="idle/waiting停滞: 開始${since_hm}から$((STALL_SECONDS/60))分超・working無し"
        stall_owner="$(_panes_owner_for "$pb")"   # 台帳(panes.jsonl)にあれば owner/role を付す（フェーズ2b）
        [ -n "$stall_owner" ] && stall_line="${stall_line}・台帳owner:${stall_owner}"
        DET_KIND+=("STALL")
        DET_LANE+=("$stall_lane")
        DET_LINE+=("$stall_line")
      fi
    fi
    # wk=1（working）のレーンはSTALL_NEWへ書かない＝停滞タイマーをクリア（再開）。
    ln_i=$((ln_i + 1))
  done
  mv "$STALL_NEW" "$STALL_FILE" 2>/dev/null || rm -f "$STALL_NEW" 2>/dev/null || true
fi

# ==== 出所なしレーン検知（子06フェーズ2・裁定1=events.jsonl正）====
# psのアクティブagentレーン(非main)のうち、events.jsonl に当該worktreeの up/send(将来spawn)イベントが
# 無いもの＝cockpit経由でない直起動/緊急直依頼の可能性。レーンごと1回WAKE(seen方式)。突合キーはworktree
# 絶対path(base64)。デイリー起票行とは突合しない(人間可読層・機械結合キー無し=裁定)。events.jsonlが
# 無い時はorigin判定不能につきスキップ(保守側・誤WAKEしない)。司令部main worktreeはis_mainで除外。
EVENTS_FILE="${COCKPIT_EVENTS_FILE:-$SCRIPT_DIR/../../../../skills/orca-cockpit/state/events.jsonl}"
if [ -f "$EVENTS_FILE" ]; then
  # up/send(将来spawn)実績のあるworktree path(base64)の集合を得る（壊れた行はskip・best-effort）。
  # 読取失敗（存在するが読めない/反復中の例外）は '__READ_ERROR__' を返し、空集合(=全レーン出所なし)との
  # 取り違えを防ぐ（レビュー差し戻し1: origin判定不能を空集合として全レーン誤検知しない＝保守側）。
  origin_rc=0
  ORIGIN_B64="$(python3 - "$EVENTS_FILE" 2>/dev/null <<'PY'
import sys, json, base64
seen = set()
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                ev = json.loads(raw)
            except Exception:
                continue
            if isinstance(ev, dict) and ev.get('event') in ('up', 'send', 'spawn'):
                wt = ev.get('worktree')
                if wt:
                    seen.add(wt)
except Exception:
    print('__READ_ERROR__')
    sys.exit(0)
for wt in seen:
    print(base64.b64encode(wt.encode('utf-8')).decode('ascii'))
PY
)" || origin_rc=1
  if [ "$origin_rc" -ne 0 ] || printf '%s\n' "$ORIGIN_B64" | grep -qxF '__READ_ERROR__'; then
    # origin判定不能: NO_ORIGIN判定自体をスキップ（誤WAKEしない・保守側）。events不在時と同じ扱い。
    log "no-origin: events.jsonl 読取失敗のためNO_ORIGIN判定をスキップ（origin判定不能=保守側）"
  else
    no_n="${#LANE_PATHB[@]}"; no_i=0
    while [ "$no_i" -lt "$no_n" ]; do
      pb="${LANE_PATHB[$no_i]}"; ismain="${LANE_ISMAIN[$no_i]:-0}"
      if [ "$ismain" != "1" ]; then
        # origin = events(up/send) ∪ panes.jsonl台帳(worktree)。台帳にあるspawn起動レーンは出所ありとする（玉A）。
        if ! printf '%s\n%s\n' "$ORIGIN_B64" "$PANES_ORIGIN_B64" | grep -qxF -- "$pb"; then
          no_origin_lane="$(b64decode "${LANE_LANEB[$no_i]}")"
          DET_KIND+=("NO_ORIGIN")
          DET_LANE+=("$no_origin_lane")
          DET_LINE+=("出所なし: cockpit up/send記録が無いレーン活動(緊急直依頼/手動起動の可能性)")
        fi
      fi
      no_i=$((no_i + 1))
    done
  fi
fi

# (lane, line) の曖昧さの無いseenキー。"${lane}|${line}"のような単純結合は、lane/lineの一方に
# 区切り文字が含まれるケースで衝突しうるため使わない（json.dumpsの文字列エスケープは可逆・一意）。
seen_key_for() {
  local lane="$1" line="$2"
  python3 -c 'import json, sys
sys.stdout.write(json.dumps([sys.argv[1], sys.argv[2]], ensure_ascii=False))' "$lane" "$line"
}

notify() {
  local lane="$1" kind="$2" line="$3" title body
  title="watch-keeper: ${lane}"
  body="${kind}: ${line}"
  if [ -n "${KEEPER_NOTIFY_CMD:-}" ]; then
    "$KEEPER_NOTIFY_CMD" "$title" "$body"
    return
  fi
  # argvでtitle/bodyを渡す（AppleScript文字列への埋め込みエスケープを避けるため。引用符/バッククォート/$等が
  # 混ざっていてもシェル文字列結合を経由しないため壊れない）。
  osascript -e 'on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run' "$title" "$body" >/dev/null 2>&1
}

append_alert() {
  local lane="$1" kind="$2" line="$3" ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 -c '
import json, sys
ts, lane, kind, line = sys.argv[1:5]
sys.stdout.write(json.dumps({"ts": ts, "lane": lane, "kind": kind, "line": line}, ensure_ascii=False) + "\n")
' "$ts" "$lane" "$kind" "$line" >> "$ALERTS_FILE"
}

# ワンショット監督起動（既定OFF）。検知1件ごとにbackground起動し、判定本体をブロックしない。
invoke_autopilot() {
  local lane="$1" kind="$2" line="$3" prompt
  prompt="watch-keeper検知: レーン=${lane} 種別=${kind} 内容=${line}
skills/cockpit-supervisor/SKILL.md の手順に従い、このレーンの状況を確認し必要な対応を判断してください。"
  if [ -n "${KEEPER_AUTOPILOT_CMD:-}" ]; then
    "$KEEPER_AUTOPILOT_CMD" "$lane" "$kind" "$line" "$prompt"
    return
  fi
  ( claude -p "$prompt" --dangerously-skip-permissions --output-format text --max-budget-usd 5 >/dev/null 2>&1 & )
}

if [ "${#DET_KIND[@]}" -gt 0 ]; then
  i=0
  n="${#DET_KIND[@]}"
  while [ "$i" -lt "$n" ]; do
    lane="${DET_LANE[$i]}"
    kind="${DET_KIND[$i]}"
    line="${DET_LINE[$i]}"
    seen_key="$(seen_key_for "$lane" "$line")"
    if grep -Fxq -- "$seen_key" "$SEEN_FILE" 2>/dev/null; then
      i=$((i + 1))
      continue
    fi
    notify "$lane" "$kind" "$line"
    append_alert "$lane" "$kind" "$line"
    printf '%s\n' "$seen_key" >> "$SEEN_FILE"
    log "検知: lane=${lane} kind=${kind} line=${line}"
    if [ "$AUTOPILOT" = "1" ]; then
      invoke_autopilot "$lane" "$kind" "$line"
    fi
    i=$((i + 1))
  done
fi

exit 0
