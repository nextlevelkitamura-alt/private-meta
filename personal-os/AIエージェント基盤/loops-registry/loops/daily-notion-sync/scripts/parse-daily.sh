#!/usr/bin/env bash
# daily-notion-sync / parse-daily.sh — 当日デイリーMDの2節を解析しTSVで出す。
# session-board/md/store.py のv3 LINE_RE・入れ子構造と同型の解析。
# 日本語・絵文字を含む行の完全一致判定はPython側で行う（bash/awkの多バイト比較は避ける。
# renderer由来 lanes-sync.sh/notion-lanes.sh の onetrueawk 多バイト比較バグの教訓を踏襲）。
#
# usage:
#   parse-daily.sh sessions <daily_md_path>   # TSV: time\trepo\ttype\tsummary\tstate\tkey
#   parse-daily.sh done <daily_md_path>       # TSV: repo\tparent\ttime\tentry
#
# ファイルが存在しない場合と、対象節が存在する正しい空節は0件・exit 0。
# 見出し欠落、未知行、壊れた入れ子、重複キーは「0件」ではなく解析失敗として非0終了する。
set -uo pipefail

cmd="${1:-}"
path="${2:-}"
case "$cmd" in
  sessions|done) ;;
  *)
    echo "usage: parse-daily.sh <sessions|done> <daily_md_path>" >&2
    exit 2
    ;;
esac

if [ ! -f "$path" ]; then
  exit 0
fi

python3 - "$cmd" "$path" <<'PYEOF'
import re
import sys

cmd, path = sys.argv[1], sys.argv[2]

with open(path, encoding="utf-8") as f:
    lines = f.read().split("\n")

AGENTS_H = "## 動いているエージェント"
DONE_H = "## 終わったこと"

# hooks-registry/shared/session-board/md/store.py の v3 LINE_RE と同一パターン。
# 実装が分離しているため、tests/run-tests.sh が実board.py出力を通してdriftを検出する。
LINE_RE = re.compile(
    r'^\s*- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) \| 計画:(?P<plan>[^|]*?) '
    r'<!-- s:(?P<key>[0-9a-zA-Z-]+)(?: sub:(?P<sub>\d+))? -->\s*$')
STATE_LABEL = {"🟢": "🟢動作中", "⏸": "⏸停止・確認待ち", "🔵": "🔵サブ稼働中"}
GOAL_SUMMARY_RE = re.compile(r'^- (🟢|⏸|🔵) [^|]+(?:（\d+件）)?$')
SUB_SUMMARY_RE = re.compile(r'^\s{4}↳ 🔵 サブ\d+体$')
DONE_CHILD_RE = re.compile(r'^  - (?P<time>\d{2}:\d{2}) (?P<entry>\S.*)$')
PLAN_MARK_RE = re.compile(r'^(?P<parent>.+?) ‹計画: (?P<plan>[^›]+)›$')


def fail(message, line_no=None):
    where = f" ({line_no}行目)" if line_no is not None else ""
    print(f"parse-daily: 解析失敗: {message}{where}", file=sys.stderr)
    raise SystemExit(1)


def section_bounds(header):
    indexes = [i for i, line in enumerate(lines) if line == header]
    if not indexes:
        fail(f"必須見出しがない: {header}")
    if len(indexes) != 1:
        fail(f"必須見出しが重複している: {header}")
    start = indexes[0]
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if lines[j].startswith("## "):
            end = j
            break
    return start, end


def tsv(*fields):
    return "\t".join(f.replace("\t", " ").replace("\n", " ") for f in fields)


if cmd == "sessions":
    start, end = section_bounds(AGENTS_H)
    rows = []
    seen_keys = set()
    in_summary = False
    summary_closed = False
    for i in range(start + 1, end):
        ln = lines[i]
        if not ln.strip():
            continue
        stripped = ln.strip()
        if stripped == "<!-- goals-summary -->":
            if in_summary or summary_closed:
                fail("目標要約の開始マーカーが重複している", i + 1)
            in_summary = True
            continue
        if stripped == "<!-- /goals-summary -->":
            if not in_summary:
                fail("目標要約の終了マーカーに対応する開始がない", i + 1)
            in_summary = False
            summary_closed = True
            continue
        m = LINE_RE.match(ln)
        if m:
            key = m.group("key")
            if key in seen_keys:
                fail(f"セッションキーが重複している: {key}", i + 1)
            seen_keys.add(key)
            rows.append(tsv(m.group("time"), m.group("repo"), m.group("type"),
                            m.group("goal"), STATE_LABEL[m.group("state")], key))
            continue
        if in_summary and (stripped == "### 本日の目標" or GOAL_SUMMARY_RE.fullmatch(stripped)
                           or SUB_SUMMARY_RE.fullmatch(ln)):
            continue
        fail("「動いているエージェント」節に未知の行形式がある", i + 1)
    if in_summary:
        fail("目標要約の終了マーカーがない")
    for row in rows:
        print(row)

elif cmd == "done":
    start, end = section_bounds(DONE_H)
    repo = None
    repo_parent_count = 0
    parent = None
    parent_child_count = 0
    rows = []
    seen_keys = set()

    def validate_parent(line_no=None):
        if parent is not None and parent_child_count == 0:
            fail("親タスクに子成果がない", line_no)

    def validate_repo(line_no=None):
        if repo is not None and repo_parent_count == 0:
            fail("repo見出しに親タスクがない", line_no)

    for i in range(start + 1, end):
        ln = lines[i]
        if not ln.strip():
            continue
        if ln.startswith("### "):
            validate_parent(i + 1)
            validate_repo(i + 1)
            repo = ln[len("### "):].strip()
            if not repo:
                fail("「終わったこと」節のrepo見出しが空", i + 1)
            repo_parent_count = 0
            parent = None
            parent_child_count = 0
            continue
        child = DONE_CHILD_RE.fullmatch(ln)
        if child:
            if repo is None or parent is None:
                fail("子成果にrepoまたは親タスクがない", i + 1)
            fields = (repo, parent, child.group("time"), child.group("entry"))
            key = "|".join(fields)
            if key in seen_keys:
                fail("完了成果キーが重複している", i + 1)
            seen_keys.add(key)
            rows.append(tsv(*fields))
            parent_child_count += 1
            continue
        if ln.startswith("- "):
            if repo is None:
                fail("親タスクにrepo見出しがない", i + 1)
            validate_parent(i + 1)
            raw_parent = ln[len("- "):].strip()
            if "‹計画:" in raw_parent or "›" in raw_parent:
                plan_match = PLAN_MARK_RE.fullmatch(raw_parent)
                if not plan_match:
                    fail("親タスクの計画マーカーが不完全", i + 1)
                parent = plan_match.group("parent").rstrip()
            else:
                parent = raw_parent
            if not parent:
                fail("「終わったこと」節の親タスクが空", i + 1)
            repo_parent_count += 1
            parent_child_count = 0
            continue
        fail("「終わったこと」節に未知の行形式がある", i + 1)
    validate_parent()
    validate_repo()
    for row in rows:
        print(row)
PYEOF
