#!/usr/bin/env python3
"""plan-ops / plansync — active計画mdをTurso(inbox)へ一方向ミラーする表示キャッシュ同期。

正本境界（親program「正本境界」）:
  - md(git)が計画の正本。DBは読み取り専用の表示キャッシュに徹する（子07が読む）。
  - ここは md→DB の一方向のみ。DB→md の書き戻し経路は作らない。

設計の柱:
  1. パーサは plan-ops `_planops_map.py` を流用（二重実装しない）。子N/M・完了条件x/y はここで事前計算。
  2. 送信は session-board `turso/store.py` を import 再利用。失敗は `turso/spool.py` の別spool(plansync)へ。
     - plan_docs/plan_progress は inbox DB。session-board既定spool(board DB向け)へ混ぜると誤ルートになるため、
       専用spool名 `plansync-spool` を使い、再送も inbox 宛senderで回す（DB取り違え防止）。
  3. content_hash 冪等（同一内容は再送スキップ）。git_commit はファイルへの最終コミットhash。
  4. secret疑い正規表現にヒットした文書は同期拒否し、通知（notices log + stderr）を出す。
  5. 走査は planning|active|done|archive の4バケット。plan_docs.bucket にフォルダ名を書く。
     active→done/archive のバケット移動で計画はUIから消えない（新bucket行がupsertされ継続）。
     自動DELETEは commit経路の明示的なファイル削除（差分同期）に限る。日次フル reconcile は孤児を
     削除せず notify（きみの番へ通知）する＝沈黙して消えない・古い行の誤爆削除を防ぐ。
     ※ plan_docs のPK(path)・plan_progress のPK(program_slug)は変更しない（バケット移動は path変化＝
       旧path削除＋新path挿入で表現。PK変更が要る事態になれば停止して人間へ報告する契約）。

CLI:
  plansync.py scan  [--root R] [--json]                 # dry-run抽出のみ（DB非依存・書込なし）
  plansync.py sync  --all      [--root R] [--apply]     # フルreconcile（孤児DELETE込み）。既定dry-run
  plansync.py sync  --paths P.. [--root R] [--apply]    # 差分同期（post-commit用）。既定dry-run
  適用（--apply）は inbox migration 適用後にのみ意味を持つ（人間ゲート）。既定は必ず dry-run。
"""
import argparse
import datetime
import fcntl
import glob
import hashlib
import json
import os
import re
import subprocess
import sys

SELFDIR = os.path.dirname(os.path.realpath(__file__))
sys.path.insert(0, SELFDIR)
from _planops_map import (  # noqa: E402
    read_lines, find_section, find_blocks, get_state, checkbox_mark,
)


# ---- session-board turso 層の import（送信・spoolを流用・二重実装しない） ----

def _session_board_dir():
    # scripts → plan-ops → skills → AIエージェント基盤 → hooks-registry/shared/session-board
    base = os.path.normpath(os.path.join(SELFDIR, "..", "..", "..",
                                         "hooks-registry", "shared", "session-board"))
    return base


def _load_turso():
    """store/spool を返す。存在しない環境（テスト等）では ImportError を素通しせず None を返す。"""
    sb = _session_board_dir()
    if sb not in sys.path:
        sys.path.insert(0, sb)
    from turso import store, spool  # noqa: E402
    return store, spool


# ---- スキャン対象と分類 ----

KIND_PROGRAM = "program"
KIND_SINGLE = "single"
KIND_CHILD = "child"
KIND_ROLE = "role"
KIND_EVAL = "eval"

# 子/評価ファイル名の判定
RE_CHILD = re.compile(r"^(\d{2})-.+\.md$")
RE_EVAL_SUFFIX = re.compile(r"^(\d{2})-.+-(?:評価|修正)\d+\.md$")
RE_EVAL_BARE = re.compile(r"^(?:評価|修正)\d+\.md$")          # program整合評価/単発plan隣接評価
RE_H1 = re.compile(r"^#\s+(.+?)\s*$")

# 完了条件チェックボックス
RE_COND_ANY = re.compile(r"^\s*- \[[ x]\]")
RE_COND_DONE = re.compile(r"^\s*- \[x\]")

COMPLETION_HEADING = "完了条件"
MAP_HEADING = "子計画マップ"


