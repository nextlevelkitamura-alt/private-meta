#!/usr/bin/env python3
"""Stop: session-boardとは独立して、計画同期忘れを一回だけ継続要求する。"""
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "plan-closeout")))
import common  # noqa: E402


def main():
    try:
        payload = json.load(sys.stdin)
        decision = common.stop_decision(payload, common.load_manifest())
        if decision.block:
            print(json.dumps({"decision": "block", "reason": decision.reason}, ensure_ascii=False))
        elif decision.notice:
            print(json.dumps({"systemMessage": decision.notice}, ensure_ascii=False))
    except Exception:
        pass


if __name__ == "__main__":
    main()
