#!/usr/bin/env python3
"""Turso送信失敗スプールの単体テスト（urlopen/keychainは全てモック）。"""
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-spool-")
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402

PASS = 0
FAIL = 0
calls = []
outcomes = []


def ok(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("PASS:", name)
    else:
        FAIL += 1
        print("FAIL:", name)


def urlopen_mock(req, timeout=None):
    calls.append(json.loads(req.data.decode("utf-8")))
    outcome = outcomes.pop(0) if outcomes else "success"
    if outcome == "fail":
        raise TimeoutError("mock timeout")
    return object()


board._turso_token = lambda _service=board.TURSO_KEYCHAIN_SERVICE: "test-token"
board.urllib.request.urlopen = urlopen_mock


def statements_in_spool():
    path, _ = board._spool_paths()
    if not os.path.exists(path):
        return []
    out = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                out.extend(json.loads(line)["statements"])
    return out


event = ("INSERT INTO session_events (session_key) VALUES (?)", [board._ta("s:e1")])
log = ("INSERT INTO session_logs (entry) VALUES (?)", [board._ta("done")])
session = ("INSERT INTO sessions (session_key) VALUES (?)", [board._ta("s:e1")])
delete = ("DELETE FROM sessions WHERE session_key = ?", [board._ta("s:e1")])
goal = ("INSERT INTO goals (name) VALUES (?)", [board._ta("g1")])

# 混在バッチ失敗: 追記式のevents/logsだけを1行へ残す。
outcomes[:] = ["fail"]
spooled = board._turso_execute([session, event, log, delete])
path, lock_path = board._spool_paths()
saved = statements_in_spool()
ok("失敗時はスプール1行を追加", spooled == 1 and os.path.exists(path))
ok("events/logsだけを保存", len(saved) == 2
   and "session_events" in saved[0][0] and "session_logs" in saved[1][0])
ok("sessions upsert/deleteは保存しない", all(" sessions " not in sql for sql, _ in saved))
ok("専用flockファイルを使用", os.path.exists(lock_path))

# 次回送信の末尾: 現在バッチ成功後、以前のスプールを再送し、成功時だけ消費。
calls.clear()
outcomes[:] = ["success", "success"]
board._turso_sync([session])
ok("次回実行で現在送信+再送の2回", len(calls) == 2)
ok("再送成功時にスプールを消費", statements_in_spool() == [])

# 再送失敗: 内容はそのまま残す。
outcomes[:] = ["fail"]
board._turso_execute([event])
before = statements_in_spool()
outcomes[:] = ["success", "fail"]
board._turso_sync([session])
ok("再送失敗時はスプールを保持", statements_in_spool() == before)

# 成功させて空に戻す。
outcomes[:] = ["success", "success"]
board._turso_sync([session])

# sessions/inboxだけの失敗はスプールしない。
outcomes[:] = ["fail"]
ok("sessionsだけの失敗は非対象", board._turso_execute([session, delete]) == 0)
outcomes[:] = ["fail"]
ok("inbox goalsの失敗は非対象", board._turso_execute(
    [goal], db_url=board.TURSO_INBOX_DB_URL,
    service=board.TURSO_INBOX_KEYCHAIN_SERVICE) == 0)
ok("非対象失敗後もスプールは空", statements_in_spool() == [])

# NO_TURSO: 送信・追記・再送を全停止。既存行にも触れない。
outcomes[:] = ["fail"]
board._turso_execute([event])
held = statements_in_spool()
calls.clear()
os.environ["SESSION_BOARD_NO_TURSO"] = "1"
board._turso_sync([event])
ok("NO_TURSOはurlopenを呼ばない", calls == [])
ok("NO_TURSOは追記も再送もしない", statements_in_spool() == held)
del os.environ["SESSION_BOARD_NO_TURSO"]
outcomes[:] = ["success"]
board._turso_replay()

# 上限はJSONL行数でなくstatement 50文。1行51文も部分消費して残り1文を保持する。
many = [(event[0], [board._ta(f"s:e{i}")]) for i in range(51)]
outcomes[:] = ["fail"]
board._turso_execute(many)
outcomes[:] = ["success"]
sent = board._turso_replay()
remaining = statements_in_spool()
ok("再送上限は50文", sent == 50)
ok("51文目を同じJSONL行へ保持", len(remaining) == 1
   and remaining[0][1][0]["value"] == "s:e50")
outcomes[:] = ["success"]
ok("残り1文を次回に消費", board._turso_replay() == 1 and statements_in_spool() == [])

# 今回失敗で追加した末尾は同一送信フェーズでは再試行しない。
calls.clear()
outcomes[:] = ["fail"]
board._turso_sync([event])
ok("新規失敗分は同一実行で即再送しない", len(calls) == 1 and len(statements_in_spool()) == 1)

# ---- 子06: plan_docs/plan_progress の許可リスト拡張と専用spool名の隔離 ----
from turso import spool as _spool  # noqa: E402

pdoc = ("INSERT INTO plan_docs (path) VALUES (?)", [board._ta("p1")])
pprog = ("INSERT INTO plan_progress (program_slug) VALUES (?)", [board._ta("s1")])
pdel = ("DELETE FROM plan_docs WHERE path = ?", [board._ta("p1")])
goal_ns = ("INSERT INTO goals (name) VALUES (?)", [board._ta("g1")])

sp = _spool.spoolable([pdoc, pprog, pdel, goal_ns, session])
ok("plan_docs/plan_progress/DELETEは許可・goals/sessionsは非許可",
   len(sp) == 3 and all("plan_" in s.lower() for s, _ in sp))

# 専用spool名に退避しても既定spool(turso-spool)は汚れない。
n = _spool.append([pdoc, pprog], name="plansync-spool")
default_path, _ = _spool.paths()
plansync_path, _ = _spool.paths("plansync-spool")
ok("plansync-spoolへ1行退避", n == 1 and os.path.exists(plansync_path))
ok("既定spool名と別ファイル", os.path.realpath(default_path) != os.path.realpath(plansync_path))

# 専用spoolはinbox宛senderで再送・成功時に消費（board既定replayとは混ざらない）。
inbox_calls = []
def _inbox_sender(statements, db_url=None, service=None):
    inbox_calls.append(len(statements)); return True
replayed = _spool.replay(_inbox_sender, name="plansync-spool")
def _plansync_left():
    if not os.path.exists(plansync_path): return []
    return [x for line in open(plansync_path, encoding="utf-8") for x in json.loads(line)["statements"]] if os.path.getsize(plansync_path) else []
ok("専用spoolをinbox宛で再送・消費", replayed == 2 and _plansync_left() == [] and inbox_calls == [2])

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
