#!/usr/bin/env bash
# orca-cockpit / cockpit.sh
# Orca上に「実装(右上) / レビュー(右下)」を既定2ペインとするコックピットを最速で構築・駆動する。
# 左(計画+監督)は計画未成熟・現場判断が多い場合のみの任意枠（方針10・2026-07-02裁定）。
# 決定的処理のみ（判断・指示内容はSKILL.md/AI/人が持つ）。
# サブコマンド: up | spawn | plan | perm | new | split | agent | send | title | status | down | help
# 依存: orca CLI, python3
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 段階イベントJSONL（up/send/down・追記のみ・git非管理）。置き場とスキーマはこのscriptの
# event_record()が正本。自動ローテーションはしない。
COCKPIT_EVENTS_FILE="${COCKPIT_EVENTS_FILE:-$SCRIPT_DIR/../state/events.jsonl}"
# spawn/up の引数渡し起動で使う state 配下の作業場（全て skills/orca-cockpit/state/ 配下で完結＝
# repo固有パスをハードコードしない＝orca登録済みの任意repoで同じ1コマンドが通る）。上書きは環境変数。
COCKPIT_STATE_DIR="${COCKPIT_STATE_DIR:-$SCRIPT_DIR/../state}"
COCKPIT_PROMPTS_DIR="${COCKPIT_PROMPTS_DIR:-$COCKPIT_STATE_DIR/prompts}"
COCKPIT_SPAWN_DIR="${COCKPIT_SPAWN_DIR:-$COCKPIT_STATE_DIR/spawn}"
COCKPIT_EMPTY_MCP="${COCKPIT_EMPTY_MCP:-$COCKPIT_STATE_DIR/empty-mcp.json}"
# ペイン台帳（spawnで立てたペインの1行記録・JSONL追記・git非管理）。統合見張り(keeper)フェーズ2bが
# 「agent無し起動レース・ペイン単位停滞」を読む正本（読む側=keeper=中間指揮官1担当・cockpitは書くだけ）。
# events.jsonl と同じく追記のみ・git非管理・自動ローテーションなし。上書きは環境変数。
COCKPIT_PANES_FILE="${COCKPIT_PANES_FILE:-$COCKPIT_STATE_DIR/panes.jsonl}"

# ==== 既定ルール（固定・上書きは引数）====
DEFAULT_REPO="Private"
DEFAULT_BASE="main"
DEF_MODEL_CODEX="gpt-5.5"
DEF_EFFORT_CODEX="xhigh"
DEF_MODEL_CLAUDE="claude-sonnet-5"
# 既定コックピット(3枠中2枠使用): 左=空slot(任意・計画未成熟時のみ計画+監督claudeを追加) /
# 右上=実装(claude sonnet5) / 右下=レビュー(codex xhigh)。実行体制の標準(program 2026-07-02裁定)に一致させる。
# 左を使う場合は --pane で3つ明示指定する。
DEFAULT_PANES=("" "実装:claude:${DEF_MODEL_CLAUDE}" "レビュー:codex:${DEF_MODEL_CODEX}:${DEF_EFFORT_CODEX}")

