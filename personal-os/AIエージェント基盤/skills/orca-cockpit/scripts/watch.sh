#!/usr/bin/env bash
# orca-cockpit / watch.sh
# 複数worktreeを1本で監視する「見張り番」。節目(error/人間確認待ち/完了・レビューマーカー/対話ダイアログ疑い/停滞/長時間稼働/タイムアウト)で
# 検知理由1行を出してexitし、指揮官チャットの自動再開を促す。判断はしない（grepと時計だけ）。
# 起動I/F: [WATCH_SEEN="<処理済み最終行>,<…>"] watch.sh <worktree-path> [<worktree-path> ...]
#   WATCH_SEEN: 指揮官が処理済みの完了/レビューマーカー最終行を完全一致で除外（再ウェイクループ防止）
#   WATCH_AUTO_REVIEW=1(既定): 実装_DONE最終行の検知時、同一worktreeの「_DONEを出していない側」の
#     ペイン(codex優先・特定できない/曖昧なら中止)へ定型レビュー指示を自動sendし、exitせず監視を継続する
#     （受け渡し自動化v1=レビュー配布の手動待ち排除・2026-07-03起票）。特定失敗/send失敗/1ペイン/
#     REVIEW_RESULT最終行は従来どおり即WAKE。同一worktreeに未処理のREVIEW_RESULTが併存する場合も
#     そちらを優先して即WAKE（_DONE側の自動配布はしない=watch再起動後の順序に依存しない）。0で無効（従来動作）。
#   WATCH_SEND_CMD(既定: 同dirのcockpit.sh): 自動配布の送信コマンド。sendサブコマンド互換I/Fが必要
#     （--terminal/--prompt/--stage/--worktree。イベント記録stage=レビューはcockpit.sh send側が担う）。
#   WATCH_REVIEW_PROMPT: 自動配布する定型レビュー指示の本文（上書き可）。
# 依存: orca CLI, python3 / macOS bash 3.2互換（連想配列不使用・indexed arrayのみ）
set -uo pipefail

WATCH_POLL="${WATCH_POLL:-60}"
WATCH_MAX="${WATCH_MAX:-10800}"
WATCH_WAIT_N="${WATCH_WAIT_N:-2}"
WATCH_STALL_N="${WATCH_STALL_N:-4}"
WATCH_BUSY_N="${WATCH_BUSY_N:-25}"
WATCH_SIG_N="${WATCH_SIG_N:-5}"
WATCH_PS_CMD="${WATCH_PS_CMD:-orca worktree ps --json}"
WATCH_TERMS_CMD="${WATCH_TERMS_CMD:-orca terminal list --json}"
WATCH_AUTO_REVIEW="${WATCH_AUTO_REVIEW:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCH_SEND_CMD="${WATCH_SEND_CMD:-$SCRIPT_DIR/cockpit.sh}"
WATCH_REVIEW_PROMPT="${WATCH_REVIEW_PROMPT:-実装ペインの完了マーカーを検知しました。このworktreeのブランチ差分と未コミット変更を担当玉の完了条件と照合してレビューしてください。指摘は具体行で示し、最終行に REVIEW_RESULT: PASS または REVIEW_RESULT: FAIL を単独で出力してください。}"

log(){ printf '[watch] %s\n' "$*" >&2; }
die(){ printf '[watch] ERROR: %s\n' "$*" >&2; exit 1; }

