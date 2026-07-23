#!/usr/bin/env python3
"""正本反転（子03・案b）後の session-board テスト用の in-memory fake Turso。

board.py は当日デイリーMDを廃止し、運用データ（sessions/session_events/session_logs/session_subagents）を
board DB へ直接読み書きする。そのため、状態遷移・体数・出力形式・イベント発行を検証するテストは
board._turso_send / board._turso_read を本ハーネスへ差し替え、in-memory sqlite（本番と同じ列）に対して
E2E で流す（本番 Turso へは一切飛ばない）。send された全 statement は `sent` に積み、送信文の形も検証できる。

board DB と inbox DB を db_url で振り分ける（inbox 宛は "inbox" を URL に含む）。
DDL は本番テーブルの列に合わせる（sessions は 20260719 migration の todo_id/theme_id 込み）。
"""
import contextlib
import io
import sqlite3
import sys

# 本番 board DB のテーブル（sessions は基底＋子09の todo_id/theme_id・列は stmt_session_upsert / affiliation 準拠）。
_BOARD_DDL = [
    """CREATE TABLE sessions (
        session_key TEXT PRIMARY KEY,
        goal TEXT, now TEXT, type TEXT, repo TEXT, model TEXT, plan TEXT,
        state TEXT, sub_n INTEGER DEFAULT 0, updated_at TEXT,
        todo_id TEXT, theme_id TEXT)""",
    """CREATE TABLE session_events (
        id INTEGER PRIMARY KEY, session_key TEXT NOT NULL, state TEXT NOT NULL,
        at TEXT NOT NULL, trig TEXT, goal TEXT, repo TEXT, type TEXT, plan TEXT, session_date TEXT)""",
    """CREATE TABLE session_logs (
        id INTEGER PRIMARY KEY, repo TEXT, parent TEXT, entry TEXT,
        session_date TEXT, created_at TEXT, session_key TEXT, todo_id TEXT)""",
    """CREATE TABLE session_subagents (
        id TEXT PRIMARY KEY, session_key TEXT NOT NULL, sub_seq INTEGER NOT NULL,
        label TEXT, status TEXT NOT NULL DEFAULT 'running',
        started_at TEXT NOT NULL, ended_at TEXT, session_date TEXT NOT NULL)""",
    """CREATE TABLE session_execution_contexts (
        session_key TEXT PRIMARY KEY,
        runtime TEXT NOT NULL CHECK (runtime IN ('codex', 'claude')),
        repo_key TEXT NOT NULL, display_name TEXT NOT NULL,
        scope_kind TEXT NOT NULL CHECK (scope_kind IN ('git', 'folder')),
        identity_state TEXT NOT NULL CHECK (identity_state IN ('detected', 'unregistered')),
        canonical_repo_path TEXT, worktree_root TEXT NOT NULL, cwd_path TEXT NOT NULL,
        branch TEXT, first_seen_at TEXT NOT NULL, updated_at TEXT NOT NULL)""",
    """CREATE TABLE session_route_proposals (
        id TEXT PRIMARY KEY, session_key TEXT NOT NULL, turn_id TEXT NOT NULL,
        runtime TEXT NOT NULL CHECK (runtime IN ('codex', 'claude')), repo_key TEXT NOT NULL,
        event_fingerprint TEXT NOT NULL, safe_summary TEXT,
        route_kind TEXT NOT NULL DEFAULT 'pending'
          CHECK (route_kind IN ('pending', 'plan', 'theme_work', 'plan_candidate', 'theme_candidate', 'unclassified')),
        theme_id TEXT, plan_slug TEXT, reason TEXT,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'proposed', 'accepted', 'rejected', 'superseded')),
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        UNIQUE(session_key, turn_id))""",
]

# 本番 inbox DB のテーブル（テストで書く分だけ・列は builder 準拠）。
_INBOX_DDL = [
    """CREATE TABLE repos (
        slug TEXT PRIMARY KEY, name TEXT NOT NULL, sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT)""",
    """CREATE TABLE todos (
        id TEXT PRIMARY KEY, title TEXT, note TEXT, do_date TEXT, due_date TEXT, repo TEXT,
        assignee TEXT, status TEXT, ai_status TEXT, source TEXT, goal_ref TEXT, session_key TEXT,
        created_at TEXT, updated_at TEXT, completed_at TEXT,
        question TEXT, question_choices TEXT, question_allow_free INTEGER, question_gate INTEGER,
        question_asked_at TEXT, answer TEXT, answered_at TEXT, answer_consumed_at TEXT,
        route TEXT, completed_by TEXT, theme_id TEXT, carried_from TEXT, awaiting_since TEXT,
        plan_slug TEXT)""",
    # todo_steps.started_at は子09の 20260719 migration で追加済み（本番適用済み）＝子02の step-doing 打刻対象。
    """CREATE TABLE todo_steps (
        id TEXT PRIMARY KEY, todo_id TEXT, seq INTEGER, title TEXT, kind TEXT,
        status TEXT, session_key TEXT, created_at TEXT, done_at TEXT, started_at TEXT)""",
    """CREATE TABLE themes (
        id TEXT PRIMARY KEY, name TEXT, purpose TEXT, done_criteria TEXT,
        goal_ref TEXT, plan_refs TEXT, sort_order INTEGER, status TEXT,
        created_at TEXT, updated_at TEXT)""",
    """CREATE TABLE goals (
        id INTEGER PRIMARY KEY, name TEXT, goal_date TEXT, created_at TEXT, source TEXT, status TEXT)""",
    """CREATE TABLE plan_docs (
        path TEXT PRIMARY KEY, program_slug TEXT, kind TEXT, nn TEXT, title TEXT, bucket TEXT,
        body TEXT, content_hash TEXT, git_commit TEXT, synced_at TEXT)""",
]


