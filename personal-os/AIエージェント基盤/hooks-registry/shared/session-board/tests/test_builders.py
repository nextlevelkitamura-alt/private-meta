#!/usr/bin/env python3
"""Turso文ビルダーのネットワーク非依存テスト。"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

import board  # noqa: E402

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


def values(args):
    return [arg["value"] for arg in args]


row = {"key": "build001", "goal": "目標", "now": "今", "type": "実装", "repo": "RepoB",
       "who": "codex/gpt5", "plan": "企画/03", "state": board.SUB, "sub": 3}
sql, args = board._stmt_session_upsert(row)
ok("session upsert: INSERT列にsub_n", "state, sub_n, updated_at" in sql)
ok("session upsert: UPDATE対象にsub_n", "sub_n=excluded.sub_n" in sql)
ok("session upsert: sub_n引数はinteger 3", args[8] == {"type": "integer", "value": "3"})
ok("session upsert: 引数数10", len(args) == 10)

events = [(dict(row, state=board.WAIT, sub=0), "wait", "reconcile")]
stmts = board._stmts_reconcile(events, "2099-02-02")
ok("reconcile builder: upsertを含む", len(stmts) == 2 and "INTO sessions" in stmts[0][0])
ok("reconcile builder: eventを同梱", "INTO session_events" in stmts[1][0])
ok("reconcile builder: 降格後のstate/sub_n", values(stmts[0][1])[7:9] == ["wait", "0"])

goal = board._stmt_goal_insert("  新しい目標  ", "2099-02-03", "manual",
                               "2099-02-03T12:34:56+09:00")
goal_sql, goal_args = goal
ok("goal-add builder: goals列", "(name, goal_date, created_at, source, status)" in goal_sql)
ok("goal-add builder: trim済みargs", values(goal_args) == ["新しい目標", "2099-02-03",
                                               "2099-02-03T12:34:56+09:00", "manual", "pending"])
ok("goal-add builder: 空nameは文を作らない", board._stmt_goal_insert("   ") is None)

default_goal = board._stmt_goal_insert("日付既定", created_at="2099-02-03T00:00:00+09:00")
default_values = values(default_goal[1])
ok("goal-add builder: 日付既定はYYYY-MM-DD", len(default_values[1]) == 10 and default_values[1][4] == "-")
ok("goal-add builder: source既定はchat", default_values[3] == "chat")

cli_root = tempfile.mkdtemp(prefix="sbtest-goal-add-")
cli_env = dict(os.environ, SESSION_BOARD_NO_TURSO="1", GOAL_BASE=os.path.join(cli_root, "missing"))
valid = subprocess.run([sys.executable, board.__file__, "goal-add", "--name", "CLI目標"],
                       capture_output=True, text=True, env=cli_env)
ok("goal-add CLI: デイリー未作成でも成功", valid.returncode == 0
   and not os.path.exists(cli_env["GOAL_BASE"]))
missing = subprocess.run([sys.executable, board.__file__, "goal-add", "--name", "   "],
                         capture_output=True, text=True, env=cli_env)
ok("goal-add CLI: 空nameはusageをstderrへ出して終了", missing.returncode != 0
   and "usage: board.py goal-add" in missing.stderr)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
