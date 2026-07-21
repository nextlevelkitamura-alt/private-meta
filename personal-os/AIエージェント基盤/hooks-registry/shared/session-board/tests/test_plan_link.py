#!/usr/bin/env python3
# 子02「計画接続」の DB 実挙動 E2E（fake DB・本番Tursoへは飛ばない）。
#   - todo-add --plan で todos.plan_slug が実際に入る。
#   - step-doing で todo_steps.started_at が実UPDATEされる（COALESCE で初回を保持）。
#   - flow-done は plan_slug 付き todo を全step消化でも自動完了しない（WHERE plan_slug IS NULL）。
#   - flow-done は plan_slug NULL の todo なら従来どおり完了できる（回帰チェック）。
# board.py を in-process で叩き、inbox コマンドは fake の inbox DB へ実際に書く。
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-planlink-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-07-21"
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import _fakedb  # noqa: E402

fake = _fakedb.install(board)

# board.py の inbox 系は _turso_send_inbox → _turso_send（db_url=INBOX）。_turso_send は fake.send に
# 差し替え済みなので inbox 宛は fake の inbox DB へ実際に書き込まれる。scan_board_routes を通すため
# flow-done 用の routine 宣言 skill を用意する。
ROUTES = os.path.join(SP, "routes", "demo-routine")
os.makedirs(ROUTES, exist_ok=True)
with open(os.path.join(ROUTES, "SKILL.md"), "w", encoding="utf-8") as f:
    f.write("---\nboard_route: routine\n---\n# demo\n")
os.environ["SESSION_BOARD_ROUTE_ROOTS"] = os.path.join(SP, "routes")

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


def b(*argv):
    return _fakedb.run_board_inprocess(board, list(argv)).rstrip("\n")


def iq(sql, params=()):
    return fake.inbox.execute(sql, params).fetchall()


# ---- (1) todo-add --plan → plan_slug が実DBへ ----
todo_plan = b("todo-add", "--title", "計画付きやること", "--assignee", "ai",
              "--plan", "2099-07-21-例#02", "--date", "2099-07-21")
row = iq("SELECT plan_slug FROM todos WHERE id = ?", (todo_plan,))
ok("todo-add --plan: plan_slug が実DBに入る", row and row[0][0] == "2099-07-21-例#02")

# ---- (2) step-doing → started_at 実打刻・COALESCE で初回保持 ----
b("steps", "--todo", todo_plan, "--entry", "実装")
b("step-doing", "--todo", todo_plan, "--seq", "1")
r1 = iq("SELECT status, started_at FROM todo_steps WHERE todo_id = ? AND seq = 1", (todo_plan,))
ok("step-doing: status=doing・started_at打刻", r1 and r1[0][0] == "doing" and r1[0][1])
first_started = r1[0][1]
b("step-doing", "--todo", todo_plan, "--seq", "1")   # 再doing でも初回を保持
r2 = iq("SELECT started_at FROM todo_steps WHERE todo_id = ? AND seq = 1", (todo_plan,))
ok("step-doing: 再doingでも started_at は初回のまま（COALESCE）", r2 and r2[0][0] == first_started)
b("step-done", "--todo", todo_plan, "--seq", "1")
r3 = iq("SELECT status, done_at, started_at FROM todo_steps WHERE todo_id = ? AND seq = 1", (todo_plan,))
ok("step-done: done_at刻む・started_at は保持（所要分の起点）",
   r3 and r3[0][0] == "done" and r3[0][1] and r3[0][2] == first_started)

# ---- (3) flow-done: plan_slug 付きは全step消化でも自動完了しない ----
b("flow-done", "--todo", todo_plan, "--skill", "demo-routine")
r4 = iq("SELECT status, completed_at FROM todos WHERE id = ?", (todo_plan,))
ok("flow-done抑止: plan_slug付きは status='open' のまま・completed_at NULL",
   r4 and r4[0][0] == "open" and r4[0][1] is None)

# ---- (4) 回帰: plan_slug NULL の todo は従来どおり flow-done で完了する ----
todo_plain = b("todo-add", "--title", "計画なしやること", "--assignee", "ai", "--date", "2099-07-21")
b("steps", "--todo", todo_plain, "--entry", "手順")
b("step-done", "--todo", todo_plain, "--seq", "1")
b("flow-done", "--todo", todo_plain, "--skill", "demo-routine")
r5 = iq("SELECT status, completed_by, completed_at FROM todos WHERE id = ?", (todo_plain,))
ok("回帰: plan_slug NULL は flow-done で done/completed_by=routine",
   r5 and r5[0][0] == "done" and r5[0][1] == "routine" and r5[0][2])

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
