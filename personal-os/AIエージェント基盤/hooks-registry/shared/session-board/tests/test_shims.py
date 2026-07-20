#!/usr/bin/env python3
# 正本反転（子03・案b）後の shim ロジック E2E（旧 test-shims.sh の密度を DB-first で置換）。
# common.py（SessionStart=start_register / UserPromptSubmit=register_prompt / Stop=stop_flip /
# Subagent=board_sub_start/end）を fake DB 上で駆動する。common が board を叩く subprocess は
# in-process 実行へ差し替え（_fakedb.patch_common）、状態は fake sqlite が保持する。本番Tursoへは飛ばない。
# 検証観点: SessionStart通知1行 / 初回=フルガイド＋枠登録 / 記入後=ミラー / Stop→⏸→復帰 /
#           既存目標一覧の注入 / ガード（slash・subagent・headless） / サブ体数の機械増減 / 回答注入。
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-shims-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-01-02"
os.environ["SESSION_BOARD_TX_ROOTS"] = os.path.join(SP, "tx")
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import common  # noqa: E402
import _fakedb  # noqa: E402

fake = _fakedb.install(board)
_fakedb.patch_common(common, board)

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


CWD = "/tmp/repoZ"


def payload(sid, prompt=None, tx=None, event=None):
    d = {"session_id": sid, "cwd": CWD,
         "transcript_path": tx or os.path.join(SP, "tx", "proj", f"{sid[:8]}-0.jsonl")}
    if prompt is not None:
        d["prompt"] = prompt
    if event is not None:
        d["hook_event_name"] = event
    return d


SID = "beefcafe-0000-1111-2222-333344445555"
KEY = "beefcafe"

# ---- 1. SessionStart: 枠登録せず通知1行（遅延登録）----
out = common.start_register(payload(SID, event="SessionStart"), "claude")
ok("SS通知にボードキー", out and f"ボードキー s:{KEY}" in out)
ok("SS通知は遅延登録を告知", out and "最初のプロンプト時に登録" in out)
ok("SessionStartでは枠を作らない",
   fake.query("SELECT COUNT(*) FROM sessions WHERE session_key=?", (f"s:{KEY}",))[0][0] == 0)

# ---- 2. 初回プロンプト: 枠を登録＋フルガイド＋今の仮置き ----
out = common.register_prompt(payload(SID, "セッションボードを再設計して実装まで進めたい"), "claude")
ok("初回=フルガイド見出し", out and "最初の依頼を理解したら" in out)
ok("初回=種別5定義を含む", out and "種別: 計画=進め方を決め文書化" in out)
ok("初回=計画チェーン(repo概要.md)", out and "repo概要.md" in out)
ok("初回プロンプトで枠がDBに登録される",
   fake.query("SELECT repo, model FROM sessions WHERE session_key=?", (f"s:{KEY}",))[0] == ("repoZ", "?"))
ok("今の初回仮置き(先頭24字)",
   fake.query("SELECT now FROM sessions WHERE session_key=?", (f"s:{KEY}",))[0][0].startswith("セッションボードを再設計"))

# ---- 3. AIが行を正した後のプロンプト: ミラー（フルガイドは出ない）----
_fakedb.run_board_inprocess(board, ["update", "--key", KEY, "--type", "実装",
                                     "--goal", "ボード再設計", "--now", "common改修",
                                     "--model", "fable5", "--plan", "ボード再設計/03"])
out = common.register_prompt(payload(SID, "続けて"), "claude")
ok("ミラー1行目(目標/今/種別/計画)", out and "目標:ボード再設計 | 今:common改修 | 種別:実装 | 計画:ボード再設計/03" in out)
ok("ミラーに催促行", out and "ズレていたら" in out)
ok("ミラーではフルガイドを出さない", out and "最初の依頼を理解したら" not in out)
ok("Pythonは今を上書きしない(AI記入が残る)",
   fake.query("SELECT now FROM sessions WHERE session_key=?", (f"s:{KEY}",))[0][0] == "common改修")