def repo_root_from(path):
    try:
        r = subprocess.run(["git", "-C", os.path.dirname(path) or ".",
                            "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def default_areas_root():
    root = repo_root_from(SELFDIR)
    if not root:
        return None
    return os.path.join(root, "personal-os", "my-brain", "areas")


def read_text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def h1_title(body, fallback):
    for line in body.splitlines()[:40]:
        m = RE_H1.match(line)
        if m:
            return m.group(1).strip()
    return fallback


def last_commit_of(path, repo_root):
    """ファイルへの最終コミットhash（40桁）。未コミット/git外なら空文字。"""
    try:
        r = subprocess.run(["git", "-C", repo_root, "log", "-1",
                            "--format=%H", "--", path],
                           capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


# ---- secret疑いスキャン（保守的・prose誤検知を避ける。値そのものは記録しない） ----

SECRET_PATTERNS = [
    ("aws_access_key", re.compile(r"AKIA[0-9A-Z]{16}")),
    ("private_key_block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("jwt", re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("quoted_secret", re.compile(
        r"""(?i)(?:secret|token|password|passwd|api[_-]?key|access[_-]?key|auth[_-]?token)\s*[:=]\s*['"][^'"\s]{8,}['"]""")),
    ("url_credential", re.compile(r"[a-z][a-z0-9+.\-]*://[^/\s:@]+:[^/\s:@]+@")),
    ("authorization_bearer", re.compile(r"(?i)authorization\s*:\s*bearer\s+[A-Za-z0-9._\-]{12,}")),
]


def scan_secrets(body):
    """(pattern_label, line_no) のリストを返す。値は返さない（記録禁止のため）。"""
    hits = []
    for i, line in enumerate(body.splitlines(), start=1):
        for label, pat in SECRET_PATTERNS:
            if pat.search(line):
                hits.append((label, i))
    return hits


# ---- 進捗集計（_planops_map 流用） ----

def state_base(state_text):
    if state_text is None:
        return ""
    m = re.search(r"[（(]", state_text)
    return (state_text[: m.start()] if m else state_text).strip()


def count_completion(lines):
    """(done, total) を「## 完了条件」セクションから数える。旧見出しも読み取り互換で受ける。"""
    section = find_section(lines, COMPLETION_HEADING)
    if section is None:
        return None
    _, body_start, body_end = section
    total = done = 0
    for i in range(body_start, body_end):
        if RE_COND_ANY.match(lines[i]):
            total += 1
            if RE_COND_DONE.match(lines[i]):
                done += 1
    return done, total


def count_children(lines):
    """(done, total) を「## 子計画マップ」から数える。無ければ None。"""
    section = find_section(lines, MAP_HEADING)
    if section is None:
        return None
    _, body_start, body_end = section
    blocks = find_blocks(lines, body_start, body_end)
    if not blocks:
        return None
    total = len(blocks)
    done = 0
    for b in blocks:
        st = get_state(lines[b.start])
        mark = checkbox_mark(lines[b.start])
        if mark == "x" or state_base(st) == "完了":
            done += 1
    return done, total


def compute_progress(program_path, kind):
    """program/single の進捗を算出。parse_ok=0 でも本文閲覧は生きる（呼び出し元で判断）。
    戻り: dict(child_done, child_total, cond_done, cond_total, parse_ok)。"""
    try:
        lines = read_lines(program_path)
    except OSError:
        return dict(child_done=0, child_total=0, cond_done=0, cond_total=0, parse_ok=0)
    parse_ok = 1
    if kind == KIND_PROGRAM:
        children = count_children(lines)
        if children is None:
            parse_ok = 0
            child_done = child_total = 0
        else:
            child_done, child_total = children
    else:  # single
        child_done = child_total = 0
    cond = count_completion(lines)
    if cond is None:
        parse_ok = 0
        cond_done = cond_total = 0
    else:
        cond_done, cond_total = cond
    return dict(child_done=child_done, child_total=child_total,
                cond_done=cond_done, cond_total=cond_total, parse_ok=parse_ok)


# ---- 抽出（1文書1行） ----

class Doc:
    __slots__ = ("path", "program_slug", "kind", "nn", "title", "bucket",
                 "body", "content_hash", "git_commit", "abspath")

    def __init__(self, **kw):
        for k in self.__slots__:
            setattr(self, k, kw.get(k))

    def to_dict(self):
        return {k: getattr(self, k) for k in self.__slots__ if k != "abspath"}


def _mk_doc(abspath, repo_root, program_slug, kind, nn, bucket="active"):
    body = read_text(abspath)
    rel = os.path.relpath(abspath, repo_root)
    return Doc(
        path=rel,
        program_slug=program_slug,
        kind=kind,
        nn=nn or "",
        title=h1_title(body, os.path.splitext(os.path.basename(abspath))[0]),
        bucket=bucket,
        body=body,
        content_hash=hashlib.sha256(body.encode("utf-8")).hexdigest(),
        git_commit=last_commit_of(rel, repo_root),
        abspath=abspath,
    )


def extract_plan_dir(plan_dir, repo_root, bucket="active"):
    """1つの計画フォルダ（bucket=planning|active|done|archive）から Doc群を抽出する。
    対象外(references/explain/misc)は無視。bucket は plan_docs.bucket 列へ書く（active から done/archive へ
    動いても表示キャッシュが消えないための状態列。子02・program.md 正本境界4条）。"""
    slug = os.path.basename(plan_dir.rstrip("/"))
    docs = []

    program_md = os.path.join(plan_dir, "program.md")
    plan_md = os.path.join(plan_dir, "plan.md")

    if os.path.isfile(program_md):
        docs.append(_mk_doc(program_md, repo_root, slug, KIND_PROGRAM, "", bucket))
    elif os.path.isfile(plan_md):
        docs.append(_mk_doc(plan_md, repo_root, slug, KIND_SINGLE, "", bucket))

    # 役割別コンテキスト
    for role in ("実装",):
        rp = os.path.join(plan_dir, role, "共通.md")
        if os.path.isfile(rp):
            docs.append(_mk_doc(rp, repo_root, slug, KIND_ROLE, "", bucket))

    # 子計画 / plans/ 内の評価
    plans_dir = os.path.join(plan_dir, "plans")
    if os.path.isdir(plans_dir):
        for name in sorted(os.listdir(plans_dir)):
            if not name.endswith(".md"):
                continue
            fp = os.path.join(plans_dir, name)
            m_eval = RE_EVAL_SUFFIX.match(name)
            if m_eval:
                docs.append(_mk_doc(fp, repo_root, slug, KIND_EVAL, m_eval.group(1), bucket))
            elif RE_EVAL_BARE.match(name):
                docs.append(_mk_doc(fp, repo_root, slug, KIND_EVAL, "", bucket))
            else:
                m_child = RE_CHILD.match(name)
                if m_child:
                    docs.append(_mk_doc(fp, repo_root, slug, KIND_CHILD, m_child.group(1), bucket))
                # それ以外(NN無しmd)は対象外

    # 評価/ フォルダ（program集約）
    eval_dir = os.path.join(plan_dir, "評価")
    if os.path.isdir(eval_dir):
        for name in sorted(os.listdir(eval_dir)):
            if not name.endswith(".md"):
                continue
            fp = os.path.join(eval_dir, name)
            m_eval = RE_EVAL_SUFFIX.match(name)
            docs.append(_mk_doc(fp, repo_root, slug, KIND_EVAL,
                                m_eval.group(1) if m_eval else "", bucket))

    # 単発plan隣接の評価/修正
    if os.path.isfile(plan_md) and not os.path.isfile(program_md):
        for name in sorted(os.listdir(plan_dir)):
            if RE_EVAL_BARE.match(name):
                docs.append(_mk_doc(os.path.join(plan_dir, name), repo_root, slug, KIND_EVAL, "", bucket))

    return docs


# Dailyでは、これからThemeへ束ねる計画も選べる必要があるため planning も表示ミラーへ含める。
# 計画本文・状態の正本は引き続きフォルダで、plan_docs は読み取りキャッシュに限定する。
SYNC_BUCKETS = ("planning", "active", "done", "archive")


def find_plan_dirs(areas_root):
    """areas/*/plans/<bucket>/<slug>/ の一覧を (絶対path, bucket) で返す。"""
    out = []
    for bucket in SYNC_BUCKETS:
        for bpath in sorted(glob.glob(os.path.join(areas_root, "*", "plans", bucket))):
            for entry in sorted(os.listdir(bpath)):
                d = os.path.join(bpath, entry)
                if os.path.isdir(d) and not entry.startswith("."):
                    out.append((d, bucket))
    return out


def extract_all(areas_root, repo_root):
    docs = []
    progress = []
    for d, bucket in find_plan_dirs(areas_root):
        dd = extract_plan_dir(d, repo_root, bucket)
        docs.extend(dd)
        slug = os.path.basename(d.rstrip("/"))
        program_md = os.path.join(d, "program.md")
        plan_md = os.path.join(d, "plan.md")
        if os.path.isfile(program_md):
            prog = compute_progress(program_md, KIND_PROGRAM)
            prog["program_slug"] = slug
            progress.append(prog)
        elif os.path.isfile(plan_md):
            prog = compute_progress(plan_md, KIND_SINGLE)
            prog["program_slug"] = slug
            progress.append(prog)
    return docs, progress


def is_plan_doc_path(rel_path):
    """repo相対pathが計画ミラー対象pathかを判定（post-commit差分の絞り込み用）。"""
    parts = rel_path.split("/")
    try:
        i = parts.index("areas")
    except ValueError:
        return False
    tail = parts[i + 1:]
    # areas/<area>/plans/<bucket>/<slug>/...
    if len(tail) < 5:
        return False
    if tail[1] != "plans" or tail[2] not in SYNC_BUCKETS:
        return False
    return rel_path.endswith(".md")


# ---- 通知（secret拒否など） ----

def _state_dir():
    return os.environ.get("SESSION_BOARD_STATE_DIR") or os.path.join(_session_board_dir(), "state")


def notices_path():
    return os.path.join(_state_dir(), "plansync-notices.log")


def notify(message):
    """人間向け通知: notices log へ追記＋stderr。secret値は渡さない前提。"""
    line = f"{datetime.datetime.now().isoformat(timespec='seconds')} {message}"
    print(f"[plansync] {message}", file=sys.stderr)
    try:
        path = notices_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# ---- SQL builder（inbox: plan_docs / plan_progress） ----

def stmt_doc_upsert(store, doc):
    sql = ("INSERT INTO plan_docs (path, program_slug, kind, nn, title, bucket, body, content_hash, git_commit, synced_at) "
           "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
           "ON CONFLICT(path) DO UPDATE SET program_slug=excluded.program_slug, kind=excluded.kind, nn=excluded.nn, "
           "title=excluded.title, bucket=excluded.bucket, body=excluded.body, content_hash=excluded.content_hash, "
           "git_commit=excluded.git_commit, synced_at=excluded.synced_at")
    now = datetime.datetime.now().isoformat(timespec="seconds")
    t = store.text_arg
    return sql, [t(doc.path), t(doc.program_slug), t(doc.kind), t(doc.nn), t(doc.title),
                 t(doc.bucket), t(doc.body), t(doc.content_hash), t(doc.git_commit), t(now)]


def stmt_doc_delete(store, rel_path):
    return "DELETE FROM plan_docs WHERE path = ?", [store.text_arg(rel_path)]


def stmt_progress_upsert(store, prog):
    sql = ("INSERT INTO plan_progress (program_slug, child_done, child_total, cond_done, cond_total, parse_ok, updated_at) "
           "VALUES (?, ?, ?, ?, ?, ?, ?) "
           "ON CONFLICT(program_slug) DO UPDATE SET child_done=excluded.child_done, child_total=excluded.child_total, "
           "cond_done=excluded.cond_done, cond_total=excluded.cond_total, parse_ok=excluded.parse_ok, updated_at=excluded.updated_at")
    now = datetime.datetime.now().isoformat(timespec="seconds")
    t, ii = store.text_arg, store.int_arg
    return sql, [t(prog["program_slug"]), ii(prog["child_done"]), ii(prog["child_total"]),
                 ii(prog["cond_done"]), ii(prog["cond_total"]), ii(prog["parse_ok"]), t(now)]


def stmt_progress_delete(store, slug):
    return "DELETE FROM plan_progress WHERE program_slug = ?", [store.text_arg(slug)]


# ---- 多重起動ロック（macに flock バイナリが無いので fcntl で自前ロック） ----

def _lock_path():
    return os.path.join(_state_dir(), ".plansync.lock")


def acquire_lock():
    """非ブロッキング排他ロック。取れなければ None（別インスタンス実行中）。"""
    path = _lock_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fh = open(path, "a+", encoding="utf-8")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fh
    except OSError:
        fh.close()
        return None


def release_lock(fh):
    if fh is None:
        return
    try:
        fcntl.flock(fh, fcntl.LOCK_UN)
    finally:
        fh.close()


# ---- 同期プラン算出（dry-run/apply共通の中核・DB非依存） ----

def build_plan(areas_root, repo_root, only_paths=None):
    """抽出→secret判定→（sync対象/拒否）に仕分けする。DBは見ない。
    戻り: dict(docs=[全Doc], sync_docs=[], blocked=[(path,[hits])], progress=[], slugs=set)。
    only_paths指定時は、その repo相対path集合に属する Doc/削除候補だけへ絞る。"""
    docs, progress = extract_all(areas_root, repo_root)
    present_paths = {d.path for d in docs}

    sync_docs, blocked = [], []
    for d in docs:
        hits = scan_secrets(d.body)
        if hits:
            blocked.append((d.path, hits))
        else:
            sync_docs.append(d)

    # only_paths 差分モード: 変更のあった path のみ対象。消えた path は削除候補。
    deletions = []
    if only_paths is not None:
        wanted = set(only_paths)
        sync_docs = [d for d in sync_docs if d.path in wanted]
        blocked = [b for b in blocked if b[0] in wanted]
        # wanted のうち現存しない = そのpathのファイルがcommitで削除/改名された → DELETE（明示削除のみ）。
        # active→done 等のバケット移動は、旧pathのファイル削除＋新pathのファイル追加が同一commitに乗るため、
        # 旧path行を消し新path行(bucket=done)をupsertする＝計画の表示は新bucketで継続し消えない（子02）。
        for p in sorted(wanted):
            if p not in present_paths and is_plan_doc_path(p):
                deletions.append(p)
        # 差分モードでは progress は関係slugだけ
        touched_slugs = {d.program_slug for d in docs if d.path in wanted}
        progress = [pr for pr in progress if pr["program_slug"] in touched_slugs]

    return dict(docs=docs, sync_docs=sync_docs, blocked=blocked,
                deletions=deletions, progress=progress, present_paths=present_paths)


# ---- DB実行（apply時のみ・fullはreconcile削除込み） ----

def filter_unchanged(sync_docs, existing_hashes):
    """DB既存 {path: content_hash} と突合し、content_hash一致のdocを送信スキップする（冪等・純関数）。
    existing_hashes が None（DB照会失敗）なら全送信（安全側フォールバック）。戻り: (送信docs, skip件数)。"""
    if existing_hashes is None:
        return list(sync_docs), 0
    keep, skipped = [], 0
    for d in sync_docs:
        if existing_hashes.get(d.path) == d.content_hash:
            skipped += 1
        else:
            keep.append(d)
    return keep, skipped


def apply_sync(plan, full=False):
    """plan(build_planの戻り)をinbox DBへ適用。失敗はplansync専用spoolへ。戻り: 送信文数の目安。"""
    if os.environ.get("SESSION_BOARD_NO_TURSO"):
        return 0  # 送信・DB照会・spoolを完全停止（テスト/明示停止時は無害化）
    store, spool = _load_turso()
    existing = _fetch_doc_hashes(store)
    docs_to_send, skipped = filter_unchanged(plan["sync_docs"], existing)
    if skipped:
        print(f"content_hash一致で {skipped} 文書をスキップ", file=sys.stderr)
    statements = []
    for d in docs_to_send:
        statements.append(stmt_doc_upsert(store, d))
    for pr in plan["progress"]:
        statements.append(stmt_progress_upsert(store, pr))
    for p in plan.get("deletions", []):
        statements.append(stmt_doc_delete(store, p))

    if full:
        # 子02: 日次フル reconcile は孤児を自動DELETEしない（削除は commit経路の明示ファイル削除＝差分同期に限る）。
        # DBに在って現存(planning|active|done|archive)に無いpath/slugは「差分」として notifyするだけ。
        # これにより active→done 移動が日次経路で誤DELETEされることを防ぎ、沈黙して消えない（program.md 方針）。
        db_paths, db_slugs = _fetch_db_keys(store)
        present = plan["present_paths"]
        present_slugs = {pr["program_slug"] for pr in plan["progress"]}
        orphan_paths = sorted(db_paths - present)
        orphan_slugs = sorted(db_slugs - present_slugs)
        for p in orphan_paths:
            notify(f"孤児検知(自動削除しない・要確認): plan_docs.path={p}")
        for s in orphan_slugs:
            notify(f"孤児検知(自動削除しない・要確認): plan_progress.program_slug={s}")

    if not statements:
        return 0
    ok = _inbox_send(store, statements)
    if not ok:
        _spool_inbox(spool, statements)
    return len(statements)


def _inbox_sender(store):
    def sender(statements, db_url=None, service=None):
        return store.send(statements, db_url=store.INBOX_DB_URL,
                          service=store.INBOX_KEYCHAIN_SERVICE, token_getter=store.token)
    return sender


def _inbox_send(store, statements):
    return _inbox_sender(store)(statements)


PLANSYNC_SPOOL = "plansync-spool"


def _spool_inbox(spool, statements):
    # plan_docs/plan_progress は許可リスト拡張済み。専用spool名でinbox宛に隔離する。
    return spool.append(statements, name=PLANSYNC_SPOOL)


def replay_inbox_spool():
    store, spool = _load_turso()
    return spool.replay(_inbox_sender(store), name=PLANSYNC_SPOOL)


def _fetch_db_keys(store):
    """inbox DBの plan_docs.path と plan_progress.program_slug 集合を取得（reconcile用）。
    取得失敗時は空集合（＝削除を見送る安全側）。"""
    try:
        secret = store.token(store.INBOX_KEYCHAIN_SERVICE)
        if not secret:
            return set(), set()
        import urllib.request
        requests = [
            {"type": "execute", "stmt": {"sql": "SELECT path FROM plan_docs", "args": []}},
            {"type": "execute", "stmt": {"sql": "SELECT program_slug FROM plan_progress", "args": []}},
            {"type": "close"},
        ]
        req = urllib.request.Request(
            store.INBOX_DB_URL + "/v2/pipeline",
            data=json.dumps({"requests": requests}).encode(), method="POST",
            headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=store.TIMEOUT) as resp:
            data = json.loads(resp.read().decode())
        paths, slugs = set(), set()
        results = data.get("results", [])
        for idx, target in ((0, paths), (1, slugs)):
            if idx < len(results):
                rows = (results[idx].get("response", {}).get("result", {}) or {}).get("rows", [])
                for row in rows:
                    if row and isinstance(row[0], dict):
                        target.add(row[0].get("value"))
        return paths, slugs
    except Exception:
        return set(), set()


def _fetch_doc_hashes(store):
    """inbox DBの {path: content_hash} を取得（冪等スキップ用）。失敗時は None（＝全送信フォールバック）。"""
    try:
        secret = store.token(store.INBOX_KEYCHAIN_SERVICE)
        if not secret:
            return None
        import urllib.request
        requests = [
            {"type": "execute", "stmt": {"sql": "SELECT path, content_hash FROM plan_docs", "args": []}},
            {"type": "close"},
        ]
        req = urllib.request.Request(
            store.INBOX_DB_URL + "/v2/pipeline",
            data=json.dumps({"requests": requests}).encode(), method="POST",
            headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=store.TIMEOUT) as resp:
            data = json.loads(resp.read().decode())
        results = data.get("results", [])
        if not results:
            return {}
        rows = (results[0].get("response", {}).get("result", {}) or {}).get("rows", [])
        out = {}
        for row in rows:
            if len(row) >= 2 and isinstance(row[0], dict) and isinstance(row[1], dict):
                out[row[0].get("value")] = row[1].get("value")
        return out
    except Exception:
        return None


# ---- CLI 出力 ----

def print_scan_report(plan, as_json=False):
    docs = plan["docs"]
    if as_json:
        out = {
            "docs": [d.to_dict() for d in docs],
            "blocked": [{"path": p, "hits": [{"pattern": lbl, "line": ln} for lbl, ln in hits]}
                        for p, hits in plan["blocked"]],
            "progress": plan["progress"],
            "deletions": plan.get("deletions", []),
        }
        # body は大きいので JSON からは省く（bytes長だけ残す）
        for d in out["docs"]:
            d["body_bytes"] = len(d.pop("body").encode("utf-8"))
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return

    from collections import Counter
    kinds = Counter(d.kind for d in docs)
    print(f"抽出文書: {len(docs)} 件  " + " / ".join(f"{k}={kinds[k]}" for k in
          (KIND_PROGRAM, KIND_SINGLE, KIND_CHILD, KIND_ROLE, KIND_EVAL) if kinds.get(k)))
    blocked_paths = {p for p, _ in plan["blocked"]}
    print(f"同期対象(secret通過): {len(plan['sync_docs'])} 件 / secret拒否: {len(plan['blocked'])} 件")
    print("")
    print("― 進捗集計（program_slug: 子N/M・完了条件x/y・parse_ok）")
    for pr in plan["progress"]:
        print(f"  {pr['program_slug']}: 子 {pr['child_done']}/{pr['child_total']}"
              f"・完了条件 {pr['cond_done']}/{pr['cond_total']}・parse_ok={pr['parse_ok']}")
    print("")
    print("― 文書一覧（kind nn : path）")
    for d in docs:
        flag = "  [SECRET拒否]" if d.path in blocked_paths else ""
        print(f"  {d.kind:<7} {d.nn or '--':<3} {d.path}{flag}")
    if plan["blocked"]:
        print("")
        print("― secret疑い（同期拒否・値は非表示）")
        for p, hits in plan["blocked"]:
            for lbl, ln in hits:
                print(f"  {p}:{ln}: {lbl}")
    if plan.get("deletions"):
        print("")
        print("― 削除候補（activeから消えたpath）")
        for p in plan["deletions"]:
            print(f"  DELETE {p}")


def cmd_scan(args):
    areas_root = args.root or default_areas_root()
    if not areas_root or not os.path.isdir(areas_root):
        print(f"areas root が見つからない: {areas_root}", file=sys.stderr)
        return 1
    repo_root = args.repo_root or repo_root_from(areas_root) or os.path.dirname(areas_root)
    plan = build_plan(areas_root, repo_root)
    # secret拒否は scan でも通知（dry-runでも人間に気づかせる）
    for p, hits in plan["blocked"]:
        notify(f"secret疑いで同期拒否: {p}（{', '.join(sorted({lbl for lbl, _ in hits}))}）")
    print_scan_report(plan, as_json=args.json)
    return 0


def cmd_sync(args):
    areas_root = args.root or default_areas_root()
    if not areas_root or not os.path.isdir(areas_root):
        print(f"areas root が見つからない: {areas_root}", file=sys.stderr)
        return 1
    repo_root = args.repo_root or repo_root_from(areas_root) or os.path.dirname(areas_root)

    only_paths = None
    if not args.all:
        only_paths = [p.strip() for p in (args.paths or []) if p.strip()]

    plan = build_plan(areas_root, repo_root, only_paths=only_paths)
    for p, hits in plan["blocked"]:
        notify(f"secret疑いで同期拒否: {p}（{', '.join(sorted({lbl for lbl, _ in hits}))}）")

    if not args.apply:
        print("== dry-run（--apply でDB書込。inbox migration適用が前提） ==")
        print_scan_report(plan, as_json=args.json)
        n = len(plan["sync_docs"]) + len(plan["progress"]) + len(plan.get("deletions", []))
        print("")
        print(f"想定送信文数(upsert+progress+delete): {n}（full孤児DELETEはapply時にDB突合で追加）")
        return 0

    # ---- apply（人間ゲート後にのみ到達させる） ----
    lock = acquire_lock()
    if lock is None:
        print("別のplansyncが実行中のためスキップ", file=sys.stderr)
        return 0
    try:
        # 先に既存spoolを掃く
        replay_inbox_spool()
        sent = apply_sync(plan, full=bool(args.all))
        print(f"apply完了: 送信/spool対象 {sent} 文")
        return 0
    finally:
        release_lock(lock)


def main(argv=None):
    argv = argv if argv is not None else sys.argv[1:]
    ap = argparse.ArgumentParser(prog="plansync.py")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_scan = sub.add_parser("scan", help="dry-run抽出のみ（DB非依存）")
    p_scan.add_argument("--root")
    p_scan.add_argument("--repo-root")
    p_scan.add_argument("--json", action="store_true")

    p_sync = sub.add_parser("sync", help="DB同期（既定dry-run・--applyで書込）")
    g = p_sync.add_mutually_exclusive_group(required=True)
    g.add_argument("--all", action="store_true", help="フルreconcile（孤児DELETE込み）")
    g.add_argument("--paths", nargs="*", help="差分同期する repo相対path（post-commit用）")
    p_sync.add_argument("--root")
    p_sync.add_argument("--repo-root")
    p_sync.add_argument("--apply", action="store_true", help="DBへ実書込（人間ゲート後）")
    p_sync.add_argument("--json", action="store_true")

    args = ap.parse_args(argv)
    if args.cmd == "scan":
        return cmd_scan(args)
    if args.cmd == "sync":
        return cmd_sync(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())
