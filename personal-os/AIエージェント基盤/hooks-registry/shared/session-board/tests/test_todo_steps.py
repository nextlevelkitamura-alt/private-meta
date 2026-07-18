#!/usr/bin/env python3
# 子05「タスク入れ子と2層チェック」のinbox系コマンド（steps/step-done/step-doing/step-skip/ask/flow-done）と
# board_route宣言スキャンの決定的ロジックを検証する。board.main() を in-process で叩き、
# _turso_send_inbox をモックして送信文をキャプチャする（ネットワーク・keychainに触れない）。
# DB接続が要る実挙動（実際のUPDATE行数・NOT EXISTSの効き）は migration 未適用のため検証範囲外。
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-steps-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-03-01"
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402

_ORIG_SEND_INBOX = board._turso_send_inbox
sent = []   # _turso_send_inbox に渡ったバッチ（1呼び出し=1リスト）


def _mock_send_inbox(statements):
    sent.append([s for s in statements if s])
    return True


board._turso_send_inbox = _mock_send_inbox

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
    sent.clear()


def run(*argv):
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    try:
        board.main()
    except SystemExit:
        pass
    finally:
        sys.argv = old


def flat():
    """最後のバッチの [(sql, args), ...] を返す（無ければ空）。"""
    return sent[-1] if sent else []


def vals(stmt):
    return [a.get("value") for a in stmt[1]]


def types(stmt):
    return [a.get("type") for a in stmt[1]]


# ---- steps: 追記INSERT。seqは MAX+1 サブセレクト・kind・session_key ----
clear()
run("steps", "--todo", "T1", "--entry", "現状の整理", "--entry", "2レーン案の記述")
batch = flat()
ok("steps: 2件のINSERT", len(batch) == 2 and all("INSERT INTO todo_steps" in s for s, _ in batch))
ok("steps: seqは MAX+1 サブセレクト", all("COALESCE(MAX(seq), 0) + 1" in s for s, _ in batch))
# args順: id(0) todo_id(1) todo_id(subselect用)(2) title(3) kind(4) session_key(5) created_at(6)
ok("steps: title/kind/statusが載る", vals(batch[0])[3] == "現状の整理" and vals(batch[0])[4] == "step")
ok("steps: session_key未指定はNULL", types(batch[0])[5] == "null")

clear()
run("steps", "--todo", "T1", "--kind", "fix", "--session-key", "s:abcd1234", "--entry", "警告色の調整")
batch = flat()
ok("steps: kind=fixが載る", vals(batch[0])[4] == "fix")
ok("steps: session_keyが載る", types(batch[0])[5] == "text" and vals(batch[0])[5] == "s:abcd1234")

clear()
run("steps", "--todo", "T1", "--kind", "bogus", "--entry", "x")
ok("steps: 不正kindはstepへ丸め", vals(flat()[0])[4] == "step")

# ---- step-done / step-doing / step-skip: 前進UPDATE・過去done行は触らない ----
clear()
run("step-done", "--todo", "T1", "--seq", "2")
stmt = flat()[0]
ok("step-done: UPDATE todo_steps", "UPDATE todo_steps SET status" in stmt[0])
ok("step-done: 完了済みは触らない(status != 'done')", "status != 'done'" in stmt[0])
ok("step-done: status=done・done_atに時刻", vals(stmt)[0] == "done" and types(stmt)[1] == "text")
ok("step-done: seqはinteger", types(stmt)[3] == "integer" and vals(stmt)[3] == "2")

clear()
run("step-doing", "--todo", "T1", "--seq", "3")
stmt = flat()[0]
ok("step-doing: status=doing・done_atはNULL", vals(stmt)[0] == "doing" and types(stmt)[1] == "null")

clear()
run("step-skip", "--todo", "T1", "--seq", "4")
ok("step-skip: status=skipped", vals(flat()[0])[0] == "skipped")

# ---- ask: 質問カラムへ。選択肢最大3・自由入力/ゲートフラグ・ai_status=確認待ち ----
clear()
run("ask", "--todo", "T2", "--q", "按分方式は？", "--choice", "A 前年同様", "--choice", "B 50:50",
    "--choice", "C 実費", "--choice", "D 余剰", "--free", "1")
stmt = flat()[0]
ok("ask: UPDATE todos 質問カラム", "UPDATE todos SET question" in stmt[0])
ok("ask: ai_status=確認待ちへ", "ai_status = '確認待ち'" in stmt[0])
ok("ask: 回答欄をリセット", "answer = NULL" in stmt[0] and "answer_consumed_at = NULL" in stmt[0])
ok("ask: 質問文が載る", vals(stmt)[0] == "按分方式は？")
import json as _json  # noqa: E402
ok("ask: 選択肢は最大3に丸め", _json.loads(vals(stmt)[1]) == ["A 前年同様", "B 50:50", "C 実費"])
ok("ask: allow_free=1 / gate=0", vals(stmt)[2] == "1" and vals(stmt)[3] == "0")

clear()
run("ask", "--todo", "T3", "--q", "本番へpushして良い？", "--gate", "1")
stmt = flat()[0]
ok("ask: 人間ゲート質問 gate=1", vals(stmt)[3] == "1")
ok("ask: 選択肢なしはNULL", types(stmt)[1] == "null")

