#!/usr/bin/env python3
# session-board board.py — 当日デイリーボードの行操作（flock付き・冪等）
# 使い方:
#   board.py add    --key K --repo R --type T --summary S [--time HH:MM]
#   board.py update --key K [--repo R] [--type T] [--summary S]
#   board.py flip   --key K --state run|wait|sub   # sub=🔵サブ稼働中（バックグラウンドのサブ実行中）
#   board.py log    --key K --repo R --parent P --entry E [--entry E ...]  # 節目: 終わったことへ入れ子で子を追記(行は消さない)
#   board.py finish --key K --repo R --parent P [--entry E ...]            # 完了: 自行削除＋入れ子で子を追記
#   board.py check  --key K    # stdout: missing|run|wait|sub
# 行末マーカー: <!-- s:KEY -->
# 「終わったこと」の構造（親＝タスク／子＝時刻付き節目・入れ子）:
#   ### repo
#   - 親タスク名
#     - HH:MM 子成果
# env: GOAL_BASE / SESSION_BOARD_DATE(YYYY-MM-DD) / SESSION_BOARD_TEMPLATE（テスト用）
import sys
import os
import re
import fcntl
import datetime
import tempfile

RUN = "🟢動作中"
WAIT = "⏸停止・確認待ち"
SUB = "🔵サブ稼働中"
AGENTS_H = "## 動いているエージェント"
DONE_H = "## 終わったこと"
LINE_RE = re.compile(
    r'^- (?P<time>\d{2}:\d{2}) \| (?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<summary>.*?) \| '
    r'(?P<state>🟢動作中|⏸停止・確認待ち|🔵サブ稼働中) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')


def daily_path():
    base = os.environ.get("GOAL_BASE") or os.path.expanduser(
        "~/Private/personal-os/my-brain/ゴール/デイリー")
    d = os.environ.get("SESSION_BOARD_DATE") or datetime.datetime.now().strftime("%Y-%m-%d")
    y, m, _ = d.split("-")
    return os.path.join(base, y, m, f"{d}.md"), d


def template_text(date_s):
    tpl = os.environ.get("SESSION_BOARD_TEMPLATE") or os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "daily-template.md")
    try:
        t = open(tpl, encoding="utf-8").read()
    except OSError:
        t = "# デイリー {{DATE}}\n\n%s\n\n%s\n" % (AGENTS_H, DONE_H)
    return t.replace("{{DATE}}", date_s)


def parse_args(argv):
    cmd, args, entries = argv[0], {}, []
    i = 1
    while i < len(argv):
        k = argv[i]
        if not k.startswith("--"):
            sys.exit(f"unexpected arg: {k}")
        v = argv[i + 1] if i + 1 < len(argv) else ""
        if k == "--entry":
            entries.append(v)
        else:
            args[k[2:]] = v
        i += 2
    return cmd, args, entries


def section_bounds(lines, header):
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


def find_line(lines, key):
    for idx, ln in enumerate(lines):
        m = LINE_RE.match(ln)
        if m and m.group("key") == key:
            return idx, m
    return None, None


def fmt(time_s, repo, type_, summary, state, key):
    return f"- {time_s} | {repo} | {type_} | {summary} | {state} <!-- s:{key} -->"


