#!/usr/bin/env python3
# session-board SessionStart（Claude受け口・薄いシム）。
# 実処理は ../../hooks/session-board/common.py の start_register（生存照合＋行の枠登録＋キー通知1行）。
# Claude は additionalContext を「plain text を stdout に print」する契約（Codex は JSON＝差はここだけ）。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "hooks", "session-board")))
import common  # noqa: E402


def main():
    d = common.load_input()
    if d is None:
        return
    txt = common.start_register(d, "claude")
    if txt:
        print(txt)


if __name__ == "__main__":
    main()