# ---- flow-done: 宣言照合。未宣言slugは自動完了しない ----
routes_dir = os.path.join(SP, "routes")
skill_dir = os.path.join(routes_dir, "keiri-daily")
os.makedirs(skill_dir, exist_ok=True)
with open(os.path.join(skill_dir, "SKILL.md"), "w", encoding="utf-8") as fh:
    fh.write("---\nname: keiri-daily\nboard_route: routine\n---\n\n本文\n")
plain_dir = os.path.join(routes_dir, "adhoc-skill")
os.makedirs(plain_dir, exist_ok=True)
with open(os.path.join(plain_dir, "SKILL.md"), "w", encoding="utf-8") as fh:
    fh.write("---\nname: adhoc-skill\n---\n\n宣言なし\n")
os.environ["SESSION_BOARD_ROUTE_ROOTS"] = routes_dir

ok("scan: routine宣言slugだけ拾う", board.scan_board_routes() == {"keiri-daily"})

clear()
run("flow-done", "--todo", "T9", "--skill", "adhoc-skill")
ok("flow-done: 未宣言は送信しない（自動完了しない）", len(sent) == 0)

clear()
run("flow-done", "--todo", "T9", "--skill", "keiri-daily")
ok("flow-done: 宣言済みは stmt_flow_done を送る", len(sent) == 1 and "UPDATE todos SET status = 'done'" in flat()[0][0])
ok("flow-done: 未完了stepがある間は完了させないガード", "NOT EXISTS" in flat()[0][0] and "status IN ('todo', 'doing')" in flat()[0][0])
ok("flow-done: routine/completed_by=routine を刻む", "route = 'routine'" in flat()[0][0] and "completed_by = 'routine'" in flat()[0][0])

del os.environ["SESSION_BOARD_ROUTE_ROOTS"]

# ---- usage/バリデーション: 引数不足は送信しない ----
clear()
run("steps", "--todo", "T1")                 # entry無し
run("step-done", "--todo", "T1")             # seq無し
run("ask", "--todo", "T1")                   # q無し
ok("引数不足のsteps/step-done/askは送信しない", len(sent) == 0)

# ---- 段階3: session_logs.todo_id は --todo 指定時だけ7列INSERT（未指定は従来6列=未migration安全）----
logs6 = board._stmts_logs("R", "P", ["e"], "2099-03-01", session_key="s:x")
ok("stmts_logs: todo_id未指定は6列（todo_id列なし）", "todo_id" not in logs6[0][0] and len(logs6[0][1]) == 6)
logs7 = board._stmts_logs("R", "P", ["e"], "2099-03-01", session_key="s:x", todo_id="T1")
ok("stmts_logs: --todo指定で7列（todo_id列あり）", "todo_id" in logs7[0][0] and len(logs7[0][1]) == 7 and vals(logs7[0])[6] == "T1")

# ---- 段階4: collect_answers（回答注入） 未消費回答を整形し消費済みに落とす ----
_orig_read = board._turso_read_inbox
board._turso_read_inbox = lambda stmt: [
    {"id": "T2", "title": "評価02を作る", "question": "按分方式は？", "answer": "A 前年同様", "answered_at": "2099-03-01T10:00:00"},
]
clear()
text = board.collect_answers("abcd1234")
ok("collect_answers: 注入文に質問と回答", "未消費の回答" in text and "按分方式は？" in text and "A 前年同様" in text)
ok("collect_answers: 渡し切り後に消費UPDATEを送る", len(sent) == 1 and "answer_consumed_at" in sent[-1][0][0])

board._turso_read_inbox = lambda stmt: []
clear()
ok("collect_answers: 未消費なしは空文字・送信なし", board.collect_answers("abcd1234") == "" and len(sent) == 0)

board._turso_read_inbox = lambda stmt: None
clear()
ok("collect_answers: 読み取り失敗は空文字（best-effort）", board.collect_answers("abcd1234") == "" and len(sent) == 0)
ok("collect_answers: key空は空文字", board.collect_answers("") == "")
board._turso_read_inbox = _orig_read

# ---- store.read: pipelineレスポンスのrows/nullをdictへパースできる ----
import turso.store as _store  # noqa: E402
_fake_payload = {"results": [{"response": {"result": {
    "cols": [{"name": "id"}, {"name": "answer"}],
    "rows": [[{"type": "text", "value": "T"}, {"type": "null"}]],
}}}]}


class _FakeResp:
    def __init__(self, payload):
        self._b = _json.dumps(payload).encode()

    def read(self):
        return self._b

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


_orig_urlopen = _store.urllib.request.urlopen
_store.urllib.request.urlopen = lambda *a, **k: _FakeResp(_fake_payload)
rows = _store.read(("SELECT id, answer FROM todos", []), token_getter=lambda s: "tok")
ok("store.read: cols/rowsをdict化しnullはNone", rows == [{"id": "T", "answer": None}])
_store.urllib.request.urlopen = _orig_urlopen

# ---- 本物 _turso_send_inbox: NO_TURSO/空リストで即return（ネットワーク・keychainに触れない）----
os.environ["SESSION_BOARD_NO_TURSO"] = "1"
try:
    r = _ORIG_SEND_INBOX([("UPDATE todos SET x=?", [board._ta("y")])])
    ok("NO_TURSO: 本物_turso_send_inboxが送信せずTrue", r is True)
except Exception:
    ok("NO_TURSO: 本物_turso_send_inboxが送信せずTrue", False)
del os.environ["SESSION_BOARD_NO_TURSO"]
try:
    ok("空/None statements: 本物が即True", _ORIG_SEND_INBOX([None]) is True)
except Exception:
    ok("空/None statements: 本物が即True", False)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
