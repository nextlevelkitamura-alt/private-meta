#!/usr/bin/env python3
# session_events（状態遷移イベントログ・層3）のイベント構築テスト（正本反転・子03後）。
# board.main() を in-process で叩き、fake DB（board._turso_send/_turso_read 差し替え）へ流す。
# 反転後は board.py が DB から現在行を読んで遷移計算するため、状態は fake sqlite が保持する
# （add した行を flip/sub が読む＝MDを介さない）。本番Tursoへは一切飛ばない。
# 検証: add新規=1本/冪等=0本・flip変化=1本/同状態=0本・finish=doneスナップショット・
#       reconcile降格=変更行分・sub状態遷移・update/log=0本・sessions/logs との同一バッチ合流（HTTP往復1回）。
import datetime
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-events-")
TX = os.path.join(SP, "tx")
os.makedirs(TX, exist_ok=True)
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-02-01"
os.environ["SESSION_BOARD_TX_ROOTS"] = TX
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)   # fake DB を使うので NO_TURSO は必ず外す

import board  # noqa: E402
import _fakedb  # noqa: E402

fake = _fakedb.install(board)
calls = fake.sent   # 1呼び出し=1バッチ=[(sql,args),...]（fake.clear()で in-place クリア）

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
    fake.clear()


def run(*argv):
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    try:
        board.main()
    except SystemExit:
        pass
    finally:
        sys.argv = old


def events():
    """全送信文から session_events INSERT を dict のリストで抽出。"""
    out = []
    for sql, args in fake.flat():
        if "session_events" in sql:
            v = [a.get("value") for a in args]
            out.append({"session_key": v[0], "state": v[1], "at": v[2], "trig": v[3],
                        "goal": v[4], "repo": v[5], "type": v[6], "plan": v[7],
                        "session_date": v[8]})
    return out


def upserts():
    return [(sql, args) for sql, args in fake.flat() if "INTO sessions" in sql]


def subagents(needle="session_subagents"):
    return [(sql, args) for sql, args in fake.flat() if needle in sql]


def hhmm_ago(mins):
    return (datetime.datetime.now() - datetime.timedelta(minutes=mins)).strftime("%H:%M")


# ---- add: 新規=1本（run/add）・sessions upsert と同一バッチ ----
clear()
run("add", "--key", "evnt0001", "--repo", "RepoE", "--who", "claude/?", "--time", "10:00")
ev = events()
ok("add新規=イベント1本", len(ev) == 1)
ok("add: state=run / trig=add", ev and ev[0]["state"] == "run" and ev[0]["trig"] == "add")
ok("add: session_key=s:形式", ev and ev[0]["session_key"] == "s:evnt0001")
ok("add: session_date=SESSION_BOARD_DATE", ev and ev[0]["session_date"] == "2099-02-01")
ok("add: at=ISO ms形式", ev and re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}$", ev[0]["at"]))
ok("add: sessions upsertも送る", len(upserts()) == 1)
ok("add: 合流=送信は1バッチ(往復1回)", len(calls) == 1 and len(calls[0]) == 2)

# ---- add 冪等: 既存行への再addはイベント0本（upsertは従来どおり送る）----
clear()
run("add", "--key", "evnt0001", "--repo", "RepoX", "--who", "codex/?")
ok("add冪等=イベント0本", len(events()) == 0)
ok("add冪等: sessions upsertは送る(従来挙動)", len(upserts()) == 1)

# ---- update: イベント0本・upsert（読み→マージ→書き）----
clear()
run("update", "--key", "evnt0001", "--goal", "イベント検証", "--type", "実装",
    "--now", "テスト", "--model", "fable5", "--plan", "デイリーボード改善/03")
ok("update=イベント0本", len(events()) == 0)
ok("update: sessions upsertは送る", len(upserts()) == 1)
ok("update: DBに反映（次のshowで確認できる状態）",
   fake.query("SELECT goal, model, plan FROM sessions WHERE session_key='s:evnt0001'")[0]
   == ("イベント検証", "fable5", "デイリーボード改善/03"))

