#!/usr/bin/env python3
# 正本反転（子03・案b）後の board.py CLI ライフサイクル E2E（旧 test-session-board.sh の
# 状態密度を DB-first で置換）。MDは介さず、add→check/show/goals→update→flip→sub→log→finish→
# reconcile が board DB を正本に動くことを in-process（fake DB）で検証する。本番Tursoへは飛ばない。
# 「MD描画そのもの」（インデント・goals-summary・‹計画:›・(+Nm)経過表示）は正本反転で廃止＝検証しない。
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-lifecycle-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-01-01"
os.environ["SESSION_BOARD_TX_ROOTS"] = os.path.join(SP, "tx")
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import _fakedb  # noqa: E402

fake = _fakedb.install(board)

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
    """board.py を in-process 実行し stdout を返す。"""
    return _fakedb.run_board_inprocess(board, list(argv)).rstrip("\n")


DAILY, _ = board.daily_path()

# ---- add → check/show（DBが正本・MDは作らない）----
b("add", "--key", "aaaa0001", "--repo", "RepoA", "--who", "claude/?", "--time", "14:00")
ok("正本反転: デイリーMDファイルを作らない", not os.path.exists(DAILY))
ok("add後 check=run", b("check", "--key", "aaaa0001") == "run")
ok("未登録keyの check=missing", b("check", "--key", "zzzz9999") == "missing")

# ---- update → show 7フィールドがDB値を返す ----
b("update", "--key", "aaaa0001", "--type", "実装", "--goal", "ボード再設計", "--now", "board.py改修", "--model", "fable5")
show = b("show", "--key", "aaaa0001").split("\t")
ok("show=7フィールド", len(show) == 7)
ok("show: 状態word/目標/今/種別/repo",
   show[0] == "run" and show[1] == "ボード再設計" and show[2] == "board.py改修"
   and show[3] == "実装" and show[4] == "RepoA")
ok("show: who=model（runtime接頭辞は非永続＝正本反転の帰結）", show[5] == "fable5")
ok("show: 計画列は既定 ?", show[6] == "?")

# ---- add冪等: 既存keyの再addは目標を上書きしない ----
b("add", "--key", "aaaa0001", "--repo", "RepoX", "--who", "codex/?")
ok("add冪等: 目標が保たれる", b("show", "--key", "aaaa0001").split("\t")[1] == "ボード再設計")

# ---- goals: 重複なし・未記入除外 ----
b("add", "--key", "bbbb0002", "--repo", "RepoA", "--who", "codex/?")
b("update", "--key", "bbbb0002", "--goal", "ボード再設計", "--now", "README")   # 同目標（重複）
b("add", "--key", "cccc0003", "--repo", "RepoB", "--who", "claude/?")
b("update", "--key", "cccc0003", "--goal", "求人PDF整理")
b("add", "--key", "dddd0004", "--repo", "RepoC", "--who", "claude/?")           # 目標未記入（?）
goals = set(b("goals").split("\n")) if b("goals") else set()
ok("goals: 記入済み目標を重複なしで返す", goals == {"ボード再設計", "求人PDF整理"})
ok("goals: 未記入(?)は除外", "?" not in goals)

# ---- flip: run⇄wait⇄sub ----
b("flip", "--key", "aaaa0001", "--state", "wait")
ok("flip wait", b("check", "--key", "aaaa0001") == "wait")
b("flip", "--key", "aaaa0001", "--state", "run")
ok("flip run復帰", b("check", "--key", "aaaa0001") == "run")

# ---- sub-start/sub-end: 体数の機械増減・🔵⇄🟢・session_subagents 個体行 ----
b("add", "--key", "subb0009", "--repo", "RepoS", "--who", "claude/?")
b("update", "--key", "subb0009", "--goal", "サブ数テスト", "--now", "委託")
b("sub-start", "--key", "subb0009")
b("sub-start", "--key", "subb0009")
ok("sub-start×2→sub", b("check", "--key", "subb0009") == "sub")
ok("DB sub_n=2", fake.query("SELECT sub_n FROM sessions WHERE session_key='s:subb0009'")[0][0] == 2)
ok("session_subagents running 2体",
   fake.query("SELECT COUNT(*) FROM session_subagents WHERE session_key='s:subb0009' AND status='running'")[0][0] == 2)
