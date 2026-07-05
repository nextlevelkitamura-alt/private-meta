#!/usr/bin/env python3
# session-board Stop hook（Codex受け口）
# 役割は「登録済みで🟢なら⏸へ機械flip」だけ。ブロックしない。
# sub（🔵サブ稼働中）/ wait / missing は触らない（サブ稼働中を維持）。
# subagent／headless は対象外。契約は ../../references/codex-hooks.md。
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
    tp = d.get("transcript_path") or ""
    if not sid or sid.startswith("agent-") or "/subagents/" in tp:
        return
    key = sid[:8]
    board = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "board.py"))
    state = subprocess.run([board, "check", "--key", key],
                           capture_output=True, text=True).stdout.strip()
    if state == "run":
        subprocess.run([board, "flip", "--key", key, "--state", "wait"], capture_output=True)


if __name__ == "__main__":
    main()
