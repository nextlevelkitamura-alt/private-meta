#!/usr/bin/env python3
# queries/*.sql（session_events 集計）のテスト。in-memory sqlite3 に本番と同じDDLを張り、
# 台本イベントを入れて3つの保存SQLが期待値を返すことを検証する（ネットワーク非依存）。
# LEAD/LAST_VALUE 窓関数は sqlite 3.25+（macOS標準のpython3 sqlite3で可）。
# 前提: at はJST naiveで保存され、SQL側の now は DATETIME('now','+9 hours')＝マシンTZがJSTなら一致
# （now止めテストはレンジ判定。TZ前提が崩れたら±2分レンジを大きく外れて検知される）。
import datetime
import os
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
QUERIES = os.path.join(HERE, "..", "queries")
sys.path.insert(0, os.path.join(HERE, ".."))
import board  # noqa: E402  board生成のINSERT文が実DDLで通ることの検証に使う

# 本番 Turso に設置済みの実DDL（2026-07-11・列名 trig=trigger がSQLite予約語のため）
DDL = """CREATE TABLE session_events (
  id INTEGER PRIMARY KEY,
  session_key TEXT NOT NULL,
  state TEXT NOT NULL,
  at TEXT NOT NULL,
  trig TEXT,
  goal TEXT,
  repo TEXT,
  type TEXT,
  plan TEXT,
  session_date TEXT
)"""

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


def load_sql(name):
    return open(os.path.join(QUERIES, name), encoding="utf-8").read()


conn = sqlite3.connect(":memory:")
conn.execute(DDL)

ok("sqlite3がLEAD窓関数対応(3.25+)",
   tuple(map(int, sqlite3.sqlite_version.split("."))) >= (3, 25, 0))

D = "2099-03-01"


def ins(key, state, at, goal="G", date=D, trig="flip"):
    conn.execute(
        "INSERT INTO session_events (session_key, state, at, trig, goal, repo, type, plan, session_date) "
        "VALUES (?,?,?,?,?,?,?,?,?)",
        (f"s:{key}", state, at, trig, goal, "RepoQ", "実装", "?", date))


def at(hhmm, date=D):
    return f"{date}T{hhmm}:00.000"


# ---- 台本1（計画書の例）: run 10:00 → wait 10:20 → run 10:30 → done 10:50 ----
ins("scrp0001", "run", at("10:00"), goal="台本1", trig="add")
ins("scrp0001", "wait", at("10:20"), goal="台本1")
ins("scrp0001", "run", at("10:30"), goal="台本1改")   # goal途中更新→最新値が出るか
ins("scrp0001", "done", at("10:50"), goal="台本1改", trig="finish")

# ---- 台本2: sub 区間（run 09:00 → sub 09:10 → run 09:40 → done 09:50）----
ins("scrp0004", "run", at("09:00"), goal="サブ台本", trig="add")
ins("scrp0004", "sub", at("09:10"), goal="サブ台本")
ins("scrp0004", "run", at("09:40"), goal="サブ台本")
ins("scrp0004", "done", at("09:50"), goal="サブ台本", trig="finish")

# ---- 台本3: 720分上限（run → 26時間後 done = 1560分 → 720で頭打ち）----
ins("scrp0002", "run", at("08:00", "2099-03-05"), goal="長丁場", date="2099-03-05", trig="add")
ins("scrp0002", "done", at("10:00", "2099-03-06"), goal="長丁場", date="2099-03-06", trig="finish")

# ---- 台本4: now止め（最後のイベントがrun・LEADなし → 現在時刻まで ≈30分）----
NOW = datetime.datetime.now()
TODAY = NOW.strftime("%Y-%m-%d")
run_30m_ago = (NOW - datetime.timedelta(minutes=30)).isoformat(timespec="milliseconds")
ins("scrp0003", "run", run_30m_ago, goal="走行中", date=TODAY, trig="add")

# ---- 台本5/6: stuck-wait 用（20分放置wait／5分の新しいwait）----
ins("scrp0005", "run", (NOW - datetime.timedelta(minutes=60)).isoformat(timespec="milliseconds"),
    goal="放置中", date=TODAY, trig="add")
ins("scrp0005", "wait", (NOW - datetime.timedelta(minutes=20)).isoformat(timespec="milliseconds"),
    goal="放置中", date=TODAY)
