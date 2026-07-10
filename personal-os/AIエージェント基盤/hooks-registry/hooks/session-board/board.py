#!/usr/bin/env python3
# session-board board.py — 当日デイリーボードの行操作（flock付き・冪等）
# 使い方:
#   board.py add    --key K --repo R [--type T] [--goal G] [--now N] [--who W] [--plan P] [--time HH:MM]
#                   # 既存行があれば何もしない（枠のみ・内容を上書きしない）。--plan 既定は ?
#   board.py update --key K [--repo R] [--type T] [--goal G] [--now N] [--model M] [--who W] [--plan P]
#                   # --summary は --goal の別名（旧互換）。--model は who の「/」以降だけ置換
#                   # --plan は拠り所/置き先の計画（?＝未記入・なし＝サクッと宣言・短縮参照）
#   board.py flip   --key K --state run|wait|sub   # sub=🔵（手動フォールバック。サブの自動増減は sub-start/sub-end）
#   board.py sub-start --key K   # サブ体数+1・🔵へ（SubagentStart 受け口が呼ぶ・行が無ければ何もしない）
#   board.py sub-end   --key K   # サブ体数-1（0でクランプ）・0になったら🔵→🟢（SubagentStop 受け口が呼ぶ）
#   board.py log    --key K --repo R --parent P --entry E [--entry E ...]  # 節目: 入れ子で子を追記
#   board.py finish --key K --repo R --parent P [--entry E ...]            # 完了: 自行削除＋子を追記
#   board.py reconcile         # 🟢/🔵を実体で照合し沈黙(🟢≥10分/🔵≥30分)を⏸へ／実体皆無の枠は開始15分超で⏸(幽霊枠掃除)
#   board.py check  --key K    # stdout: missing|run|wait|sub
#   board.py show   --key K    # stdout: state/goal/now/type/repo/who/plan のタブ区切り7列（無ければ "missing"）
#   board.py goals             # stdout: 現在の目標一覧（重複なし・未記入除外・表示順）
# 行フォーマット v3（2026-07-10〜・入れ子ボード。セッション行の列構成は v2.2 と同じ＋任意 sub:N）:
#   「動いているエージェント」節は goals-summary マーカー内に 目標親行（- <代表絵文字> <目標>［（N件）］）
#   → 2字インデントのセッション行 → sub>0 なら「    ↳ 🔵 サブN体」の入れ子で機械再描画（render_body）。
#   - 🟢 HH:MM | <目標> | 今:<今> | <repo> | <種別> | <runtime/model> | 計画:<計画> <!-- s:KEY [sub:N] -->
#   計画値の語彙: ?＝未記入(催促対象)／なし＝サクッと作業の宣言／短縮参照＝企画名[/NN]・ai運用:企画名[/NN]。
#   v2.2（フラット・計画列あり）・v2（計画列なし）・v1（旧1要約列・状態語末尾）は読み取り互換。
#   書き込みは常に v3（全書き込みで自然移行）。sub体数は sub-start/sub-end が機械増減（AIが手で書かない）。
# 「終わったこと」の構造（親＝目標名／子＝時刻＋所要(+Nm)付き節目・入れ子）:
#   ### repo
#   - 親タスク名
#     - HH:MM (+38m) 子成果
# goals-summary: 「動いているエージェント」節の入れ子本体を自動再描画（手で編集しない）:
#   <!-- goals-summary --> … <!-- /goals-summary -->
# env: GOAL_BASE / SESSION_BOARD_DATE(YYYY-MM-DD) / SESSION_BOARD_TEMPLATE / SESSION_BOARD_TX_ROOTS
import sys
import os
import re
import glob
import fcntl
import datetime
import tempfile
import json
import subprocess
import urllib.request

RUN = "🟢"
WAIT = "⏸"
SUB = "🔵"
STATE_RANK = {RUN: 0, SUB: 1, WAIT: 2}   # 表示順: 🟢動作中 → 🔵サブ → ⏸停止確認待ち
RANK_STATE = {v: k for k, v in STATE_RANK.items()}   # 代表rank→絵文字（目標親行用）
STATE_WORD = {RUN: "run", WAIT: "wait", SUB: "sub"}
STALE_MIN = 10        # 🟢: 実体トランスクリプトがN分超沈黙なら死体→⏸へ降格
STALE_MIN_SUB = 30    # 🔵: サブ委託は長引くので閾値を緩く（実体照合はサブのファイルも見る）
STALE_MIN_NOFILE = 15 # 🟢/🔵: 実体が探索ルートに1つも無い枠は開始からN分「超」で幽霊枠→⏸（補助セッション掃除・行は消さない）
NOFILE_MAX = 720      # 実体皆無の掃除が有効なのは開始からこの分数「未満」まで（逆行クロックの +1440≈1439 を弾く上限・12h）
PLACEHOLDER = "?"     # goal/now/who の未記入プレースホルダ（AIが update で正す）
AGENTS_H = "## 動いているエージェント"
DONE_H = "## 終わったこと"
GS_OPEN = "<!-- goals-summary -->"
GS_CLOSE = "<!-- /goals-summary -->"
LINE_RE = re.compile(   # v3/v2.2: 計画列あり（インデント可・末尾コメントの sub:N は任意＝欠落は0）
    r'^\s*- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) \| 計画:(?P<plan>[^|]*?) '
    r'<!-- s:(?P<key>[0-9a-zA-Z-]+)(?: sub:(?P<sub>\d+))? -->\s*$')
