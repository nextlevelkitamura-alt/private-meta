#!/usr/bin/env bash
# orca-cockpit / worktree-sweep.sh
# 夜締め(23:30前)にworktreeの「クローズ候補」と「注意」を検知し、夜会で人間が読む短いリストを出す
# （マルチ指揮官体制program 子07・2026-07-03裁定=夜バッチ形）。
#
# 検知とレポートだけ。down / worktree削除は絶対に実行しない（GLOBAL_AGENTS.md §7・常に人間ゲート）。
# クローズ候補には down コマンド案を併記するが、このスクリプトは実行しない（人間が夜会で一括承認して実行）。
#
# 判定（計画07方針1・5が正本／迷ったら保守側＝候補にしない）:
#   クローズ候補 = mainへマージ済み（HEADがmainの祖先） かつ 作業ツリーclean かつ 非稼働（working/waiting/error無し）。
#   注意        = 上記を満たさないworktree。理由（稼働中／エラー／未マージ／未コミット差分）を併記する。
#   main worktree・archived は対象外（スキップ）。git状態を取れない場合は保守側（dirty/未マージ扱い＝候補にしない）。
#
# 使い方: worktree-sweep.sh
#   テスト時は SWEEP_PS_CMD="cat fixture.json"（orca ps差替）・SWEEP_MAIN_REF（マージ基準ブランチ名）で差し替える。
# 依存: orca CLI, git, python3 / macOS bash 3.2互換（indexed arrayのみ）
set -uo pipefail

SWEEP_PS_CMD="${SWEEP_PS_CMD:-orca worktree ps --json}"
SWEEP_MAIN_REF="${SWEEP_MAIN_REF:-main}"       # マージ判定の基準（各repo内でのmainブランチ名）
SWEEP_DOWN_HINT="${SWEEP_DOWN_HINT:-skills/orca-cockpit/scripts/cockpit.sh down --worktree}"

# base64(1引数)を原文へ復元（python3固定・BSD/GNUのbase64フラグ差を避ける）。
_b64d(){ python3 -c 'import sys,base64
sys.stdout.write(base64.b64decode(sys.argv[1]).decode("utf-8","replace"))' "$1"; }

# ---- 判定（純関数・テスト対象。副作用なし） ----
# _classify <merged:0|1> <clean:0|1> <agentflag: idle|empty|active|error>
#   候補条件 = merged=1 かつ clean=1 かつ 非稼働(idle/empty)。1つでも欠けたら "attention:<理由;...>"。
#   merged判定不能は呼び出し側で 0（未マージ扱い）にする＝保守側で候補にしない。
_classify(){
  local merged="$1" clean="$2" flag="$3" reasons=""
  case "$flag" in
    active) reasons="稼働中" ;;
    error)  reasons="エージェントerror" ;;
  esac
  [ "$merged" = "1" ] || reasons="${reasons:+$reasons; }未マージ"
  [ "$clean" = "1" ]  || reasons="${reasons:+$reasons; }未コミット差分"
  if [ -z "$reasons" ]; then printf 'candidate'; else printf 'attention:%s' "$reasons"; fi
}

