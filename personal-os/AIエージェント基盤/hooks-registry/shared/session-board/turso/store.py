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


def read(statement, db_url=DB_URL, service=KEYCHAIN_SERVICE, token_getter=token):
    """1件のSELECTを実行し、行を [{col: value}, ...] で返す。失敗・NO_TURSOは None（best-effort読み取り）。"""
    if not statement or os.environ.get("SESSION_BOARD_NO_TURSO"): return None
    try:
        secret = token_getter(service)
        if not secret: return None
        sql, args = statement
        body = {"requests": [{"type": "execute", "stmt": {"sql": sql, "args": args}}, {"type": "close"}]}
        request = urllib.request.Request(db_url + "/v2/pipeline", data=json.dumps(body).encode(), method="POST",
                                         headers={"Authorization": f"Bearer {secret}", "Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            payload = json.loads(response.read().decode())
        result = payload["results"][0]["response"]["result"]
        cols = [c.get("name") for c in result.get("cols", [])]
        rows = []
        for raw in result.get("rows", []):
            rows.append({cols[i]: (None if cell.get("type") == "null" else cell.get("value")) for i, cell in enumerate(raw)})
        return rows
    except Exception:
        return None


def stmt_unconsumed_answers(session_key):
    """当該セッションに紐づく todos のうち、回答済み・未消費の質問回答を取得するSELECT。"""
    if not session_key: return None
    sql = ("SELECT id, title, question, answer, answered_at FROM todos "
           "WHERE session_key = ? AND answer IS NOT NULL AND answer != '' AND answer_consumed_at IS NULL "
           "ORDER BY answered_at")
    return sql, [text_arg(session_key)]


def stmt_mark_answers_consumed(session_key, consumed_at=None):
    """当該セッションの未消費回答を消費済みに落とすUPDATE（注入して渡した後に呼ぶ）。"""
    if not session_key: return None
    now = consumed_at or datetime.datetime.now().isoformat(timespec="seconds")
    sql = ("UPDATE todos SET answer_consumed_at = ?, updated_at = ? "
           "WHERE session_key = ? AND answer IS NOT NULL AND answer != '' AND answer_consumed_at IS NULL")
    return sql, [text_arg(now), text_arg(now), text_arg(session_key)]


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


def stmt_session_affiliation(key, todo_id=None, theme_id=None):
    """子09: セッションの所属先（宣言済み todo_id / theme_id）を sessions へ書く（board DB）。
    プロンプト登録時にAIが update --todo/--theme で宣言した参照値を保存する専用UPDATE。
    MD行には載せない（todo_id/theme_id はボード表示・格納先判定だけに使う board DB 限定列）。
    指定された列だけをSET（partial可）。両方Noneなら None（送らない）。行が無ければ0件で無害。"""
    if not key:
        return None
    sets, params = [], []
    if todo_id is not None:
        sets.append("todo_id = ?"); params.append(text_arg(todo_id))
    if theme_id is not None:
        sets.append("theme_id = ?"); params.append(text_arg(theme_id))
    if not sets:
        return None
    params.append(text_arg(f"s:{key}"))
    return f"UPDATE sessions SET {', '.join(sets)} WHERE session_key = ?", params


def stmt_theme_insert(theme_id, name, purpose, done_criteria, goal_ref=None, plan_refs=None):
    """子09: 大課題テーマを inbox themes へ INSERT（board.py theme-add の実体）。
    themes.ts insertTheme と同型: sort_order は active テーマの MAX+1。purpose/done_criteria は
    AI起点では必須（欠落チェックは呼び出し元＝board.py の usage 停止で機械保証・DB制約では縛らない）。
    plan_refs は slug のリスト（JSON配列文字列で保存・本文コピーはしない）。"""
    name = (name or "").strip()
    if not theme_id or not name:
        return None
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).isoformat(timespec="seconds")
    picked = [p for p in (plan_refs or []) if (p or "").strip()]
    plan_refs_json = json.dumps(picked, ensure_ascii=False) if picked else None
    sql = ("INSERT INTO themes (id, name, purpose, done_criteria, goal_ref, plan_refs, sort_order, status, created_at, updated_at) "
           "VALUES (?, ?, ?, ?, ?, ?, "
           "(SELECT COALESCE(MAX(sort_order), 0) + 1 FROM themes WHERE status = 'active'), "
           "'active', ?, ?)")
    args = [text_arg(theme_id), text_arg(name),
            (text_arg(purpose) if (purpose or "").strip() else null_arg()),
            (text_arg(done_criteria) if (done_criteria or "").strip() else null_arg()),
            (text_arg(goal_ref) if (goal_ref or "").strip() else null_arg()),
            (text_arg(plan_refs_json) if plan_refs_json else null_arg()),
            text_arg(now), text_arg(now)]
    return sql, args


def stmts_logs(repo, parent, entries, date_s, session_key=None, todo_id=None):
    # todo_id 未指定は従来の6列INSERT（session_logs.todo_id 未適用DBでも安全）。
    # 子05: --todo 指定時だけ todo_id 列を含む7列INSERT（migration適用後にAIが渡す）。
    created = datetime.datetime.now().isoformat(timespec="seconds")
    if todo_id:
        sql = "INSERT INTO session_logs (repo, parent, entry, session_date, created_at, session_key, todo_id) VALUES (?, ?, ?, ?, ?, ?, ?)"
        return [(sql, [text_arg(repo), text_arg(parent), text_arg(entry), text_arg(date_s), text_arg(created), text_arg(session_key), text_arg(todo_id)]) for entry in entries]
    sql = "INSERT INTO session_logs (repo, parent, entry, session_date, created_at, session_key) VALUES (?, ?, ?, ?, ?, ?)"
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


# ---- 子08 サブエージェント入れ子可視化（board DB: session_subagents）----
# 設計契約: 体数±1・🔵⇄🟢 は sessions/MD 側そのまま。ここは個体の行を積むだけ。
# ラベルは board.py sub-label（AI）だけが書く＝hookは文面を創作しない。
# 「稼働中N体」は status='running' 集計でSQL導出する（主観値を保存しない）。


def stmt_subagent_start(session_key, session_date, started_at=None):
    """SubagentStart: 個体行を1本INSERT（sub_seq は 親セッション×日 内の MAX+1・labelはNULL）。
    session_key は s:xxxx 形式で渡す（呼び出し元 board.py で付与済み）。"""
    if not session_key or not session_date:
        return None
    now = started_at or datetime.datetime.now().isoformat(timespec="seconds")
    sql = ("INSERT INTO session_subagents (id, session_key, sub_seq, label, status, started_at, session_date) "
           "VALUES (?, ?, (SELECT COALESCE(MAX(sub_seq), 0) + 1 FROM session_subagents "
           "WHERE session_key = ? AND session_date = ?), NULL, 'running', ?, ?)")
    return sql, [text_arg(uuid.uuid4().hex), text_arg(session_key), text_arg(session_key),
                 text_arg(session_date), text_arg(now), text_arg(session_date)]


def stmt_subagent_end(session_key, session_date, ended_at=None):
    """SubagentStop: running のうち最も早く開始した1行を close（FIFO・体数-1と対応）。
    サブ個体の識別子はhookから来ないため、started_at昇順の先頭を閉じる近似（既知の限界・実装結果に記録）。"""
    if not session_key or not session_date:
        return None
    now = ended_at or datetime.datetime.now().isoformat(timespec="seconds")
    sql = ("UPDATE session_subagents SET status = 'done', ended_at = ? "
           "WHERE id = (SELECT id FROM session_subagents "
           "WHERE session_key = ? AND session_date = ? AND status = 'running' "
           "ORDER BY started_at, sub_seq LIMIT 1)")
    return sql, [text_arg(now), text_arg(session_key), text_arg(session_date)]


def stmt_subagent_label(session_key, session_date, label, seq=None):
    """AI（board.py sub-label）が個体行へ1行ラベルを付ける。
    --seq 指定=その連番の行／未指定=最も新しく開始した running 行（＝直前に起動したサブ）。"""
    if not session_key or not session_date or not (label or "").strip():
        return None
    now = datetime.datetime.now().isoformat(timespec="seconds")
    if seq is not None:
        sql = "UPDATE session_subagents SET label = ? WHERE session_key = ? AND session_date = ? AND sub_seq = ?"
        return sql, [text_arg(label), text_arg(session_key), text_arg(session_date), int_arg(seq)]
    sql = ("UPDATE session_subagents SET label = ? "
           "WHERE id = (SELECT id FROM session_subagents "
           "WHERE session_key = ? AND session_date = ? AND status = 'running' "
           "ORDER BY started_at DESC, sub_seq DESC LIMIT 1)")
    return sql, [text_arg(label), text_arg(session_key), text_arg(session_date)]


def stmt_goal_insert(name, goal_date=None, source="chat", created_at=None):
    name = (name or "").strip()
    if not name: return None
    now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
    values = [name, goal_date or now.strftime("%Y-%m-%d"), created_at or now.isoformat(timespec="seconds"), (source or "").strip() or "chat", "pending"]
    return "INSERT INTO goals (name, goal_date, created_at, source, status) VALUES (?, ?, ?, ?, ?)", [text_arg(v) for v in values]
