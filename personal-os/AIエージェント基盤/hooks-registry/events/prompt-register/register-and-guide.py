#!/usr/bin/env python3
# session-board UserPromptSubmit の実行本体。
# common.register_prompt を呼び、--runtime に応じて Claude=plain / Codex=JSON で注入する。
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "session-board")))
import common  # noqa: E402


def runtime_arg():
    try:
        runtime = sys.argv[sys.argv.index("--runtime") + 1]
    except (ValueError, IndexError):
        return None
    return runtime if runtime in ("claude", "codex") else None


if __name__ == "__main__":
    runtime = runtime_arg()
    if runtime is None:
        sys.exit(0)
    d = common.load_input()
    if d is not None:
        txt = common.register_prompt(d, runtime)
        if txt:
            if runtime == "claude":
                print(txt)
            else:
                print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit",
                                                         "additionalContext": txt}}, ensure_ascii=False))
