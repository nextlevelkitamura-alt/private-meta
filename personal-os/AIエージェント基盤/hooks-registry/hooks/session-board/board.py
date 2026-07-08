#!/usr/bin/env python3
# session-board board.py — 当日デイリーボードの行操作（flock付き・冪等）
# 使い方:
#   board.py add    --key K --repo R [--type T] [--goal G] [--now N] [--who W] [--plan P] [--time HH:MM]
#                   # 既存行があれば何もしない（枠のみ・内容を上書きしない）。--plan 既定は ?
#   board.py update --key K [--repo R] [--type T] [--goal G] [--now N] [--model M] [--who W] [--plan P]
#                   # --summary は --goal の別名（旧互換）。--model は who の「/」以降だけ置換
#                   # --plan は拠り所/置き先の計画（?＝未記入・なし＝サクッと宣言・短縮参照）
#   board.py flip   --key K --state run|wait|sub   # sub=🔵（バックグラウンドのサブ実行中）
#   board.py log    --key K --repo R --parent P --entry E [--entry E ...]  # 節目: 入れ子で子を追記
#   board.py finish --key K --repo R --parent P [--entry E ...]            # 完了: 自行削除＋子を追記
#   board.py reconcile         # 🟢/🔵を実体トランスクリプトで照合し沈黙(🟢≥10分/🔵≥30分)を⏸へ
#   board.py check  --key K    # stdout: missing|run|wait|sub
#   board.py show   --key K    # stdout: state/goal/now/type/repo/who/plan のタブ区切り7列（無ければ "missing"）
#   board.py goals             # stdout: 現在の目標一覧（重複なし・未記入除外・表示順）
# 行フォーマット v2.2（2026-07-08〜・状態絵文字先頭の2列ボード＋計画参照列）:
#   - 🟢 HH:MM | <目標> | 今:<今> | <repo> | <種別> | <runtime/model> | 計画:<計画> <!-- s:KEY -->
#   計画値の語彙: ?＝未記入(催促対象)／なし＝サクッと作業の宣言／短縮参照＝企画名[/NN]・ai運用:企画名[/NN]。
#   v2（計画列なし）・v1（旧1要約列・状態語末尾）は読み取り互換。書き込みは常に v2.2（全書き込みで自然移行）。
# 「終わったこと」の構造（親＝目標名／子＝時刻＋所要(+Nm)付き節目・入れ子）:
#   ### repo
#   - 親タスク名
#     - HH:MM (+38m) 子成果
# goals-summary: 「動いているエージェント」節の先頭に目的別集計を自動再生成（手で編集しない）:
#   <!-- goals-summary --> … <!-- /goals-summary -->
# env: GOAL_BASE / SESSION_BOARD_DATE(YYYY-MM-DD) / SESSION_BOARD_TEMPLATE / SESSION_BOARD_TX_ROOTS
import sys
import os
import re
import glob
import fcntl
import datetime
import tempfile