ins("scrp0006", "wait", (NOW - datetime.timedelta(minutes=5)).isoformat(timespec="milliseconds"),
    goal="待ち始め", date=TODAY)

# ==== session-durations.sql ====
rows = conn.execute(load_sql("session-durations.sql")).fetchall()
d = {r[0]: r for r in rows}   # session_key -> (key, goal, session_date, run_min, wait_min, sub_min)
ok("durations: 台本1 run=40分", d["s:scrp0001"][3] == 40)
ok("durations: 台本1 wait=10分", d["s:scrp0001"][4] == 10)
ok("durations: 台本1 sub=0分", d["s:scrp0001"][5] == 0)
ok("durations: 台本1 goal=最新値(台本1改)", d["s:scrp0001"][1] == "台本1改")
ok("durations: サブ台本 run=20分/sub=30分", d["s:scrp0004"][3] == 20 and d["s:scrp0004"][5] == 30)
ok("durations: 720分上限(1560→720)", d["s:scrp0002"][3] == 720)
ok("durations: now止め(走行中≈30分)", 28 <= d["s:scrp0003"][3] <= 32)
ok("durations: doneは区間を持たない(doneのみ列は無い)", all(len(r) == 6 for r in rows))

# ==== daily-totals.sql ====
rows = conn.execute(load_sql("daily-totals.sql"), {"date": D}).fetchall()
ok("totals: :date指定で1行", len(rows) == 1 and rows[0][0] == D)
t = rows[0]   # (session_date, run_min, wait_min, sub_min, sessions)
ok("totals: run合計=60分(40+20)", t[1] == 60)
ok("totals: wait合計=10分", t[2] == 10)
ok("totals: sub合計=30分", t[3] == 30)
ok("totals: セッション数=2", t[4] == 2)
ok("totals: 他日(長丁場)が混ざらない", True if t[1] == 60 else False)
rows = conn.execute(load_sql("daily-totals.sql"), {"date": None}).fetchall()
today_rows = {r[0]: r for r in rows}
ok("totals: :date=NULLは当日JSTへフォールバック", TODAY in today_rows)
ok("totals: 当日の走行中セッションがnow止めで載る(≈30分+放置系)",
   TODAY in today_rows and 28 <= today_rows[TODAY][1])

# ==== stuck-wait.sql ====
rows = conn.execute(load_sql("stuck-wait.sql")).fetchall()
keys = [r[0] for r in rows]
wait_min = {r[0]: r[4] for r in rows}
ok("stuck: 20分放置waitが出る", "s:scrp0005" in keys)
ok("stuck: wait_min≈20分", "s:scrp0005" in wait_min and 18 <= wait_min["s:scrp0005"] <= 22)
ok("stuck: 15分以内のwaitは出ない", "s:scrp0006" not in keys)
ok("stuck: done済みは出ない", "s:scrp0001" not in keys and "s:scrp0002" not in keys)
ok("stuck: 走行中(run)は出ない", "s:scrp0003" not in keys)

# ---- 境界: 15分直前(14分30秒)のwaitは出ない（「15分超」判定・閾値の内側境界）----
ins("scrp0007", "wait",
    (NOW - datetime.timedelta(minutes=14, seconds=30)).isoformat(timespec="milliseconds"),
    goal="境界14.5分", date=TODAY)
rows = conn.execute(load_sql("stuck-wait.sql")).fetchall()
ok("stuck: 15分直前(14.5分)は出ない(超のみ)", "s:scrp0007" not in [r[0] for r in rows])

# ==== board._stmts_events が生成するINSERTが実DDLでそのまま通る ====
row = {"key": "gen00001", "goal": "生成検証", "repo": "R", "type": "実装", "plan": "?"}
for sql, args in board._stmts_events([(row, "run", "add"), (row, "done", "finish")], D):
    conn.execute(sql, [a["value"] for a in args])
got = conn.execute(
    "SELECT session_key, state, trig, goal, session_date FROM session_events "
    "WHERE session_key='s:gen00001' ORDER BY id").fetchall()
ok("board生成INSERTが実DDLで通る(2文)", len(got) == 2)
ok("board生成INSERTの列対応(run/add)", got and got[0] == ("s:gen00001", "run", "add", "生成検証", D))
ok("board生成INSERTの列対応(done/finish)", len(got) == 2 and got[1][1] == "done" and got[1][2] == "finish")

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