log(){ printf '[cockpit] %s\n' "$*" >&2; }
die(){ printf '[cockpit] ERROR: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "$1 が必要"; }
need orca; need python3

# ==== json 抽出ヘルパ（フィールドを正確に取る。split戻り値のhandleは分割で変わるため使わない）====
# terminal list --json の最初の端末handle（分割前の単一端末想定）
_first_term(){ python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d={}
ts=(d.get('result') or {}).get('terminals') or []
print(ts[0]['handle'] if ts else '')"; }
# 最新レイアウト木 visualLayouts[0].root.tabs[0].panes を辿り、指定パスのterminal handleを返す
# 例: _node_handle first / _node_handle second
_node_handle(){ python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d={}
vl=(d.get('result') or {}).get('visualLayouts') or []
node=None
if vl:
    tabs=((vl[0].get('root') or {}).get('tabs')) or []
    if tabs: node=tabs[0].get('panes')
for k in sys.argv[1:]:
    node=(node or {}).get(k) if isinstance(node,dict) else None
print((node or {}).get('handle','') if isinstance(node,dict) else '')" "$@"; }
# 最新レイアウト木から 位置→handle のJSONを出す（3 or 4ペイン）
_layout_map(){ python3 -c "import sys,json
n=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: d={}
vl=(d.get('result') or {}).get('visualLayouts') or []
panes=None
if vl:
    tabs=((vl[0].get('root') or {}).get('tabs')) or []
    if tabs: panes=tabs[0].get('panes')
def h(x): return (x or {}).get('handle','') if isinstance(x,dict) and x.get('type')=='terminal' else ''
first=(panes or {}).get('first'); second=(panes or {}).get('second')
if n=='4':
    out={'left_top':h((first or {}).get('first')),'left_bottom':h((first or {}).get('second')),
         'right_top':h((second or {}).get('first')),'right_bottom':h((second or {}).get('second'))}
else:
    out={'left':h(first),'right_top':h((second or {}).get('first')),'right_bottom':h((second or {}).get('second'))}
print(json.dumps(out,ensure_ascii=False))" "$@"; }
# 自作JSONの1階層キー
_key(){ python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d={}
print(d.get('$1','') if isinstance(d,dict) else '')"; }

# 段階イベント追記（1呼び出し=JSONL1行）。機構は判断しない: stageは呼び出し元が明示した値をそのまま
# 記録するだけで、本文からの推測・語彙検証は行わない（運用契約§2の語彙判断はAI/人が持つ）。
# 追記失敗はwarnのみで主処理を止めない（up/send/downの成否とは独立の副チャンネル）。
_log_event(){ # <event:up|send|down> <repo> <branch> <worktree> <terminal> <stage> [owner]
  # owner=管轄指揮官（先行部品①・任意/後方互換）。stageと同じく呼び出し元が明示した値をそのまま記録し
  # （検証・推測しない）、無指定はnull。既存6引数の呼び出しはowner=null扱いで従来どおり動く。
  local event="$1" repo="$2" branch="$3" worktree="$4" terminal="$5" stage="$6" owner="${7:-}"
  mkdir -p "$(dirname "$COCKPIT_EVENTS_FILE")" 2>/dev/null || { log "event: 記録先ディレクトリ作成失敗・スキップ"; return 0; }
  python3 -c "
import json, sys, datetime
event, repo, branch, worktree, terminal, stage, owner, path = sys.argv[1:9]
line = {
    'ts': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'repo': repo or None,
    'branch': branch or None,
    'worktree': worktree or None,
    'terminal': terminal or None,
    'event': event,
    'stage': stage or None,
    'owner': owner or None,
}
with open(path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(line, ensure_ascii=False) + chr(10))
" "$event" "$repo" "$branch" "$worktree" "$terminal" "$stage" "$owner" "$COCKPIT_EVENTS_FILE" \
    || log "event: 追記失敗・スキップ（主処理は継続）"
  return 0
}

_list_json(){ orca terminal list --worktree "path:$1" --json 2>&1; }

# ペイン台帳へ1行追記（spawn起動成功時）。keeperフェーズ2bがペイン単位の生死・停滞を読む正本。
# 追記失敗はwarnのみで主処理を止めない（events.jsonlと同じ副チャンネル流儀）。
_log_pane(){ # <handle> <worktree> <role/title> <owner> <model> <prompt_saved>
  local handle="$1" worktree="$2" role="$3" owner="$4" model="$5" prompt_saved="$6"
  mkdir -p "$(dirname "$COCKPIT_PANES_FILE")" 2>/dev/null || { log "pane: 記録先ディレクトリ作成失敗・スキップ"; return 0; }
  python3 -c "
import json, sys, datetime
handle, worktree, role, owner, model, prompt_saved, path = sys.argv[1:8]
line = {
    'ts': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'handle': handle or None,
    'worktree': worktree or None,
    'role': role or None,
    'owner': owner or None,
    'model': model or None,
    'prompt': prompt_saved or None,
}
with open(path, 'a', encoding='utf-8') as f:
    f.write(json.dumps(line, ensure_ascii=False) + chr(10))
" "$handle" "$worktree" "$role" "$owner" "$model" "$prompt_saved" "$COCKPIT_PANES_FILE" \
    || log "pane: 追記失敗・スキップ（主処理は継続）"
  return 0
}

# ==== 引数渡し起動の共有部品（送信レース事故対策・2026-07-03）====
# 背景: ペイン起動→プロンプトsendの二段構えは、send がagent起動前に届くとプロンプトがzshへ流出する
# （claude不起動20分無検知の実事故）。対策=プロンプトを起動引数へ畳み込み「送信ステップ」自体を消す。
# 巨大プロンプトを --command へ $(cat) で直埋めするとクォート層が崩れ --mcp-config が長大文字列を食って
# ENAMETOOLONG になる（15:36実測）。正解=小さな起動ラッパー.sh を生成し --command は 'bash <ラッパー>' の
# 短い1行に保つ（クォートはラッパー内で閉じる・15:38手動実証）。

# state配下の空mcp.jsonを自前で用意（--no-mcp用。--strict-mcp-config と併せMCPを一切読ませない）。
_ensure_empty_mcp(){
  mkdir -p "$COCKPIT_STATE_DIR" 2>/dev/null || { log "empty-mcp: state作成失敗"; return 1; }
  [ -f "$COCKPIT_EMPTY_MCP" ] || printf '{"mcpServers": {}}\n' > "$COCKPIT_EMPTY_MCP"
}

# ファイル名向けにtitleを無害化。空白/スラッシュ/バックスラッシュ/改行は-へ、シェル活性なASCIIメタ文字
# （$ ` " ' ( ) { } [ ] < > | & ; * ? ! # ~ = :）は除去する。生成wrapperの `cat "<保存パス>"` で
# titleがパスに入るため、$()やバッククォートが残るとwrapper実行時にコマンド置換が走る事故を防ぐ
# （2026-07-03 codexレビュー指摘）。ASCIIメタ文字の除去はUTF-8のJP（非ASCIIバイト）を壊さない。
_safe_slug(){
  local s="$1" c
  s="${s//$'\n'/-}"; s="${s//$'\r'/-}"; s="${s//$'\t'/-}"
  s="${s// /-}"; s="${s//\//-}"; s="${s//\\/-}"
  for c in '$' '`' '"' "'" '(' ')' '{' '}' '[' ']' '<' '>' '|' '&' ';' '*' '?' '!' '#' '~' '=' ':'; do
    s="${s//"$c"/}"
  done
  printf '%s' "$s"
}

# モデルid/effort/permission-mode 等のトークンを安全な文字集合（英数 . _ -）に限定する。
# base_cmd/wrapper へそのまま埋まるため、シェルメタ文字混入によるコマンド注入を防ぐ（codexレビュー指摘）。
_safe_token(){ # <value>  0=安全 / 1=不正
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1;; *) return 0;; esac
}

# 起動ラッパーを生成し、そのパスをstdoutに出す。
#   _build_agent_wrapper <base_cmd文字列> <prompt_file> <title> <ts>
# base_cmd 例: claude --model M --permission-mode P [--strict-mcp-config --mcp-config '空json'] / codex -m M -c ...
# 生成物: state/prompts/<ts>-<slug>.md（プロンプト保存＝記録兼用）、state/spawn/<ts>-<slug>.sh（exec起動）。
_build_agent_wrapper(){ # <base_cmd> <prompt_file> <title> <ts>
  local base_cmd="$1" prompt_file="$2" title="$3" ts="$4"
  local slug; slug="$(_safe_slug "$title")"; [ -n "$slug" ] || slug="pane"
  mkdir -p "$COCKPIT_PROMPTS_DIR" "$COCKPIT_SPAWN_DIR" 2>/dev/null || { log "wrapper: state配下作成失敗"; return 1; }
  local saved="$COCKPIT_PROMPTS_DIR/${ts}-${slug}.md"
  local wrapper="$COCKPIT_SPAWN_DIR/${ts}-${slug}.sh"
  cat "$prompt_file" > "$saved" 2>/dev/null || { log "wrapper: プロンプト保存失敗: $saved"; return 1; }
  {
    printf '#!/usr/bin/env bash\n'
    printf '# auto-generated by cockpit.sh (spawn/up 引数渡し起動)。プロンプト正本: %s\n' "$saved"
    # プロンプトの前に `--`（オプション終端）を置く。claudeの --mcp-config <configs...> は可変長引数で、
    # `--` が無いと後続の位置引数（プロンプト）まで設定ファイルとして飲み込むため（実測2026-07-03）。
    printf 'exec %s -- "$(cat "%s")"\n' "$base_cmd" "$saved"
  } > "$wrapper" || { log "wrapper: ラッパー生成失敗: $wrapper"; return 1; }
  chmod +x "$wrapper" 2>/dev/null || true
  printf '%s' "$wrapper"
}

# selector(path:/name:/branch:/id:) → worktree絶対パス（解決不能なら空）。汎用（repo非依存）。
_resolve_wt_path(){ # <selector>
  local sel="$1"
  case "$sel" in
    "") return 0;;
    path:*) printf '%s' "${sel#path:}"; return 0;;
  esac
  local key="${sel%%:*}" val="${sel#*:}"
  orca worktree ps --json 2>/dev/null | python3 -c "
import sys,json
key,val=sys.argv[1],sys.argv[2]
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for w in (d.get('result') or {}).get('worktrees',[]) or []:
    if key=='name' and (w.get('displayName') or '')==val: print(w.get('path','') or ''); break
    if key=='branch' and val and val in (w.get('branch') or ''): print(w.get('path','') or ''); break
    if key=='id' and (w.get('id') or '')==val: print(w.get('path','') or ''); break
" "$key" "$val" 2>/dev/null
}

# 指定worktree(絶対パス)のagent数を返す。見つかったら実数(0含む)、psが未取得/未解釈/対象worktree不在
# なら -1（=不明）を返す。ガードは「見つかって0」の時だけ効かせ、-1（不明）はフェイルオープンにする
# （psが使えない環境で既存sendを壊さない後方互換）。
_worktree_agent_count(){ # <wt_path>  → N(>=0) | -1(不明)
  [ -n "$1" ] || { printf -- '-1'; return 0; }
  orca worktree ps --json 2>/dev/null | python3 -c "
import sys,json
t=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: print(-1); sys.exit(0)
for w in (d.get('result') or {}).get('worktrees',[]) or []:
    if (w.get('path') or '')==t: print(len(w.get('agents') or [])); break
else: print(-1)
" "$1" 2>/dev/null || printf -- '-1'
}

# worktree(絶対パス)のrepo名/branchを返す（"repo\tbranch"）。event記録の補完用。
_worktree_repo_branch(){ # <wt_path>
  [ -n "$1" ] || return 0
  orca worktree ps --json 2>/dev/null | python3 -c "
import sys,json
t=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for w in (d.get('result') or {}).get('worktrees',[]) or []:
    if (w.get('path') or '')==t:
        print('%s\t%s' % (w.get('repo') or '', w.get('branch') or '')); break
" "$1" 2>/dev/null
}

# 新ペインのagent出現を待つ（起動確認）。create前のbaselineより増えたら成功＝既存ペインのある
# worktree(Private等)での偽陽性を避ける。baselineが-1(不明)なら「1以上」を成功条件にフォールバック。
# 10s間隔・上限180s。terminal wait --for tui-idle は「作業中claudeがidleになるまで」で意味が合わない
# （fast起動が台無し）ため、agent出現ポーリングを採用する。
_wait_agent_grows(){ # <wt_path> <baseline> [max_s=180] [interval_s=10]
  local wt="$1" base="$2" max="${3:-180}" iv="${4:-10}" waited=0 n
  [ -n "$wt" ] || return 1
  while [ "$waited" -lt "$max" ]; do
    n="$(_worktree_agent_count "$wt")"
    if [ "${base:-0}" -lt 0 ] 2>/dev/null; then
      [ "${n:-0}" -ge 1 ] 2>/dev/null && return 0
    else
      [ "${n:-0}" -gt "${base:-0}" ] 2>/dev/null && return 0
    fi
    sleep "$iv"; waited=$((waited+iv))
  done
  return 1
}

cmd_new(){ # --repo --branch [--title] [--base]
  local repo="$DEFAULT_REPO" branch="" title="" base="$DEFAULT_BASE"
  while [ $# -gt 0 ]; do case "$1" in
    --repo) repo="$2";shift 2;; --branch) branch="$2";shift 2;; --title) title="$2";shift 2;; --base) base="$2";shift 2;;
    *) die "new: 不明な引数 $1";; esac; done
  [ -n "$branch" ] || die "new: --branch 必須"
  local out; out=$(orca worktree create --name "$branch" --repo "name:$repo" --base-branch "$base" --no-parent --json 2>&1) \
    || die "worktree create 失敗: $out"
  local path; path=$(printf '%s' "$out" | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['worktree']['path'])" 2>/dev/null) \
    || die "path取得失敗"
  [ -n "$title" ] && orca worktree set --worktree "path:$path" --display-name "$title" >/dev/null 2>&1
  local t0; t0=$(_list_json "$path" | _first_term)
  printf '{"path":"%s","term0":"%s"}\n' "$path" "$t0"
}

