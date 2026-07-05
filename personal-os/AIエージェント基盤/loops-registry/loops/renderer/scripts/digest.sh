#!/usr/bin/env bash
# renderer / digest.sh — 当日のrepo別コミットとcockpitレーン段階所要時間を機械集計し、
# claude -p でLLM要約した上で当日デイリーの「## 今日のダイジェスト」(auto:digest)区画へ冪等書込む。
# usage: digest.sh [YYYY-MM-DD]
#   YYYY-MM-DD  省略時は実行時点のJST当日。
#
# 12:30/18:30/23:30の3回、daily-digest/scripts/run.sh経由でlaunchdから呼ばれる想定（--snapshot時も
# --final時も同じロジックを実行する。冪等＝auto:digest区画は毎回全置換）。
# 失敗時（デイリー不在・LLM失敗・イベント集計失敗等）は警告をstderrへ出しexit 0で終わる
# （本流のrun.sh/render.shを止めない）。secretの値は一切出力しない。
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DAILY_DIGEST_SCRIPTS="$(cd "$SCRIPT_DIR/../../daily-digest/scripts" && pwd)"
# shellcheck source=/dev/null
source "$DAILY_DIGEST_SCRIPTS/_paths.sh"

date_str="${1:-}"
[ -n "$date_str" ] || date_str="$(TZ=Asia/Tokyo date '+%Y-%m-%d')"

daily_file="$(daily_file_for "$date_str")"
set_marker="$DAILY_DIGEST_SCRIPTS/set-marker-block.sh"

: "${DIGEST_EVENTS_FILE:=$HOME/Private/personal-os/AIエージェント基盤/skills/orca-cockpit/state/events.jsonl}"
: "${DIGEST_REPO_OVERVIEW:=$HOME/Private/personal-os/AIエージェント基盤/repo-registry/repo概要.md}"
: "${DIGEST_LLM_CMD:=claude -p --model claude-sonnet-5}"
# 対象repo固定リスト（pathはenvで個別差替可・テスト用）。ラベルは固定4本。
: "${DIGEST_REPO_PATH_AIKIBAN:=$HOME/Private/personal-os/AIエージェント基盤}"
: "${DIGEST_REPO_PATH_PRIVATE:=$HOME/Private}"
: "${DIGEST_REPO_PATH_SHIGOTO:=$HOME/Private/projects/active/仕事}"
: "${DIGEST_REPO_PATH_FOCUSMAP:=$HOME/Private/projects/active/focusmap}"

warn() { echo "警告: $1" >&2; }

if [ ! -f "$daily_file" ]; then
  warn "デイリーファイルが無いためdigestをスキップ: $daily_file"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/digest.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# --- (1) repo別 git log 集計（件数+subject列挙。決定的・非AI） ---
# 対象は固定4repo＋当日cockpitイベントに現れたworktree（計画§データ源）。
REPO_LABELS=("AIエージェント基盤" "Private" "仕事" "focusmap")
REPO_PATHS=("$DIGEST_REPO_PATH_AIKIBAN" "$DIGEST_REPO_PATH_PRIVATE" "$DIGEST_REPO_PATH_SHIGOTO" "$DIGEST_REPO_PATH_FOCUSMAP")
REPO_SUBJECT_LIMIT=20

# 固定4repoのいずれかと同一パス（末尾スラッシュ差は無視）かどうか。当日イベント由来worktreeの
# 二重集計を避けるために使う。
is_fixed_repo_path() {
  local candidate="${1%/}" i=0 fixed
  while [ "$i" -lt "${#REPO_PATHS[@]}" ]; do
    fixed="${REPO_PATHS[$i]%/}"
    [ "$candidate" = "$fixed" ] && return 0
    i=$((i + 1))
  done
  return 1
}

# stdoutへ「[repo] label」「コミット: N件」「- subject」…のブロックを1個出す。
# $date_str（外側スコープ）を参照する。`.git`はworktree（git worktree add由来）だとファイル、
# 通常repoだとディレクトリなので `-e` で両方を許容する（`-d`だとworktreeを常に「無い」扱いしてしまう）。
repo_section() {
  local label="$1" path="$2"
  if [ ! -e "$path/.git" ]; then
    printf '[repo] %s\nコミット: 取得不可（repoパス無し: %s）\n' "$label" "$path"
    return 0
  fi
  local subjects count shown
  subjects="$(git -C "$path" log --since="${date_str} 00:00:00 +0900" --until="${date_str} 23:59:59 +0900" --pretty=%s 2>/dev/null || true)"
  if [ -z "$subjects" ]; then
    printf '[repo] %s\nコミット: 0件\n' "$label"
    return 0
  fi
  count="$(printf '%s\n' "$subjects" | grep -c .)"
  printf '[repo] %s\nコミット: %s件\n' "$label" "$count"
  shown="$(printf '%s\n' "$subjects" | head -n "$REPO_SUBJECT_LIMIT")"
  printf '%s\n' "$shown" | sed 's/^/- /'
  if [ "$count" -gt "$REPO_SUBJECT_LIMIT" ]; then
    printf -- '- …ほか%d件\n' "$((count - REPO_SUBJECT_LIMIT))"
  fi
}

