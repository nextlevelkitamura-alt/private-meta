#!/usr/bin/env python3
"""PreToolUse: 計画バケットへの生 mv / git mv だけをdenyする。"""
import json
import re
import sys


MOVE = re.compile(r"(?:^|[;&|]\s*)(?:git\s+mv|mv)\b")
PLAN_BUCKET = re.compile(r"(?:^|[\s'\"])(?:[^\s'\"]*/)?plans/(?:planning|active|paused|done|archive)(?:/|\b)")


def command_of(payload):
    tool = payload.get("tool_input") or payload.get("toolInput") or {}
    return tool.get("command", "") if isinstance(tool, dict) else ""


def denial(payload):
    command = command_of(payload)
    if not isinstance(command, str) or "bucketctl" in command or not MOVE.search(command) or not PLAN_BUCKET.search(command):
        return None
    return "計画バケットへの生 mv / git mv は使えません。bucketctl check --json で件数・上限・対象一覧を確認し、必要な人間判断を返してから bucketctl を使ってください。"


def main():
    try:
        payload = json.load(sys.stdin)
        reason = denial(payload)
        if reason:
            print(json.dumps({"hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": reason}}, ensure_ascii=False))
    except Exception:
        pass


if __name__ == "__main__":
    main()