V2_LINE_RE = re.compile(   # v2: 計画列なし（読み互換・parse_line で plan=? を補完・書き込みで v3 へ移行）
    r'^\s*- (?P<state>🟢|⏸|🔵) (?P<time>\d{2}:\d{2}) \| (?P<goal>[^|]*?) \| 今:(?P<now>[^|]*?) \| '
    r'(?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<who>[^|]+?) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_LINE_RE = re.compile(
    r'^\s*- (?P<time>\d{2}:\d{2}) \| (?P<repo>[^|]+?) \| (?P<type>[^|]+?) \| (?P<summary>.*?) \| '
    r'(?P<state>🟢動作中|⏸停止・確認待ち|🔵サブ稼働中) <!-- s:(?P<key>[0-9a-zA-Z-]+) -->\s*$')
OLD_STATE = {"🟢動作中": RUN, "⏸停止・確認待ち": WAIT, "🔵サブ稼働中": SUB}
CHILD_RE = re.compile(r'^  - (\d{2}:\d{2})')
PLAN_MARK = " ‹計画:"   # log/finish が親行末尾へ転記する計画マーカーの開始（先勝ち・親照合で無視）


TURSO_DB_URL = "https://personal-os-board-nextlevelkitamura-alt.aws-ap-northeast-1.turso.io"
TURSO_KEYCHAIN_SERVICE = "turso-personal-os-board"
TURSO_TIMEOUT = 3   # 秒。MDが正本・Tursoはベストエフォートのミラーなので短く切る


def _turso_token():
    """keychainからトークンを取得。値は一切ログ・stdoutへ出さない。失敗時は None。"""
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-a", os.environ.get("USER", ""),
             "-s", TURSO_KEYCHAIN_SERVICE, "-w"],
            capture_output=True, text=True, timeout=2)
        return r.stdout.strip() or None
    except Exception:
        return None


def _ta(v):
    return {"type": "text", "value": "" if v is None else str(v)}


def _turso_execute(statements):
    """statements: [(sql, args), ...] を1バッチで実行。失敗は静かに無視（非ブロッキング・
    MD運用に一切影響させないベストエフォート送信。secret規律によりtoken値は出力しない）。
    SESSION_BOARD_NO_TURSO=1 でスキップ（テスト実行が本番Tursoにデータを漏らさないためのガード）。"""
    if os.environ.get("SESSION_BOARD_NO_TURSO"):
        return
    token = _turso_token()
    if not token:
        return
    requests = [{"type": "execute", "stmt": {"sql": sql, "args": args}} for sql, args in statements]
    requests.append({"type": "close"})
    body = json.dumps({"requests": requests}).encode("utf-8")
    req = urllib.request.Request(
        TURSO_DB_URL + "/v2/pipeline", data=body, method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=TURSO_TIMEOUT)
    except Exception:
        pass


def turso_sync_session(row):
    """sessions テーブルへ現在行の状態を upsert（層1・機械送信）。"""
    if not row or not row.get("key"):
        return
    sql = ("INSERT INTO sessions (session_key, goal, now, type, repo, model, plan, state, updated_at) "
           "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) "
           "ON CONFLICT(session_key) DO UPDATE SET goal=excluded.goal, now=excluded.now, "
           "type=excluded.type, repo=excluded.repo, model=excluded.model, plan=excluded.plan, "
           "state=excluded.state, updated_at=excluded.updated_at")
    who = row.get("who") or ""
    model = who.split("/")[-1] if "/" in who else who
    args = [_ta(f"s:{row['key']}"), _ta(row.get("goal")), _ta(row.get("now")),
            _ta(row.get("type")), _ta(row.get("repo")), _ta(model), _ta(row.get("plan")),
            _ta(STATE_WORD.get(row.get("state"), "run")),
            _ta(datetime.datetime.now().isoformat(timespec="seconds"))]
    _turso_execute([(sql, args)])


