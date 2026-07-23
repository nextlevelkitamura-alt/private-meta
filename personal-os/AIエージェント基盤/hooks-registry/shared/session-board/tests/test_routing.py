#!/usr/bin/env python3
"""Focusmap Daily session routing のfake DB統合テスト。実Tursoへは接続しない。"""
import os
import json
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import board  # noqa: E402
import common  # noqa: E402
import routing  # noqa: E402
from turso import store as turso_store  # noqa: E402
from _fakedb import install, patch_common, run_board_inprocess  # noqa: E402

PASS = FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        print(f"FAIL: {name}")


with tempfile.TemporaryDirectory() as tmp:
    subprocess.run(["git", "init", "-q", tmp], check=True)
    subprocess.run(["git", "-C", tmp, "checkout", "-q", "-b", "routing-test"], check=True)
    ctx = routing.resolve_execution_context(tmp, "codex")
    check("git repoを安定キーで認識", ctx["repo_key"].startswith("git:") and ctx["scope_kind"] == "git")
    check("branchと表示名を取得", ctx["branch"] == "routing-test" and ctx["display_name"] == os.path.basename(tmp))
    check("remote URLをContextへ含めない", all("remote" not in k for k in ctx))

with tempfile.TemporaryDirectory() as parent:
    main = os.path.join(parent, "main")
    worktree = os.path.join(parent, "worktree")
    os.mkdir(main)
    subprocess.run(["git", "init", "-q", main], check=True)
    subprocess.run(["git", "-C", main, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                    "commit", "-q", "--allow-empty", "-m", "init"], check=True)
    subprocess.run(["git", "-C", main, "worktree", "add", "-q", "-b", "routing-worktree", worktree], check=True)
    main_ctx = routing.resolve_execution_context(main, "codex")
    wt_ctx = routing.resolve_execution_context(worktree, "codex")
    check("linked worktreeは同じrepo_key", main_ctx["repo_key"] == wt_ctx["repo_key"])
    check("linked worktreeのcanonical/displayは同じ", main_ctx["canonical_repo_path"] == wt_ctx["canonical_repo_path"] and main_ctx["display_name"] == wt_ctx["display_name"])
    check("linked worktreeのroot/cwdは区別", main_ctx["worktree_root"] != wt_ctx["worktree_root"] and main_ctx["cwd_path"] != wt_ctx["cwd_path"])

with tempfile.TemporaryDirectory() as tmp:
    ctx = routing.resolve_execution_context(tmp, "claude")
    check("非Git folderも記録対象", ctx["repo_key"].startswith("folder:") and ctx["identity_state"] == "unregistered")

os.environ.pop("SESSION_BOARD_NO_TURSO", None)
os.environ["SESSION_BOARD_DATE"] = "2026-07-23"
fake = install(board)
real_run = patch_common(common, board)

# 今日＋対象repoに絞る候補（inbox DB）。Themeのplan_refsだけがPlan候補になる。
fake.inbox.execute("INSERT INTO repos VALUES (?,?,?,?)", ("private", "Private", 1, "2026-07-23"))
fake.inbox.execute("INSERT INTO repos VALUES (?,?,?,?)", ("focusmap", "focusmap", 2, "2026-07-23"))
fake.inbox.execute(
    "INSERT INTO themes VALUES (?,?,?,?,?,?,?,?,?,?)",
    ("theme-1", "AI協業を見える化", "迷わず判断", "Dailyで確認", None, '["plan-1"]', 1, "active", "2026-07-23", "2026-07-23"),
)
fake.inbox.execute(
    "INSERT INTO themes VALUES (?,?,?,?,?,?,?,?,?,?)",
    ("theme-other", "別repoのテーマ", None, None, None, '["plan-other"]', 2, "active", "2026-07-23", "2026-07-23"),
)
todo_values = ("todo-1", "分類", None, "2026-07-23", None, "private", "self", "open", "未検知", "web",
               None, None, "2026-07-23", "2026-07-23", None, None, None, 1, 0, None, None, None, None,
               "plan", None, "theme-1", None, None, "plan-1")
