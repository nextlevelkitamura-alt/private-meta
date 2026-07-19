#!/usr/bin/env python3
"""Delegate exactly one Task Packet to Codex or Claude.

This module deliberately has no program-level scheduler and never removes a
worktree.  It is usable from any repository because every location is an
explicit CLI argument or is derived from ``--repo-root``.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import manifest
import worktree
from runtimes import claude, codex


@dataclass
class ProcessResult:
    returncode: int
    stdout: str = ""
    stderr: str = ""


Runner = Callable[[list[str], Path, dict[str, str]], ProcessResult]


def _run(command: list[str], cwd: Path, env: dict[str, str]) -> ProcessResult:
    completed = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True)
    return ProcessResult(completed.returncode, completed.stdout, completed.stderr)


def _git_root(path: Path) -> Path:
    completed = subprocess.run(["git", "-C", str(path), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if completed.returncode:
        raise worktree.HarnessConflict("repo_rootがgit repositoryではありません")
    return Path(completed.stdout.strip()).resolve()


def _ignored_state_dir(repo_root: Path, state_dir: Path) -> None:
    try:
        relative = state_dir.relative_to(repo_root)
    except ValueError as exc:
        raise worktree.HarnessConflict("state-dirはrepo_root配下のgitignore対象で指定してください") from exc
    check = subprocess.run(["git", "-C", str(repo_root), "check-ignore", "-q", "--", str(relative) + "/"], capture_output=True)
    if check.returncode != 0:
        raise worktree.HarnessConflict("state-dirはgitignore配下で指定してください")


def _section(plan: Path, name: str, fallback: str) -> str:
    """A short reference, not a copy of the plan or template."""
    lines = plan.read_text(encoding="utf-8").splitlines()
    heading = f"## {name}"
    try:
        start = lines.index(heading) + 1
    except ValueError:
        return fallback
    parts: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        stripped = line.strip()
        if stripped:
            parts.append(stripped)
    return " ".join(parts[:4]) or fallback


def _reading_steps(data: dict[str, object], role: str) -> list[str]:
    """役割別の読み順。親programと役割別共通ファイルが実在する時だけ分岐する。"""
    default = [
        "対象repoから対象ファイルまでの最寄り `AGENTS.md`",
        "親program（ある場合）",
        "対象計画",
        "計画の「実行契約」で指定されたreferences",
        "必要な実装ファイル",
    ]
    program = data.get("program_path")
    if not program or role == "explorer":
        return default
    if role == "evaluator":
        return [
            "対象repoから対象ファイルまでの最寄り `AGENTS.md`",
            "親program（ある場合）",
            "対象計画の「完了条件」",
            "実装diff（目的のdiff範囲）",
            "評価テンプレ",
        ]
    folder = {"implementer": "実装"}[role]
    common = Path(str(program)).parent / folder / "共通.md"
    if not common.is_file():
        return default
    head = ["対象repoから対象ファイルまでの最寄り `AGENTS.md`", "親program"]
    if role == "implementer":
        return head + [f"実装の共通コンテキスト `{common}`", "対象計画", "計画の「実行契約」で指定されたreferences", "必要な実装ファイル"]
    return default


def render_task_packet(data: dict[str, object], purpose: str, writable: bool) -> str:
    program = data["program_path"] or "なし"
    work = data["worktree_path"] or "なし（read-only task）"
    branch = data["branch"] or "なし（read-only task）"
    role = str(data["role"])
    extra = {
        "implementer": "一つのTask Packetだけを最小・安全に実装し、検証、対象path限定commit、result packetまでを担当する。",
        "evaluator": "read-onlyで完了条件とdiffを照合し、自己申告でPASSにせず、各項目をPASS / FAIL / 対象外と根拠付きで評価MDへ記録する。",
        "explorer": "read-onlyで実行経路、正本、影響path、依存、リスク、不明点を根拠付きで返す。",
    }[role]
    steps = "\n".join(f"{number}. {step}" for number, step in enumerate(_reading_steps(data, role), 1))
    return f"""# 実行指示（Task Packet）

あなたは {role} 担当です。

## 起動時の確認

- Task ID: {data['task_id']}
- 対象repo: {data['repo_root']}
- 対象計画: {data['plan_path']}
- 親program: {program}
- base commit: {data['base_commit']}
- worktree: {work}
- branch: {branch}
- result packet: {data['result_path']}

目的: {purpose}

最初に読む順番:

{steps}

