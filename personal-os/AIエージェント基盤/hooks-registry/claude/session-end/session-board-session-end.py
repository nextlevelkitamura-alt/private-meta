#!/usr/bin/env python3
# session-board Stop（Claude受け口・薄いシム）。
# 実処理は common.stop_flip（run のときだけ⏸へ）。ブロックしない。
# 完了確認の注入は Stop の prompt型フック（milestone.md）が節目でのみ行う（別経路）。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "hooks", "session-board")))
import common  # noqa: E402


if __name__ == "__main__":
    d = common.load_input()
    if d is not None:
        common.stop_flip(d)