def _params(args):
    """turso pipeline の args（{"type","value"} 列）を sqlite の位置引数へ。null は None。integer は int。"""
    out = []
    for a in args:
        t = a.get("type")
        if t == "null":
            out.append(None)
        elif t == "integer":
            out.append(int(a.get("value")))
        else:
            out.append(a.get("value"))
    return out


class FakeTurso:
    def __init__(self):
        self.board = sqlite3.connect(":memory:")
        self.inbox = sqlite3.connect(":memory:")
        for ddl in _BOARD_DDL:
            self.board.execute(ddl)
        for ddl in _INBOX_DDL:
            self.inbox.execute(ddl)
        self.sent = []      # 送信バッチの履歴（1要素=1バッチ=[(sql,args),...]）
        self.db_urls = []   # sent と並行: 各バッチの宛先 db_url（board / inbox の検証用）

    def _conn(self, db_url):
        return self.inbox if "inbox" in (db_url or "") else self.board

    def send(self, statements, db_url=None, service=None, token_getter=None):
        statements = [s for s in statements if s]
        if not statements:
            return True
        self.sent.append(list(statements))
        self.db_urls.append(db_url)
        conn = self._conn(db_url)
        try:
            for sql, args in statements:
                conn.execute(sql, _params(args))
            conn.commit()
            return True
        except Exception:   # noqa: BLE001  失敗しても sent には積んである（形の検証は可能）
            return False

    def read(self, statement, db_url=None, service=None, token_getter=None):
        if statement is None:
            return None
        conn = self._conn(db_url)
        sql, args = statement
        try:
            cur = conn.execute(sql, _params(args))
        except Exception:   # noqa: BLE001
            return None
        cols = [c[0] for c in cur.description] if cur.description else []
        return [dict(zip(cols, row)) for row in cur.fetchall()]

    def read_many(self, statements, db_url=None, service=None, token_getter=None):
        batches = []
        for statement in statements:
            rows = self.read(statement, db_url=db_url, service=service, token_getter=token_getter)
            if rows is None:
                return None
            batches.append(rows)
        return batches

    # ---- 検証補助 ----
    def flat(self):
        """全バッチをフラット化した [(sql, args), ...]。"""
        return [stmt for batch in self.sent for stmt in batch]

    def clear(self):
        self.sent.clear()
        self.db_urls.clear()

    def last(self):
        """最後のバッチ (statements, db_url)。無ければ ([], None)。"""
        if not self.sent:
            return [], None
        return self.sent[-1], self.db_urls[-1]

    def query(self, sql, params=(), db="board"):
        conn = self.board if db == "board" else self.inbox
        return conn.execute(sql, params).fetchall()


def install(board):
    """board モジュールの送受信を fake へ差し替える。返り値の FakeTurso で状態と送信文を検証する。
    NO_TURSO は execute/send_inbox が短絡させるため、呼び出し側で必ず pop しておくこと。"""
    fake = FakeTurso()
    board._turso_send = fake.send
    board._turso_read = fake.read
    board._turso_read_many = fake.read_many
    return fake


class _CP:
    """subprocess.CompletedProcess の最小代替（stdout/returncode のみ）。"""
    def __init__(self, stdout="", returncode=0):
        self.stdout = stdout
        self.returncode = returncode


def run_board_inprocess(board, argv):
    """board.main() を in-process で叩き stdout を返す（subprocess を使わずに fake DB を共有するため）。"""
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            try:
                board.main()
            except SystemExit:
                pass
    finally:
        sys.argv = old
    return buf.getvalue()


def patch_common(common, board):
    """common.py が board を叩く subprocess を in-process 実行へ差し替える。
    これで shim ロジック（初回ガイド／ミラー／復帰／回答注入）を fake DB 上で E2E 検証できる。
    board.py 以外（git 等）の subprocess.run は本物へ委譲する。"""
    real_run = common.subprocess.run

    def fake_run(cmd, *a, **k):
        if cmd and str(cmd[0]).endswith("board.py"):
            return _CP(stdout=run_board_inprocess(board, list(cmd[1:])), returncode=0)
        return real_run(cmd, *a, **k)

    common.subprocess.run = fake_run
    return real_run
