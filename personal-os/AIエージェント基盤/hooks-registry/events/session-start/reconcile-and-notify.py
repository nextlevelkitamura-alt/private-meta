#!/usr/bin/env python3
# session-board SessionStart の実行本体。
# ../../shared/session-board/common.py の start_register を呼び、runtime ごとの出力契約だけを吸収する。
# --runtime claude は plain text、--runtime codex は hookSpecificOutput JSON を stdout へ出す。
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "session-board")))
import common  # noqa: E402


def runtime_arg():
    """設定ファイルが渡す runtime を取り出す。想定外なら非ブロッキングで何もしない。"""
    try:
        runtime = sys.argv[sys.argv.index("--runtime") + 1]
    except (ValueError, IndexError):
        return None
    return runtime if runtime in ("claude", "codex") else None


def main():
    runtime = runtime_arg()
    if runtime is None:
        return
    d = common.load_input()
    if d is None:
        return
    txt = common.start_register(d, runtime)
    if txt:
        if runtime == "claude":
            print(txt)
        else:
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart",
                                                     "additionalContext": txt}}, ensure_ascii=False))


if __name__ == "__main__":
    main()
