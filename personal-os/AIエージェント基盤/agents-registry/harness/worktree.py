"""Git worktree operations.  Creation is explicit; cleanup deliberately is not."""
from __future__ import annotations

import fnmatch
import json
import subprocess
from pathlib import Path


class HarnessConflict(RuntimeError):
    pass


def _git(repo: Path, *args: str) -> str:
    run = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    if run.returncode:
        raise HarnessConflict("git操作に失敗しました（詳細出力はstateに保存しません）")
    return run.stdout.strip()


def verify_base(repo: Path, base_commit: str) -> None:
    if not base_commit:
        raise HarnessConflict("write taskは明示base SHAが必要")
    _git(repo, "cat-file", "-e", f"{base_commit}^{{commit}}")


def require_clean(repo: Path) -> None:
    if _git(repo, "status", "--porcelain"):
        raise HarnessConflict("dirty checkoutではwrite taskを開始できません")


def task_branch(task_id: str) -> str:
    return f"plan-task/{task_id}"


def task_worktree_path(repo: Path, worktree_root: Path, task_id: str) -> Path:
    return (worktree_root / repo.name / task_id).resolve()


def create_task_worktree(repo: Path, worktree_root: Path, task_id: str, base_commit: str) -> tuple[Path, str]:
    require_clean(repo)
    verify_base(repo, base_commit)
    branch = task_branch(task_id)
    target = task_worktree_path(repo, worktree_root, task_id)
    existing = _git(repo, "worktree", "list", "--porcelain")
    if target.exists() or f"branch refs/heads/{branch}" in existing:
        raise HarnessConflict("task worktreeまたはbranchが既に存在するため停止しました")
    worktree_root.mkdir(parents=True, exist_ok=True)
    _git(repo, "worktree", "add", "--detach", str(target), base_commit)
    try:
        _git(target, "switch", "-c", branch)
    except Exception:
        # The worktree is intentionally retained for inspection; no automatic cleanup.
        raise
    return target, branch


def scopes_overlap(left: list[str], right: list[str]) -> bool:
    for a in left:
        for b in right:
            if a == b or a.startswith(b.rstrip("/") + "/") or b.startswith(a.rstrip("/") + "/"):
                return True
            if fnmatch.fnmatch(a, b) or fnmatch.fnmatch(b, a):
                return True
    return False


def reject_active_scope_overlap(state_dir: Path, allowed_paths: list[str], task_id: str) -> None:
    for path in state_dir.glob("*-manifest.json"):
        try:
            item = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if item.get("task_id") == task_id or item.get("phase") not in {"running", "implemented", "evaluated"}:
            continue
        if scopes_overlap(allowed_paths, item.get("allowed_paths", [])):
            raise HarnessConflict("実行中taskと変更可能範囲が重なるため停止しました")