# ---- flip: 変化=1本（行スナップショット付き）・同状態=0本 ----
clear()
run("flip", "--key", "evnt0001", "--state", "wait")
ev = events()
ok("flip変化=イベント1本", len(ev) == 1)
ok("flip: state=wait / trig=flip", ev and ev[0]["state"] == "wait" and ev[0]["trig"] == "flip")
ok("flip: goal/plan/type/repoスナップショット",
   ev and ev[0]["goal"] == "イベント検証" and ev[0]["plan"] == "デイリーボード改善/03"
   and ev[0]["type"] == "実装" and ev[0]["repo"] == "RepoE")
clear()
run("flip", "--key", "evnt0001", "--state", "wait")
ok("同状態flip=イベント0本", len(events()) == 0)
ok("同状態flip: sessions upsertは送る(従来挙動)", len(upserts()) == 1)
clear()
run("flip", "--key", "evnt0001", "--state", "run")
ok("flip復帰(wait→run)=イベント1本", len(events()) == 1 and events()[0]["state"] == "run")

# ---- sub-start / sub-end: 状態変化時だけevent、体数変化は毎回upsert、子08=個体行も積む ----
clear()
run("sub-start", "--key", "evnt0001")
ok("sub-start: run→subイベント", len(events()) == 1
   and events()[0]["state"] == "sub" and events()[0]["trig"] == "sub-start")
ok("sub-start(run→sub): upsert+event+subagent行を1バッチ",
   len(calls) == 1 and len(calls[0]) == 3 and len(upserts()) == 1)
ok("子08 sub-start: session_subagents INSERT 1本", len(subagents("INTO session_subagents")) == 1)
clear()
run("sub-start", "--key", "evnt0001")
ok("サブ1→2体: 状態遷移event無し・upsertあり（体数±1不変）", len(events()) == 0 and len(upserts()) == 1)
ok("子08 サブ1→2体: 遷移event無しでも個体行は積む", len(subagents("INTO session_subagents")) == 1)
clear()
run("sub-end", "--key", "evnt0001")
ok("サブ2→1体: 状態遷移event無し・upsertあり", len(events()) == 0 and len(upserts()) == 1)
ok("子08 サブ2→1体: 個体行を1本close(UPDATE)", len(subagents("UPDATE session_subagents")) == 1)
clear()
run("sub-end", "--key", "evnt0001")
ok("最後のsub-end: sub→runイベント", len(events()) == 1
   and events()[0]["state"] == "run" and events()[0]["trig"] == "sub-end")
ok("最後のsub-end(sub→run): upsert+event+subagent closeを1バッチ",
   len(calls) == 1 and len(calls[0]) == 3 and len(upserts()) == 1)
ok("子08 最後のsub-end: session_subagents UPDATE(close) 1本", len(subagents("UPDATE session_subagents")) == 1)
run("flip", "--key", "evnt0001", "--state", "wait")
clear()
run("sub-start", "--key", "evnt0001")
ok("sub-start: wait→subもイベント", len(events()) == 1
   and events()[0]["state"] == "sub" and events()[0]["trig"] == "sub-start")
ok("子08 wait→sub でも個体行を積む", len(subagents("INTO session_subagents")) == 1)
run("sub-end", "--key", "evnt0001")

# ---- log: イベント0本 ----
clear()
run("log", "--key", "evnt0001", "--repo", "RepoE", "--parent", "イベント検証", "--entry", "節目1")
ok("log=イベント0本", len(events()) == 0)
ok("log: session_logs INSERTを送る", any("session_logs" in sql for sql, _ in fake.flat()))

# ---- finish: done 1本（del前スナップショット）・logs+delete+eventsの同一バッチ ----
clear()
run("finish", "--key", "evnt0001", "--repo", "RepoE", "--parent", "イベント検証", "--entry", "締め")
ev = events()
ok("finish=doneイベント1本", len(ev) == 1)
ok("finish: state=done / trig=finish", ev and ev[0]["state"] == "done" and ev[0]["trig"] == "finish")
ok("finish: 削除前スナップショット(goal保持)", ev and ev[0]["goal"] == "イベント検証")
ok("finish: 合流=1バッチにlogs+delete+event",
   len(calls) == 1 and len(calls[0]) == 3
   and any("session_logs" in sql for sql, _ in calls[0])
   and any("DELETE FROM sessions" in sql for sql, _ in calls[0]))
ok("finish: DBから行が消える", fake.query("SELECT COUNT(*) FROM sessions WHERE session_key='s:evnt0001'")[0][0] == 0)

