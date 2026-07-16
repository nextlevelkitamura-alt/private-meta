#!/usr/bin/env python3
"""SubagentStart/Stop: manifestの割当・成果物を検査する（状態は更新しない）。"""
import json
import os
import sys

sys.path.insert(0, os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "shared", "plan-closeout")))
import common  # noqa: E402


def main():
    try:
        payload = json.load(sys.stdin)
        manifest = common.load_manifest()
        event = payload.get("hook_event_name") or payload.get("hookEventName")
        decision = common.start_decision(payload, manifest) if event == "SubagentStart" else common.subagent_stop_decision(payload, manifest) if event == "SubagentStop" else common.Decision()
        if decision.block:
            print(json.dumps({"decision": "block", "reason": decision.reason}, ensure_ascii=False))
        elif decision.notice:
            print(json.dumps({"systemMessage": decision.notice}, ensure_ascii=False))
    except Exception:
        pass


if __name__ == "__main__":
    main()
