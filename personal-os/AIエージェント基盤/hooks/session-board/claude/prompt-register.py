#!/usr/bin/env python3
# session-board UserPromptSubmit hook（Claude受け口）
# 未登録なら board へ登録（要約=プロンプト先頭24字）。⏸なら🟢へ復帰。stdoutは常に空。
# subagent／headless／スラッシュコマンド／空・添付のみは対象外。
import json
import os
import re
import subprocess
import sys


def main():
    if os.environ.get("AIJOBS_RUN"):
        return
    try:
        d = json.load(sys.stdin)
    except Exception:
        return
    sid = d.get("session_id") or d.get("sessionId") or ""
    tp = d.get("transcript_path") or d.get("transcriptPath") or ""
    prompt = d.get("prompt") or ""
    cwd = d.get("cwd") or ""
    if not sid or sid.startswith("agent-") or "/subagents/" in tp:
        return
    p = prompt.strip() if isinstance(prompt, str) else ""
    if not p or p.startswith("/") or p.startswith("<"):
        return
    key = sid[:8]
    board = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "board.py"))
    state = subprocess.run([board, "check", "--key", key],
                           capture_output=True, text=True).stdout.strip()
    if state == "missing":
        repo = ""
        if cwd:
            r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                               capture_output=True, text=True)
            repo = os.path.basename(r.stdout.strip()) if r.returncode == 0 else os.path.basename(cwd)
        summary = re.sub(r"\s+", " ", p).replace("|", "／").replace("<", "＜").replace(">", "＞")[:24]
        subprocess.run([board, "add", "--key", key, "--repo", repo or "?",
                        "--type", "その他", "--summary", summary], capture_output=True)
    elif state == "wait":
        subprocess.run([board, "flip", "--key", key, "--state", "run"], capture_output=True)
    # sub（🔵サブ稼働中）は触らない＝サブ完了までエージェントが自分で run へ戻す。


if __name__ == "__main__":
    main()
