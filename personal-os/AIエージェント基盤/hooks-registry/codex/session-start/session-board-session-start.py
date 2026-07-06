#!/usr/bin/env python3
# session-board SessionStart（Codex受け口・薄いシム）。
# 共通本文（common.start_lines）を JSON(hookSpecificOutput.additionalContext) で返す契約。
# Codex hooks: 入力=stdin JSON / 出力=stdout JSON（詳細は ../../references/codex-hooks.md）。
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "hooks", "session-board")))
import common  # noqa: E402


def main():
    d = common.load_input()
    if d is None:
        return
    key = common.session_key(d)
    if not key:
        return
    repo = common.repo_of(d.get("cwd") or "")
    ctx = "\n".join(common.start_lines(key, repo))
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                              "additionalContext": ctx}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
