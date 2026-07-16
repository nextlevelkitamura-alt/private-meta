"""Claude Code adapter with only locally and officially verified print-mode flags.

Verification record (2026-07-15): local ``claude --help`` listed ``--print``
and ``--output-format``; Anthropic CLI reference documents this pair for
non-interactive JSON output.  No permission-bypass or unverified resume flag is
used here.
"""
from __future__ import annotations

from pathlib import Path
import json

VERIFIED_FLAGS = ("--print", "--output-format")
FEATURE_DISABLED = "feature-disabled: Claude non-interactive flags are not verified"


def supported(help_text: str) -> bool:
    return all(flag in help_text for flag in VERIFIED_FLAGS)


def command(*, cwd: Path, prompt: str, help_text: str | None) -> list[str] | None:
    if help_text is None or not supported(help_text):
        return None
    # cwd is passed to the process by delegate rather than a guessed CLI flag.
    return ["claude", "--print", "--output-format", "json", prompt]


def final_text(stdout: str) -> str:
    """print/json の最終応答本文を取り出す。非JSONは安全に本文として残す。"""
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError:
        return stdout
    if isinstance(payload, dict) and isinstance(payload.get("result"), str):
        return payload["result"]
    return stdout
