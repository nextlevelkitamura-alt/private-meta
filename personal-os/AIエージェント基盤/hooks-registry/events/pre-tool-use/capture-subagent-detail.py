#!/usr/bin/env python3
# 子03: PreToolUse でサブエージェント起動ツール（Agent / Task）の tool_input から
# prompt・subagent_type・model を抜き、親セッションキーで一時スプールへ積む本体。
# 直後の SubagentStart（sync-subagent-status.py）がこれを pop して個体行へ enrich する。
#
# 完全 fail-open（非ブロッキング）: 例外・詳細欠落でも一切ブロックせず本体のサブ起動を止めない。
#   permissionDecision は返さない＝この hook は「観測」だけ。stdout も出さない（tool挙動を変えない）。
# session_id は**親セッション**の id（サブ起動を発行した側）＝session_key は親キーで正しい。
# Claude 経路のみ（Codex 直接exec駆動は board.py sub-start --via exec の呼び出し規律で捕捉する）。
#
# payload（stdin JSON）の実形は references/claude-hooks.md「§5.1 実測」を参照。
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(
    os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "session-board")))
import common  # noqa: E402

# このツール名を PreToolUse matcher（^(Agent|Task)$）と本体の二重で絞る。
# SDK/CLI 双方の名称ゆれ（Agent＝SDK・Task＝旧CLI）を吸収する。
_SUBAGENT_TOOLS = {"Agent", "Task"}


def _detail_from(payload):
    """tool_input からサブ詳細 dict を作る。抜けは None（後段で NULL 保存）。"""
    tool_input = payload.get("tool_input") or payload.get("toolInput") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}

    def pick(*keys):
        for k in keys:
            v = tool_input.get(k)
            if isinstance(v, str) and v.strip():
                return v.strip()
        return None

    return {
        "runtime": "claude",
        "model": pick("model"),                       # 明示指定時のみ（未指定=親モデル継承→表示側で補完）
        "agent_type": pick("subagent_type", "agent"),  # reviewer / general-purpose / impl-opus 等
        "launch_via": "agent-tool",
        "prompt": tool_input.get("prompt") if isinstance(tool_input.get("prompt"), str) else None,
    }


def main():
    try:
        d = common.load_input()
        if d is None:
            return
        if (d.get("tool_name") or d.get("toolName")) not in _SUBAGENT_TOOLS:
            return
        key = common.session_key(d)
        if not key:
            return
        common.spool_subagent_detail(key, _detail_from(d))
    except Exception:
        # fail-open: 捕捉に失敗しても本体・サブ起動を止めない。
        return


if __name__ == "__main__":
    main()
