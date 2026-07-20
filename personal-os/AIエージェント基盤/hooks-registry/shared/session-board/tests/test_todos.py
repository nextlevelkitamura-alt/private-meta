#!/usr/bin/env python3
# 子03スコープA「board.py todo-add」の session-board 追加分を検証する。
#   - todo-add: inbox todos への INSERT。全列を明示（focusmap db/turso/migrations の3ファイル準拠）。
#     status='open'・ai_status='未検知'・route既定=plan・question_allow_free=1/gate=0・作成時NULL列。
#   - CHECK制約列（assignee/source/route）は正当値のみ許可＝不正値は usage 停止（送信なし）。
#   - store.py の builder（stmt_todo_insert）の決定的な形。
# board.main() を in-process で叩き、_turso_sync をモックして送信文をキャプチャする
# （ネットワーク・keychainに触れない）。DB接続が要る実挙動は migration 未適用のため範囲外。
import datetime
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-todos-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-05-01"
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import turso.store as store  # noqa: E402

# board.py の全 Turso 送信は _turso_sync 経由。ここをモックして (statements, db_url) をキャプチャする。
synced = []   # [(statements, db_url), ...]


def _mock_sync(statements, db_url=board.TURSO_DB_URL, service=board.TURSO_KEYCHAIN_SERVICE):
    synced.append(([s for s in statements if s], db_url))


board._turso_sync = _mock_sync

PASS = 0
FAIL = 0


def ok(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("PASS:", name)
    else:
        FAIL += 1
        print("FAIL:", name)


def clear():
    synced.clear()


def run(*argv):
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    try:
        board.main()
    except SystemExit:
        pass
    finally:
        sys.argv = old


def last():
    return synced[-1] if synced else ([], None)


def vals(stmt):
    return [a.get("value") for a in stmt[1]]


def types(stmt):
    return [a.get("type") for a in stmt[1]]


# 列位置（stmt_todo_insert の cols 並びと一致）。読みやすさのため名前で参照する。
COL = {name: i for i, name in enumerate([
    "id", "title", "note", "do_date", "due_date", "repo", "assignee",
    "status", "ai_status", "source", "goal_ref", "session_key",
    "created_at", "updated_at", "completed_at",
    "question", "question_choices", "question_allow_free", "question_gate",
    "question_asked_at", "answer", "answered_at", "answer_consumed_at",
    "route", "completed_by", "theme_id", "carried_from", "awaiting_since"])}

JST_TODAY = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9))).strftime("%Y-%m-%d")

# ---- todo-add: inbox todos への INSERT・既定値 ----
clear()
run("todo-add", "--title", "求人票のドラフトを作る")
stmts, db_url = last()
ok("todo-add: 1件のINSERT INTO todos", len(stmts) == 1 and "INSERT INTO todos" in stmts[0][0])
ok("todo-add: 送信先はinbox DB", db_url == board.TURSO_INBOX_DB_URL)
v = vals(stmts[0])
ok("todo-add: titleが載る", v[COL["title"]] == "求人票のドラフトを作る")
ok("todo-add: do_date既定=今日JST", v[COL["do_date"]] == JST_TODAY)
ok("todo-add: status='open'", v[COL["status"]] == "open")
ok("todo-add: ai_status='未検知'", v[COL["ai_status"]] == "未検知")
ok("todo-add: assignee既定=self", v[COL["assignee"]] == "self")
ok("todo-add: source既定=cli", v[COL["source"]] == "cli")
ok("todo-add: route既定=plan", v[COL["route"]] == "plan")
ok("todo-add: repo既定=none", v[COL["repo"]] == "none")
ok("todo-add: question_allow_free=1 / question_gate=0",
   v[COL["question_allow_free"]] == "1" and v[COL["question_gate"]] == "0")
t = types(stmts[0])
ok("todo-add: completed_at/completed_by/question系は作成時NULL",
   t[COL["completed_at"]] == "null" and t[COL["completed_by"]] == "null"
   and t[COL["question"]] == "null" and t[COL["answer"]] == "null"
   and t[COL["awaiting_since"]] == "null")
