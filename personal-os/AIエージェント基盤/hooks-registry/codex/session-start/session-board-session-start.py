#!/usr/bin/env python3
# session-board SessionStart（Codex受け口・薄いシム）。
# 実処理は common.start_register（生存照合＋行の枠登録＋キー通知1行）。
# Codex hooks: 入力=stdin JSON / 出力=stdout JSON(hookSpecificOutput.additionalContext)。
# 詳細は ../../references/codex-hooks.md。
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
    txt = common.start_register(d, "codex")
    if txt:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                                 "additionalContext": txt}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
