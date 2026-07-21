#!/usr/bin/env python3
# 子03: subspool の FIFO push/pop・キー分離、および PreToolUse 捕捉hook
# （events/pre-tool-use/capture-subagent-detail.py）の payload 解析と fail-open を
# ネットワーク非依存で検証する（本番Turso・実DBには一切触れない）。
import importlib.util
import io
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-capture-")
os.environ["SESSION_BOARD_STATE_DIR"] = SP
os.environ.pop("AIJOBS_RUN", None)

import subspool  # noqa: E402
import common    # noqa: E402

# capture hook はファイル名にハイフンを含むので importlib で直接ロードする。
CAP = os.path.normpath(os.path.join(HERE, "..", "..", "..", "events", "pre-tool-use", "capture-subagent-detail.py"))
_spec = importlib.util.spec_from_file_location("capture_subagent_detail", CAP)
cap = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cap)

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


def feed(payload):
    """合成stdinで capture hook の main() を1回走らせる。"""
    old = sys.stdin
    sys.stdin = io.StringIO(json.dumps(payload))
    try:
        cap.main()
    finally:
        sys.stdin = old


# ---- 1. subspool: FIFO と キー分離 ----
subspool.push("k1", {"runtime": "claude", "prompt": "one"})
subspool.push("k1", {"runtime": "claude", "prompt": "two"})
subspool.push("k2", {"runtime": "codex", "prompt": "other"})
ok("subspool: 先入れ先出し1", (subspool.pop("k1") or {}).get("prompt") == "one")
ok("subspool: 先入れ先出し2", (subspool.pop("k1") or {}).get("prompt") == "two")
ok("subspool: 空でNone", subspool.pop("k1") is None)
ok("subspool: キー分離(k2は独立)", (subspool.pop("k2") or {}).get("prompt") == "other")
ok("subspool: 不正入力はpush 0(非dict)", subspool.push("k3", "not-a-dict") == 0)
ok("subspool: key欠落pop None", subspool.pop("") is None)

# ---- 2. common ラッパーの roundtrip ----
common.spool_subagent_detail("kc", {"runtime": "claude", "prompt": "p"})
rd = common.pop_subagent_detail("kc")
ok("common: spool→pop roundtrip", rd is not None and rd.get("prompt") == "p")

# ---- 3. capture hook: Agent ツールの捕捉（prompt/type/model/via/runtime）----
feed({"hook_event_name": "PreToolUse", "tool_name": "Agent", "session_id": "abcd1234XXXX",
      "tool_input": {"prompt": "調べて", "subagent_type": "explorer", "model": "sonnet"}})
d = subspool.pop("abcd1234")
ok("Agent捕捉: detailがspoolされる", d is not None)
ok("Agent捕捉: 5項目が乗る",
   bool(d) and d["prompt"] == "調べて" and d["agent_type"] == "explorer"
   and d["model"] == "sonnet" and d["launch_via"] == "agent-tool" and d["runtime"] == "claude")
ok("Agent捕捉: pop後は空", subspool.pop("abcd1234") is None)

# ---- 4. capture hook: Task 名でも捕捉・model未指定はNone ----
feed({"hook_event_name": "PreToolUse", "tool_name": "Task", "session_id": "eeee5678",
      "tool_input": {"prompt": "実装", "subagent_type": "implementer"}})
d2 = subspool.pop("eeee5678")
ok("Task捕捉: 名称ゆれ吸収", d2 is not None and d2["agent_type"] == "implementer")
ok("Task捕捉: model未指定はNone(表示側で親モデル補完)", bool(d2) and d2["model"] is None)

# ---- 5. 非対象ツールは捕捉しない ----
feed({"hook_event_name": "PreToolUse", "tool_name": "Bash", "session_id": "ffff9999",
      "tool_input": {"command": "ls"}})
ok("非対象ツール(Bash)は捕捉しない", subspool.pop("ffff9999") is None)

# ---- 6. fail-open: agent-発のsid（サブ内経路）は親を汚さず捕捉しない・例外なし ----
crashed = False
try:
    feed({"hook_event_name": "PreToolUse", "tool_name": "Agent", "session_id": "agent-xyz",
          "tool_input": {"prompt": "x"}})
except Exception:
    crashed = True
ok("agent-発sidは捕捉せず例外も出さない", crashed is False)

# ---- 7. fail-open: 不正JSON/欠落payloadでも例外を投げない ----
crashed = False
try:
    old = sys.stdin
    sys.stdin = io.StringIO("{not json")
    cap.main()
    sys.stdin = old
    feed({"tool_name": "Agent"})            # session_id/tool_input 欠落
    feed({})                                 # 全欠落
except Exception:
    crashed = True
finally:
    sys.stdin = sys.__stdin__
ok("不正JSON・欠落でも例外を投げない(完全fail-open)", crashed is False)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