cmd_split(){ # --worktree <path> [--panes 3|4]  → 左/右上/右下(/左下)。直後の単一端末worktree想定。
  local wt="" panes=3
  while [ $# -gt 0 ]; do case "$1" in --worktree) wt="$2";shift 2;; --panes) panes="$2";shift 2;; *) die "split: 不明な引数 $1";; esac; done
  [ -n "$wt" ] || die "split: --worktree 必須"
  local p0; p0=$(_list_json "$wt" | _first_term)
  [ -n "$p0" ] || die "split: 元端末が見つからない"
  # 1) 左右分割（handleは分割で変わるので戻り値は使わない）
  orca terminal split --terminal "$p0" --direction vertical --json >/dev/null 2>&1 || die "split: vertical失敗"
  # 2) 右ペインの"現"handleを取り直して上下分割
  local rp; rp=$(_list_json "$wt" | _node_handle second)
  [ -n "$rp" ] || die "split: 右ペイン取得失敗"
  orca terminal split --terminal "$rp" --direction horizontal --json >/dev/null 2>&1 || die "split: horizontal失敗"
  if [ "$panes" = 4 ]; then
    local lp; lp=$(_list_json "$wt" | _node_handle first)
    [ -n "$lp" ] || die "split: 左ペイン取得失敗"
    orca terminal split --terminal "$lp" --direction horizontal --json >/dev/null 2>&1 || die "split: 左下失敗"
  fi
  # 3) 最終レイアウト木から 位置→現handle を確定して出力
  _list_json "$wt" | _layout_map "$panes"
}

# 起動プロンプト(codex update / claude browser)を"読んで判定"で潰す。矢印は最小限。
_dismiss_prompts(){ # <terminal> <ready_regex>
  local h="$1" ready="$2" i out
  for i in $(seq 1 12); do
    orca terminal wait --terminal "$h" --for tui-idle --timeout-ms 8000 >/dev/null 2>&1
    out=$(orca terminal read --terminal "$h" --limit 40 2>&1)
    printf '%s' "$out" | grep -qiE "$ready" && return 0
    if printf '%s' "$out" | grep -qiE 'Update available'; then
      [ -n "${COCKPIT_UPDATE_FLAG:-}" ] && : > "$COCKPIT_UPDATE_FLAG"   # 更新ありを記録→後で4つ目端末で更新
      orca terminal send --terminal "$h" --text $'\x1b[B' >/dev/null 2>&1; sleep 1
      orca terminal send --terminal "$h" --enter >/dev/null 2>&1
    elif printf '%s' "$out" | grep -qiE 'Chrome extension|use my browser'; then
      orca terminal send --terminal "$h" --text $'\x1b[B' >/dev/null 2>&1; sleep 1
      orca terminal send --terminal "$h" --enter >/dev/null 2>&1
    fi
  done
  return 1
}

cmd_agent(){ # --terminal <h> --kind claude|codex|opencode [--model][--effort][--prompt-file <p>][--no-mcp][--permission-mode <m>][--title <t>]
  # --prompt-file: プロンプトを起動引数へ畳み込む（送信レース根絶）。claude/codexは引数渡し対応、
  # opencodeは非対応（bare起動＝従来どおり別途send）。--no-mcp/--permission-modeはclaudeにのみ効く。
  local h="" kind="" model="" effort="" prompt_file="" no_mcp=0 perm_mode="" title=""
  while [ $# -gt 0 ]; do case "$1" in
    --terminal) h="$2";shift 2;; --kind) kind="$2";shift 2;; --model) model="$2";shift 2;; --effort) effort="$2";shift 2;;
    --prompt-file) prompt_file="$2";shift 2;; --no-mcp) no_mcp=1;shift;; --permission-mode) perm_mode="$2";shift 2;; --title) title="$2";shift 2;;
    *) die "agent: 不明な引数 $1";; esac; done
  [ -n "$h" ] && [ -n "$kind" ] || die "agent: --terminal と --kind は必須"
  [ -z "$prompt_file" ] || [ -f "$prompt_file" ] || die "agent: --prompt-file が存在しない: $prompt_file"
  # base_cmd/wrapperへ埋まるトークンはシェルメタ文字を弾く（コマンド注入防止・codexレビュー指摘2）。
  [ -z "$model" ]     || _safe_token "$model"     || die "agent: --model に使えない文字: $model"
  [ -z "$effort" ]    || _safe_token "$effort"    || die "agent: --effort に使えない文字: $effort"
  [ -z "$perm_mode" ] || _safe_token "$perm_mode" || die "agent: --permission-mode に使えない文字: $perm_mode"
  local base ready argpass=0
  case "$kind" in
    claude)
      base="claude"; [ -n "$model" ] && base="$base --model $model"
      [ -n "$perm_mode" ] && base="$base --permission-mode $perm_mode"
      if [ "$no_mcp" = 1 ]; then _ensure_empty_mcp && base="$base --strict-mcp-config --mcp-config \"$COCKPIT_EMPTY_MCP\""; fi
      ready='tok|Opus|Sonnet|Haiku|Welcome to Claude'; argpass=1 ;;
    codex)
      base="codex -m ${model:-$DEF_MODEL_CODEX} -c model_reasoning_effort=${effort:-$DEF_EFFORT_CODEX}"
      ready='gpt-5|YOLO mode|model:'; argpass=1 ;;
    opencode)
      base="opencode"; [ -n "$model" ] && base="$base --model $model"; ready='opencode|ready|›'; argpass=0 ;;
    *) die "agent: 未知のkind '$kind'（claude|codex|opencode）";;
  esac
  # prompt_delivered: プロンプトを実際に届けられたか。呼び出し側(cmd_up)はこれが true の時だけ
  # owner表示用の send イベントを記録し、未投入ペインに phantom イベントを残さない（codexレビュー指摘）。
  local launch="$base" argpass_prompt=0 prompt_delivered=na
  if [ -n "$prompt_file" ] && [ "$argpass" = 1 ]; then
    local ts wrapper; ts="$(date +%Y%m%d-%H%M%S)"
    wrapper="$(_build_agent_wrapper "$base" "$prompt_file" "${title:-$kind}" "$ts")" || die "agent: ラッパー生成失敗"
    launch="bash \"$wrapper\""
    argpass_prompt=1   # プロンプトはwrapperへ畳み込み済み＝起動送信が成功すれば投入完了（送信レース無し）
  elif [ -n "$prompt_file" ] && [ "$argpass" = 0 ]; then
    # opencode 等は初期プロンプトの引数渡しに非対応。ここで別 send を撃つと、未起動時に zsh へ
    # プロンプトが流出し得るうえ成否も検証できない（起動確認regexは偽陽性あり）。よって bare 起動のみとし
    # 「未投入」を正直に返す（呼び出し側はイベントを残さない）。必要なら人が明示的に send する。
    prompt_delivered=false
    log "agent: kind=$kind は初期プロンプトの引数渡し非対応。bare起動のみでプロンプトは未投入（必要なら手動send）。handle=${h}"
  fi
  # 起動送信も cmd_send と同じく --json の ok で成否判定する。ハンドルが無効/staleなら「bash wrapper」自体が
  # 届かず agent は起動しない→ argpass_prompt でも prompt_delivered=false にして phantom event を防ぐ
  # （終了コードは環境差で ok:false でも 0 を返し得るため ok と rc の両方を見る・codexレビュー指摘）。
  local launch_out launch_rc launch_ok=1 lok
  launch_out="$(orca terminal send --terminal "$h" --text "$launch" --enter --json 2>&1)"; launch_rc=$?
  lok="$(printf '%s' "$launch_out" | python3 -c "import sys,json