def add_children(lines, repo, parent, children):
    """「終わったこと」の ### repo > - parent の下に '  - <child>' を最新が上で入れ子挿入。
    repo見出し・親が無ければ作る（最新が上）。"""
    if DONE_H not in lines:
        lines += ["", DONE_H]
    s, _ = section_bounds(lines, DONE_H)
    head = f"### {repo}"
    # repo見出しを DONE セクション内で探す
    _, e = section_bounds(lines, DONE_H)
    hidx = None
    for j in range(s + 1, e):
        if lines[j].strip() == head:
            hidx = j
            break
    if hidx is None:
        lines.insert(s + 1, head)      # 節先頭＝最新repoが上
        hidx = s + 1
    # repo ブロックの終端（次の ### か ## まで）
    bend = len(lines)
    for j in range(hidx + 1, len(lines)):
        if lines[j].startswith("### ") or lines[j].startswith("## "):
            bend = j
            break
    # 親を探す（インデント無しの '- parent'）
    pidx = None
    for j in range(hidx + 1, bend):
        if lines[j].rstrip() == f"- {parent}":
            pidx = j
            break
    if pidx is None:
        lines.insert(hidx + 1, f"- {parent}")   # repo見出し直下＝最新親が上
        pidx = hidx + 1
    # 子を親直下に挿入（最新が上）
    for k2, ch in enumerate(children):
        lines.insert(pidx + 1 + k2, f"  - {ch}")
    return lines


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: board.py <add|update|flip|finish|log|check> ...")
    cmd, args, entries = parse_args(sys.argv[1:])
    key = args.get("key", "").removeprefix("s:")
    if not key:
        sys.exit("--key required")
    path, date_s = daily_path()
    if cmd == "check":   # 読み取り専用: makedirs/lock せず、ファイルが無ければ missing
        if not os.path.exists(path):
            print("missing")
            return
        lines = open(path, encoding="utf-8").read().split("\n")
        idx, m = find_line(lines, key)
        if idx is None:
            print("missing")
        else:
            st = m.group("state")
            print("run" if st == RUN else ("sub" if st == SUB else "wait"))
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # lockはdot-prefixで不可視に（0バイト・flock用。日付ごとに1個でき、消さないのが安全）
    lock = open(os.path.join(os.path.dirname(path), "." + os.path.basename(path) + ".lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        text = open(path, encoding="utf-8").read() if os.path.exists(path) else template_text(date_s)
        lines = text.rstrip("\n").split("\n")
        for h in (AGENTS_H, DONE_H):   # 節が無ければ末尾に足す（既存本文は壊さない）
            if h not in lines:
                lines += ["", h]
        idx, m = find_line(lines, key)
        now = datetime.datetime.now().strftime("%H:%M")

        if cmd == "add":
            t = args.get("time") or now
            repo, type_ = args.get("repo", "?"), args.get("type", "その他")
            summary = args.get("summary", "")
            if idx is not None:        # 冪等: 既存行は上書き（時刻は既存を維持）
                lines[idx] = fmt(m.group("time"), repo, type_, summary, m.group("state"), key)
            else:
                s, e = section_bounds(lines, AGENTS_H)
                ins = e
                while ins > s + 1 and lines[ins - 1].strip() == "":
                    ins -= 1
                lines.insert(ins, fmt(t, repo, type_, summary, RUN, key))
        elif cmd == "update":
            if idx is None:
                sys.exit(f"line not found for key {key}")
            lines[idx] = fmt(m.group("time"), args.get("repo", m.group("repo")),
                             args.get("type", m.group("type")),
                             args.get("summary", m.group("summary")), m.group("state"), key)
        elif cmd == "flip":
            if idx is None:
                return                 # 行が無ければ何もしない（non-blocking）
            sv = args.get("state")
            if sv not in ("run", "wait", "sub"):
                return             # 未知の --state は無変更（打ち間違いで⏸/🟢に誤って落とさない）
            state = RUN if sv == "run" else (SUB if sv == "sub" else WAIT)
            lines[idx] = fmt(m.group("time"), m.group("repo"), m.group("type"),
                             m.group("summary"), state, key)
        elif cmd == "log":
            repo = args.get("repo") or (m.group("repo") if m else "?")
            parent = args.get("parent") or args.get("summary") or (m.group("summary") if m else "作業")
            t = args.get("time") or now
            add_children(lines, repo, parent, [f"{t} {en}" for en in entries])
        elif cmd == "finish":
            repo = args.get("repo") or (m.group("repo") if m else "?")
            parent = args.get("parent") or args.get("summary") or (m.group("summary") if m else "作業")
            t = args.get("time") or now
            if idx is not None:
                del lines[idx]
            add_children(lines, repo, parent, [f"{t} {en}" for en in entries])
        else:
            sys.exit(f"unknown command: {cmd}")

        out = "\n".join(lines) + "\n"
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(out)
        os.replace(tmp, path)
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


if __name__ == "__main__":
    main()