repo_agg="$work/repo-agg.txt"
: > "$repo_agg"
idx=0
while [ "$idx" -lt "${#REPO_LABELS[@]}" ]; do
  repo_section "${REPO_LABELS[$idx]}" "${REPO_PATHS[$idx]}" >> "$repo_agg"
  echo >> "$repo_agg"
  idx=$((idx + 1))
done

# --- (2) cockpit段階イベント集計（当日(JST)行のみ・レーンごとの段階遷移と所要時間(分)） ---
# COCKPIT_EVENTS_FILEが無い/壊れていてもレーン0件として扱う（best-effort・非致命）。
collect_events_agg() {
  python3 - "$DIGEST_EVENTS_FILE" "$date_str" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone

events_file, target_date = sys.argv[1], sys.argv[2]
JST = timezone(timedelta(hours=9))


def to_jst(ts):
    dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return dt.astimezone(JST)


lanes = {}
try:
    with open(events_file, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                ev = json.loads(raw)
            except Exception:
                continue
            if not isinstance(ev, dict):
                continue
            ts = ev.get("ts")
            worktree = ev.get("worktree")
            if not ts or not worktree:
                continue
            try:
                dt = to_jst(ts)
            except Exception:
                continue
            if dt.strftime("%Y-%m-%d") != target_date:
                continue
            lanes.setdefault(worktree, []).append((dt, ev.get("event"), ev.get("stage"), ev.get("branch")))
except FileNotFoundError:
    pass

lane_worktrees = sorted(lanes.keys())
completed = 0
lines = []
for wt in lane_worktrees:
    evs = sorted(lanes[wt], key=lambda x: x[0])
    label = wt.rstrip("/").split("/")[-1] or wt
    branch = next((b for _, _, _, b in evs if b), None)
    closed_at = None
    for dt, kind, _stage, _branch in evs:
        if kind == "down":
            closed_at = dt
    if closed_at is not None:
        completed += 1
    stage_events = [(dt, stage) for dt, kind, stage, _branch in evs if kind == "send" and stage]
    seg_strs = []
    for i, (dt, stage) in enumerate(stage_events):
        end_dt = stage_events[i + 1][0] if i + 1 < len(stage_events) else closed_at
        if end_dt is not None:
            mins = max(0, round((end_dt - dt).total_seconds() / 60))
            seg_strs.append("%s(%d分)" % (stage, mins))
        else:
            seg_strs.append("%s(進行中)" % stage)
    detail = "→".join(seg_strs) if seg_strs else "段階イベント無し"
    line = label
    if branch:
        line += "（%s）" % branch
    line += ": %s" % detail
    lines.append(line)

total = len(lane_worktrees)
in_progress = total - completed
print("レーン%d本（%d完了・%d進行中）" % (total, completed, in_progress))
for l in lines:
    print(l)
print("###WORKTREES###")
for wt in lane_worktrees:
    print(wt)
PY
}

events_agg="$work/events-agg.txt"
worktrees_file="$work/today-worktrees.txt"
: > "$worktrees_file"
if command -v python3 >/dev/null 2>&1; then
  if collect_events_agg > "$work/events-raw.txt" 2>"$work/events.err"; then
    sed '/^###WORKTREES###$/,$d' "$work/events-raw.txt" > "$events_agg"
    sed -n '/^###WORKTREES###$/,$p' "$work/events-raw.txt" | tail -n +2 > "$worktrees_file"
  else
    warn "イベント集計に失敗（レーン所要時間はダイジェストに含めない）: $(tr '\n' ' ' < "$work/events.err" 2>/dev/null)"
    printf 'レーン0本（集計失敗）\n' > "$events_agg"
  fi
else
  warn "python3が無いためイベント集計をスキップ"
  printf 'レーン0本（python3無し）\n' > "$events_agg"
fi

# --- (1b) 当日イベントに現れたworktreeをrepo別集計へ追加 ---
# 固定4repoと同一パスのものは除外（二重集計防止）。既に消えているフォルダーパスは
# 警告なし・出力なしで完全にスキップする（レーン終了後のworktree削除は正常な運用のため）。
if [ -s "$worktrees_file" ]; then
  while IFS= read -r wt; do
    [ -n "$wt" ] || continue
    is_fixed_repo_path "$wt" && continue
    [ -e "$wt/.git" ] || continue
    repo_section "$(basename "$wt")" "$wt" >> "$repo_agg"
    echo >> "$repo_agg"
  done < "$worktrees_file"
fi

# --- (3) 機械集計のとりまとめ ---
machine_agg="$work/machine-agg.txt"
{
  echo "=== repo別（${date_str}） ==="
  cat "$repo_agg"
  echo "=== レーン段階所要時間（cockpit・${date_str}） ==="
  cat "$events_agg"
} > "$machine_agg"

repo_overview=""
[ -f "$DIGEST_REPO_OVERVIEW" ] && repo_overview="$(cat "$DIGEST_REPO_OVERVIEW")"

# --- (4) LLM要約（失敗時は機械集計だけの素朴なダイジェストへフォールバック） ---
prompt_file="$work/prompt.txt"
{
  echo "あなたはpersonal-os運用のデイリーダイジェスト生成器です。以下の${date_str}分の機械集計をもとに、日本語で簡潔なダイジェストを書いてください。"
  echo "出力形式: repoごとに1〜2行（コミット内容の要旨）、続けて全体1行、最後にレーン所要時間の短い箇条書き。マークダウン見出しは付けず「- 」の箇条書き中心で。前置き・後書きの説明文・コードブロックは書かない。"
  echo
  echo "## repo概要（各repoが何をしている場所かの前提）"
  if [ -n "$repo_overview" ]; then
    printf '%s\n' "$repo_overview"
  else
    echo "(repo概要.md未整備)"
  fi
  echo
  echo "## 機械集計"
  cat "$machine_agg"
} > "$prompt_file"

digest_body=""
llm_ok=0
if llm_out="$($DIGEST_LLM_CMD < "$prompt_file" 2>"$work/llm.err")" && [ -n "$llm_out" ]; then
  digest_body="$llm_out"
  llm_ok=1
else
  warn "LLM要約に失敗したため機械集計のみのダイジェストへフォールバック: $(tr '\n' ' ' < "$work/llm.err" 2>/dev/null)"
fi

content_file="$work/digest-content.txt"
if [ "$llm_ok" -eq 1 ]; then
  printf '%s\n' "$digest_body" > "$content_file"
else
  {
    echo "- [auto] LLM要約に失敗したため機械集計のみを表示（${date_str}）。"
    while IFS= read -r line; do
      case "$line" in
        "") continue ;;
        "[repo] "*) echo "- [auto] ${line#'[repo] '}" ;;
        *) echo "  ${line}" ;;
      esac
    done < "$repo_agg"
    first=1
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      if [ "$first" -eq 1 ]; then
        echo "- [auto] ${line}"
        first=0
      else
        echo "  - ${line}"
      fi
    done < "$events_agg"
  } > "$content_file"