try: print('true' if json.load(sys.stdin).get('ok') else 'false')
except Exception: print('none')" 2>/dev/null)"
  { [ "$launch_rc" -ne 0 ] || [ "$lok" = "false" ]; } && launch_ok=0
  [ "$launch_ok" = 0 ] && log "agent: 起動送信に失敗（handle=${h}＝無効/stale等）: $(printf '%s' "$launch_out" | tr '\n' ' ')"
  if [ "$argpass_prompt" = 1 ]; then
    if [ "$launch_ok" = 1 ]; then prompt_delivered=true; else prompt_delivered=false; fi
  fi
  if _dismiss_prompts "$h" "$ready"; then log "agent起動OK: $kind ($h)"; else log "agent起動: readyマーカー未確認・要目視 ($kind $h)"; fi
  printf '{"terminal":"%s","kind":"%s","prompt_delivered":"%s"}\n' "$h" "$kind" "$prompt_delivered"
}

cmd_send(){ # --terminal <h> --prompt <text> [--stage <段階語彙>] [--owner <指揮官>] [--worktree <path>] [--repo <name>] [--branch <b>] [--force]
  # --stage / --owner は送信者(人/AI)が明示宣言する任意フラグ。本文から段階・管轄を推測するロジックは入れない
  # （運用契約§2の語彙判断・妥当性検証は機構の責務外＝呼び出し元がそのまま記録される）。
  # 安全ガード（2026-07-03）: --worktree指定時、そのworktreeにagentが1つも居なければ送信を拒否する
  # （プロンプトがzshへ流出する事故=claude不起動20分無検知の再発防止）。--forceで明示上書き可。
  local h="" p="" stage="" owner="" wt="" repo="" branch="" force=0
  while [ $# -gt 0 ]; do case "$1" in
    --terminal) h="$2";shift 2;; --prompt) p="$2";shift 2;; --stage) stage="$2";shift 2;; --owner) owner="$2";shift 2;;
    --worktree) wt="$2";shift 2;; --repo) repo="$2";shift 2;; --branch) branch="$2";shift 2;; --force) force=1;shift;;
    *) die "send: 不明な引数 $1";; esac; done
  [ -n "$h" ] && [ -n "$p" ] || die "send: --terminal と --prompt は必須"
  if [ "$force" != 1 ] && [ -n "$wt" ]; then
    # 「worktreeが見つかってagent 0」の時だけブロック。-1(不明)はフェイルオープン（psが使えない環境で
    # 既存sendを壊さない）。0のときだけ、起動途中のラグを考慮して数秒リトライしてから拒否する。
    local n try; n="$(_worktree_agent_count "$wt")"
    for try in 1 2; do [ "$n" != "0" ] && break; sleep 2; n="$(_worktree_agent_count "$wt")"; done
    [ "$n" = "0" ] && die "send: 送信先worktree($wt)にagentが居ない=zshへ流出の恐れ。起動確認後に送るか --force で上書き"
  fi
  # 送信は --json の ok で成否を判定する。orca terminal send の終了コードは環境差で
  # stale/無効ハンドルでも0を返す場合があり（誤送信が無音成功になる穴・2026-07-03実測）、
  # 終了コードだけに頼らない。ok:false もしくは終了非0なら誤送信としてエラー返す（記録しない）。
  local send_out send_rc ok
  send_out="$(orca terminal send --terminal "$h" --text "$p" --enter --json 2>&1)"; send_rc=$?
  ok="$(printf '%s' "$send_out" | python3 -c "import sys,json