対象範囲:

- 変更可能: {', '.join(data['allowed_paths']) or 'read-only'}
- 変更禁止: planの「変更禁止範囲」
- 非対象: planの「非対象」

規律:

- manifestのbaseまたは作業場所が割当と違えば、編集せずblockedで返す。
- 目的達成に必要な最小変更だけを行い、範囲外の問題は `out_of_scope_findings` に記録する。
- 共有契約の変更が必要なら実装せずblockedで返す。secret・token・credentialを出力やcommitに含めない。
- push、merge、deploy、worktree削除をしない。commitは対象pathだけを指定する。

停止条件: planの「停止・エスカレーション条件」に従う。

完了時: {"評価MD本文を最終出力へ返す" if role == "evaluator" else f"`{data['result_path']}` に result-packet schema のJSONを返し、最終メッセージにも要点を短く出す。"}

役割別追加指示: {extra}
"""


def render_evaluation_output_contract(data: dict[str, object]) -> str:
    """evaluatorの最終出力を、hookとplanctlが検証できる評価MDの形に固定する。"""
    return f"""

## evaluatorの最終出力形式

最終出力は次の見出しを含む評価MD本文だけにする。各完了条件を実物のdiff・テスト結果で判定し、PASS / FAIL / 対象外と根拠を記す。自己申告だけでPASSにしない。

# 評価

- 対象計画: {Path(str(data['plan_path'])).name}
- 対象diff: {data['base_commit']}..（result packetで示されたcommit）

## 項目別採点

- [PASS / FAIL / 対象外] 完了条件: 根拠

## 総合判定

