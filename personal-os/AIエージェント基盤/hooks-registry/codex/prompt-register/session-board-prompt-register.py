#!/usr/bin/env python3
# session-board UserPromptSubmit（Codex受け口・薄いシム）。
# 実処理は common.register_prompt（未登録保険／⏸→🟢／「今」初回仮置き＋二段注入）。
# Codex は注入を stdout JSON(hookSpecificOutput.additionalContext) で返す契約（Claude は plain）。
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
    txt = common.register_prompt(d, "codex")
    if txt:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                                 "additionalContext": txt}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