try: print('true' if json.load(sys.stdin).get('ok') else 'false')
except Exception: print('none')" 2>/dev/null)"
  if [ "$send_rc" -ne 0 ] || [ "$ok" = "false" ]; then
    log "send: 送信失敗（handle=${h} 無効/staleハンドル等の誤送信を検知・記録せず）: $(printf '%s' "$send_out" | tr '\n' ' ')"
    return 1
  fi
  _log_event send "$repo" "$branch" "$wt" "$h" "$stage" "$owner"
  printf '{"terminal":"%s","sent":true}\n' "$h"
}

cmd_title(){ # --worktree <path> --title <display>
  local wt="" t=""
  while [ $# -gt 0 ]; do case "$1" in --worktree) wt="$2";shift 2;; --title) t="$2";shift 2;; *) die "title: 不明な引数 $1";; esac; done
  [ -n "$wt" ] && [ -n "$t" ] || die "title: --worktree と --title は必須"
  orca worktree set --worktree "path:$wt" --display-name "$t" >/dev/null 2>&1 && printf '{"worktree":"%s","title":"%s"}\n' "$wt" "$t"
}

cmd_status(){ # --worktree <path>
  local wt=""
  while [ $# -gt 0 ]; do case "$1" in --worktree) wt="$2";shift 2;; *) die "status: 不明な引数 $1";; esac; done
  [ -n "$wt" ] || die "status: --worktree 必須"
  orca terminal list --worktree "path:$wt" 2>&1 | sed -n '/visual layout/,$p'
}

cmd_down(){ # --worktree <path> | --branch <b> [--owner <指揮官>]  … コックピットworktreeを撤去（端末停止＋worktree削除）
  local sel="" wt="" branch="" owner=""
  while [ $# -gt 0 ]; do case "$1" in
    --worktree) sel="path:$2"; wt="$2"; shift 2;;
    --branch) sel="branch:$2"; branch="$2"; shift 2;;
    --owner) owner="$2"; shift 2;;
    *) die "down: 不明な引数 $1";; esac; done
  [ -n "$sel" ] || die "down: --worktree <path> か --branch <b> が必要"
  orca terminal stop --worktree "$sel" >/dev/null 2>&1 || true
  orca worktree rm --worktree "$sel" --force --json >/dev/null 2>&1 \
    && { _log_event down "" "$branch" "$wt" "" "" "$owner"; printf '{"removed":"%s"}\n' "$sel"; } \
    || die "down: 削除失敗 ($sel)"
}

# ==== 役割別権限（worktree共有cwdにつき1枚に統合。claudeペインのみ効く／codexは無視）====
# acceptEdits(実装のworktree内編集を自動許可) + orca/git読取allowlist(監督・レビューの確認操作) を1枚に統合。
# 削除・push・main反映・.env読取は常にdeny。bypassPermissionsは使わない（グローバル ~/.claude は絶対に触らない）。
_write_settings(){ # <worktree-path> <force:0|1>
  local wt="$1" force="${2:-0}"
  local dir="$wt/.claude" file="$wt/.claude/settings.json"
  if [ -f "$file" ] && [ "$force" != "1" ]; then
    log "perm: 既存の $file を検出・スキップ（上書きするなら --force-perm）"
    return 0
  fi
  mkdir -p "$dir" 2>/dev/null || { log "perm: $dir 作成失敗"; return 1; }
  cat > "$file" <<'JSON'
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash(orca worktree ps:*)",
      "Bash(orca worktree list:*)",
      "Bash(orca terminal read:*)",
      "Bash(orca terminal list:*)",
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git branch:*)"
    ],
    "deny": [
      "Bash(git push:*)",
      "Bash(git merge:*)",
      "Bash(rm -rf:*)",
      "Bash(orca worktree rm:*)",
      "Read(.env)",
      "Read(.env.*)"
    ]
  }
}
JSON
  log "perm: $file を配布"
}

