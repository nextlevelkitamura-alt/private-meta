#!/usr/bin/env python3
"""plan-closeout共通判定とClaude/Codex stdin/stdout fixture。"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve()
ROOT = HERE.parents[3]
SHARED = ROOT / "shared" / "plan-closeout"
EVENTS = ROOT / "events"
sys.path.insert(0, str(SHARED))
import common  # noqa: E402

PASS = FAIL = 0


def check(name: str, condition: bool) -> None:
    global PASS, FAIL
    if condition:
        PASS += 1
    else:
        FAIL += 1
        print("FAIL:", name)


def manifest(root: Path, *, role="implementer", phase="running", result=True, evaluation=False) -> tuple[Path, dict]:
    plan = root / "plans" / "active" / "2026-07-15-検証" / "plan.md"
    plan.parent.mkdir(parents=True, exist_ok=True)
    plan.write_text("# 計画\n", encoding="utf-8")
    result_path = root / "result.json"
    if result:
        result_path.write_text(json.dumps({"version": 1, "task_id": "task-04", "status": "done", "base_commit": "base", "result_commit": "head", "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []}), encoding="utf-8")
    evaluation_path = root / "評価01.md"
    if evaluation:
        evaluation_path.write_text(f"対象計画: {plan.name}\n\n## 項目別採点\n- [PASS] 項目\n\n## 総合判定\n全PASS\n", encoding="utf-8")
    value = {"version": 1, "task_id": "task-04", "role": role, "runtime": "codex", "repo_root": str(root), "plan_path": str(plan), "program_path": None, "child_id": "04", "base_commit": "base", "worktree_path": str(root), "branch": "task/04", "result_path": str(result_path), "evaluation_path": str(evaluation_path) if evaluation else None, "phase": phase}
    if role != "implementer":
        value["worktree_path"] = None; value["branch"] = None
    path = root / "manifest.json"; path.write_text(json.dumps(value), encoding="utf-8")
    return path, value


def invoke(script: Path, payload: dict, env: dict[str, str]) -> tuple[int, str]:
    run = subprocess.run([sys.executable, str(script)], input=json.dumps(payload), text=True, capture_output=True, env=env)
    return run.returncode, run.stdout.strip()


with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    path, data = manifest(root)
    before = (Path(data["plan_path"]).read_bytes(), path.read_bytes(), Path(data["result_path"]).read_bytes())
    loaded = common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})
    check("manifestをschema相当で読める", loaded == data)
    check("manifest不在はfail-open", common.stop_decision({}, None) == common.Decision())
    check("runningは通す", not common.stop_decision({}, loaded).block)
    data["phase"] = "implemented"; path.write_text(json.dumps(data), encoding="utf-8")
    check("implemented（一括待ち）は通す", not common.stop_decision({}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)
    data["phase"] = "review_passed"; path.write_text(json.dumps(data), encoding="utf-8")
    check("review_passed未同期だけblock", common.stop_decision({}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)
    check("stop_hook_activeは再blockしない", not common.stop_decision({"stop_hook_active": True}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)
    data["phase"] = "synced"; path.write_text(json.dumps(data), encoding="utf-8")
    check("syncedは通す", not common.stop_decision({}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)
    data["phase"] = "blocked"; path.write_text(json.dumps(data), encoding="utf-8")
    check("blockedは通す", not common.stop_decision({}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)
    check("guardは計画・resultを変更しない", before[0] == Path(data["plan_path"]).read_bytes() and before[2] == Path(data["result_path"]).read_bytes())

with tempfile.TemporaryDirectory() as td:
    root = Path(td); path, data = manifest(root, result=False)
    loaded = common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})
    check("implementer result欠落はblock", common.subagent_stop_decision({}, loaded).block)
    check("implementerの連続blockを防止", not common.subagent_stop_decision({"stop_hook_active": "true"}, loaded).block)
    path, data = manifest(root, role="reviewer", evaluation=False)
    loaded = common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})
    check("reviewer評価欠落はblock", common.subagent_stop_decision({}, loaded).block)
    path, data = manifest(root, role="explorer")
    check("explorerは内容評価せず通す", not common.subagent_stop_decision({}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})).block)

with tempfile.TemporaryDirectory() as td:
    root = Path(td); path, data = manifest(root, phase="review_passed")
    env = os.environ.copy(); env["PLAN_RUN_MANIFEST"] = str(path)
    for runtime in ("claude", "codex"):
        rc, out = invoke(EVENTS / "session-end" / "guard-plan-closeout.py", {"hook_event_name": "Stop", "stop_hook_active": False, "runtime": runtime}, env)
        check(f"{runtime} Stop stdout JSON", rc == 0 and json.loads(out)["decision"] == "block")
        rc, out = invoke(EVENTS / "subagent" / "verify-plan-worker.py", {"hook_event_name": "SubagentStop", "stop_hook_active": False, "runtime": runtime}, env)
        check(f"{runtime} SubagentStop resultありは通る", rc == 0 and out == "")
        (root / "unassigned").mkdir(exist_ok=True)
        rc, out = invoke(EVENTS / "subagent" / "verify-plan-worker.py", {"hook_event_name": "SubagentStart", "cwd": str(root / "unassigned"), "runtime": runtime}, env)
        check(f"{runtime} SubagentStartの割当ずれは警告", rc == 0 and "systemMessage" in json.loads(out))
        rc, out = invoke(EVENTS / "pre-tool-use" / "guard-plan-bucket-move.py", {"tool_input": {"command": "git mv plans/active/a plans/done/a"}, "runtime": runtime}, env)
        check(f"{runtime} PreTool deny JSON", rc == 0 and json.loads(out)["hookSpecificOutput"]["permissionDecision"] == "deny")
        rc, out = invoke(EVENTS / "pre-tool-use" / "guard-plan-bucket-move.py", {"tool_input": {"command": "git mv docs/a docs/b"}, "runtime": runtime}, env)
        check(f"{runtime} 通常git mvを通す", rc == 0 and out == "")
        rc, out = invoke(EVENTS / "pre-tool-use" / "guard-plan-bucket-move.py", {"toolInput": {"command": "bucketctl move --source plans/active/a --to done"}, "runtime": runtime}, env)
        check(f"{runtime} bucketctlを通す", rc == 0 and out == "")

with tempfile.TemporaryDirectory() as td:
    root = Path(td); path, data = manifest(root, role="reviewer", evaluation=True)
    check("read-only roleはStartのworktree照合を省略", common.start_decision({"cwd": str(root / "elsewhere")}, common.load_manifest({"PLAN_RUN_MANIFEST": str(path)})) == common.Decision())

print(f"== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
