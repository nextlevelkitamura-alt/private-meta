#!/usr/bin/env python3
# session-board SubagentStart / SubagentStop hook（Codex受け口）
# サブエージェント開始で🔵、停止で🟢へ自動flip（Claudeの自己申告に相当・Codexは自動）。
# hook_event_name で分岐。session_id は親セッション。契約は ../../references/codex-hooks.md。
# 注意(v1): 同時に複数サブが走ると、最後のSubagentStopが早めに🟢へ戻す可能性あり
#   （ref-count は v2・未確定）。親がターン終了後にサブ停止した場合の⏸との整合も実測で詰める。
import json
import os
import subprocess
import sys


def main():
    if os.environ.get("AIJOBS_RUN"):
        return
    try:
        d = json.load(sys.stdin)
    except Exception:
        return
    sid = d.get("session_id") or ""
    if not sid or sid.startswith("agent-"):
        return
    ev = d.get("hook_event_name") or ""
    if ev == "SubagentStart":
        state = "sub"
    elif ev == "SubagentStop":
        state = "run"
    else:
        return
    key = sid[:8]
    board = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "board.py"))
    subprocess.run([board, "flip", "--key", key, "--state", state], capture_output=True)


if __name__ == "__main__":
    main()
