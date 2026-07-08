#!/usr/bin/env bash
# daily-notion-sync / parse-daily.sh — 当日デイリーMDの2節を解析しTSVで出す。
# board.py（hooks-registry/hooks/session-board/board.py）のLINE_RE・入れ子構造と同型の解析。
# 日本語・絵文字を含む行の完全一致判定はPython側で行う（bash/awkの多バイト比較は避ける。
# renderer由来 lanes-sync.sh/notion-lanes.sh の onetrueawk 多バイト比較バグの教訓を踏襲）。
#
# usage:
#   parse-daily.sh sessions <daily_md_path>   # TSV: time\trepo\ttype\tsummary\tstate\tkey
#   parse-daily.sh done <daily_md_path>       # TSV: repo\tparent\ttime\tentry
#
# ファイルが存在しない場合は何も出さず終了0（当日デイリー未生成は正常な状態として扱う。
# board.pyが初回イベントで生成するまでの空白期間に相当。呼び出し側が0件として扱う）。
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

# board.py の LINE_RE と同一パターン（正本を割らない・二重定義だが同期は目視で保つ契約）。
LINE_RE = re.compile(
    r'^- (?P<time>\d{2}:\d{2}) \| (?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<summary>.*?) \| '
    r'(?P<state>🟢動作中|⏸停止・確認待ち|🔵サブ稼働中) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')


def section_bounds(header):
    try:
        start = lines.index(header)
    except ValueError:
        return None, None
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
    if start is not None:
        for i in range(start + 1, end):
            m = LINE_RE.match(lines[i])
            if not m:
                continue
            print(tsv(m.group("time"), m.group("repo"), m.group("type"),
                      m.group("summary"), m.group("state"), m.group("key")))

elif cmd == "done":
    start, end = section_bounds(DONE_H)
    if start is not None:
        repo = None
        parent = None
        for i in range(start + 1, end):
            ln = lines[i]
            if ln.startswith("### "):
                repo = ln[len("### "):].strip()
                parent = None
                continue
            if ln.startswith("  - "):
                if repo is None or parent is None:
                    continue
                child = ln[len("  - "):]
                tm, _, entry = child.partition(" ")
                print(tsv(repo, parent, tm, entry))
                continue
            if ln.startswith("- "):
                if repo is None:
                    continue
                parent = ln[len("- "):].strip()
                continue
PYEOF
