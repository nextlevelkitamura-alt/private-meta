#!/usr/bin/env python3
# session-board SubagentStart / SubagentStop（Claude受け口・薄いシム）。
# 開始で体数+1・🔵(sub)、停止で体数-1・0になったら🟢(run) へ自動増減（board.py sub-start / sub-end）。
# hook_event_name で分岐。payload の session_id は**親セッション**の id（sid[:8]＝親キーで正しい）。
# transcript_path はサブ側を指しうるので is_subagent ガードは掛けない（このイベントは親の行を操作する）。
# Codex 受け口 ../../codex/subagent/session-board-subagent.py と同型。詳細は ../../references/claude-hooks.md。
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
    ev = d.get("hook_event_name") or ""
    if ev == "SubagentStart":
        common.board_sub_start(key)
    elif ev == "SubagentStop":
        common.board_sub_end(key)


if __name__ == "__main__":
    main()
