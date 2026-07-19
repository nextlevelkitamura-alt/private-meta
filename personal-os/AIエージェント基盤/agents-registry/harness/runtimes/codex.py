"""Codex CLI adapter.  The caller owns process lifecycle and state storage."""
from __future__ import annotations

from pathlib import Path


def command(*, role: str, cwd: Path, final_path: Path, prompt: str) -> list[str]:
    args = ["codex", "exec", "--json", "-C", str(cwd)]
    if role in {"explorer", "evaluator"}:
        args += ["-s", "read-only"]
    return args + ["-o", str(final_path), prompt]


def resume_command(*, session_id: str, prompt: str) -> list[str]:
    """確認済みのCodex resume契約。--lastや未確認フラグは使わない。"""
    return ["codex", "exec", "resume", session_id, prompt]
