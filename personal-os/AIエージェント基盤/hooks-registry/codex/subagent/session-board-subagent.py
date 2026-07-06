#!/usr/bin/env python3
# session-board SubagentStart / SubagentStop（Codex専用受け口・薄いシム）。
# 開始で🔵(sub)・停止で🟢(run) へ自動flip（Claudeは自己申告／Codexは自動）。
# hook_event_name で分岐。session_id は親セッション。詳細は ../../references/codex-hooks.md。
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
    ev = d.get("hook_event_name") or ""
    if ev == "SubagentStart":
        common.board_flip(key, "sub")
    elif ev == "SubagentStop":
        common.board_flip(key, "run")


if __name__ == "__main__":
    main()
