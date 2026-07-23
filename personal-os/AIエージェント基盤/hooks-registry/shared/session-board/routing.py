#!/usr/bin/env python3
"""Focusmap Daily のセッション分類に使う、runtime非依存の実行Context生成。"""
import hashlib
import os
import subprocess


PRIVATE_ROOT = os.path.realpath(os.path.expanduser("~/Private"))


def _git(cwd, *args):
    try:
        result = subprocess.run(
            ["git", "-C", cwd, *args], capture_output=True, text=True, timeout=2
        )
        return result.stdout.strip() if result.returncode == 0 else ""
    except Exception:
        return ""


def _digest(value):
    return hashlib.sha256(value.encode("utf-8", errors="replace")).hexdigest()[:16]


def resolve_execution_context(cwd, runtime):
    """cwdからrepo/worktree/branchを機械判定する。remote URLは読まない・保存しない。"""
    cwd_path = os.path.realpath(os.path.expanduser(cwd or os.getcwd()))
    repo_root = _git(cwd_path, "rev-parse", "--show-toplevel")
    if repo_root:
        repo_root = os.path.realpath(repo_root)
        common_dir = _git(cwd_path, "rev-parse", "--git-common-dir")
        if common_dir and not os.path.isabs(common_dir):
            common_dir = os.path.realpath(os.path.join(cwd_path, common_dir))
        common_dir = os.path.realpath(common_dir or os.path.join(repo_root, ".git"))
        # linked worktreeでもcommon-dirはmain worktreeの .git を指す。表示名/canonicalはここから固定する。
        canonical_root = os.path.dirname(common_dir) if os.path.basename(common_dir) == ".git" else None
        branch = _git(cwd_path, "branch", "--show-current") or "detached"
        return {
            "runtime": runtime,
            "repo_key": "git:" + _digest(os.path.realpath(common_dir)),
            "display_name": os.path.basename(canonical_root or repo_root) or "repo",
            "scope_kind": "git",
            "identity_state": "detected",
            "canonical_repo_path": canonical_root,
            "worktree_root": repo_root,
            "cwd_path": cwd_path,
            "branch": branch,
        }
    return {
        "runtime": runtime,
        "repo_key": "folder:" + _digest(cwd_path),
        "display_name": os.path.basename(cwd_path) or "folder",
        "scope_kind": "folder",
        "identity_state": "unregistered",
        "canonical_repo_path": None,
        "worktree_root": cwd_path,
        "cwd_path": cwd_path,
        "branch": None,
    }
