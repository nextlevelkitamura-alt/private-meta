#!/usr/bin/env python3
"""PLAN_RUN_MANIFEST を読む、状態を書き換えないplan-closeout guard。"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

PHASES = {"running", "implemented", "review_passed", "synced", "closed", "blocked"}
ROLES = {"explorer", "implementer", "reviewer"}
RUNTIMES = {"codex", "claude"}
TASK_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
MANIFEST_REQUIRED = {
    "version", "task_id", "role", "runtime", "repo_root", "plan_path", "program_path",
    "child_id", "base_commit", "worktree_path", "branch", "result_path", "evaluation_path", "phase",
}
RESULT_REQUIRED = {
    "version", "task_id", "status", "base_commit", "result_commit", "changed_paths", "tests",
    "assumptions", "blockers", "remaining_risks", "out_of_scope_findings",
}


@dataclass(frozen=True)
class Decision:
    block: bool = False
    reason: str = ""
    notice: str = ""


def _truthy(value: Any) -> bool:
    return value is True or (isinstance(value, str) and value.lower() == "true")


def _valid_manifest(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) - (MANIFEST_REQUIRED | {"allowed_paths"}):
        return False
    if MANIFEST_REQUIRED - set(value) or type(value.get("version")) is not int or value["version"] != 1:
        return False
    if not isinstance(value.get("task_id"), str) or not TASK_ID.fullmatch(value["task_id"]):
        return False
    if (not isinstance(value.get("role"), str) or value["role"] not in ROLES
            or not isinstance(value.get("runtime"), str) or value["runtime"] not in RUNTIMES
            or not isinstance(value.get("phase"), str) or value["phase"] not in PHASES):
        return False
    if not all(isinstance(value.get(key), str) and value[key] for key in ("task_id", "repo_root", "plan_path", "base_commit", "result_path")):
        return False
    if any(value.get(key) is not None and not isinstance(value[key], str) for key in ("program_path", "child_id", "worktree_path", "branch", "evaluation_path")):
        return False
    allowed_paths = value.get("allowed_paths")
    if allowed_paths is not None and (not isinstance(allowed_paths, list) or not all(isinstance(path, str) and path for path in allowed_paths) or len(allowed_paths) != len(set(allowed_paths))):
        return False
    if value["role"] == "implementer" and (not isinstance(value.get("worktree_path"), str) or not value["worktree_path"] or not isinstance(value.get("branch"), str) or not value["branch"]):
        return False
    return True


def load_manifest(environ: dict[str, str] | None = None) -> dict[str, Any] | None:
    """環境変数が無い・壊れている時は通常セッションとして通す。"""
    raw = (environ or os.environ).get("PLAN_RUN_MANIFEST")
    if not raw:
        return None
    try:
        value = json.loads(Path(raw).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return value if _valid_manifest(value) else None


def _valid_result(path: str, task_id: str, base_commit: str) -> bool:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    if not isinstance(value, dict) or RESULT_REQUIRED - set(value):
        return False
    if value.get("version") != 1 or value.get("task_id") != task_id or value.get("base_commit") != base_commit:
        return False
    if value.get("status") not in {"done", "blocked", "partial", "failed"}:
        return False
    return isinstance(value.get("changed_paths"), list) and isinstance(value.get("tests"), list)


def _valid_evaluation(path: str | None, plan_path: str) -> bool:
    if not path:
        return False
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError:
        return False
    # planctl.parse_evaluation と同じ、最低限の必須評価項目の存在だけを読む。
    return bool("対象計画:" in text and "## 項目別採点" in text and "## 総合判定" in text and "[" in text and Path(plan_path).name in text)


def _git(cwd: Path, *args: str) -> tuple[int, str]:
    result = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)
    return result.returncode, result.stdout.strip()


def start_decision(payload: dict[str, Any], manifest: dict[str, Any] | None) -> Decision:
    """SubagentStartは止められないので、implementerのずれを警告だけする。"""
    if not manifest or manifest["role"] != "implementer":
        return Decision()
    cwd_raw = payload.get("cwd")
    if not isinstance(cwd_raw, str) or not cwd_raw:
        return Decision(notice="plan-closeout: implementerのcwdを観測できない。manifestのworktree/base/branchを確認してから編集する。")
    try:
        cwd, expected = Path(cwd_raw).resolve(), Path(str(manifest["worktree_path"])).resolve()
    except OSError:
        return Decision()
    problems: list[str] = []
    if cwd != expected:
        problems.append("worktree_path")
    rc, branch = _git(cwd, "rev-parse", "--abbrev-ref", "HEAD")
    if rc == 0 and branch != manifest["branch"]:
        problems.append("branch")
    rc, _ = _git(cwd, "merge-base", "--is-ancestor", manifest["base_commit"], "HEAD")
    if rc != 0:
        problems.append("base_commit")
    if problems:
        return Decision(notice="plan-closeout: manifestと実作業場所の " + "・".join(problems) + " が不一致。編集前にblockedで返し、harnessの割当を確認する。")
    return Decision()


def stop_decision(payload: dict[str, Any], manifest: dict[str, Any] | None) -> Decision:
    if not manifest:
        return Decision()
    if manifest["phase"] == "review_passed":
        if _truthy(payload.get("stop_hook_active")):
            return Decision(notice="plan-closeout: review_passed未同期だが、同一Stopでの再blockはしない。planctl sync-checkを実行する。")
        return Decision(block=True, reason="plan-closeout: review_passedだが未同期。planctl apply-evaluation または planctl sync-check を実行してから終了する。")
    if manifest["phase"] == "blocked":
        return Decision(notice="plan-closeout: manifestはblocked。blockerをresult packetへ残し、hookは解消・再blockしない。")
    return rename_notice(manifest)


def subagent_stop_decision(payload: dict[str, Any], manifest: dict[str, Any] | None) -> Decision:
    if not manifest:
        return Decision()
    missing = False
    if manifest["role"] == "implementer":
        missing = not _valid_result(manifest["result_path"], manifest["task_id"], manifest["base_commit"])
        reason = "plan-closeout: implementerのresult packetが無いかschema不正。result packetを作成してから終了する。"
    elif manifest["role"] == "reviewer":
        missing = not _valid_evaluation(manifest.get("evaluation_path"), manifest["plan_path"])
        reason = "plan-closeout: reviewerの必須評価項目が無い。対象計画・項目別採点・総合判定を評価MDへ記録してから終了する。"
    else:
        return Decision()
    if missing and not _truthy(payload.get("stop_hook_active")):
        return Decision(block=True, reason=reason)
    if missing:
        return Decision(notice="plan-closeout: 同一SubagentStopでの再blockはしない。" + reason)
    return Decision()


def rename_notice(manifest: dict[str, Any]) -> Decision:
    """rename --checkだけを実行する。失敗は通常のStopを止めない。"""
    script = Path(__file__).resolve().parents[3] / "skills" / "plan-ops" / "scripts" / "planctl.py"
    if not script.is_file() or not Path(manifest["plan_path"]).is_file():
        return Decision()
    try:
        result = subprocess.run(
            [sys.executable, str(script), "rename", "--plan", manifest["plan_path"], "--date", date.today().isoformat(), "--check"],
            capture_output=True, text=True, timeout=3,
        )
        value = json.loads(result.stdout) if result.returncode == 0 else {}
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return Decision()
    if value.get("rename_required"):
        return Decision(notice="plan-closeout: 計画の目的・子構成を大幅更新したなら、planctl rename --check を確認してフォルダ日付を最新化してから終了する。")
    return Decision()