cmd_perm(){ # --worktree <path> [--force]
  local wt="" force=0
  while [ $# -gt 0 ]; do case "$1" in
    --worktree) wt="$2";shift 2;; --force|--force-perm) force=1;shift;; *) die "perm: 不明な引数 $1";; esac; done
  [ -n "$wt" ] || die "perm: --worktree 必須"
  [ -d "$wt" ] || die "perm: worktreeが存在しない: $wt"
  _write_settings "$wt" "$force"
}

cmd_plan(){ # --repo --branch [--title] [--panes 3|4] [--pane "役割:kind[:model[:effort]]"]... [--scope <text>] [--base <ref>]
  # 構成カードをstdoutに出すだけ。worktree作成・分割・agent起動は一切行わない（up と同じ引数体系）。
  local repo="$DEFAULT_REPO" branch="" title="" panes=3 scope="" base="$DEFAULT_BASE"
  local -a specs=()
  while [ $# -gt 0 ]; do case "$1" in
    --repo) repo="$2";shift 2;; --branch) branch="$2";shift 2;; --title) title="$2";shift 2;;
    --panes) panes="$2";shift 2;; --pane) specs+=("$2");shift 2;;
    --scope) scope="$2";shift 2;; --base) base="$2";shift 2;;
    *) die "plan: 不明な引数 $1";; esac; done
  [ -n "$branch" ] || die "plan: --branch 必須"
  [ ${#specs[@]} -eq 0 ] && specs=("${DEFAULT_PANES[@]}")

  local -a pos poslabel
  if [ "$panes" = 4 ]; then pos=(left_top left_bottom right_top right_bottom); poslabel=("左上" "左下" "右上" "右下")
  else pos=(left right_top right_bottom); poslabel=("左  " "右上" "右下"); fi

  echo "── コックピット構成カード（起動前確認・未起動）──"
  printf 'レーン(title): %s\n' "${title:-未指定}"
  printf 'repo/branch  : %s / %s   (base: %s)\n' "$repo" "$branch" "$base"
  printf '規模/scope   : %s\n' "${scope:-未指定}"
  echo "ペイン構成:"
  local i role kind model effort perm label
  for i in "${!pos[@]}"; do
    IFS=: read -r role kind model effort <<<"${specs[$i]:-}"
    if [ -z "$role" ] || [ -z "$kind" ]; then
      printf '  %s (空slot・未使用。計画未成熟時のみ計画+監督claudeを追加)\n' "${poslabel[$i]}"
      continue
    fi
    case "$role" in
      *実装*|*impl*|*implementer*) perm="acceptEdits" ;;
      *計画*|*監督*|*supervisor*) perm="read-allowlist" ;;
      *レビュー*|*review*|*reviewer*) perm="read-allowlist" ;;
      *) perm="read-allowlist" ;;
    esac
    label="$kind"; [ -n "$model" ] && label="$label $model"; [ -n "$effort" ] && label="$label $effort"
    printf '  %s %-8s %-20s 権限: %s\n' "${poslabel[$i]}" "$role" "$label" "$perm"
  done
  echo "権限方式     : 役割別 .claude/settings.json を worktree に配布（グローバル不変更・bypassPermissions不使用）"
  local upcmd="cockpit.sh up --repo $repo --branch $branch"
  [ -n "$title" ] && upcmd="$upcmd --title \"$title\""
  local s; for s in "${specs[@]}"; do [ -n "$s" ] && upcmd="$upcmd --pane \"$s\""; done
  printf '起動コマンド : %s\n' "$upcmd"
  echo "※これは提示のみ。人間のOK後に up を実行する（モデル構成をAIが黙って決めない）。"
}