def turso_delete_session(key):
    """finish: sessions から自行を削除（セッション終了）。"""
    _turso_execute([("DELETE FROM sessions WHERE session_key = ?", [_ta(f"s:{key}")])])


def turso_sync_logs(repo, parent, entries, date_s):
    """session_logs へ「終わったこと」の子エントリを追記（層2・要約送信）。
    entry は呼び出し元のAIが既に人間向けに要約済みの1行なので、追加のLLM API呼び出しはしない。"""
    if not entries:
        return
    sql = "INSERT INTO session_logs (repo, parent, entry, session_date, created_at) VALUES (?, ?, ?, ?, ?)"
    created = datetime.datetime.now().isoformat(timespec="seconds")
    _turso_execute([(sql, [_ta(repo), _ta(parent), _ta(e), _ta(date_s), _ta(created)]) for e in entries])


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
    """ボード行を dict（state/time/goal/now/repo/type/who/plan/key/sub）に。v3/v2.2/v2/v1 を読む
    （インデント可・sub は int・欠落は0）。"""
    m = LINE_RE.match(ln)          # v3/v2.2（計画列あり・sub:N は任意）
    if m:
        r = m.groupdict()
        r["sub"] = int(r["sub"] or 0)
        return r
    m = V2_LINE_RE.match(ln)       # v2（計画列なし）: plan=? を補って読む
    if m:
        r = m.groupdict()
        r["plan"] = PLACEHOLDER
        r["sub"] = 0
        return r
    m = OLD_LINE_RE.match(ln)      # v1（旧1要約列・状態語末尾）
    if m:
        return {"state": OLD_STATE[m.group("state")], "time": m.group("time"),
                "goal": m.group("summary") or PLACEHOLDER, "now": PLACEHOLDER,
                "repo": m.group("repo"), "type": m.group("type"),
                "who": PLACEHOLDER, "plan": PLACEHOLDER, "key": m.group("key"), "sub": 0}
    return None


def fmt(r):
    plan = r.get("plan") or PLACEHOLDER
    n = int(r.get("sub") or 0)
    tail = f" sub:{n}" if n > 0 else ""   # sub=0 は書かない（後方互換の任意グループ）
    return (f"- {r['state']} {r['time']} | {r['goal']} | 今:{r['now']} | "
            f"{r['repo']} | {r['type']} | {r['who']} | 計画:{plan} <!-- s:{r['key']}{tail} -->")


def find_line(lines, key):
    for idx, ln in enumerate(lines):
        r = parse_line(ln)
        if r and r["key"] == key:
            return idx, r
    return None, None


