#!/usr/bin/env python3
"""md/turso責務分離と既存board import互換の回帰テスト。"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
root = tempfile.mkdtemp(prefix="sbtest-layers-")
os.environ.update(GOAL_BASE=os.path.join(root, "goal"), SESSION_BOARD_DATE="2099-03-01",
                  SESSION_BOARD_STATE_DIR=os.path.join(root, "state"))
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
from md import store as md_store  # noqa: E402
from turso import store as turso_store  # noqa: E402

passed = failed = 0


def ok(name, condition):
    global passed, failed
    if condition: passed += 1; print("PASS:", name)
    else: failed += 1; print("FAIL:", name)


ok("parse_line互換re-export", board.parse_line is md_store.parse_line)
ok("daily_path互換re-export", board.daily_path is md_store.daily_path)
ok("SQL builder互換re-export", board._stmt_session_upsert is turso_store.stmt_session_upsert)
md_source = open(md_store.__file__, encoding="utf-8").read()
turso_source = open(turso_store.__file__, encoding="utf-8").read()
ok("MD層はHTTP/keychain非依存", "urllib" not in md_source and "security" not in md_source and "turso" not in md_source.lower())
ok("Turso層はデイリーMD非依存", "GOAL_BASE" not in turso_source and "daily-template" not in turso_source)

calls = []


def capture(statements, **kwargs):
    path, _ = board.daily_path()
    calls.append((os.path.exists(path), list(statements), kwargs))


board._turso_sync = capture
old_argv = sys.argv
sys.argv = ["board.py", "add", "--key", "layer001", "--repo", "RepoL", "--who", "codex/gpt5"]
try: board.main()
finally: sys.argv = old_argv
ok("Turso呼出時点でMD確定済み", len(calls) == 1 and calls[0][0])
ok("addはupsert+eventの1バッチ", len(calls[0][1]) == 2 and "INTO sessions" in calls[0][1][0][0] and "session_events" in calls[0][1][1][0])

print(f"\n== 結果: PASS={passed} FAIL={failed} ==")
sys.exit(1 if failed else 0)