全PASS または FAILあり
"""


def _blocked_result(data: dict[str, object], reason: str) -> dict[str, object]:
    return {"version": 1, "task_id": data["task_id"], "status": "blocked", "base_commit": data["base_commit"], "result_commit": "", "changed_paths": [], "tests": [], "assumptions": [], "blockers": [reason], "remaining_risks": [], "out_of_scope_findings": []}


def _load_claude_help() -> str | None:
    try:
        result = subprocess.run(["claude", "--help"], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return result.stdout + result.stderr if result.returncode == 0 else None


def _thread_path(state_dir: Path, task_id: str) -> Path:
    return state_dir / f"{task_id}-thread.json"


def _thread_id(stdout: str) -> str | None:
    """codex exec --jsonのthread.started記録からだけ識別子を取得する。"""
    for line in stdout.splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict) and isinstance(event.get("thread_id"), str) and event["thread_id"]:
            return event["thread_id"]
    return None


def _record_thread(state_dir: Path, task_id: str, runtime: str, stdout: str) -> str | None:
    if runtime != "codex":
        return None
    thread_id = _thread_id(stdout)
    if thread_id:
        manifest.write_json(_thread_path(state_dir, task_id), {"version": 1, "task_id": task_id, "runtime": runtime, "thread_id": thread_id})
    return thread_id


def delegate(args: argparse.Namespace, runner: Runner = _run, claude_help: str | None = None) -> dict[str, object]:
    plan = Path(args.plan).resolve()
    if not plan.is_file():
        raise worktree.HarnessConflict("--plan が見つからない")
    repo_root = _git_root(Path(args.repo_root).resolve())
    if not str(plan).startswith(str(repo_root) + os.sep):
        raise worktree.HarnessConflict("plan pathはrepo_root配下で指定してください")
    if args.role == "implementer" and not args.base_commit:
        raise worktree.HarnessConflict("write taskは明示base SHAが必要")
    if args.role == "implementer" and not args.allowed_path:
        raise worktree.HarnessConflict("write taskは変更可能範囲を少なくとも1つ指定してください")
    program_path = Path(args.program_path).resolve() if args.program_path else None
    if program_path is None and plan.parent.name == "plans" and (plan.parent.parent / "program.md").is_file():
        # 引数省略時だけ、<program>/plans/ 配下の子から親programを自動推定する（2026-07-17）。
        program_path = (plan.parent.parent / "program.md").resolve()

    state_dir = Path(args.state_dir).resolve() if args.state_dir else repo_root / ".planops-state"
    _ignored_state_dir(repo_root, state_dir)
    state_dir.mkdir(parents=True, exist_ok=True)
    writable = args.role == "implementer"
    base_commit = args.base_commit or subprocess.run(["git", "-C", str(repo_root), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    if writable:
        worktree.reject_active_scope_overlap(state_dir, args.allowed_path, args.task_id)
        work_root = Path(args.worktree_root).resolve() if args.worktree_root else repo_root.parent / f".{repo_root.name}-planops-worktrees"
        task_path, branch = worktree.create_task_worktree(repo_root, work_root, args.task_id, base_commit)
    else:
        task_path, branch = None, None

    result_path = state_dir / f"{args.task_id}-result.json"
    manifest_path = state_dir / f"{args.task_id}-manifest.json"
    packet_path = state_dir / f"{args.task_id}-実行指示.md"
    final_path = state_dir / f"{args.task_id}-final.md"
    data: dict[str, object] = {"version": 1, "task_id": args.task_id, "role": args.role, "runtime": args.runtime, "repo_root": str(repo_root), "plan_path": str(plan), "program_path": str(program_path) if program_path else None, "child_id": args.child_id, "base_commit": base_commit, "worktree_path": str(task_path) if task_path else None, "branch": branch, "result_path": str(result_path), "evaluation_path": str(final_path) if args.role == "evaluator" else None, "phase": "running", "allowed_paths": args.allowed_path}
    manifest.validate_manifest(data)
    manifest.write_json(manifest_path, data)
    purpose = args.purpose or _section(plan, "目的", "計画の完了条件を満たす")
    packet = render_task_packet(data, purpose, writable)
    if args.role == "evaluator":
        packet += render_evaluation_output_contract(data)
    packet_path.write_text(packet, encoding="utf-8")

    if args.dry_run:
        return {"status": "prepared", "manifest": str(manifest_path), "task_packet": str(packet_path), "result_path": str(result_path), "worktree_path": data["worktree_path"]}

    cwd = task_path if task_path else repo_root
    if args.runtime == "codex":
        command = codex.command(role=args.role, cwd=cwd, final_path=final_path, prompt=packet_path.read_text(encoding="utf-8"))
    else:
        help_text = claude_help if claude_help is not None else _load_claude_help()
        command = claude.command(cwd=cwd, prompt=packet_path.read_text(encoding="utf-8"), help_text=help_text)
        if command is None:
            reason = claude.FEATURE_DISABLED
            blocked = _blocked_result(data, reason)
            manifest.write_json(result_path, blocked)
            data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
            return {"status": "feature-disabled", "manifest": str(manifest_path), "result_path": str(result_path), "reason": reason}

    env = os.environ.copy(); env["PLAN_RUN_MANIFEST"] = str(manifest_path)
    result = runner(command, cwd, env)
    if args.runtime == "claude" and result.returncode == 0:
        final_path.write_text(claude.final_text(result.stdout), encoding="utf-8")
    thread_id = _record_thread(state_dir, args.task_id, args.runtime, result.stdout)
    manifest.write_json(state_dir / f"{args.task_id}-process-output.json", {"returncode": result.returncode, "stdout": manifest.redact(result.stdout), "stderr": manifest.redact(result.stderr)})
    if result.returncode:
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path)}
    if args.role == "evaluator":
        if not final_path.is_file():
            data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
            return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path), "evaluation_path": data["evaluation_path"], "reason": "evaluatorの評価本文が無い"}
        data["phase"] = "evaluated"
        manifest.write_json(manifest_path, data)
        return {"status": "done", "manifest": str(manifest_path), "result_path": str(result_path), "evaluation_path": data["evaluation_path"], "worktree_path": data["worktree_path"], "thread_id": thread_id}
    if not result_path.is_file():
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path), "reason": "result packetが無い"}
    try:
        packet = manifest.validate_result(manifest.read_json(result_path))
    except manifest.ValidationError:
        # A worker may have accidentally emitted a credential-shaped value.  Do
        # not leave it in state or echo it while reporting the validation error.
        manifest.write_json(result_path, _blocked_result(data, "result packetのschema検証に失敗"))
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path), "reason": "result packetのschema検証に失敗"}
    if packet["task_id"] != args.task_id or packet["base_commit"] != base_commit:
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path), "reason": "result packetのtask_idまたはbase_commitが不一致"}
    if writable and any(not worktree.scopes_overlap([changed], args.allowed_path) for changed in packet["changed_paths"]):
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": str(result_path), "reason": "result packetのchanged_pathsが変更可能範囲外です"}
    data["phase"] = ("evaluated" if args.role == "evaluator" else "implemented") if packet["status"] == "done" else "blocked"
    manifest.write_json(manifest_path, data)
    return {"status": packet["status"], "manifest": str(manifest_path), "result_path": str(result_path), "evaluation_path": data["evaluation_path"], "worktree_path": data["worktree_path"], "thread_id": thread_id}


def resume(manifest_path: Path, reason: str, runner: Runner = _run) -> dict[str, object]:
    """同一Codex threadへ差し戻す公開経路。Claudeはfeature-disabledを維持する。"""
    manifest_path = manifest_path.resolve()
    data = manifest.validate_manifest(manifest.read_json(manifest_path))
    if data["runtime"] != "codex":
        return {"status": "feature-disabled", "reason": "feature-disabled: Claude resumeは未確認です", "manifest": str(manifest_path)}
    state_dir = manifest_path.parent
    thread_file = _thread_path(state_dir, data["task_id"])
    try:
        thread = manifest.read_json(thread_file)
    except manifest.ValidationError as exc:
        raise worktree.HarnessConflict("resumeに必要なCodex thread識別子がありません") from exc
    if thread.get("task_id") != data["task_id"] or thread.get("runtime") != "codex" or not isinstance(thread.get("thread_id"), str):
        raise worktree.HarnessConflict("resume thread stateが不正です")
    cwd = Path(data["worktree_path"] or data["repo_root"])
    if not cwd.is_dir():
        raise worktree.HarnessConflict("resume対象worktreeがありません")
    prompt = f"修正指示: {reason}\n完了時は既存result packetをschemaどおり更新してください。"
    env = os.environ.copy(); env["PLAN_RUN_MANIFEST"] = str(manifest_path)
    result = runner(codex.resume_command(session_id=thread["thread_id"], prompt=prompt), cwd, env)
    _record_thread(state_dir, data["task_id"], "codex", result.stdout)
    manifest.write_json(state_dir / f"{data['task_id']}-resume-process-output.json", {"returncode": result.returncode, "stdout": manifest.redact(result.stdout), "stderr": manifest.redact(result.stderr)})
    if result.returncode or not Path(data["result_path"]).is_file():
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": data["result_path"]}
    packet = manifest.validate_result(manifest.read_json(Path(data["result_path"])))
    if packet["task_id"] != data["task_id"] or packet["base_commit"] != data["base_commit"]:
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": data["result_path"], "reason": "resume result packetのtask_idまたはbase_commitが不一致"}
    allowed = data.get("allowed_paths", [])
    if data["role"] == "implementer" and (not isinstance(allowed, list) or any(not worktree.scopes_overlap([changed], allowed) for changed in packet["changed_paths"])):
        data["phase"] = "blocked"; manifest.write_json(manifest_path, data)
        return {"status": "blocked", "manifest": str(manifest_path), "result_path": data["result_path"], "reason": "resume result packetのchanged_pathsが変更可能範囲外です"}
    data["phase"] = "implemented" if packet["status"] == "done" else "blocked"
    manifest.write_json(manifest_path, data)
    return {"status": packet["status"], "manifest": str(manifest_path), "result_path": data["result_path"], "thread_id": thread["thread_id"]}


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "resume":
        parser = argparse.ArgumentParser(description="同一Codex threadへ差し戻す")
        parser.add_argument("--manifest", required=True)
        parser.add_argument("--reason", required=True)
        args = parser.parse_args(sys.argv[2:])
        try:
            print(json.dumps(resume(Path(args.manifest), args.reason), ensure_ascii=False))
        except (worktree.HarnessConflict, manifest.ValidationError) as exc:
            print(f"delegate: {exc}", file=sys.stderr)
            raise SystemExit(2)
        return
    parser = argparse.ArgumentParser(description="1 Task Packetをruntimeへ委譲する")
    parser.add_argument("--runtime", required=True, choices=sorted(manifest.RUNTIMES))
    parser.add_argument("--role", required=True, choices=sorted(manifest.ROLES))
    parser.add_argument("--plan", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--base-commit")
    parser.add_argument("--program-path")
    parser.add_argument("--child-id")
    parser.add_argument("--state-dir")
    parser.add_argument("--worktree-root")
    parser.add_argument("--allowed-path", action="append", default=[])
    parser.add_argument("--purpose")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        print(json.dumps(delegate(args), ensure_ascii=False))
    except (worktree.HarnessConflict, manifest.ValidationError) as exc:
        print(f"delegate: {exc}", file=sys.stderr)
        raise SystemExit(2)


if __name__ == "__main__":
    main()