fi

# --- (5) 「## 今日のダイジェスト」節が無ければ「## 今日終わったこと」の直前に節ごと挿入 ---
if ! grep -qE '^<!-- auto:digest:begin' "$daily_file" 2>/dev/null; then
  if grep -qE '^## 今日終わったこと' "$daily_file" 2>/dev/null; then
    section_tmp="$(mktemp "${daily_file}.tmp.XXXXXX")"
    awk '
      BEGIN { inserted = 0 }
      /^## 今日終わったこと/ && inserted == 0 {
        print "## 今日のダイジェスト"
        print "<!-- auto:digest:begin — renderer: 当日のrepo別コミット/レーン段階を自動要約。人間はマーカー外に書く -->"
        print "<!-- auto:digest:end -->"
        print ""
        inserted = 1
      }
      { print }
    ' "$daily_file" > "$section_tmp" && mv "$section_tmp" "$daily_file"
  else
    warn "挿入先見出し '## 今日終わったこと' が無いため auto:digest 節を追加できない: $daily_file"
  fi
fi

# --- (6) auto:digest区画へ冪等書込 ---
"$set_marker" "$daily_file" digest "$content_file" >/dev/null
rc=$?
if [ "$rc" -eq 3 ]; then
  warn "auto:digest マーカーが無いため更新をスキップ: $daily_file"
elif [ "$rc" -ne 0 ]; then
  warn "set-marker-block.sh が失敗した(rc=$rc): $daily_file"
fi

exit 0