# ---- ps JSON を parse（main/archived除外・free-textはbase64で運ぶ） ----
# 出力: 1行/worktree = "<b64 path> <b64 repo> <b64 branch> <agentflag> <b64 displayName> <b64 agentlabel>"
_ps_parse(){ python3 -c '
import sys, json, base64
def b64(t): return base64.b64encode((t or "").encode("utf-8")).decode("ascii")
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
wts = ((d.get("result") or {}).get("worktrees")) or []
for w in wts:
    if not isinstance(w, dict): continue
    if w.get("isMainWorktree") or w.get("isArchived"): continue
    path = w.get("path") or ""
    if not path: continue
    repo = w.get("repo") or ""
    branch = w.get("branch") or ""
    if branch.startswith("refs/heads/"): branch = branch[len("refs/heads/"):]
    disp = w.get("displayName") or ""
    agents = [a for a in (w.get("agents") or []) if isinstance(a, dict) and a.get("agentType")]
    states = [((a.get("agentType") or "?"), (a.get("state") or "").strip()) for a in agents]
    if any(s in ("working","waiting") for _,s in states): flag = "active"
    elif any(s in ("error","failed","crashed") for _,s in states): flag = "error"
    elif states: flag = "idle"
    else: flag = "empty"
    label = ", ".join("%s:%s" % (t, s or "?") for t,s in states) or "(agentなし)"
    print(b64(path), b64(repo), b64(branch), flag, b64(disp), b64(label))
'; }

sweep_run(){
  local ps_out
  ps_out="$($SWEEP_PS_CMD 2>/dev/null)"
  if [ -z "$ps_out" ]; then
    echo "== worktree状況 == 取得失敗（orca ps 空・orca不在の可能性）。夜会での手動確認を推奨。"
    return 0
  fi
  local parsed
  parsed="$(printf '%s' "$ps_out" | _ps_parse)"

  # bash 3.2互換: 候補/注意を改行区切りの文字列に貯める
  local cand="" attn="" total=0
  local b_path b_repo b_branch aflag b_disp b_alabel
  while read -r b_path b_repo b_branch aflag b_disp b_alabel; do
    [ -z "${b_path:-}" ] && continue
    total=$((total+1))
    local path repo branch disp alabel clean merged verdict
    path="$(_b64d "$b_path")"; repo="$(_b64d "$b_repo")"; branch="$(_b64d "$b_branch")"
    disp="$(_b64d "$b_disp")"; alabel="$(_b64d "$b_alabel")"

    # 作業ツリーclean判定（git不能=保守側で dirty=0 扱い）
    if git -C "$path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if [ -z "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then clean=1; else clean=0; fi
      # マージ済み判定: HEADが基準ブランチの祖先か（不能=未マージ扱い=0）
      if git -C "$path" merge-base --is-ancestor HEAD "$SWEEP_MAIN_REF" >/dev/null 2>&1; then merged=1; else merged=0; fi
    else
      clean=0; merged=0
    fi

    verdict="$(_classify "$merged" "$clean" "$aflag")"
    if [ "$verdict" = "candidate" ]; then
      cand="${cand}  - ${repo}/${branch}  「${disp}」  [agent: ${alabel}]"$'\n'
      cand="${cand}      down案: ${SWEEP_DOWN_HINT} \"${path}\"   ※未実行・夜会承認後に人間が実行"$'\n'
    else
      attn="${attn}  - ${repo}/${branch}  「${disp}」  理由: ${verdict#attention:}  [agent: ${alabel}]"$'\n'
    fi
  done <<< "$parsed"

  local nc na
  nc="$(printf '%s' "$cand" | grep -c 'down案:' 2>/dev/null)"; nc="${nc:-0}"
  na="$(printf '%s' "$attn" | grep -c '理由:' 2>/dev/null)"; na="${na:-0}"

  echo "== worktree状況（対象${total}本 / 検知のみ・down/削除は人間ゲート） =="
  echo "[クローズ候補 ${nc}本] マージ済み・clean・非稼働"
  if [ "$nc" -gt 0 ]; then printf '%s' "$cand"; else echo "  （なし）"; fi
  echo "[注意 ${na}本] 未マージ / 未コミット差分 / 稼働中・error のいずれか"
  if [ "$na" -gt 0 ]; then printf '%s' "$attn"; else echo "  （なし）"; fi
  echo "※ main worktree・archived は集計対象外。実行は必ず夜会での人間承認後。"
}

# 直接実行時のみscanを走らせる（テストは source して _classify を単体で叩く）。
if [ "${BASH_SOURCE[0]}" = "${0:-}" ]; then
  sweep_run
fi
