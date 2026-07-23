#!/usr/bin/env python3
"""実際のevent shimをsubprocessで呼び、Codex/Claude stdout契約を検証する。"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EVENTS = os.path.normpath(os.path.join(ROOT, "..", "..", "events"))
CODEX_HOOKS = os.path.normpath(os.path.join(ROOT, "..", "..", "codex", "hooks.json"))
PROMPT = os.path.join(EVENTS, "prompt-register", "register-and-guide.py")
START = os.path.join(EVENTS, "session-start", "reconcile-and-notify.py")
ENV = dict(os.environ, SESSION_BOARD_NO_TURSO="1")


def run(script, runtime, payload):
    result = subprocess.run([script, "--runtime", runtime], input=json.dumps(payload), text=True,
                            capture_output=True, env=ENV, timeout=10)
    if result.returncode:
        raise SystemExit(result.stderr or f"exit={result.returncode}")
    return result.stdout.strip()


payload = {"session_id": "feedface-1111", "turn_id": "turn-output", "cwd": os.path.expanduser("~/Private"),
           "prompt": "Hook出力形式を確認"}

codex_start = json.loads(run(START, "codex", payload))
assert codex_start["hookSpecificOutput"]["hookEventName"] == "SessionStart"
assert "SESSION ROUTING POLICY v1" in codex_start["hookSpecificOutput"]["additionalContext"]

codex_prompt = json.loads(run(PROMPT, "codex", payload))
assert codex_prompt["hookSpecificOutput"]["hookEventName"] == "UserPromptSubmit"
assert "[FOCUSMAP ROUTING CONTEXT]" in codex_prompt["hookSpecificOutput"]["additionalContext"]

claude_start = run(START, "claude", payload)
assert not claude_start.startswith("{") and "SESSION ROUTING POLICY v1" in claude_start

claude_prompt = run(PROMPT, "claude", {k: v for k, v in payload.items() if k != "turn_id"})
assert not claude_prompt.startswith("{") and "[FOCUSMAP ROUTING CONTEXT]" in claude_prompt

with open(CODEX_HOOKS, encoding="utf-8") as handle:
    codex_hooks = json.load(handle)
start_matcher = codex_hooks["hooks"]["SessionStart"][0]["matcher"]
assert set(start_matcher.split("|")) == {"startup", "resume", "clear", "compact"}

print("PASS: Codex JSON / Claude plain text / SessionStart 4 sources")