def render_body(lines):
    """『動いているエージェント』節を耐久行から入れ子で再描画する（v3・2026-07-10。
    旧 strip_summary→sort_agents→rebuild_summary の3段を耐久行保全型に統合）。
    ① 節内の耐久行（<!-- s:KEY -->・parse_line が当たる行）をマーカー内外・インデントを問わず全収集。
    ② 「目標グループ（生存優先）→ 目標 → 状態 → 時刻」でソート（旧 sort_agents と同キー）。
    ③ GS_OPEN・「### 本日の目標」・[目標親行 → 2字インデントのセッション行 → ↳サブ行]×グループ・
       GS_CLOSE を再描画。親行＝旧サマリ行の昇格: - <代表絵文字> <目標>［（N件・2件以上のみ）］
       （代表絵文字＝グループ内最良状態 🟢>🔵>⏸・目標 ? のラベルは「目標未記入」）。
       sub>0 の行の直下に「    ↳ 🔵 サブN体」（4字インデント・体数のみ）。
    マーカー内の派生行（見出し・親行・↳）は破棄して作り直す。パース不能に壊れた耐久行や
    手書きメモ・空行は kept としてブロックの後ろへ保全する。書き戻しは fmt()＝常に v3
    （v1/v2/v2.2 のフラット行はどの書き込みでも自然移行）。行が無ければブロックを出さない。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    rows, kept, in_gs = [], [], False
    for j in range(s + 1, e):
        ln = lines[j]
        r = parse_line(ln)
        if r:
            rows.append(r)
            continue
        t = ln.strip()
        if t == GS_OPEN:
            in_gs = True
            continue
        if t == GS_CLOSE:
            in_gs = False
            continue
        if in_gs and (t.startswith("### ") or t.startswith("↳ ")
                      or (re.match(r"- [🟢🔵⏸] ", t) and "<!-- s:" not in t)):
            continue                     # 派生行（見出し・目標親行・↳サブ行）は再生成する
        kept.append(ln)                  # 壊れた耐久行・手書きメモ・空行は消さずに保全
    if not rows:
        lines[s + 1:e] = kept
        return lines
    best, count = {}, {}
    for r in rows:   # 目標グループの代表rank＝グループ内で最も生きている状態
        rk = STATE_RANK.get(r["state"], 9)
        best[r["goal"]] = min(best.get(r["goal"], 9), rk)
        count[r["goal"]] = count.get(r["goal"], 0) + 1
    rows.sort(key=lambda r: (best[r["goal"]], r["goal"],
                             STATE_RANK.get(r["state"], 9), r["time"]))
    body, cur = [GS_OPEN, "### 本日の目標"], None
    for r in rows:
        g = r["goal"]
        if g != cur:                     # グループ先頭で目標親行を立てる（ソート順＝表示順）
            label = g if g != PLACEHOLDER else "目標未記入"
            suffix = f"（{count[g]}件）" if count[g] >= 2 else ""
            body.append(f"- {RANK_STATE.get(best[g], WAIT)} {label}{suffix}")
            cur = g
        body.append("  " + fmt(r))
        n = int(r.get("sub") or 0)
        if n > 0:
            body.append(f"    ↳ {SUB} サブ{n}体")
    body.append(GS_CLOSE)
    lines[s + 1:e] = body + kept
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
    （🟢=STALE_MIN・🔵=STALE_MIN_SUB）。実体が探索ルートに1つも無い枠は開始時刻から
    STALE_MIN_NOFILE 分超で⏸（プロンプトを持たない補助セッション等の幽霊枠掃除・
    行削除はせず翌日の新ボードで消える・2026-07-08）。
    降格時はサブ体数（sub）も0へクリアする（sub-end が届かない前提で仕切り直す幽霊ガード）。"""
    s, e = section_bounds(lines, AGENTS_H)
    if s is None:
        return lines
    now_dt = datetime.datetime.now()
    now = now_dt.timestamp()
    now_hhmm = now_dt.strftime("%H:%M")
    files = None
    for j in range(s + 1, e):
        r = parse_line(lines[j])
        if not r or r["state"] not in (RUN, SUB):
            continue
        if files is None:                 # 遅延: 🟢/🔵が1つも無ければツリーを走査しない
            files = _list_transcripts()
        f = _newest_for(r["key"], files)
        if f is None:                     # 実体皆無の枠: 幽霊枠掃除（誤爆を防ぐガード付き）
            m = _minutes_between(r["time"], now_hhmm)
            limit = STALE_MIN_SUB if r["state"] == SUB else STALE_MIN_NOFILE
            # files空→探索不能につき抑止（全行一括⏸を防ぐ）／🔵は30分猶予／上限NOFILE_MAXで逆行クロック(+1440≈1439)を弾く
            if files and limit < m < NOFILE_MAX:
                r["state"] = WAIT
                r["sub"] = 0
                lines[j] = fmt(r)
            continue
        limit = STALE_MIN_SUB if r["state"] == SUB else STALE_MIN
        try:
            if (now - os.path.getmtime(f)) / 60 >= limit:
                r["state"] = WAIT
                r["sub"] = 0
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
        sys.exit("usage: board.py <add|update|flip|sub-start|sub-end|finish|log|check|show|goals|reconcile> ...")
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
        elif cmd in ("sub-start", "sub-end"):
            if idx is None:
                return                 # 行が無ければ何もしない（non-blocking・flipと同じ）
            n = int(row.get("sub") or 0)
            if cmd == "sub-start":     # サブ開始: 体数+1・状態は🔵へ。⏸からも🔵にする
                row["sub"] = n + 1     # （開始イベント＝親が生きている合図。旧シムの flip sub と同じ挙動）
                row["state"] = SUB
            else:                      # サブ終了: 体数-1（0でクランプ）・全員戻ったら🔵→🟢
                row["sub"] = max(0, n - 1)
                if row["sub"] == 0 and row["state"] == SUB:
                    row["state"] = RUN
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

        # どの変更後も: 節を入れ子で再描画（旧形式行はここで v3 へ自然移行）
        render_body(lines)
        out = "\n".join(lines) + "\n"
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(out)
        os.replace(tmp, path)
    finally:
        fcntl.flock(lock, fcntl.LOCK_UN)
        lock.close()

    # Turso同期（MD書き込み・flock解放後のベストエフォート送信。失敗はMD運用に一切影響しない）
    if cmd in ("add", "update", "flip"):
        _, r2 = find_line(lines, key)
        turso_sync_session(r2)
    elif cmd == "log":
        turso_sync_logs(repo, parent, entries, date_s)
    elif cmd == "finish":
        turso_sync_logs(repo, parent, entries, date_s)
        turso_delete_session(key)


if __name__ == "__main__":
    main()
