#!/usr/bin/env python3
# session-board Stop（Codex受け口・薄いシム）。
# 実処理は common.stop_flip（run のときだけ⏸へ）。ブロックしない。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "hooks", "session-board")))
import common  # noqa: E402


if __name__ == "__main__":
    d = common.load_input()
    if d is not None:
        common.stop_flip(d)
