#!/usr/bin/env python3
# session-board UserPromptSubmit（Claude受け口・薄いシム）。
# 実処理は common.register_prompt（未登録保険／⏸→🟢／「今」初回仮置き＋二段注入）。
# Claude の UserPromptSubmit は stdout(plain) が context に追加される契約（Codex は JSON）。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "hooks", "session-board")))
import common  # noqa: E402


if __name__ == "__main__":
    d = common.load_input()
    if d is not None:
        txt = common.register_prompt(d, "claude")
        if txt:
            print(txt)