cmd_up(){ # --repo --branch --title [--panes 3|4] [--pane "役割:kind[:model[:effort]]"]... [--prompt "役割=text"]... [--no-perm] [--no-update]
  local repo="$DEFAULT_REPO" branch="" title="" panes=3 auto_update=1 write_perm=1 owner="" no_mcp=0
  local -a specs=() prompts=()
  while [ $# -gt 0 ]; do case "$1" in
    --repo) repo="$2";shift 2;; --branch) branch="$2";shift 2;; --title) title="$2";shift 2;;
    --panes) panes="$2";shift 2;; --pane) specs+=("$2");shift 2;; --prompt) prompts+=("$2");shift 2;;
    --owner) owner="$2";shift 2;;
    --no-update) auto_update=0;shift;; --no-perm) write_perm=0;shift;; --no-mcp) no_mcp=1;shift;;
    *) die "up: 不明な引数 $1";; esac; done
  [ -n "$branch" ] || die "up: --branch 必須"
  [ ${#specs[@]} -eq 0 ] && specs=("${DEFAULT_PANES[@]}")

  log "worktree作成: $repo/$branch (title=${title:-なし})"
  local -a newargs=(--repo "$repo" --branch "$branch"); [ -n "$title" ] && newargs+=(--title "$title")
  local path; path=$(cmd_new "${newargs[@]}" | _key path)
  [ -n "$path" ] || die "up: worktree path取得失敗"

  log "分割: ${panes}ペイン"
  local sj; sj=$(cmd_split --worktree "$path" --panes "$panes")

  local -a pos
  if [ "$panes" = 4 ]; then pos=(left_top left_bottom right_top right_bottom); else pos=(left right_top right_bottom); fi

  # 役割別権限（claudeペインが読む .claude/settings.json）をagent起動前に配布。--no-permで無効化。
  if [ "$write_perm" = 1 ]; then
    _write_settings "$path" 0
  fi

  # codex更新検出フラグ（並列サブシェルからはファイル経由で通知）
  COCKPIT_UPDATE_FLAG="${TMPDIR:-/tmp}/cockpit-update-$$"; rm -f "$COCKPIT_UPDATE_FLAG"; export COCKPIT_UPDATE_FLAG

  # 各ペインを並列起動（別端末なので独立。逐次の待ち合わせを避けて短縮）
  local i role kind model effort key h
  for i in "${!specs[@]}"; do
    IFS=: read -r role kind model effort <<<"${specs[$i]}"
    [ -n "$role" ] && [ -n "$kind" ] || { log "ペイン[${pos[$i]:-?}] は空slot・未使用（既定=2ペイン運用）"; continue; }
    key="${pos[$i]:-}"; [ -n "$key" ] || { log "ペイン数超過: '${specs[$i]}' をスキップ"; continue; }
    h=$(printf '%s' "$sj" | _key "$key")
    [ -n "$h" ] || { log "ペイン '$key' のhandle無し・スキップ"; continue; }
    log "ペイン[$key] = $role : $kind 起動(並列)"
    (
      # 該当ロールのプロンプトを引数渡し起動へ畳み込む（別sendを廃し送信レースを構造的に消す）。
      role_prompt=""
      if [ ${#prompts[@]} -gt 0 ]; then
        for pr in "${prompts[@]}"; do case "$pr" in "$role="*) role_prompt="${pr#*=}";; esac; done
      fi
      aargs=(--terminal "$h" --kind "$kind" --title "$role")
      [ -n "$model" ] && aargs+=(--model "$model")
      [ -n "$effort" ] && aargs+=(--effort "$effort")
      [ "$no_mcp" = 1 ] && aargs+=(--no-mcp)
      if [ -n "$role_prompt" ]; then
        pf="$(mktemp "${TMPDIR:-/tmp}/cockpit-up-prompt.XXXXXX")"
        printf '%s' "$role_prompt" > "$pf"
        aargs+=(--prompt-file "$pf")
      fi
      agent_out="$(cmd_agent "${aargs[@]}")"
      # プロンプトを実際に届けられたペインだけ send イベントを記録する。owner表示(読む側=renderer)は
      # event=send を読むため必要だが、未投入ペイン（引数渡し非対応kind等）に phantom イベントを
      # 残さないよう prompt_delivered=true を条件にする（codexレビュー指摘）。実送信はしていない＝レース無し。
      if [ -n "$role_prompt" ]; then
        delivered="$(printf '%s' "$agent_out" | _key prompt_delivered)"
        [ "$delivered" = "true" ] && _log_event send "$repo" "$branch" "$path" "$h" "" "$owner"
      fi
    ) &
  done
  wait
  # codex更新が検出されたら4つ目の端末(別タブ)で codex update を自動実行（走行中セッションは無停止）
  if [ "$auto_update" = 1 ] && [ -f "$COCKPIT_UPDATE_FLAG" ]; then
    log "codex更新あり → 4つ目の端末で codex update を自動実行"
    orca terminal create --worktree "path:$path" --title "codex-update" --command "codex update" --json >/dev/null 2>&1 || log "codex-update 端末起動に失敗"
  fi
  rm -f "$COCKPIT_UPDATE_FLAG"
  _log_event up "$repo" "$branch" "$path" "" "" "$owner"
  log "コックピット構築完了: $path"
  printf '%s' "$sj" | python3 -c "import sys,json;d=json.load(sys.stdin);print(json.dumps({'path':'$path','panes':d},ensure_ascii=False))"
}

cmd_spawn(){ # --worktree <selector> --title <名> [--model <m>] --prompt-file <path> [--stage <段階>] [--owner <指揮官>] [--no-mcp] [--permission-mode <mode>=acceptEdits]
  # 既存worktreeへ claude ペインを1発で立てる（中間指揮官を立てる/緊急1ペイン向け）。プロンプトは
  # 起動引数へ畳み込む（送信ステップ無し＝レース不可能）。--no-mcpでMCPを一切読ませず起動を高速化。
  # 汎用: --worktree は orca selector（path:/name:/branch:/id:）＝orca登録済みの任意repoで通る。
  local sel="" title="" model="" prompt_file="" stage="" owner="" no_mcp=0 perm="acceptEdits"
  while [ $# -gt 0 ]; do case "$1" in
    --worktree) sel="$2";shift 2;; --title) title="$2";shift 2;; --model) model="$2";shift 2;;
    --prompt-file) prompt_file="$2";shift 2;; --stage) stage="$2";shift 2;; --owner) owner="$2";shift 2;;
    --no-mcp) no_mcp=1;shift;; --permission-mode) perm="$2";shift 2;;
    *) die "spawn: 不明な引数 $1";; esac; done
  [ -n "$sel" ] && [ -n "$title" ] && [ -n "$prompt_file" ] || die "spawn: --worktree --title --prompt-file は必須"
  [ -f "$prompt_file" ] || die "spawn: --prompt-file が存在しない: $prompt_file"
  : "${model:=$DEF_MODEL_CLAUDE}"
  # base_cmd/wrapperへ埋まるトークンはシェルメタ文字を弾く（コマンド注入防止・codexレビュー指摘2）。
  _safe_token "$model" || die "spawn: --model に使えない文字: $model"
  [ -z "$perm" ] || _safe_token "$perm" || die "spawn: --permission-mode に使えない文字: $perm"
  local t0; t0="$(date +%s)"

  local base="claude --model $model"
  [ -n "$perm" ] && base="$base --permission-mode $perm"
  if [ "$no_mcp" = 1 ]; then _ensure_empty_mcp && base="$base --strict-mcp-config --mcp-config \"$COCKPIT_EMPTY_MCP\""; fi
  local ts slug; ts="$(date +%Y%m%d-%H%M%S)"; slug="$(_safe_slug "$title")"; [ -n "$slug" ] || slug="pane"
  local wrapper; wrapper="$(_build_agent_wrapper "$base" "$prompt_file" "$title" "$ts")" || die "spawn: ラッパー生成失敗"
  local saved="$COCKPIT_PROMPTS_DIR/${ts}-${slug}.md"

  # create前に対象worktreeのagent数(baseline)を取る＝既存ペインと新ペインを区別して確認するため。
  local wt_path baseline
  wt_path="$(_resolve_wt_path "$sel")"
  baseline="$(_worktree_agent_count "$wt_path")"

  local create_out handle
  create_out="$(orca terminal create --worktree "$sel" --title "$title" --command "bash \"$wrapper\"" --json 2>&1)" \
    || die "spawn: terminal create 失敗: $create_out"
  # handleは {\"result\":{\"handle\":{...,\"handle\":\"term_...\"}}} のようにネストし得る。term_文字列まで掘る。
  handle="$(printf '%s' "$create_out" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: d={}