ok("todo-add: note/due/theme/carried_from未指定はNULL",
   t[COL["note"]] == "null" and t[COL["due_date"]] == "null"
   and t[COL["theme_id"]] == "null" and t[COL["carried_from"]] == "null")

# 生成した todo_id を stdout へ（AIがステップ登録・質問・紐付けに使う）
import io  # noqa: E402
import contextlib  # noqa: E402
clear()
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    run("todo-add", "--title", "繰越しの検証", "--note", "昨日の続き",
        "--date", "2099-05-02", "--due", "2099-05-10", "--repo", "focusmap",
        "--assignee", "ai", "--route", "single", "--theme", "THEME-9",
        "--carried-from", "2099-04-30", "--source", "chat")
printed = buf.getvalue().strip()
stmts, _ = last()
v = vals(stmts[0])
ok("todo-add: 生成したtodo_idをstdoutへ", len(printed) >= 8 and v[COL["id"]] == printed)
ok("todo-add: 全引数が正しい列へ反映",
   v[COL["title"]] == "繰越しの検証" and v[COL["note"]] == "昨日の続き"
   and v[COL["do_date"]] == "2099-05-02" and v[COL["due_date"]] == "2099-05-10"
   and v[COL["repo"]] == "focusmap" and v[COL["assignee"]] == "ai"
   and v[COL["route"]] == "single" and v[COL["theme_id"]] == "THEME-9"
   and v[COL["carried_from"]] == "2099-04-30" and v[COL["source"]] == "chat")

# ---- 機械必須化・CHECK値の検証（不正は usage 停止＝送信なし）----
clear()
run("todo-add")                                                    # title無し
run("todo-add", "--note", "メモだけ")                              # title無し
run("todo-add", "--title", "x", "--assignee", "boss")             # 不正 assignee
run("todo-add", "--title", "x", "--source", "sms")                # 不正 source
run("todo-add", "--title", "x", "--route", "auto")                # 不正 route
ok("todo-add: title欠落・CHECK不正値は送信しない", len(synced) == 0)

# 正当な CHECK 値はすべて通る
for a in ("self", "ai"):
    clear()
    run("todo-add", "--title", "t", "--assignee", a)
    ok(f"todo-add: assignee={a} は通る", len(synced) == 1)
for s in ("web", "chat", "cli"):
    clear()
    run("todo-add", "--title", "t", "--source", s)
    ok(f"todo-add: source={s} は通る", len(synced) == 1)
for r in ("plan", "routine", "single"):
    clear()
    run("todo-add", "--title", "t", "--route", r)
    ok(f"todo-add: route={r} は通る", len(synced) == 1)

# ---- store.py builder: stmt_todo_insert の決定的な形 ----
st = store.stmt_todo_insert("TID", "やること", "2099-05-01")
ok("stmt_todo_insert: INSERT INTO todos", st is not None and st[0].startswith("INSERT INTO todos"))
ok("stmt_todo_insert: 列数とプレースホルダ数が一致（28）",
   st[0].count("?") == 28 and len(st[1]) == 28)
sv = [a.get("value") for a in st[1]]
ok("stmt_todo_insert: id/title/do_dateが載る",
   sv[COL["id"]] == "TID" and sv[COL["title"]] == "やること" and sv[COL["do_date"]] == "2099-05-01")
ok("stmt_todo_insert: 既定 status='open'/ai_status='未検知'/route='plan'/repo='none'/source='cli'/assignee='self'",
   sv[COL["status"]] == "open" and sv[COL["ai_status"]] == "未検知" and sv[COL["route"]] == "plan"
   and sv[COL["repo"]] == "none" and sv[COL["source"]] == "cli" and sv[COL["assignee"]] == "self")
ok("stmt_todo_insert: created_at==updated_at（同一now）", sv[COL["created_at"]] == sv[COL["updated_at"]])
ok("stmt_todo_insert: todo_id/title/do_date 欠落は None",
   store.stmt_todo_insert("", "t", "2099-05-01") is None
   and store.stmt_todo_insert("i", "", "2099-05-01") is None
   and store.stmt_todo_insert("i", "t", "") is None)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
