#!/usr/bin/env python3
"""md/turso責務分離と正本反転（子03・案b）の契約回帰テスト。

反転後: board.py は当日デイリーMDを一切読み書きしない。運用データの正本は board DB。
旧「Turso呼出時点でMD確定済み」（MD先・DB後）は逆転し、「MDファイルを作らずDBへ直接書く」を検証する。"""
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
import _fakedb  # noqa: E402

passed = failed = 0


def ok(name, condition):
    global passed, failed
    if condition: passed += 1; print("PASS:", name)
    else: failed += 1; print("FAIL:", name)


# ---- 層の責務分離（正本反転後）----
ok("daily_path互換re-export", board.daily_path is md_store.daily_path)
ok("SQL builder互換re-export", board._stmt_session_upsert is turso_store.stmt_session_upsert)
ok("session読みbuilder re-export", board._stmt_session_read is turso_store.stmt_session_read)
md_source = open(md_store.__file__, encoding="utf-8").read()
turso_source = open(turso_store.__file__, encoding="utf-8").read()
ok("MD層はHTTP/keychain非依存", "urllib" not in md_source and "security" not in md_source and "turso" not in md_source.lower())
ok("MD層はMD I/O（描画・原子的置換）を持たない",
   "edit_daily" not in md_source and "render_body" not in md_source and "def fmt(" not in md_source)
ok("Turso層はデイリーMD非依存", "GOAL_BASE" not in turso_source and "daily-template" not in turso_source)
board_source = open(board.__file__, encoding="utf-8").read()
ok("board.pyはedit_dailyを使わない（MD書き経路が無い）", "edit_daily" not in board_source)

# ---- 正本反転: add はMDファイルを作らず、board DBへ upsert+event を1バッチで送る ----
fake = _fakedb.install(board)
old_argv = sys.argv
sys.argv = ["board.py", "add", "--key", "layer001", "--repo", "RepoL", "--who", "codex/gpt5"]
try: board.main()
finally: sys.argv = old_argv

daily, _ = board.daily_path()
ok("add はデイリーMDファイルを作らない（正本反転）", not os.path.exists(daily))
ok("add は1バッチ送信（HTTP往復1回）", len(fake.sent) == 1)
ok("addはupsert+eventの2文", len(fake.sent[0]) == 2
   and "INTO sessions" in fake.sent[0][0][0] and "session_events" in fake.sent[0][1][0])

# ---- 反転後はDBが正本: 直後の show/check がDBの値を返す（MDを読まない）----
ok("check はDBから run を返す", _fakedb.run_board_inprocess(board, ["check", "--key", "layer001"]).strip() == "run")
show = _fakedb.run_board_inprocess(board, ["show", "--key", "layer001"]).rstrip("\n").split("\t")
ok("show は7フィールド・DB由来", len(show) == 7 and show[0] == "run" and show[4] == "RepoL")
ok("show の who は model 列（runtime接頭辞は非永続＝正本反転の帰結）", show[5] == "gpt5")

print(f"\n== 結果: PASS={passed} FAIL={failed} ==")
sys.exit(1 if failed else 0)
