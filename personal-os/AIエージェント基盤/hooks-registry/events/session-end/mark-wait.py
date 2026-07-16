#!/usr/bin/env python3
# session-board Stop の実行本体。common.stop_flip で run のときだけ⏸へする。ブロックしない。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "session-board")))
import common  # noqa: E402


if __name__ == "__main__":
    d = common.load_input()
    if d is not None:
        common.stop_flip(d)