b("sub-end", "--key", "subb0009")
ok("sub-end×1→sub維持(残1体)", b("check", "--key", "subb0009") == "sub")
ok("running 1体へ減少（最古1本close）",
   fake.query("SELECT COUNT(*) FROM session_subagents WHERE session_key='s:subb0009' AND status='running'")[0][0] == 1)
b("sub-end", "--key", "subb0009")
ok("全end→run復帰", b("check", "--key", "subb0009") == "run")
ok("DB sub_n=0", fake.query("SELECT sub_n FROM sessions WHERE session_key='s:subb0009'")[0][0] == 0)
b("sub-end", "--key", "subb0009")
ok("0でクランプ(下回らない)", b("check", "--key", "subb0009") == "run"
   and fake.query("SELECT sub_n FROM sessions WHERE session_key='s:subb0009'")[0][0] == 0)
# 存在しないkeyのsub-startは行も個体行も作らない
b("sub-start", "--key", "nokey999")
ok("存在しないkeyのsub-startは無害(行を作らない)",
   fake.query("SELECT COUNT(*) FROM sessions WHERE session_key='s:nokey999'")[0][0] == 0
   and fake.query("SELECT COUNT(*) FROM session_subagents WHERE session_key='s:nokey999'")[0][0] == 0)

# ---- log: session_logs へ成果を追記（repo/parent/entry/session_key）----
b("log", "--key", "aaaa0001", "--repo", "RepoA", "--parent", "ボード再設計", "--entry", "board.py改修完了")
b("log", "--key", "aaaa0001", "--repo", "RepoA", "--parent", "ボード再設計", "--entry", "common改修", "--entry", "受け口更新")
logs = fake.query("SELECT repo, parent, entry, session_key FROM session_logs WHERE session_key='s:aaaa0001' ORDER BY id")
ok("log: 3件のentryが session_logs に入る（複数entryも各行）", len(logs) == 3)
ok("log: repo/parent/entry/session_key が刻まれる",
   logs[0] == ("RepoA", "ボード再設計", "board.py改修完了", "s:aaaa0001")
   and logs[2][2] == "受け口更新")

# ---- finish: session行を削除・logs へ締めを追記・done event ----
b("finish", "--key", "aaaa0001", "--repo", "RepoA", "--parent", "ボード再設計", "--entry", "締め")
ok("finish: session行が消える(check=missing)", b("check", "--key", "aaaa0001") == "missing")
ok("finish: 締めが session_logs に残る",
   fake.query("SELECT COUNT(*) FROM session_logs WHERE session_key='s:aaaa0001' AND entry='締め'")[0][0] == 1)
ok("finish: done event を発行",
   fake.query("SELECT COUNT(*) FROM session_events WHERE session_key='s:aaaa0001' AND state='done'")[0][0] == 1)

# ---- finish は log 用の repo/parent 省略時、DBの現在行から補完する ----
b("add", "--key", "eeee0005", "--repo", "RepoE", "--who", "claude/?")
b("update", "--key", "eeee0005", "--goal", "補完テスト")
b("finish", "--key", "eeee0005", "--entry", "終わり")   # --repo/--parent 省略
lg = fake.query("SELECT repo, parent FROM session_logs WHERE session_key='s:eeee0005'")[0]
ok("finish: repo/parent 省略時はDBの repo/goal で補完", lg == ("RepoE", "補完テスト"))

# ---- CLI引数互換: --time/--todo/--theme を受けてもエラーにならない（呼び出し側hook・skill互換）----
b("add", "--key", "ffff0006", "--repo", "R", "--who", "claude/?", "--time", "09:00")
out = b("update", "--key", "ffff0006", "--goal", "G", "--todo", "T1", "--theme", "H1")
ok("update --todo/--theme はエラーを出さず所属先をDBへ",
   fake.query("SELECT todo_id, theme_id FROM sessions WHERE session_key='s:ffff0006'")[0] == ("T1", "H1"))

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
