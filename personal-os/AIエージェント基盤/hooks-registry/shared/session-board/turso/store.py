"""Turso token・SQL builder・HTTP送信。Markdownへは依存しない。"""
import datetime
import json
import os
import subprocess
import urllib.request

DB_URL = "https://personal-os-board-nextlevelkitamura-alt.aws-ap-northeast-1.turso.io"
KEYCHAIN_SERVICE = "turso-personal-os-board"
INBOX_DB_URL = "https://personal-os-inbox-nextlevelkitamura-alt.aws-ap-northeast-1.turso.io"
INBOX_KEYCHAIN_SERVICE = "turso-personal-os-inbox"
TIMEOUT = 3
STATE_WORD = {"🟢": "run", "⏸": "wait", "🔵": "sub"}


def token(service=KEYCHAIN_SERVICE):
    try:
        result = subprocess.run(["security", "find-generic-password", "-a", os.environ.get("USER", ""), "-s", service, "-w"], capture_output=True, text=True, timeout=2)
        return result.stdout.strip() or None
    except Exception: return None


def text_arg(value): return {"type": "text", "value": "" if value is None else str(value)}
def int_arg(value): return {"type": "integer", "value": str(int(value))}


def send(statements, db_url=DB_URL, service=KEYCHAIN_SERVICE, token_getter=token):
    if not statements: return True
    try:
        secret = token_getter(service)
        if not secret: return False
        requests = [{"type": "execute", "stmt": {"sql": sql, "args": args}} for sql, args in statements] + [{"type": "close"}]
        request = urllib.request.Request(db_url + "/v2/pipeline", data=json.dumps({"requests": requests}).encode(), method="POST",
                                         headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json"})
        urllib.request.urlopen(request, timeout=TIMEOUT); return True
    except Exception: return False


def execute(statements, sender, spool_append, db_url=DB_URL, service=KEYCHAIN_SERVICE):
    if not statements or os.environ.get("SESSION_BOARD_NO_TURSO"): return 0
    return 0 if sender(statements, db_url=db_url, service=service) else spool_append(statements)


def stmt_session_upsert(row):
    if not row or not row.get("key"): return None
    sql = ("INSERT INTO sessions (session_key, goal, now, type, repo, model, plan, state, sub_n, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
           "ON CONFLICT(session_key) DO UPDATE SET goal=excluded.goal, now=excluded.now, type=excluded.type, repo=excluded.repo, "
           "model=excluded.model, plan=excluded.plan, state=excluded.state, sub_n=excluded.sub_n, updated_at=excluded.updated_at")
    who = row.get("who") or ""; model = who.split("/")[-1] if "/" in who else who
    return sql, [text_arg(f"s:{row['key']}"), text_arg(row.get("goal")), text_arg(row.get("now")), text_arg(row.get("type")),
                 text_arg(row.get("repo")), text_arg(model), text_arg(row.get("plan")), text_arg(STATE_WORD.get(row.get("state"), "run")),
                 int_arg(int(row.get("sub") or 0)), text_arg(datetime.datetime.now().isoformat(timespec="seconds"))]


def stmt_session_delete(key): return "DELETE FROM sessions WHERE session_key = ?", [text_arg(f"s:{key}")]


def stmts_logs(repo, parent, entries, date_s):
    sql = "INSERT INTO session_logs (repo, parent, entry, session_date, created_at) VALUES (?, ?, ?, ?, ?)"
    created = datetime.datetime.now().isoformat(timespec="seconds")
    return [(sql, [text_arg(repo), text_arg(parent), text_arg(entry), text_arg(date_s), text_arg(created)]) for entry in entries]


def stmts_events(events, date_s):
    if not events: return []
    at = datetime.datetime.now().isoformat(timespec="milliseconds")
    sql = "INSERT INTO session_events (session_key, state, at, trig, goal, repo, type, plan, session_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    return [(sql, [text_arg(f"s:{row['key']}"), text_arg(state), text_arg(at), text_arg(trigger), text_arg(row.get("goal")),
                   text_arg(row.get("repo")), text_arg(row.get("type")), text_arg(row.get("plan")), text_arg(date_s)])
            for row, state, trigger in events]


def stmts_reconcile(events, date_s):
    return [stmt for stmt in (stmt_session_upsert(row) for row, _, _ in events) if stmt] + stmts_events(events, date_s)


def stmt_goal_insert(name, goal_date=None, source="chat", created_at=None):
    name = (name or "").strip()
    if not name: return None
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    values = [name, goal_date or now.strftime("%Y-%m-%d"), created_at or now.isoformat(timespec="seconds"), (source or "").strip() or "chat", "pending"]
    return "INSERT INTO goals (name, goal_date, created_at, source, status) VALUES (?, ?, ?, ?, ?)", [text_arg(v) for v in values]