fake.inbox.execute("INSERT INTO todos VALUES (" + ",".join("?" for _ in todo_values) + ")", todo_values)
other_values = ("todo-other", "別", None, "2026-07-23", None, "focusmap", "self", "open", "未検知", "web",
                None, None, "2026-07-23", "2026-07-23", None, None, None, 1, 0, None, None, None, None,
                "plan", None, "theme-other", None, None, "plan-other")
fake.inbox.execute("INSERT INTO todos VALUES (" + ",".join("?" for _ in other_values) + ")", other_values)
fake.inbox.execute(
    "INSERT INTO plan_docs VALUES (?,?,?,?,?,?,?,?,?,?)",
    ("personal-os/test/program.md", "plan-1", "program", None, "分類Hookを作る", "active", "", "h", None, "2026-07-23"),
)
fake.inbox.execute(
    "INSERT INTO plan_docs VALUES (?,?,?,?,?,?,?,?,?,?)",
    ("projects/focusmap/plan.md", "plan-other", "program", None, "別Plan", "active", "", "h2", None, "2026-07-23"),
)
fake.inbox.commit()

event = {"session_id": "12345678-aaaa", "cwd": os.path.expanduser("~/Private"), "turn_id": "turn-1",
         "prompt": "password=secret-value Bearer fake_test user@example.com 090-1234-5678 分類Hookを実装して"}
start = common.start_register(event, "codex")
check("SessionStartイベントで方針を注入", "FOCUSMAP SESSION ROUTING POLICY v1" in start)
context_rows = fake.query("SELECT runtime, repo_key, display_name FROM session_execution_contexts WHERE session_key='s:12345678'")
check("SessionStartで実行Contextを記録", len(context_rows) == 1 and context_rows[0][0] == "codex")

out = common.register_prompt(event, "codex")
route_rows = fake.query(
    "SELECT turn_id, route_kind, status, event_fingerprint, safe_summary FROM session_route_proposals WHERE session_key='s:12345678'"
)
check("UserPromptSubmitでpendingを先に記録", len(route_rows) == 1 and route_rows[0][0:3] == ("turn-1", "pending", "pending"))
route_batches = [batch for batch in fake.sent if any("session_route_proposals" in sql for sql, _ in batch)]
check("Contextとpendingは同じroute-prepare batch", any(
    any("session_execution_contexts" in sql for sql, _ in batch) and
    any("session_route_proposals" in sql for sql, _ in batch)
    for batch in route_batches
))
check("fingerprintはprompt非依存のevent識別子", len(route_rows[0][3]) == 64 and route_rows[0][3] == __import__("hashlib").sha256(b"s:12345678|turn-1|codex").hexdigest())
check("safe summaryはsecretと連絡先をマスク", all(value not in (route_rows[0][4] or "") for value in ("secret-value", "fake_test", "user@example.com", "090-1234-5678")))
check("候補と書戻し契約を同じ本文で注入", all(s in out for s in ("FOCUSMAP ROUTING CONTEXT", "theme-1=AI協業を見える化", "plan-1=分類Hookを作る", "route-propose")))
check("別repoの候補は注入しない", "theme-other" not in out and "plan-other" not in out)
check("固定policyはUserPrompt本文へ重複しない", "SESSION ROUTING POLICY v1" not in out)

same_session = dict(event, turn_id="turn-1b", prompt="まだsession行を更新していない")
out_short = common.register_prompt(same_session, "codex")
check("長い開始ガイドは初回だけ", "最初の依頼を理解したら" not in out_short and "[session-board] 現在:" in out_short)

# 意味判断の書戻しはAI/Skillが専用CLIで行う。既存session表を破壊しない。
writeback = run_board_inprocess(board, ["route-propose", "--key", "12345678", "--turn", "turn-1",
                            "--kind", "plan_candidate", "--plan", "plan-1",
                            "--status", "accepted", "--summary", "token=raw-secret 分類Hookを実装",
                            "--reason", "user@example.com 複数工程のため"])
