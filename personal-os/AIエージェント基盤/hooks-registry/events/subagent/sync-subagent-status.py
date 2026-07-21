#!/usr/bin/env python3
# session-board SubagentStart / SubagentStop の実行本体。
# 開始で体数+1・🔵(sub)、停止で体数-1・0になったら🟢(run) へ自動増減（board.py sub-start / sub-end）。
# hook_event_name で分岐。payload の session_id は**親セッション**の id（sid[:8]＝親キーで正しい）。
# transcript_path はサブ側を指しうるので is_subagent ガードは掛けない（このイベントは親の行を操作する）。
# Claude/Codex 共通。詳細は ../../references/claude-hooks.md と ../../references/codex-hooks.md。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "session-board")))
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
        # 子03: 直前の PreToolUse（Agent/Task）がスプールしたサブ詳細を最古1件だけ取り出して enrich。
        # 無ければ detail=None＝詳細なしで積む（Codex直接exec経路や捕捉失敗でも本体を止めない）。
        detail = common.pop_subagent_detail(key)
        common.board_sub_start(key, detail)
    elif ev == "SubagentStop":
        common.board_sub_end(key)


if __name__ == "__main__":
    main()