[ $# -ge 1 ] || die "使い方: watch.sh <worktree-path> [<worktree-path> ...]"

# ==== レーン登録（引数順のindexed arrayのみで管理。連想配列は使わない）====
PATHS=("$@")
LANE_COUNT=${#PATHS[@]}
LANES=()
WAIT=()
STALL=()
BUSY=()
i=0
while [ "$i" -lt "$LANE_COUNT" ]; do
  LANES[$i]=$(basename "${PATHS[$i]}")
  WAIT[$i]=0
  STALL[$i]=0
  BUSY[$i]=0
  i=$((i+1))
done

# ==== 状態判定（stdin=`orca worktree ps --json`相当の出力、引数=登録path順）====
# 1行/レーン: "<idx> <mark> <err> <alldone> <waiting> <busy> <donemark> <status> <b_title> <b_agent> <b_line> <nagents>"
# nagents=そのworktreeのagent数。自動レビュー配布のゲート（2以上=実装+レビューの複数ペイン構成の時だけ試す）。
# 末尾3列はWAKE通知の診断情報（2026-07-02夜の診断ロス対策）: b_title=pane識別(cockpitの--title/displayName・
# 無ければlane名)、b_agent=際立つagentのagentType、b_line=検知した行(マーカー/エラーの最終行)。空白・改行・記号の
# 衝突を避けるためbase64で運ぶ（keeper.shと同方式）。値が無い列は"-"のbase64（空文字だと列がずれるため）。
# パース失敗/空入力は "PARSE_ERR" の1行のみを出す。
PY_JUDGE=$(cat <<'PYEOF'
import sys, json, os, re, base64

def b64(text):
    return base64.b64encode((text or "").encode("utf-8")).decode("ascii")

def last_line(msg):
    ls = (msg or "").rstrip().splitlines()
    return (ls[-1] if ls else "").strip()

def is_gate(msg):
    l = last_line(msg)
    return l.startswith("段階:") and "人間確認待ち" in l and len(l) <= 30

DONE_RE = re.compile(r'[A-Z][A-Z0-9_]*_DONE|REVIEW_RESULT: (?:PASS|FAIL)')
SEEN = [s for s in os.environ.get('WATCH_SEEN', '').split(',') if s]

def is_done(msg):
    l = last_line(msg)
    return bool(DONE_RE.fullmatch(l)) and l not in SEEN

paths = sys.argv[1:]
try:
    d = json.load(sys.stdin)
    if not isinstance(d, dict):
        raise ValueError("not an object")
except Exception:
    print("PARSE_ERR")
    sys.exit(0)

worktrees = ((d.get('result') or {}).get('worktrees')) or []
by_path = {}
for w in worktrees:
    if isinstance(w, dict) and w.get('path'):
        by_path[w['path']] = w

for i, p in enumerate(paths):
    w = by_path.get(p)
    lane = os.path.basename(p.rstrip('/')) or p
    if w is None:
        print(i, 0, 0, 0, 0, 0, 0, "missing", b64(lane), b64("-"), b64("-"), 0)
        continue
    agents = [a for a in (w.get('agents') or []) if isinstance(a, dict) and a.get('agentType')]
    mark = 1 if any(is_gate(a.get('lastAssistantMessage')) for a in agents) else 0
    donemark = 1 if any(is_done(a.get('lastAssistantMessage')) for a in agents) else 0
    err = 1 if any(a.get('state') in ('error', 'failed', 'crashed') for a in agents) else 0
    alldone = 1 if agents and all(a.get('state') == 'done' for a in agents) else 0
    waiting = 1 if any(a.get('state') == 'waiting' for a in agents) else 0
    busy = 1 if any(a.get('state') == 'working' for a in agents) else 0
    status = w.get('status') or '?'
    # WAKE詳細用に「際立つagent/行」を優先度(err>人間確認待ち>完了>先頭)で1つ選ぶ（bashが発火させる優先度に対応）。
    sal_agent = ""
    sal_line = ""
    for a in agents:
        if a.get('state') in ('error', 'failed', 'crashed'):
            sal_agent = a.get('agentType') or ''
            sal_line = last_line(a.get('lastAssistantMessage')) or ('state:' + (a.get('state') or ''))
            break
    if not sal_agent:
        for a in agents:
            if is_gate(a.get('lastAssistantMessage')):
                sal_agent = a.get('agentType') or ''
                sal_line = last_line(a.get('lastAssistantMessage'))
                break
    if not sal_agent:
        # 未処理のREVIEW_RESULTは実装_DONEより優先して選ぶ（自動配布ではなく即WAKEすべきレビュー結果を
        # 先に評価する=watch再起動でSEEN_EXTRAが消えた後のagent並び順に依存させない・差し戻し1所見2）
        for a in agents:
            if is_done(a.get('lastAssistantMessage')) and last_line(a.get('lastAssistantMessage')).startswith('REVIEW_RESULT:'):
                sal_agent = a.get('agentType') or ''
                sal_line = last_line(a.get('lastAssistantMessage'))
                break
    if not sal_agent:
        for a in agents:
            if is_done(a.get('lastAssistantMessage')):
                sal_agent = a.get('agentType') or ''
                sal_line = last_line(a.get('lastAssistantMessage'))
                break
    if not sal_agent and agents:
        sal_agent = agents[0].get('agentType') or ''
        sal_line = last_line(agents[0].get('lastAssistantMessage'))
    title = w.get('displayName') or lane
    print(i, mark, err, alldone, waiting, busy, donemark, status, b64(title), b64(sal_agent or "-"), b64(sal_line or "-"), len(agents))
PYEOF
)

# ==== 画面シグネチャ判定（stdin=`orca terminal list --json`相当、argv=worktree path 1つ）====
# workingのままペインを塞ぐ対話ダイアログ（codex利用上限セレクタ等）をpreviewの固定文字列で検知。
# stateがworkingのため優先度3(waiting)にも4(idle)にも掛からない停滞クラス（運用学習17）への対処。
PY_SIG=$(cat <<'PYEOF'
import sys, json
sigs = ("hit your usage limit", "Press enter to confirm")
path = sys.argv[1]
try:
    d = json.load(sys.stdin)
    ts = ((d.get('result') or {}).get('terminals')) or []
except Exception:
    print(0); sys.exit(0)
hit = 0
for t in ts:
    if isinstance(t, dict) and t.get('worktreePath') == path:
        p = t.get('preview') or ''
        if any(s in p for s in sigs):
            hit = 1
print(hit)
PYEOF
)

# base64(1引数)を原文へ復元（python3固定・BSD/GNUのbase64フラグ差を避ける）。WAKE詳細の復号に使う。
_b64d(){ python3 -c 'import sys,base64
sys.stdout.write(base64.b64decode(sys.argv[1]).decode("utf-8","replace"))' "$1"; }

# WAKE行へ付す診断詳細（どのpane/agent・検知した行）。mark系(err/人間確認待ち/完了)は行内容まで、
# 状態系(waiting/idle/busy/sig)はpane/agentの識別のみ（状態WAKEには「検知した行」が無いため）。
# 値はbase64で受け取り復号する。"-"は値なしの標識。
_wake_detail(){ # <mode: mark|state> <b_title> <b_agent> <b_line>
  local mode="$1" t a l s
  t="$(_b64d "$2")"; a="$(_b64d "$3")"; l="$(_b64d "$4")"
  [ "$a" = "-" ] && a=""
  [ "$l" = "-" ] && l=""
  s=" | pane「${t}」"
  [ -n "$a" ] && s="${s} agent=${a}"
  [ "$mode" = "mark" ] && [ -n "$l" ] && s="${s} 行「${l}」"
  printf '%s' "$s"
}

# ==== 自動レビュー配布v1のペイン特定（argv=path, done行, psのJSONファイル, terminal listのJSONファイル）====
# レビューペイン=同一worktreeで「_DONE行を出していないagent」(codex優先)。1つに絞れなければ "-" を返し
# 呼び出し側が従来WAKEへフォールバックする（判断はしない: 候補が曖昧なまま送らない）。
# agent.paneKey("<tabId>:<leafId>")とterminalの(tabId,leafId)を突合してsend用handleへ解決する。
PY_RESOLVE=$(cat <<'PYEOF'
import sys, json

def last_line(msg):
    ls = (msg or "").rstrip().splitlines()
    return (ls[-1] if ls else "").strip()

def load(f):
    try:
        with open(f, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return None

path, line, ps_f, terms_f = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
d = load(ps_f)
worktrees = (((d or {}).get('result') or {}).get('worktrees')) or []
w = None
for x in worktrees:
    if isinstance(x, dict) and x.get('path') == path:
        w = x
        break
if w is None:
    print("-"); sys.exit(0)
agents = [a for a in (w.get('agents') or []) if isinstance(a, dict) and a.get('agentType')]
others = [a for a in agents if last_line(a.get('lastAssistantMessage')) != line]
codex = [a for a in others if a.get('agentType') == 'codex']
if len(codex) == 1:
    cand = codex[0]
elif len(others) == 1:
    cand = others[0]
else:
    print("-"); sys.exit(0)
pane = cand.get('paneKey') or ''
t = load(terms_f)
terms = (((t or {}).get('result') or {}).get('terminals')) or []
matches = []
for term in terms:
    if not isinstance(term, dict):
        continue
    key = str(term.get('tabId') or '') + ':' + str(term.get('leafId') or '')
    if term.get('worktreePath') == path and pane and key == pane:
        matches.append(term.get('handle') or '')
# 突合結果がちょうど1件の時だけ送る。0件/複数件は曖昧=中止して従来WAKE（誤送信防止・差し戻し1所見1）
if len(matches) == 1 and matches[0]:
    print(matches[0])
else:
    print("-")
PYEOF
)

_resolve_review_handle(){ # <worktree-path> <done行> → 標準出力にhandle（特定不可は "-"）
  local ps_f terms_f h
  ps_f=$(mktemp 2>/dev/null) || { printf '%s' "-"; return 0; }
  terms_f=$(mktemp 2>/dev/null) || { rm -f "$ps_f"; printf '%s' "-"; return 0; }
  $WATCH_PS_CMD >"$ps_f" 2>/dev/null
  $WATCH_TERMS_CMD >"$terms_f" 2>/dev/null
  h=$(python3 -c "$PY_RESOLVE" "$1" "$2" "$ps_f" "$terms_f" 2>/dev/null)
  rm -f "$ps_f" "$terms_f"
  printf '%s' "${h:--}"
}

START_TS=$(date +%s)
DEADLINE=$((START_TS + WATCH_MAX))

# 自動配布済みマーカーの実行時seen。起動時WATCH_SEENへ連結して判定側へ渡し、配布後の再検知を抑止する
SEEN_EXTRA=""

log "見張り開始: ${LANE_COUNT}レーン poll=${WATCH_POLL}s max=${WATCH_MAX}s auto_review=${WATCH_AUTO_REVIEW} (${LANES[*]})"

while true; do
  NOW=$(date +%s)
  if [ "$NOW" -ge "$DEADLINE" ]; then
    echo "WAKE: 3時間タイムアウト(進捗未達・要点検)"
    exit 0
  fi

  OUT=$($WATCH_PS_CMD 2>/dev/null | WATCH_SEEN="${WATCH_SEEN:-}${SEEN_EXTRA}" python3 -c "$PY_JUDGE" "${PATHS[@]}")

  if [ "$OUT" = "PARSE_ERR" ] || [ -z "$OUT" ]; then
    log "PARSE_ERR: ps結果を読めず・1周スキップ"
    sleep "$WATCH_POLL"
    continue
  fi

  # here-stringで受ける（パイプにするとサブシェルになりexitが効かないため）
  while read -r idx mark err alldone waiting busy donemark status b_title b_agent b_line nag; do
    [ -z "${idx:-}" ] && continue
    lane="${LANES[$idx]}"

    # 優先度1: エラー系は即exit
    if [ "${err:-0}" = "1" ]; then
      echo "WAKE[$lane]: ペインがerror/failed/crashed(即対応)$(_wake_detail mark "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi
    # 優先度2: 人間確認待ちマーカーは即exit
    if [ "${mark:-0}" = "1" ]; then
      echo "WAKE[$lane]: 人間確認待ちマーカー検知(段階:…最終行)$(_wake_detail mark "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi
    # 優先度2.5: 完了/レビューマーカーの単独最終行（正規表現grepのみ・判断はしない。
    # 指揮官が処理済みのマーカーは WATCH_SEEN の完全一致で除外＝停滞検知(優先度4)へ格下げ）。
    # 実装_DONEはWATCH_AUTO_REVIEW=1かつ複数ペイン構成なら自動レビュー配布して監視継続（受け渡し自動化v1）。
    # REVIEW_RESULT最終行・配布不可(特定失敗/send失敗/1ペイン)は従来どおり即WAKE=指揮官対応。
    if [ "${donemark:-0}" = "1" ]; then
      d_line="$(_b64d "${b_line:-}")"
      if [ "$WATCH_AUTO_REVIEW" = "1" ] && [ "${nag:-0}" -ge 2 ]; then
        case "$d_line" in
          REVIEW_RESULT:*) : ;;
          *)
            h="$(_resolve_review_handle "${PATHS[$idx]}" "$d_line")"
            if [ -n "$h" ] && [ "$h" != "-" ]; then
              if $WATCH_SEND_CMD send --terminal "$h" --prompt "${WATCH_REVIEW_PROMPT}（検知マーカー: ${d_line}・自動配布=watch.sh）" --stage "レビュー" --worktree "${PATHS[$idx]}" >/dev/null 2>&1; then
                log "AUTO_REVIEW[$lane]: ${d_line} → レビューペインへ自動配布(handle=${h})・監視継続"
                SEEN_EXTRA="${SEEN_EXTRA},${d_line}"
                continue
              fi
              log "AUTO_REVIEW[$lane]: send失敗→従来WAKEへフォールバック"
            else
              log "AUTO_REVIEW[$lane]: レビューペイン特定不可→従来WAKEへフォールバック"
            fi
            ;;
        esac
      fi
      echo "WAKE[$lane]: 完了/レビューマーカー検知(_DONE/REVIEW_RESULT:最終行)$(_wake_detail mark "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi

    # 優先度3: 権限確認/質問待ちが連続
    if [ "${waiting:-0}" = "1" ]; then WAIT[$idx]=$((${WAIT[$idx]} + 1)); else WAIT[$idx]=0; fi
    if [ "${WAIT[$idx]}" -ge "$WATCH_WAIT_N" ]; then
      echo "WAKE[$lane]: 権限確認/質問待ちが約2分継続(要解除)$(_wake_detail state "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi

    # 優先度4: 全ペインidleが連続（完了マーカー無しの停滞含む）
    if [ "${alldone:-0}" = "1" ]; then STALL[$idx]=$((${STALL[$idx]} + 1)); else STALL[$idx]=0; fi
    if [ "${STALL[$idx]}" -ge "$WATCH_STALL_N" ]; then
      echo "WAKE[$lane]: 全ペインidleが約4分継続(完了マーカー無し or 停滞)$(_wake_detail state "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi

    # 優先度5: 長時間稼働（異常ではなくハートビート通知）
    if [ "${busy:-0}" = "1" ]; then BUSY[$idx]=$((${BUSY[$idx]} + 1)); else BUSY[$idx]=0; fi
    # 優先度4.5: working継続が約5分を超えたら画面シグネチャを確認（利用上限/対話セレクタのworking偽装停滞）
    if [ "${BUSY[$idx]}" -ge "$WATCH_SIG_N" ]; then
      SIGHIT=$($WATCH_TERMS_CMD 2>/dev/null | python3 -c "$PY_SIG" "${PATHS[$idx]}")
      if [ "$SIGHIT" = "1" ]; then
        echo "WAKE[$lane]: working継続中に対話ダイアログ/利用上限の画面シグネチャ検知(ペイン解除が必要)$(_wake_detail state "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
        exit 0
      fi
    fi
    if [ "${BUSY[$idx]}" -ge "$WATCH_BUSY_N" ]; then
      echo "WAKE[$lane]: 約25分連続稼働(中間報告のハートビート/異常ではない)$(_wake_detail state "${b_title:-}" "${b_agent:-}" "${b_line:-}")"
      exit 0
    fi
  done <<< "$OUT"

  sleep "$WATCH_POLL"
done