proposed = fake.query("SELECT route_kind, plan_slug, status FROM session_route_proposals WHERE turn_id='turn-1'")
check("route-proposeで対象turnだけ更新しreadback", proposed == [("plan_candidate", "plan-1", "accepted")] and "recorded status=accepted" in writeback)
masked = fake.query("SELECT safe_summary, reason FROM session_route_proposals WHERE turn_id='turn-1'")[0]
check("明示書戻しもDB境界で再マスク", "raw-secret" not in masked[0] and "user@example.com" not in masked[1])

# 同じhookイベントが再試行されてもaccepted行をpendingへ戻さない。
common.register_prompt(event, "codex")
preserved = fake.query("SELECT route_kind, status FROM session_route_proposals WHERE turn_id='turn-1'")
check("pending再試行はacceptedを上書きしない", preserved == [("plan_candidate", "accepted")])

# 既存の明示所属があれば毎turnの候補一覧を省き、現在地だけを短く返す。
run_board_inprocess(board, ["update", "--key", "12345678", "--goal", "分類Hook完成", "--type", "実装",
                            "--now", "Claude互換を検証", "--plan", "plan-1", "--theme", "theme-1"])
event2 = {"session_id": "12345678-aaaa", "cwd": os.path.expanduser("~/Private"), "turn_id": "turn-2",
          "prompt": "続けてClaude形式も確認して"}
out2 = common.register_prompt(event2, "codex")
check("確定所属があっても毎turn書戻し契約を返す", "current: theme=theme-1 / plan=plan-1" in out2 and "route-propose" in out2)

# ambient contextの後ろにある実依頼を取りこぼさない。
ambient = "<in-app-browser-context>ambient only</in-app-browser-context>\n\n実依頼です"
check("ambientの後ろの実依頼を抽出", common._prompt_body(ambient) == "実依頼です")

with tempfile.NamedTemporaryFile() as transcript:
    claude_event = {"session_id": "12345678-aaaa", "transcript_path": transcript.name, "prompt": "同じ入力"}
    turn_a = common._turn_id(claude_event, "12345678", "同じ入力")
    turn_b = common._turn_id(claude_event, "12345678", "同じ入力")
    check("Claudeの再試行は同じturn ID", turn_a == turn_b)

long_packet = common._classification_packet("12345678", "turn-long", {"display_name": "Private"}, {
    "themes": [{"id": "theme-long", "name": "長" * 500}],
    "plans": [{"program_slug": "plan-long", "title": "計" * 500, "bucket": "active"}],
})
check("候補packetは文字数上限付き", len(long_packet) <= 1800 and ("長" * 80) not in long_packet and ("計" * 80) not in long_packet)


class _FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def read(self):
        return json.dumps(self.payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False


original_urlopen = turso_store.urllib.request.urlopen
try:
    turso_store.urllib.request.urlopen = lambda *a, **k: _FakeResponse({"results": [{"error": {"message": "no table"}}]})
    check("pipeline内SQL errorを送信成功にしない", turso_store.send([("SELECT 1", [])], token_getter=lambda service: "token") is False)
    turso_store.urllib.request.urlopen = lambda *a, **k: _FakeResponse({"results": [
        {"response": {"result": {"cols": [{"name": "n"}], "rows": [[{"type": "integer", "value": "1"}]]}}},
        {"response": {"result": {"cols": [{"name": "n"}], "rows": [[{"type": "null"}]]}}},
    ]})
    batches = turso_store.read_many([("SELECT 1", []), ("SELECT NULL", [])], token_getter=lambda service: "token")
    check("read_manyは複数SELECTを入力順に返す", batches == [[{"n": "1"}], [{"n": None}]])
finally:
    turso_store.urllib.request.urlopen = original_urlopen

common.subprocess.run = real_run
os.environ.pop("SESSION_BOARD_DATE", None)
print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