# ---- 4. Stop→⏸、次プロンプトで🟢復帰 ----
common.stop_flip(payload(SID, event="Stop"))
ok("Stopで⏸", _fakedb.run_board_inprocess(board, ["check", "--key", KEY]).strip() == "wait")
common.register_prompt(payload(SID, "再開する"), "claude")
ok("プロンプトで🟢復帰", _fakedb.run_board_inprocess(board, ["check", "--key", KEY]).strip() == "run")

# ---- 5. 別セッションの初回ガイドに既存目標一覧が出る ----
SID2 = "cafe0002-0000-1111-2222-333344445555"
out = common.register_prompt(payload(SID2, "ボード再設計のREADMEを直したい"), "claude")
ok("既存目標一覧の注入", out and "いま動いている他の目標" in out and "「ボード再設計」" in out)
ok("合流規約の案内", out and "コピーして合流" in out)

# ---- 6. Codex runtime も同じ shim ロジックでテキストを返す（JSON整形は受け口の責務）----
SID3 = "c0dec0de-0000-1111-2222-333344445555"
out = common.register_prompt(payload(SID3, "Codexからの依頼テスト"), "codex")
ok("Codex初回もフルガイド本文", out and "最初の依頼を理解したら" in out)
ok("Codex枠は runtime=codex で登録",
   fake.query("SELECT model FROM sessions WHERE session_key='s:c0dec0de'")[0][0] == "?")

# ---- 7. ガード: slash / subagent / headless は None（枠を作らない）----
ok("スラッシュは無視", common.register_prompt(payload("badbad01-0000-1111-2222-333344445555", "/compact"), "claude") is None)
sub_d = payload("badbad02-0000-1111-2222-333344445555", "サブの依頼",
                tx=os.path.join(SP, "tx", "proj", "s", "subagents", "agent-x.jsonl"))
ok("subagent transcriptは無視", common.register_prompt(sub_d, "claude") is None)
os.environ["AIJOBS_RUN"] = "1"
ok("headless(AIJOBS_RUN)はload_input None", common.load_input() is None)
del os.environ["AIJOBS_RUN"]
ok("ガード対象は枠を作らない",
   fake.query("SELECT COUNT(*) FROM sessions WHERE session_key LIKE 's:badbad%'")[0][0] == 0)

# ---- 8. Subagent shim: board_sub_start/end で体数増減（🔵⇄🟢）----
common.board_sub_start(KEY)
common.board_sub_start(KEY)
ok("SubagentStart×2→🔵", _fakedb.run_board_inprocess(board, ["check", "--key", KEY]).strip() == "sub")
ok("DB sub_n=2", fake.query("SELECT sub_n FROM sessions WHERE session_key=?", (f"s:{KEY}",))[0][0] == 2)
common.board_sub_end(KEY)
ok("SubagentStop×1→🔵維持(残1体)", _fakedb.run_board_inprocess(board, ["check", "--key", KEY]).strip() == "sub")
common.board_sub_end(KEY)
ok("全Stop→🟢復帰", _fakedb.run_board_inprocess(board, ["check", "--key", KEY]).strip() == "run")

# ---- 9. 回答注入: ⏸→🟢 復帰時に inbox の未消費回答を注入し消費済みへ落とす ----
# 当該セッションに紐づく todo に回答を入れておく（focusmap側でスマホ回答された状態を模す）。
fake.inbox.execute(
    "INSERT INTO todos (id, title, session_key, question, answer, answered_at, answer_consumed_at, "
    "status, ai_status, source, route, question_allow_free, question_gate, created_at, updated_at) "
    "VALUES ('TQ','評価を作る','s:beefcafe','按分方式は？','A 前年同様','2099-01-02T10:00:00',NULL,"
    "'open','確認待ち','web','plan',1,0,'2099-01-02T09:00:00','2099-01-02T09:00:00')")
fake.inbox.commit()
common.stop_flip(payload(SID, event="Stop"))   # ⏸へ
out = common.register_prompt(payload(SID, "回答を反映して続行"), "claude")   # 復帰＝回答注入
ok("復帰時に未消費回答を注入", out and "スマホから届いた未消費の回答" in out and "A 前年同様" in out)
ok("注入後は回答を消費済みへ落とす",
   fake.inbox.execute("SELECT answer_consumed_at FROM todos WHERE id='TQ'").fetchone()[0] is not None)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