RUN = "🟢"
WAIT = "⏸"
SUB = "🔵"
STATE_RANK = {RUN: 0, SUB: 1, WAIT: 2}   # 表示順: 🟢動作中 → 🔵サブ → ⏸停止確認待ち
STATE_WORD = {RUN: "run", WAIT: "wait", SUB: "sub"}
STALE_MIN = 10        # 🟢: 実体トランスクリプトがN分超沈黙なら死体→⏸へ降格
STALE_MIN_SUB = 30    # 🔵: サブ委託は長引くので閾値を緩く（実体照合はサブのファイルも見る）
PLACEHOLDER = "?"     # goal/now/who の未記入プレースホルダ（AIが update で正す）
AGENTS_H = "## 動いているエージェント"
DONE_H = "## 終わったこと"
GS_OPEN = "<!-- goals-summary -->"
GS_CLOSE = "<!-- /goals-summary -->"
LINE_RE = re.compile(   # v2.2: who の後に「| 計画:<計画>」を持つ現行フォーマット
    r'^- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) \| 計画:(?P<plan>[^|]*?) '
    r'<!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
V2_LINE_RE = re.compile(   # v2: 計画列なし（読み互換・parse_line で plan=? を補完・書き込みで v2.2 へ移行）
    r'^- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_LINE_RE = re.compile(
    r'^- (?P<time>\d{2}:\d{2}) \| (?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<summary>.*?) \| '
    r'(?P<state>🟢動作中|⏸停止・確認待ち|🔵サブ稼働中) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_STATE = {"🟢動作中": RUN, "⏸停止・確認待ち": WAIT, "🔵サブ稼働中": SUB}
CHILD_RE = re.compile(r'^  - (\d{2}:\d{2})')
PLAN_MARK = " ‹計画:"   # log/finish が親行末尾へ転記する計画マーカーの開始（先勝ち・親照合で無視）


def strip_plan_mark(text):
    """親行本体から末尾の ' ‹計画: …›' を除いた文字列（転記後も親行を同一視するため）。"""
    i = text.find(PLAN_MARK)
    return text[:i] if i != -1 else text


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


def clean(s):
    """列区切り・行構造を壊す文字を無害化（AIが直接叩く時の保護）。"""
    return re.sub(r"\s+", " ", s or "").replace("|", "／").strip()


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


def parse_line(ln):
    """ボード行を dict（state/time/goal/now/repo/type/who/plan/key）に。v2.2/v2/v1 を読む。"""
    m = LINE_RE.match(ln)          # v2.2（計画列あり）
    if m:
        return m.groupdict()
    m = V2_LINE_RE.match(ln)       # v2（計画列なし）: plan=? を補って読む
    if m:
        r = m.groupdict()
        r["plan"] = PLACEHOLDER
        return r
    m = OLD_LINE_RE.match(ln)      # v1（旧1要約列・状態語末尾）
    if m:
        return {"state": OLD_STATE[m.group("state")], "time": m.group("time"),
                "goal": m.group("summary") or PLACEHOLDER, "now": PLACEHOLDER,
                "repo": m.group("repo"), "type": m.group("type"),
                "who": PLACEHOLDER, "plan": PLACEHOLDER, "key": m.group("key")}
    return None


def fmt(r):
    plan = r.get("plan") or PLACEHOLDER
    return (f"- {r['state']} {r['time']} | {r['goal']} | 今:{r['now']} | "
            f"{r['repo']} | {r['type']} | {r['who']} | 計画:{plan} <!-- s:{r['key']} -->")


def find_line(lines, key):
    for idx, ln in enumerate(lines):
        r = parse_line(ln)
        if r and r["key"] == key:
            return idx, r
    return None, None


def strip_summary(lines):
    """『動いているエージェント』節内の goals-summary ブロックを除去（再生成の前段）。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    i0 = i1 = None
    for j in range(s + 1, e):
        if lines[j].strip() == GS_OPEN and i0 is None:
            i0 = j
        elif lines[j].strip() == GS_CLOSE:
            i1 = j
            break
    if i0 is not None and i1 is not None and i1 >= i0:
        del lines[i0:i1 + 1]
    return lines


def sort_agents(lines):
    """行を「目標グループ（生存優先）→ 目標 → 状態 → 時刻」で整列。同じ目的が隣接する。
    行以外（見出し・summary・空行）の位置は保ち、行スロットにだけ書き戻す（非破壊）。
    書き戻しは fmt()＝新形式なので、旧形式行はここで自然移行する。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    slots, rows = [], []
    for j in range(s + 1, e):
        r = parse_line(lines[j])
        if r:
            slots.append(j)
            rows.append(r)
    best = {}
    for r in rows:   # 目標グループの代表rank＝グループ内で最も生きている状態
        rk = STATE_RANK.get(r["state"], 9)
        best[r["goal"]] = min(best.get(r["goal"], 9), rk)
    rows.sort(key=lambda r: (best[r["goal"]], r["goal"],
                             STATE_RANK.get(r["state"], 9), r["time"]))
    for pos, r in zip(slots, rows):
        lines[pos] = fmt(r)
    return lines


def rebuild_summary(lines):
    """節先頭に目的別集計（- <目標> — N体（🟢x 🔵y ⏸z））を再生成。行が無ければ出さない。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    rows = [r for j in range(s + 1, e) if (r := parse_line(lines[j]))]
    if not rows:
        return lines
    order, agg = [], {}
    for r in rows:   # sort_agents 後の出現順＝表示順
        g = r["goal"]
        if g not in agg:
            agg[g] = {RUN: 0, SUB: 0, WAIT: 0}
            order.append(g)
        agg[g][r["state"]] = agg[g].get(r["state"], 0) + 1
    block = [GS_OPEN]
    for g in order:
        c = agg[g]
        n = sum(c.values())
        parts = " ".join(f"{st}{c[st]}" for st in (RUN, SUB, WAIT) if c.get(st))
        label = g if g != PLACEHOLDER else "（目標未記入）"
        block.append(f"- {label} — {n}体（{parts}）")
    block.append(GS_CLOSE)
    lines[s + 1:s + 1] = block
    return lines


def _tx_roots():
    """トランスクリプト探索の根。テスト/移設用に SESSION_BOARD_TX_ROOTS（:区切り）で差し替え可。"""
    env = os.environ.get("SESSION_BOARD_TX_ROOTS")
    if env:
        return [p for p in env.split(":") if p]
    return [os.path.expanduser("~/.claude/projects"),   # Claude: <cwd>/<uuid>.jsonl
            os.path.expanduser("~/.codex/sessions")]     # Codex: rollout-*-<uuid>-*.jsonl
    # Claude のサブエージェント実体は <cwd>/<uuid>/subagents/agent-*.jsonl（親uuidはパス側）


def _list_transcripts():
    """全 runtime のトランスクリプト .jsonl を1回だけ列挙（ツリー走査は per-row でなく1回）。"""
    files = []
    for r in _tx_roots():
        try:
            files += glob.glob(os.path.join(r, "**", "*.jsonl"), recursive=True)
        except OSError:
            pass
    return files


def _newest_for(key, files):
    """パスに key（sid先頭8字）を含む .jsonl のうち最新mtimeのもの。無ければ None。
    basename でなく**パス全体**を見る: サブエージェント実体（<親uuid>/subagents/agent-*.jsonl）の
    書き込みを親の生存として数えるため（🔵の誤降格防止・2026-07-08）。8字hexの偶然一致は実用上無視できる。"""
    cand = [f for f in files if key in f and os.path.exists(f)]
    if not cand:
        return None
    try:
        return max(cand, key=os.path.getmtime)
    except OSError:
        return None


def reconcile_rows(lines):
    """🟢/🔵の各行を実体トランスクリプトの最終更新で照合し、閾値超の沈黙は⏸へ降格
    （🟢=STALE_MIN・🔵=STALE_MIN_SUB）。実体が見つからない行は判定不能として触らない。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    now = datetime.datetime.now().timestamp()
    files = None
    for j in range(s + 1, e):
        r = parse_line(lines[j])
        if not r or r["state"] not in (RUN, SUB):
            continue
        if files is None:                 # 遅延: 🟢/🔵が1つも無ければツリーを走査しない
            files = _list_transcripts()
        f = _newest_for(r["key"], files)
        if f is None:
            continue
        limit = STALE_MIN_SUB if r["state"] == SUB else STALE_MIN
        try:
            if (now - os.path.getmtime(f)) / 60 >= limit:
                r["state"] = WAIT
                lines[j] = fmt(r)
        except OSError:
            continue
    return lines


def _minutes_between(t0, t1):
    h0, m0 = map(int, t0.split(":"))
    h1, m1 = map(int, t1.split(":"))
    d = (h1 * 60 + m1) - (h0 * 60 + m0)
    return d + (1440 if d < 0 else 0)   # 負差は日跨ぎとみなし +24h


def _fmt_elapsed(mins):
    if mins < 1:
        return ""
    if mins < 60:
        return f"(+{mins}m)"
    return f"(+{mins // 60}h{mins % 60:02d}m)"


def _base_time_for(lines, repo, parent, row):
    """(+Nm) の基準時刻: 同じ親の直前の子（最新＝親直下の最初の子）→ 無ければセッション行の開始時刻。"""
    s, e = section_bounds(lines, DONE_H)
    if s is not None:
        head = f"### {repo}"
        hidx = None
        for j in range(s + 1, e):
            if lines[j].strip() == head:
                hidx = j
                break
        if hidx is not None:
            bend = e
            for j in range(hidx + 1, e):
                if lines[j].startswith("### "):
                    bend = j
                    break
            pidx = None
            for j in range(hidx + 1, bend):
                if strip_plan_mark(lines[j].rstrip()) == f"- {parent}":
                    pidx = j
                    break
            if pidx is not None and pidx + 1 < bend:
                m = CHILD_RE.match(lines[pidx + 1])
                if m:
                    return m.group(1)
    return row["time"] if row else None


def add_children(lines, repo, parent, children):
    """「終わったこと」の ### repo > - parent の下に '  - <child>' を最新が上で入れ子挿入。
    repo見出し・親が無ければ作る（最新が上）。"""
    if DONE_H not in lines:
        lines += ["", DONE_H]
    s, _ = section_bounds(lines, DONE_H)
    head = f"### {repo}"
    _, e = section_bounds(lines, DONE_H)
    hidx = None
    for j in range(s + 1, e):
        if lines[j].strip() == head:
            hidx = j
            break
    if hidx is None:
        lines.insert(s + 1, head)      # 節先頭＝最新repoが上
        hidx = s + 1
    bend = len(lines)
    for j in range(hidx + 1, len(lines)):
        if lines[j].startswith("### ") or lines[j].startswith("## "):
            bend = j
            break
    pidx = None
    for j in range(hidx + 1, bend):
        if strip_plan_mark(lines[j].rstrip()) == f"- {parent}":
            pidx = j
            break
    if pidx is None:
        lines.insert(hidx + 1, f"- {parent}")   # repo見出し直下＝最新親が上
        pidx = hidx + 1
    for k2, ch in enumerate(children):
        lines.insert(pidx + 1 + k2, f"  - {ch}")
    return lines


def annotate_parent_plan(lines, repo, parent, plan):
    """log/finish: 自行の計画値が参照（?/なし 以外）なら ### repo > - parent 行の末尾へ
    ' ‹計画: <plan>›' を付与。既に ‹計画: を含む親行には付けない（先勝ち・重複禁止）。
    add_children の直後に呼ぶ（対象親行は必ず存在する）。"""
    if not plan or plan in (PLACEHOLDER, "なし"):
        return
    s, e = section_bounds(lines, DONE_H)
    if s is None:
        return
    head = f"### {repo}"
    hidx = None
    for j in range(s + 1, e):
        if lines[j].strip() == head:
            hidx = j
            break
    if hidx is None:
        return
    bend = len(lines)
    for j in range(hidx + 1, len(lines)):
        if lines[j].startswith("### ") or lines[j].startswith("## "):
            bend = j
            break
    for j in range(hidx + 1, bend):
        if strip_plan_mark(lines[j].rstrip()) == f"- {parent}":
            if PLAN_MARK not in lines[j]:
                lines[j] = f"{lines[j].rstrip()} ‹計画: {plan}›"
            return


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: board.py <add|update|flip|finish|log|check|show|goals|reconcile> ...")
    cmd, args, entries = parse_args(sys.argv[1:])
    key = args.get("key", "").removeprefix("s:")
    if not key and cmd not in ("reconcile", "goals"):
        sys.exit("--key required")
    path, date_s = daily_path()

    if cmd in ("check", "show", "goals"):   # 読み取り専用: makedirs/lock しない
        if not os.path.exists(path):
            if cmd != "goals":
                print("missing")
            return
        lines = open(path, encoding="utf-8").read().split("\n")
        if cmd == "goals":
            s, e = section_bounds(lines, AGENTS_H)
            seen = []
            if s is not None:
                for j in range(s + 1, e):
                    r = parse_line(lines[j])
                    if r and r["goal"] != PLACEHOLDER and r["goal"] not in seen:
                        seen.append(r["goal"])
            for g in seen:
                print(g)
            return
        idx, r = find_line(lines, key)
        if idx is None:
            print("missing")
        elif cmd == "check":
            print(STATE_WORD.get(r["state"], "wait"))
        else:
            print("\t".join([STATE_WORD.get(r["state"], "wait"), r["goal"], r["now"],
                             r["type"], r["repo"], r["who"], r.get("plan") or PLACEHOLDER]))
        return

    if cmd == "reconcile" and not os.path.exists(path):
        return   # ボード未作成なら掃除対象なし（空ファイルを作らない）
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
        idx, row = find_line(lines, key) if key else (None, None)
        now = datetime.datetime.now().strftime("%H:%M")

        if cmd == "add":
            if idx is None:            # 冪等: 既存行があれば何もしない（枠のみ・内容を守る）
                r = {"state": RUN, "time": args.get("time") or now,
                     "goal": clean(args.get("goal") or args.get("summary")) or PLACEHOLDER,
                     "now": clean(args.get("now")) or PLACEHOLDER,
                     "repo": clean(args.get("repo")) or "?",
                     "type": clean(args.get("type")) or "その他",
                     "who": clean(args.get("who")) or PLACEHOLDER,
                     "plan": clean(args.get("plan")) or PLACEHOLDER, "key": key}
                s, e = section_bounds(lines, AGENTS_H)
                ins = e
                while ins > s + 1 and lines[ins - 1].strip() == "":
                    ins -= 1
                lines.insert(ins, fmt(r))
        elif cmd == "update":
            if idx is None:
                sys.exit(f"line not found for key {key}")
            if "goal" in args or "summary" in args:
                row["goal"] = clean(args.get("goal") or args.get("summary")) or PLACEHOLDER
            if "now" in args:
                row["now"] = clean(args["now"]) or PLACEHOLDER
            if "repo" in args:
                row["repo"] = clean(args["repo"]) or row["repo"]
            if "type" in args:
                row["type"] = clean(args["type"]) or row["type"]
            if "who" in args:
                row["who"] = clean(args["who"]) or PLACEHOLDER
            elif "model" in args:      # who の runtime 部分は保ち、モデル名だけ置換
                base = row["who"].split("/")[0] if "/" in row["who"] else ""
                model = clean(args["model"])
                row["who"] = f"{base}/{model}" if base and model else (model or row["who"])
            if "plan" in args:         # ?＝未記入・なし＝サクッと宣言・短縮参照。空は ? へ
                row["plan"] = clean(args["plan"]) or PLACEHOLDER
            lines[idx] = fmt(row)
        elif cmd == "flip":
            if idx is None:
                return                 # 行が無ければ何もしない（non-blocking）
            sv = args.get("state")
            if sv not in ("run", "wait", "sub"):
                return             # 未知の --state は無変更（打ち間違いで誤って落とさない）
            row["state"] = RUN if sv == "run" else (SUB if sv == "sub" else WAIT)
            lines[idx] = fmt(row)
        elif cmd in ("log", "finish"):
            repo = clean(args.get("repo")) or (row["repo"] if row else "?")
            parent = clean(args.get("parent") or args.get("summary")) or \
                (row["goal"] if row else "作業")
            plan = (row.get("plan") if row else None) or PLACEHOLDER   # 転記元＝自行の計画値
            t = args.get("time") or now
            base = _base_time_for(lines, repo, parent, row)
            mark = _fmt_elapsed(_minutes_between(base, t)) if base else ""
            if cmd == "finish" and idx is not None:
                del lines[idx]
            children = [f"{t} {mark} {en}" if (i == 0 and mark) else f"{t} {en}"
                        for i, en in enumerate(entries)]
            add_children(lines, repo, parent, children)
            annotate_parent_plan(lines, repo, parent, plan)   # 参照計画なら親行へ ‹計画:›（先勝ち）
        elif cmd == "reconcile":
            reconcile_rows(lines)
        else:
            sys.exit(f"unknown command: {cmd}")

        # どの変更後も: summary除去 → 整列（旧形式はここで新形式へ移行）→ summary再生成
        strip_summary(lines)
        sort_agents(lines)
        rebuild_summary(lines)
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
