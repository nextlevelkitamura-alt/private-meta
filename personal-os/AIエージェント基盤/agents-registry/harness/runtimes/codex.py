"""Codex CLI adapter.  The caller owns process lifecycle and state storage."""
from __future__ import annotations

from pathlib import Path


def command(*, role: str, cwd: Path, final_path: Path, prompt: str) -> list[str]:
    args = ["codex", "exec", "--json", "-C", str(cwd)]
    if role in {"explorer", "reviewer"}:
        args += ["-s", "read-only"]
    return args + ["-o", str(final_path), prompt]
