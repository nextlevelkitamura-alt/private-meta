#!/usr/bin/env python3
# session-board SessionStart hook（Codex受け口）
# 開始手順 ../session-start.md を additionalContext として注入する。
# Codex hooks は入力=stdin JSON / 出力=stdout JSON（契約は ../../references/codex-hooks.md）。
# 非対話（AIJOBS_RUN）・subagent（session_id が agent-*）は無出力で抜ける。
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
    key = sid[:8]
    cwd = d.get("cwd") or ""
    repo = ""
    if cwd:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True)
        repo = os.path.basename(r.stdout.strip()) if r.returncode == 0 else os.path.basename(cwd)
    here = os.path.dirname(os.path.abspath(__file__))
    board = os.path.normpath(os.path.join(here, "..", "board.py"))
    ref = os.path.normpath(os.path.join(here, "..", "session-start.md"))
    lines = [
        f"[session-board] このセッションのボードキー: s:{key}（repo推定: {repo or '不明'}）",
        "最初の依頼を理解したら、開始手順を実行する。種別・要約を正す例:",
        f'  {board} update --key {key} --repo "{repo or "<repo>"}" '
        '--type <計画|実装|レビュー|その他> --summary "<依頼の1行要約>"',
        "",
    ]
    try:
        lines.append(open(ref, encoding="utf-8").read())
    except OSError:
        pass
    out = {"hookSpecificOutput": {"hookEventName": "SessionStart",
                                  "additionalContext": "\n".join(lines)}}
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
