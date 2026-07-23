#!/usr/bin/env python3
"""Codex公式app-server APIを使い、登録正本の現在hashを自動trustする。"""

from __future__ import annotations

import argparse
import json
import os
import selectors
import subprocess
import sys
import time
from pathlib import Path


DEFAULT_SOURCE = Path.home() / ".codex" / "hooks.json"
DEFAULT_CONFIG = Path.home() / ".codex" / "config.toml"


class AppServer:
    def __init__(self, timeout: float = 10.0) -> None:
        self.timeout = timeout
        self.next_id = 1
        self.process = subprocess.Popen(
            ["codex", "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
        )
        if self.process.stdin is None or self.process.stdout is None:
            raise RuntimeError("Codex app-serverのstdioを開けませんでした")
        self.selector = selectors.DefaultSelector()
        self.selector.register(self.process.stdout, selectors.EVENT_READ)
        self.request(
            "initialize",
            {
                "clientInfo": {"name": "codex-hook-auto-trust", "version": "1.0"},
                "capabilities": {"experimentalApi": True},
            },
        )

    def request(self, method: str, params: object) -> dict:
        request_id = self.next_id
        self.next_id += 1
        payload = {"id": request_id, "method": method, "params": params}
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(payload, ensure_ascii=False) + "\n")
        self.process.stdin.flush()
        deadline = time.monotonic() + self.timeout
        while time.monotonic() < deadline:
            remaining = max(0.0, deadline - time.monotonic())
            if not self.selector.select(remaining):
                break
            assert self.process.stdout is not None
            line = self.process.stdout.readline()
            if not line:
                break
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("id") != request_id:
                continue
            if "error" in message:
                raise RuntimeError(f"{method}: {message['error']}")
            return message.get("result") or {}
        raise TimeoutError(f"{method}: Codex app-serverの応答待ちがtimeoutしました")

    def close(self) -> None:
        self.selector.close()
        self.process.terminate()
        try:
            self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            self.process.kill()


def quote_key_segment(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def list_source_hooks(cwd: Path, source: Path) -> list[dict]:
    server = AppServer()
    try:
        result = server.request("hooks/list", {"cwds": [str(cwd)]})
    finally:
        server.close()
    hooks: dict[str, dict] = {}
    for entry in result.get("data", []):
        for hook in entry.get("hooks", []):
            if hook.get("sourcePath") == str(source):
                hooks[hook["key"]] = hook
    return sorted(hooks.values(), key=lambda item: item["key"])


def trust_hooks(config: Path, hooks: list[dict]) -> None:
    edits = []
    for hook in hooks:
        key_path = f"hooks.state.{quote_key_segment(hook['key'])}.trusted_hash"
        edits.append(
            {
                "keyPath": key_path,
                "value": hook["currentHash"],
                "mergeStrategy": "upsert",
            }
        )
    if not edits:
        return
    server = AppServer()
    try:
        server.request(
            "config/batchWrite",
            {
                "edits": edits,
                "filePath": str(config),
                "reloadUserConfig": True,
            },
        )
    finally:
        server.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--check", action="store_true", help="状態確認だけで書き込まない")
    args = parser.parse_args()

    cwd = args.cwd.expanduser().resolve()
    source = args.source.expanduser().absolute()
    config = args.config.expanduser().absolute()
    if not source.exists() or not config.exists():
        print("hooks.jsonまたはconfig.tomlが見つかりません", file=sys.stderr)
        return 2

    hooks = list_source_hooks(cwd, source)
    if not hooks:
        print(f"対象hookなし: {source}", file=sys.stderr)
        return 3
    pending = [hook for hook in hooks if hook.get("trustStatus") != "trusted"]
    if args.check:
        print(f"hooks={len(hooks)} trusted={len(hooks) - len(pending)} pending={len(pending)}")
        return 0 if not pending else 1
    if pending:
        trust_hooks(config, pending)
    verified = list_source_hooks(cwd, source)
    unresolved = [hook for hook in verified if hook.get("trustStatus") != "trusted"]
    print(f"hooks={len(verified)} trusted={len(verified) - len(unresolved)} pending={len(unresolved)}")
    if unresolved:
        for hook in unresolved:
            print(f"untrusted: {hook['key']} ({hook.get('trustStatus')})", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