# ---- 行なしfinish: スナップショットできる行が無い→イベント0本（logs+deleteは送る）----
clear()
run("finish", "--key", "nol1ne99", "--repo", "RepoE", "--parent", "行なし", "--entry", "残務")
ok("行なしfinish=イベント0本", len(events()) == 0)
ok("行なしfinish: logs+deleteは送る", len(calls) == 1 and len(calls[0]) == 2)

# ---- reconcile: ⏸降格=変更行分（NOFILE経路: files非空・実体なし・updated_at 15分超）----
open(os.path.join(TX, "other-key.jsonl"), "w").close()   # files非空（key不一致）
run("add", "--key", "evre0001", "--repo", "RepoR", "--who", "claude/?", "--time", hhmm_ago(30))
run("update", "--key", "evre0001", "--goal", "降格対象", "--now", "放置")
# updated_at を16分前へ手で戻す（実運用の「登録後に更新が止まって沈黙」を再現。fake DBを直接更新）。
_old_iso = (datetime.datetime.now() - datetime.timedelta(minutes=16)).isoformat(timespec="seconds")
fake.board.execute("UPDATE sessions SET updated_at=? WHERE session_key='s:evre0001'", (_old_iso,))
fake.board.commit()
run("add", "--key", "evre0002", "--repo", "RepoR", "--who", "claude/?", "--time", hhmm_ago(5))
clear()
run("reconcile")
ev = events()
ok("reconcile降格=変更行分(1本)", len(ev) == 1)
ok("reconcile: state=wait / trig=reconcile",
   ev and ev[0]["state"] == "wait" and ev[0]["trig"] == "reconcile")
ok("reconcile: 降格行のスナップショット", ev and ev[0]["session_key"] == "s:evre0001"
   and ev[0]["goal"] == "降格対象")
ok("reconcile: 降格行のsessions upsertを同梱", len(upserts()) == 1)
ok("reconcile: upsert+eventを1バッチ", len(calls) == 1 and len(calls[0]) == 2)
ok("reconcile: DB上も wait に降格", fake.query(
   "SELECT state, sub_n FROM sessions WHERE session_key='s:evre0001'")[0] == ("wait", 0))
clear()
run("reconcile")
ok("再reconcile(既に⏸)=イベント0本", len(events()) == 0)

# ---- Stop経路（session-end.py 相当: flip wait → reconcile）: wait はちょうど1本 ----
run("add", "--key", "evst0001", "--repo", "RepoS", "--who", "claude/?")   # 現在時刻で登録
open(os.path.join(TX, "evst0001-tx.jsonl"), "w").close()   # 実体あり(新しい)→reconcile降格対象外
clear()
run("flip", "--key", "evst0001", "--state", "wait")
run("reconcile")
ev = [e for e in events() if e["session_key"] == "s:evst0001"]
ok("Stop経路: waitイベントはちょうど1本(二重打ち無し)",
   len(ev) == 1 and ev[0]["state"] == "wait" and ev[0]["trig"] == "flip")

# ---- turso_append_events 単体（date_s省略=当日解決・空リスト=送信なし）----
clear()
row = {"key": "evap0001", "goal": "G", "repo": "R", "type": "実装", "plan": "?"}
board.turso_append_events([(row, "run", "add")])
ev = events()
ok("turso_append_events: 1バッチ1文", len(calls) == 1 and len(calls[0]) == 1)
ok("turso_append_events: date_s省略で当日(SESSION_BOARD_DATE)",
   ev and ev[0]["session_date"] == "2099-02-01")
clear()
board.turso_append_events([])
ok("turso_append_events: 空リストは送信しない", len(calls) == 0)

# ---- _turso_execute 本物: NO_TURSO/空リストで即return（ネットワーク・keychainに触れない）----
os.environ["SESSION_BOARD_NO_TURSO"] = "1"
try:
    board._turso_execute([("INSERT INTO session_events (session_key) VALUES (?)", [board._ta("s:x")])])
    ok("NO_TURSO: 本物_turso_executeが即return", True)
except Exception:
    ok("NO_TURSO: 本物_turso_executeが即return", False)
del os.environ["SESSION_BOARD_NO_TURSO"]
try:
    board._turso_execute([])
    ok("空statements: 本物_turso_executeが即return", True)
except Exception:
    ok("空statements: 本物_turso_executeが即return", False)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
