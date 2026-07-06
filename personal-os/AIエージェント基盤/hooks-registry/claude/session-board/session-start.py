#!/usr/bin/env python3
# session-board SessionStart（Claude受け口・薄いシム）。
# 共通ロジックは ../../hooks/session-board/common.py。Claude は additionalContext を
# 「plain text を stdout に print」する契約（Codex は JSON で返す＝差はここだけ）。
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
    print("\n".join(common.start_lines(key, repo)))


if __name__ == "__main__":
    main()
