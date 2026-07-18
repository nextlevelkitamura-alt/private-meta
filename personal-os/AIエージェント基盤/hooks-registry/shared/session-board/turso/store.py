"""Turso token・SQL builder・HTTP送信。Markdownへは依存しない。"""
import datetime
import json
import os
import subprocess
import urllib.request
import uuid

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
def null_arg(): return {"type": "null"}


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


def stmts_logs(repo, parent, entries, date_s, session_key=None):
    sql = "INSERT INTO session_logs (repo, parent, entry, session_date, created_at, session_key) VALUES (?, ?, ?, ?, ?, ?)"
    created = datetime.datetime.now().isoformat(timespec="seconds")
    return [(sql, [text_arg(repo), text_arg(parent), text_arg(entry), text_arg(date_s), text_arg(created), text_arg(session_key)]) for entry in entries]


def stmts_events(events, date_s):
    if not events: return []
    at = datetime.datetime.now().isoformat(timespec="milliseconds")
    sql = "INSERT INTO session_events (session_key, state, at, trig, goal, repo, type, plan, session_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
    return [(sql, [text_arg(f"s:{row['key']}"), text_arg(state), text_arg(at), text_arg(trigger), text_arg(row.get("goal")),
                   text_arg(row.get("repo")), text_arg(row.get("type")), text_arg(row.get("plan")), text_arg(date_s)])
            for row, state, trigger in events]


def stmts_reconcile(events, date_s):
    return [stmt for stmt in (stmt_session_upsert(row) for row, _, _ in events) if stmt] + stmts_events(events, date_s)


# ---- 子05 タスク入れ子・2層チェック（inbox DB: todo_steps / todos）----
# 設計契約: %と「レビュー待ち」は保存せずSQL導出・過去ステップ行は書き換えず手直し/レビューは追記。
# ここは決定的なSQL文の生成だけを担い、遷移可否の機械保証をWHERE句に閉じ込める。

_STEP_KINDS = ("step", "review", "fix")
_STEP_STATUSES = ("todo", "doing", "done", "skipped")


def stmts_todo_steps(todo_id, titles, kind="step", session_key=None):
    """計画ステップを追記（登録）。seqは todo 内の MAX+1 を都度採番（連続実行で単調増加）。"""
    if not todo_id or not titles:
        return []
    kind = kind if kind in _STEP_KINDS else "step"
    now = datetime.datetime.now().isoformat(timespec="seconds")
    sql = ("INSERT INTO todo_steps (id, todo_id, seq, title, kind, status, session_key, created_at) "
           "VALUES (?, ?, (SELECT COALESCE(MAX(seq), 0) + 1 FROM todo_steps WHERE todo_id = ?), ?, ?, 'todo', ?, ?)")
    out = []
    for title in titles:
        if not (title or "").strip():
            continue
        out.append((sql, [text_arg(uuid.uuid4().hex), text_arg(todo_id), text_arg(todo_id), text_arg(title),
                          text_arg(kind), (text_arg(session_key) if session_key else null_arg()), text_arg(now)]))
    return out


def stmt_step_status(todo_id, seq, status):
    """ステップ状態を前進（doing/done/skipped）。完了済み(done)行は触らない=過去行UPDATE禁止の機械保証。"""
    if not todo_id or status not in _STEP_STATUSES:
        return None
    now = datetime.datetime.now().isoformat(timespec="seconds")
    sql = "UPDATE todo_steps SET status = ?, done_at = ? WHERE todo_id = ? AND seq = ? AND status != 'done'"
    done_at = text_arg(now) if status == "done" else null_arg()
    return sql, [text_arg(status), done_at, text_arg(todo_id), int_arg(seq)]


def stmt_ask(todo_id, question, choices=None, allow_free=True, gate=False):
    """AIの質問（質問文＋選択肢最大3＋自由入力可否＋人間ゲート可否）を todos へ。回答欄はリセット。"""
    if not todo_id or not (question or "").strip():
        return None
    now = datetime.datetime.now().isoformat(timespec="seconds")
    picked = [c for c in (choices or []) if (c or "").strip()][:3]
    choices_json = json.dumps(picked, ensure_ascii=False) if picked else None
    sql = ("UPDATE todos SET question = ?, question_choices = ?, question_allow_free = ?, question_gate = ?, "
           "question_asked_at = ?, answer = NULL, answered_at = NULL, answer_consumed_at = NULL, "
           "ai_status = '確認待ち', updated_at = ? WHERE id = ?")
    return sql, [text_arg(question), (text_arg(choices_json) if choices_json else null_arg()),
                 int_arg(1 if allow_free else 0), int_arg(1 if gate else 0),
                 text_arg(now), text_arg(now), text_arg(todo_id)]


def stmt_flow_done(todo_id):
    """定型自動流入: routine確定で done へ直行。ただし未完了ステップが残る間は完了させない（NOT EXISTS）。
    宣言照合(scan_board_routes)を通した呼び出し元だけがこの文を送る前提。"""
    if not todo_id:
        return None
    now = datetime.datetime.now().isoformat(timespec="seconds")
    sql = ("UPDATE todos SET status = 'done', ai_status = '完了', route = 'routine', completed_by = 'routine', "
           "completed_at = ?, updated_at = ? "
           "WHERE id = ? AND status != 'done' "
           "AND NOT EXISTS (SELECT 1 FROM todo_steps s WHERE s.todo_id = todos.id AND s.status IN ('todo', 'doing'))")
    return sql, [text_arg(now), text_arg(now), text_arg(todo_id)]


def stmt_goal_insert(name, goal_date=None, source="chat", created_at=None):
    name = (name or "").strip()
    if not name: return None
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    values = [name, goal_date or now.strftime("%Y-%m-%d"), created_at or now.isoformat(timespec="seconds"), (source or "").strip() or "chat", "pending"]
    return "INSERT INTO goals (name, goal_date, created_at, source, status) VALUES (?, ?, ?, ?, ?)", [text_arg(v) for v in values]
