"""デイリーMarkdownのpath・parse・描画・排他・原子的書き込み。"""
import contextlib
import datetime
import fcntl
import glob
import os
import re
import tempfile

RUN, WAIT, SUB = "🟢", "⏸", "🔵"
STATE_RANK = {RUN: 0, SUB: 1, WAIT: 2}
RANK_STATE = {v: k for k, v in STATE_RANK.items()}
STATE_WORD = {RUN: "run", WAIT: "wait", SUB: "sub"}
STALE_MIN, STALE_MIN_SUB, STALE_MIN_NOFILE, NOFILE_MAX = 10, 30, 15, 720
PLACEHOLDER = "?"
AGENTS_H, DONE_H = "## 動いているエージェント", "## 終わったこと"
GS_OPEN, GS_CLOSE = "<!-- goals-summary -->", "<!-- /goals-summary -->"
LINE_RE = re.compile(
    r'^\s*- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) \| 計画:(?P<plan>[^|]*?) '
    r'<!-- s:(?P<key>[0-9a-zA-Z-]+)(?: sub:(?P<sub>\d+))? -->\s*$')
V2_LINE_RE = re.compile(
    r'^\s*- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_LINE_RE = re.compile(
    r'^\s*- (?P<time>\d{2}:\d{2}) \| (?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<summary>.*?) \| '
    r'(?P<state>🟢動作中|⏸停止・確認待ち|🔵サブ稼働中) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_STATE = {"🟢動作中": RUN, "⏸停止・確認待ち": WAIT, "🔵サブ稼働中": SUB}
CHILD_RE = re.compile(r'^  - (\d{2}:\d{2})')
PLAN_MARK = " ‹計画:"


def daily_path():
    base = os.environ.get("GOAL_BASE") or os.path.expanduser("~/Private/personal-os/my-brain/ゴール/デイリー")
    date_s = os.environ.get("SESSION_BOARD_DATE") or datetime.datetime.now().strftime("%Y-%m-%d")
    year, month, _ = date_s.split("-")
    return os.path.join(base, year, month, f"{date_s}.md"), date_s


def template_text(date_s):
    template = os.environ.get("SESSION_BOARD_TEMPLATE") or os.path.join(os.path.dirname(os.path.dirname(__file__)), "daily-template.md")
    try:
        text = open(template, encoding="utf-8").read()
    except OSError:
        text = f"# デイリー {{{{DATE}}}}\n\n{AGENTS_H}\n\n{DONE_H}\n"
    return text.replace("{{DATE}}", date_s)


@contextlib.contextmanager
def edit_daily(path, date_s):
    """日付別flock下で読み、正常終了時だけ原子的に置換する。"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lock = open(os.path.join(os.path.dirname(path), "." + os.path.basename(path) + ".lock"), "w")
    fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        text = open(path, encoding="utf-8").read() if os.path.exists(path) else template_text(date_s)
        lines = text.rstrip("\n").split("\n")
        yield lines
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines) + "\n")
            os.replace(tmp, path)
        except Exception:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()


def clean(value):
    return re.sub(r"\s+", " ", value or "").replace("|", "／").strip()


def section_bounds(lines, header):
    try:
        start = lines.index(header)
    except ValueError:
        return None, None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
    return start, end


def parse_line(line):
    match = LINE_RE.match(line)
    if match:
        row = match.groupdict(); row["sub"] = int(row["sub"] or 0); return row
    match = V2_LINE_RE.match(line)
    if match:
        row = match.groupdict(); row.update(plan=PLACEHOLDER, sub=0); return row
    match = OLD_LINE_RE.match(line)
    if match:
        return {"state": OLD_STATE[match.group("state")], "time": match.group("time"),
                "goal": match.group("summary") or PLACEHOLDER, "now": PLACEHOLDER,
                "repo": match.group("repo"), "type": match.group("type"), "who": PLACEHOLDER,
                "plan": PLACEHOLDER, "key": match.group("key"), "sub": 0}
    return None


def fmt(row):
    tail = f" sub:{int(row.get('sub') or 0)}" if int(row.get("sub") or 0) > 0 else ""
    return (f"- {row['state']} {row['time']} | {row['goal']} | 今:{row['now']} | {row['repo']} | "
            f"{row['type']} | {row['who']} | 計画:{row.get('plan') or PLACEHOLDER} <!-- s:{row['key']}{tail} -->")


def find_line(lines, key):
    for index, line in enumerate(lines):
        row = parse_line(line)
        if row and row["key"] == key:
            return index, row
    return None, None


def render_body(lines):
    start, end = section_bounds(lines, AGENTS_H)
    if start is None:
        return lines
    rows, kept, in_summary = [], [], False
    for line in lines[start + 1:end]:
        row = parse_line(line)
        if row:
            rows.append(row); continue
        stripped = line.strip()
        if stripped == GS_OPEN: in_summary = True; continue
        if stripped == GS_CLOSE: in_summary = False; continue
        if in_summary and (stripped.startswith("### ") or stripped.startswith("↳ ")
                           or (re.match(r"- [🟢🔵⏸] ", stripped) and "<!-- s:" not in stripped)):
            continue
        kept.append(line)
    if not rows:
        lines[start + 1:end] = kept; return lines
    best, count = {}, {}
    for row in rows:
        best[row["goal"]] = min(best.get(row["goal"], 9), STATE_RANK.get(row["state"], 9))
        count[row["goal"]] = count.get(row["goal"], 0) + 1
    rows.sort(key=lambda r: (best[r["goal"]], r["goal"], STATE_RANK.get(r["state"], 9), r["time"]))
    body, current = [GS_OPEN, "### 本日の目標"], None
    for row in rows:
        goal = row["goal"]
        if goal != current:
            label = goal if goal != PLACEHOLDER else "目標未記入"
            suffix = f"（{count[goal]}件）" if count[goal] >= 2 else ""
            body.append(f"- {RANK_STATE.get(best[goal], WAIT)} {label}{suffix}"); current = goal
        body.append("  " + fmt(row))
        if int(row.get("sub") or 0) > 0: body.append(f"    ↳ {SUB} サブ{int(row['sub'])}体")
    body.append(GS_CLOSE)
    lines[start + 1:end] = body + kept
    return lines


def tx_roots():
    env = os.environ.get("SESSION_BOARD_TX_ROOTS")
    return [p for p in env.split(":") if p] if env else [os.path.expanduser("~/.claude/projects"), os.path.expanduser("~/.codex/sessions")]


def list_transcripts():
    files = []
    for root in tx_roots():
        try: files += glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
        except OSError: pass
    return files


def newest_for(key, files):
    candidates = [f for f in files if key in f and os.path.exists(f)]
    try: return max(candidates, key=os.path.getmtime) if candidates else None
    except OSError: return None


def minutes_between(t0, t1):
    h0, m0 = map(int, t0.split(":")); h1, m1 = map(int, t1.split(":"))
    delta = (h1 * 60 + m1) - (h0 * 60 + m0)
    return delta + (1440 if delta < 0 else 0)


def reconcile_rows(lines, changed=None, transcript_loader=list_transcripts):
    start, end = section_bounds(lines, AGENTS_H)
    if start is None: return lines
    now_dt, files = datetime.datetime.now(), None
    for index in range(start + 1, end):
        row = parse_line(lines[index])
        if not row or row["state"] not in (RUN, SUB): continue
        if files is None: files = transcript_loader()
        transcript = newest_for(row["key"], files)
        demote = False
        if transcript is None:
            age = minutes_between(row["time"], now_dt.strftime("%H:%M"))
            limit = STALE_MIN_SUB if row["state"] == SUB else STALE_MIN_NOFILE
            demote = bool(files) and limit < age < NOFILE_MAX
        else:
            limit = STALE_MIN_SUB if row["state"] == SUB else STALE_MIN
            try: demote = (now_dt.timestamp() - os.path.getmtime(transcript)) / 60 >= limit
            except OSError: pass
        if demote:
            row.update(state=WAIT, sub=0); lines[index] = fmt(row)
            if changed is not None: changed.append(dict(row))
    return lines


def strip_plan_mark(text):
    index = text.find(PLAN_MARK)
    return text[:index] if index != -1 else text


def fmt_elapsed(minutes):
    if minutes < 1: return ""
    return f"(+{minutes}m)" if minutes < 60 else f"(+{minutes // 60}h{minutes % 60:02d}m)"


def base_time_for(lines, repo, parent, row):
    start, end = section_bounds(lines, DONE_H)
    if start is not None:
        heading = next((i for i in range(start + 1, end) if lines[i].strip() == f"### {repo}"), None)
        if heading is not None:
            block_end = next((i for i in range(heading + 1, end) if lines[i].startswith("### ")), end)
            parent_index = next((i for i in range(heading + 1, block_end) if strip_plan_mark(lines[i].rstrip()) == f"- {parent}"), None)
            if parent_index is not None:
                last = None
                for i in range(parent_index + 1, block_end):
                    if not lines[i].startswith("  "): break
                    match = CHILD_RE.match(lines[i])
                    if match: last = match.group(1)
                if last: return last
    return row["time"] if row else None


def add_children(lines, repo, parent, children):
    if DONE_H not in lines: lines += ["", DONE_H]
    start, end = section_bounds(lines, DONE_H)
    heading = next((i for i in range(start + 1, end) if lines[i].strip() == f"### {repo}"), None)
    if heading is None:
        insert = end
        while insert > start + 1 and not lines[insert - 1].strip(): insert -= 1
        lines.insert(insert, f"### {repo}"); heading = insert
    block_end = next((i for i in range(heading + 1, len(lines)) if lines[i].startswith("### ") or lines[i].startswith("## ")), len(lines))
    parent_index = next((i for i in range(heading + 1, block_end) if strip_plan_mark(lines[i].rstrip()) == f"- {parent}"), None)
    if parent_index is None:
        insert = block_end
        while insert > heading + 1 and not lines[insert - 1].strip(): insert -= 1
        lines.insert(insert, f"- {parent}"); parent_index = insert
    child_end = parent_index + 1
    while child_end < len(lines) and lines[child_end].startswith("  "): child_end += 1
    for offset, child in enumerate(children): lines.insert(child_end + offset, f"  - {child}")
    return lines


def annotate_parent_plan(lines, repo, parent, plan):
    if not plan or plan in (PLACEHOLDER, "なし"): return
    start, end = section_bounds(lines, DONE_H)
    if start is None: return
    heading = next((i for i in range(start + 1, end) if lines[i].strip() == f"### {repo}"), None)
    if heading is None: return
    block_end = next((i for i in range(heading + 1, len(lines)) if lines[i].startswith("### ") or lines[i].startswith("## ")), len(lines))
    for index in range(heading + 1, block_end):
        if strip_plan_mark(lines[index].rstrip()) == f"- {parent}":
            if PLAN_MARK not in lines[index]: lines[index] = f"{lines[index].rstrip()} ‹計画: {plan}›"
            return