def dig(x):
    if isinstance(x,str): return x
    if isinstance(x,dict): return dig(x.get('handle') or x.get('id') or x.get('terminal') or '')
    return ''
r=(d.get('result') or d) if isinstance(d,dict) else {}
h=dig(r.get('handle')) or dig(r.get('terminal'))
print(h if isinstance(h,str) else '')" 2>/dev/null)"

  local repo branch confirmed=false
  # ペイン台帳へ記録（terminal create成功時＝confirm前に書く。agent無し起動レースもkeeperが読める）。
  _log_pane "$handle" "${wt_path:-$sel}" "$title" "$owner" "$model" "$saved"
  # 起動確認: baselineより agent が増えたら新ペインのagent出現とみなす（既存ペインのあるworktree=Private等の偽陽性回避）。
  if [ -n "$wt_path" ] && _wait_agent_grows "$wt_path" "$baseline" 180 10; then
    confirmed=true
    local rb; rb="$(_worktree_repo_branch "$wt_path")"; repo="${rb%%$'\t'*}"; branch="${rb#*$'\t'}"
  fi
  _log_event spawn "$repo" "$branch" "${wt_path:-$sel}" "$handle" "$stage" "$owner"

  local elapsed=$(( $(date +%s) - t0 ))
  [ "$confirmed" = true ] && log "spawn起動確認OK: $title (${elapsed}s, mcp=$([ "$no_mcp" = 1 ] && echo off || echo on))" \
    || log "spawn起動: agent未確認・要目視 ($title ${elapsed}s)"
  printf '{"worktree":"%s","terminal":"%s","prompt_saved":"%s","wrapper":"%s","mcp":"%s","agent_confirmed":%s,"elapsed_s":%s}\n' \
    "${wt_path:-$sel}" "$handle" "$saved" "$wrapper" "$([ "$no_mcp" = 1 ] && echo off || echo on)" "$confirmed" "$elapsed"
}

usage(){ cat >&2 <<'U'
cockpit.sh — Orca分割コックピット構築・駆動（既定2ペイン: 右上=実装 / 右下=レビュー。
             左=計画+監督は計画未成熟時のみ --pane で3つ明示指定する任意枠。方針10・2026-07-02裁定）
既定エージェント: 実装=codex(gpt-5.5,medium) / レビュー=codex(gpt-5.5,medium)

  plan    --repo <name> --branch <english> [--title <計画名>] [--panes 3|4] [--scope <text>] [--base <ref>]
          [--pane "役割:kind[:model[:effort]]"]...
          構成カードを表示するだけ（起動しない）。人間のOK後に up を実行する。
  up      --repo <name> --branch <english> [--title <計画名>] [--panes 3|4] [--owner <指揮官>] [--no-update] [--no-perm]
          [--pane "役割:kind[:model[:effort]]"]... [--prompt "役割=text"]...
          codex更新が出たら自動Skip＋4つ目の端末で codex update（--no-updateで無効化）
          worktreeに役割別 .claude/settings.json を配布（--no-permで無効化。既存があれば自動でスキップ）
          プロンプトは起動引数へ畳み込む（別send無し＝送信レース無し）。--no-mcpでMCP無効化し起動を高速化
  spawn   --worktree <selector> --title <名> [--model <m>] --prompt-file <path> [--stage <段階>] [--owner <指揮官>] [--no-mcp] [--permission-mode <mode>=acceptEdits]
          既存worktreeへclaudeペインを1発起動（中間指揮官を立てる/緊急1ペイン向け）。プロンプトを
          state/prompts/へ保存し起動ラッパー(state/spawn/)経由で引数渡し＝送信ステップ無し。--no-mcpで
          MCPを読ませず高速起動。agent出現(10s/180s)を確認後にspawnイベント(owner付き)を記録。汎用selector。
  perm    --worktree <path> [--force]        # 既存worktreeにも .claude/settings.json を配布
  new     --repo <name> --branch <english> [--title <計画名>] [--base <ref>]
  split   --worktree <path> [--panes 3|4]
  agent   --terminal <handle> --kind claude|codex|opencode [--model <m>] [--effort <e>]
  send    --terminal <handle> --prompt <text> [--stage <段階語彙>] [--owner <指揮官>] [--worktree <path>] [--repo <name>] [--branch <b>] [--force]
          --stage/--ownerは送信者が明示宣言する任意フラグ（本文からの推測はしない・無指定はnull）
          安全ガード: --worktree指定時、そのworktreeにagentが0なら送信を拒否（zsh流出防止）。--forceで上書き
  title   --worktree <path> --title <display>
  status  --worktree <path>
  down    --worktree <path> | --branch <b> [--owner <指揮官>]   # コックピットworktree撤去(端末停止+削除)

段階イベント: up/spawn/send/downの実行時にJSONL1行(ts/repo/branch/worktree/terminal/event/stage/owner)を
skills/orca-cockpit/state/events.jsonl（既定・git非管理）に追記する。ownerは管轄指揮官(先行部品①・任意/
後方互換・無指定はnull)。上書きは環境変数COCKPIT_EVENTS_FILE。置き場とスキーマはこのscriptの
event_record()が正本。自動ローテーションはしない。

見張り番: scripts/watch.sh <worktree-path>... を通知つき背景タスクで起動し、節目でexit→指揮官チャットを自動再開。

例: cockpit.sh plan --repo Private --branch design/skill-x --title "コックピット:スキルX"
    cockpit.sh up   --repo Private --branch design/skill-x --title "コックピット:スキルX"
U
}

main(){
  local sub="${1:-help}"; shift || true
  case "$sub" in
    up) cmd_up "$@";; plan) cmd_plan "$@";; perm) cmd_perm "$@";; spawn) cmd_spawn "$@";;
    new) cmd_new "$@";; split) cmd_split "$@";; agent) cmd_agent "$@";;
    send) cmd_send "$@";; title) cmd_title "$@";; status) cmd_status "$@";; down) cmd_down "$@";;
    help|-h|--help) usage;;
    *) usage; die "未知のサブコマンド: $sub";;
  esac
}
main "$@"
