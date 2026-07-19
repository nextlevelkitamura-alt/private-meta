#!/usr/bin/env python3
"""Program を Wave 順に実行する、runtime 非依存の小さなオーケストレータ。

実行状態は ``--state-dir``（gitignore 配下）だけに保存する。implementer / evaluator
の実際の起動は :class:`Operations` 境界の向こうに置き、合成テストは CLI を
起動しない fake を渡して、順序と停止条件を検証できるようにしている。
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

HERE = Path(__file__).resolve().parent
PLANOPS = HERE.parents[1] / "skills" / "plan-ops" / "scripts"
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))
import delegate
import manifest
import worktree


class ProgramRunBlocked(RuntimeError):
    """停止理由を、secret や subprocess の詳細を出さずに上位へ渡す。"""


@dataclass(frozen=True)
class Child:
    nn: str
    plan: Path
    execution: str
    allowed_paths: tuple[str, ...]
    dependencies: tuple[str, ...]
    human_gate: str


@dataclass
class Task:
    child: Child
    task_id: str
    base_commit: str
    result_path: Path
    manifest_path: Path
    worktree_path: Path | None = None
    branch: str | None = None
    thread_id: str | None = None
    result: dict[str, Any] | None = None


@dataclass
class Evaluation:
    passed: bool
    evaluation_path: Path | None = None
    reason: str = ""


def parse_evaluation(path: Path) -> Evaluation:
    """評価本文の総合判定を読む。曖昧な本文をPASSへ倒さない。"""
    text = path.read_text(encoding="utf-8")
    section = re.search(r"^##\s*総合判定\s*$\n(?P<body>.*?)(?=^##\s|\Z)", text, re.M | re.S)
    if section is None:
        return Evaluation(False, reason="評価MDに総合判定がありません")
    body = section.group("body")
    if re.search(r"^\s*- \[FAIL\]", text, re.M):
        return Evaluation(False, reason="評価MDにFAIL項目があります")
    if "FAILあり" in body:
        return Evaluation(False, reason="評価MDの総合判定がFAILです")
    if "全PASS" not in body:
        return Evaluation(False, reason="評価MDの総合判定を判定できません")
    return Evaluation(True, path)


def evaluation_dir(child_plan: Path) -> Path:
    """programの評価置き場（2026-07-17に plans/ 隣接から分離）。旧配置の読み取り互換は呼び出し側が持つ。"""
    return child_plan.parent.parent / "評価"


def next_evaluation_path(child_plan: Path) -> Path:
    """規約準拠 `NN-〈子名〉-評価RR.md` の次ラウンドpath。RRは新旧両配置の既存ラウンド数+1。"""
    stem = child_plan.stem
    folder = evaluation_dir(child_plan)
    rounds = len(list(folder.glob(f"{stem}-評価*.md"))) if folder.is_dir() else 0
    rounds += len(list(child_plan.parent.glob(f"{stem}-評価*.md")))
    return folder / f"{stem}-評価{rounds + 1:02d}.md"


def child_evaluations(child_plan: Path) -> list[Path]:
    """この子の実在する評価md（新配置・旧配置・旧命名 評価NN.md の順）。"""
    stem = child_plan.stem
    folder = evaluation_dir(child_plan)
    paths = sorted(folder.glob(f"{stem}-評価*.md")) if folder.is_dir() else []
    paths += sorted(child_plan.parent.glob(f"{stem}-評価*.md"))
    legacy = child_plan.parent / f"評価{stem[:2]}.md"
    if legacy.is_file():
        paths.append(legacy)
    return paths


@dataclass
class RunState:
    run_id: str
    program: str
    status: str = "running"
    completed: list[str] = field(default_factory=list)
    held_worktrees: dict[str, str] = field(default_factory=dict)
    approvals: list[str] = field(default_factory=list)
    integration_evaluation: dict[str, dict[str, str]] = field(default_factory=dict)
    events: list[str] = field(default_factory=list)
    reason: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {
            "version": 1, "run_id": self.run_id, "program": self.program,
            "status": self.status, "completed": self.completed,
            "held_worktrees": self.held_worktrees,
            "approvals": self.approvals, "integration_evaluation": self.integration_evaluation,
            "events": self.events, "reason": self.reason,
        }


def _field(lines: list[str], label: str) -> str:
    for line in lines:
        text = line.lstrip(" -\t")
        if text.startswith(label):
            return text[len(label):].strip().split(" ／", 1)[0].strip()
    return ""


def _section(lines: list[str], heading: str) -> list[str]:
    # 前方一致: 正本テンプレは見出し直後に注記が続く（例:「## 子計画マップ   ※ …」）。
    # _planops_map.find_section() と同じ解釈に揃える（bareな見出しも引き続き一致する）。
    prefix = f"## {heading}"
    start = next((i + 1 for i, line in enumerate(lines) if line.rstrip().startswith(prefix)), None)
    if start is None:
        return []
    result: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        result.append(line)
    return result


def _child_blocks(program: Path) -> Iterable[tuple[str, list[str]]]:
    lines = program.read_text(encoding="utf-8").splitlines()
    section = _section(lines, "子計画マップ")
    current: list[str] = []
    nn = ""
    for line in section:
        hit = re.match(r"^- \[[ x]\] (\d{2})\b", line)
        if hit:
            if nn:
                yield nn, current
            nn, current = hit.group(1), [line]
        elif nn:
            current.append(line)
    if nn:
        yield nn, current


def _resolve_plan(program: Path, nn: str, block: list[str]) -> Path:
    location = _field(block[1:], "場所:").split("／", 1)[0].strip()
    if re.fullmatch(r"plans/\d{2}", location):
        matches = sorted((program.parent / "plans").glob(f"{nn}-*.md"))
        if len(matches) == 1:
            return matches[0]
    candidate = (program.parent / location).resolve()
    if candidate.is_file():
        return candidate
    raise ProgramRunBlocked(f"子{nn}の計画pathを解決できません")


def _contract(child: Path, nn: str, map_block: list[str]) -> Child:
    lines = child.read_text(encoding="utf-8").splitlines()
    contract = _section(lines, "実行契約")
    raw_execution = _field(contract, "実行形:") or "delegated-single"
    match = re.match(r"[a-z-]+", raw_execution)
    execution = match.group(0) if match else raw_execution
    top = lines[:6]
    scope = _field(contract, "変更可能範囲:")
    backticked = re.findall(r"`([^`]+)`", scope)
    paths = tuple(dict.fromkeys(backticked)) if backticked else tuple(
        dict.fromkeys(item.strip().rstrip("/") for item in re.split(r"[,、]", scope) if item.strip() and item.strip() not in {"なし", "該当なし"})
    )
    dependencies = tuple(re.findall(r"\b(\d{2})\b", _field(map_block[1:], "依存:")))
    gate = _field(top, "人間ゲート:") or _field(map_block[1:], "人間ゲート:")
    return Child(nn, child, execution, paths, dependencies, gate)


def read_program(program: Path) -> list[Child]:
    children = [_contract(_resolve_plan(program, nn, block), nn, block) for nn, block in _child_blocks(program)]
    if not children:
        raise ProgramRunBlocked("子計画マップに実行対象がありません")
    known = {child.nn for child in children}
    for child in children:
        unknown = set(child.dependencies) - known
        if unknown:
            raise ProgramRunBlocked(f"子{child.nn}の依存先が子計画マップにありません")
        if child.execution == "delegated-parallel":
            text = child.plan.read_text(encoding="utf-8")
            if not re.search(r"^\s*(?:- )?ファイル担当マップ:\s*\S+", text, re.M) or not re.search(r"^\s*(?:- )?worktree方針:\s*\S+", text, re.M):
                raise ProgramRunBlocked(f"子{child.nn}: delegated-parallelにファイル担当マップまたはworktree方針がありません")
    return children


def waves(children: list[Child]) -> list[list[Child]]:
    pending = {child.nn: child for child in children}
    completed: set[str] = set()
    output: list[list[Child]] = []
    while pending:
        wave = [child for child in pending.values() if set(child.dependencies) <= completed]
        if not wave:
            raise ProgramRunBlocked("子計画の依存関係が循環しています")
        output.append(sorted(wave, key=lambda child: child.nn))
        completed.update(child.nn for child in wave)
        for child in wave:
            del pending[child.nn]
    return output


class Operations:
    """副作用の境界。テストではこのメソッドだけを fake に差し替える。"""

    def __init__(self, evaluator_runtime: str = "claude") -> None:
        if evaluator_runtime not in manifest.RUNTIMES:
            raise ValueError("evaluator_runtimeはcodexまたはclaude")
        self.evaluator_runtime = evaluator_runtime

    def lint(self, path: Path, *, program: bool = False) -> None:
        script = PLANOPS / ("program-lint.sh" if program else "plan-lint.sh")
        done = subprocess.run([str(script), str(path)], capture_output=True, text=True)
        if done.returncode:
            raise ProgramRunBlocked("起動前lintに失敗しました")

    def base_commit(self, repo_root: Path) -> str:
        done = subprocess.run(["git", "-C", str(repo_root), "rev-parse", "HEAD"], capture_output=True, text=True)
        if done.returncode:
            raise ProgramRunBlocked("repo_rootのbase commitを取得できません")
        return done.stdout.strip()

    def ensure_integration_branch(self, repo_root: Path) -> None:
        branch = subprocess.run(["git", "-C", str(repo_root), "branch", "--show-current"], capture_output=True, text=True).stdout.strip()
        if branch in {"", "main", "master"}:
            raise ProgramRunBlocked("main/masterまたはdetached HEADではprogram-runを起動できません")
        dirty = subprocess.run(["git", "-C", str(repo_root), "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
        if dirty:
            raise ProgramRunBlocked("dirty checkoutではprogram-runを起動できません")

    def prepare(self, task: Task, repo_root: Path, state_dir: Path, worktree_root: Path) -> None:
        # planctlのgitignore確認は既存ディレクトリを対象にするため、追跡前に
        # state directoryだけを作る（gitignore検証自体はplanctlが担う）。
        state_dir.mkdir(parents=True, exist_ok=True)
        planned = worktree.task_worktree_path(repo_root, worktree_root, task.task_id)
        branch = worktree.task_branch(task.task_id)
        command = [sys.executable, str(PLANOPS / "planctl.py"), "prepare", "--plan", str(task.child.plan), "--plans-root", str(repo_root / "plans"), "--task-id", task.task_id, "--role", "implementer", "--runtime", "codex", "--repo-root", str(repo_root), "--base-commit", task.base_commit, "--worktree-path", str(planned), "--branch", branch, "--state-dir", str(state_dir)]
        done = subprocess.run(command, capture_output=True, text=True)
        if done.returncode:
            raise ProgramRunBlocked("planctl prepareに失敗しました")

    def implement(self, task: Task, repo_root: Path, state_dir: Path, worktree_root: Path) -> Task:
        program = task.child.plan.parent.parent / "program.md"
        args = argparse.Namespace(runtime="codex", role="implementer", plan=str(task.child.plan), repo_root=str(repo_root), task_id=task.task_id, base_commit=task.base_commit, program_path=str(program) if program.is_file() else None, child_id=task.child.nn, state_dir=str(state_dir), worktree_root=str(worktree_root), allowed_path=list(task.child.allowed_paths), purpose=None, dry_run=False)
        answer = delegate.delegate(args)
        task.worktree_path = Path(answer["worktree_path"]).resolve() if answer.get("worktree_path") else None
        if task.worktree_path:
            task.branch = worktree.task_branch(task.task_id)
        task.result_path = Path(str(answer["result_path"]))
        task.manifest_path = Path(str(answer["manifest"]))
        task.thread_id = answer.get("thread_id") if isinstance(answer.get("thread_id"), str) else None
        task.result = manifest.validate_result(manifest.read_json(task.result_path)) if task.result_path.is_file() else None
        return task

    def evaluate(self, task: Task, repo_root: Path, state_dir: Path) -> Evaluation:
        evaluation_id = f"{task.task_id}-evaluation"
        program = task.child.plan.parent.parent / "program.md"
        args = argparse.Namespace(runtime=self.evaluator_runtime, role="evaluator", plan=str(task.child.plan), repo_root=str(repo_root), task_id=evaluation_id, base_commit=task.base_commit, program_path=str(program) if program.is_file() else None, child_id=task.child.nn, state_dir=str(state_dir), worktree_root=None, allowed_path=[], purpose=f"対象diff: {task.base_commit}..{task.result.get('result_commit', '') if task.result else ''}。完了条件を根拠付きで評価し、評価テンプレに沿う本文を最終出力へ返す。", dry_run=False)
        answer = delegate.delegate(args)
        if answer.get("status") != "done":
            return Evaluation(False, reason="evaluatorがblockedです")
        final = Path(str(answer.get("evaluation_path") or state_dir / f"{evaluation_id}-final.md"))
        if not final.is_file():
            return Evaluation(False, reason="evaluatorの評価本文がありません")
        evaluation = next_evaluation_path(task.child.plan)
        evaluation.parent.mkdir(parents=True, exist_ok=True)
        evaluation.write_text(final.read_text(encoding="utf-8"), encoding="utf-8")
        return parse_evaluation(evaluation)

    def resume(self, task: Task, reason: str) -> Task:
        answer = delegate.resume(task.manifest_path, reason)
        if answer.get("status") != "done":
            raise ProgramRunBlocked(str(answer.get("reason") or "Codex resumeがblockedです"))
        task.result_path = Path(str(answer["result_path"]))
        task.result = manifest.validate_result(manifest.read_json(task.result_path))
        task.thread_id = answer.get("thread_id") if isinstance(answer.get("thread_id"), str) else task.thread_id
        return task

    def apply(self, task: Task, evaluation: Evaluation, repo_root: Path) -> None:
        if not evaluation.evaluation_path or not task.result:
            raise ProgramRunBlocked("評価またはresult packetがありません")
        command = [sys.executable, str(PLANOPS / "planctl.py"), "apply-evaluation", "--plan", str(task.child.plan), "--plans-root", str(repo_root / "plans"), "--evaluation", str(evaluation.evaluation_path), "--result", str(task.result_path), "--repo-root", str(repo_root), "--manifest", str(task.manifest_path)]
        done = subprocess.run(command, capture_output=True, text=True)
        if done.returncode:
            raise ProgramRunBlocked("planctl apply-evaluationに失敗しました")

    def commit_sync(self, task: Task, repo_root: Path) -> None:
        status = subprocess.run(["git", "-C", str(repo_root), "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
        if not status:
            return
        paths = [str(task.child.plan.relative_to(repo_root))]
        program = task.child.plan.parent.parent / "program.md"
        if program.is_file():
            paths.append(str(program.relative_to(repo_root)))
        for evaluation in child_evaluations(task.child.plan):
            paths.append(str(evaluation.relative_to(repo_root)))
        add = subprocess.run(["git", "-C", str(repo_root), "add", "--", *paths], capture_output=True, text=True)
        if add.returncode or subprocess.run(["git", "-C", str(repo_root), "commit", "-m", f"plan: 子{task.child.nn}の評価を同期", "--", *paths], capture_output=True).returncode:
            raise ProgramRunBlocked("評価同期のcommitに失敗しました")

    def sync_approval(self, approval: Path, repo_root: Path) -> None:
        if not approval.is_file():
            return
        relative = str(approval.relative_to(repo_root))
        add = subprocess.run(["git", "-C", str(repo_root), "add", "--", relative], capture_output=True, text=True)
        if add.returncode:
            raise ProgramRunBlocked("承認セットをstageできません")
        staged = subprocess.run(["git", "-C", str(repo_root), "diff", "--cached", "--quiet", "--", relative], capture_output=True)
        if staged.returncode == 0:
            return
        commit = subprocess.run(["git", "-C", str(repo_root), "commit", "-m", "plan: 承認セットを同期", "--", relative], capture_output=True)
        if commit.returncode:
            raise ProgramRunBlocked("承認セットの同期commitに失敗しました")

    def merge(self, task: Task, repo_root: Path) -> None:
        if not task.branch:
            return
        done = subprocess.run(["git", "-C", str(repo_root), "merge", "--no-ff", "--no-edit", task.branch], capture_output=True, text=True)
        if done.returncode:
            raise ProgramRunBlocked("merge conflictまたは統合失敗です（自動解決しません）")

    def smoke(self, task: Task, repo_root: Path, commands: tuple[str, ...]) -> None:
        checks = [("git", "diff", "--check")] + [tuple(command.split()) for command in commands]
        for command in checks:
            if subprocess.run(command, cwd=repo_root, capture_output=True, text=True).returncode:
                raise ProgramRunBlocked("統合後スモークに失敗しました")

    def cleanup(self, task: Task, repo_root: Path) -> None:
        if task.worktree_path:
            done = subprocess.run(["git", "-C", str(repo_root), "worktree", "remove", str(task.worktree_path)], capture_output=True, text=True)
            if done.returncode:
                raise ProgramRunBlocked("統合済みworktreeのcleanupに失敗しました")


class ProgramRunner:
    def __init__(self, program: Path, repo_root: Path, state_dir: Path, *, operations: Operations | None = None, run_id: str | None = None, smoke_commands: tuple[str, ...] = ()):
        self.program, self.repo_root, self.state_dir = program.resolve(), repo_root.resolve(), state_dir.resolve()
        self.ops = operations or Operations()
        self.state = RunState(run_id or time.strftime("program-%Y%m%d%H%M%S"), str(self.program))
        self.smoke_commands = smoke_commands
        self.worktree_root = self.repo_root.parent / f".{self.repo_root.name}-planops-worktrees"
        self.tasks: dict[str, Task] = {}

    @property
    def state_path(self) -> Path:
        return self.state_dir / f"{self.state.run_id}-state.json"

    def _save(self) -> None:
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.state_path.write_text(json.dumps(self.state.as_dict(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def _stop(self, reason: str) -> dict[str, Any]:
        self.state.status, self.state.reason = "blocked", reason
        self.state.events.append(f"blocked: {reason}")
        self._save()
        return self.state.as_dict() | {"state_path": str(self.state_path)}

    def _approval(self, child: Child) -> None:
        gate = child.human_gate
        if not gate or gate.startswith("なし") and not re.search(r"hook|symlink|trust|移動|削除|push|main", gate, re.I):
            return
        approval = self.program.parent / "承認セット.md"
        entry = f"\n## program-run {self.state.run_id} / 子{child.nn}\n\n- 対象: {child.plan.name}\n- 操作候補: {gate}\n- 根拠: 子計画の人間ゲート\n- 推奨: このrunでは実行せず、最終一括確認で判断する。\n"
        existing = approval.read_text(encoding="utf-8") if approval.exists() else "# 承認セット\n\nprogram-runが危険操作を実行せず蓄積する判断資料。\n"
        if f"## program-run {self.state.run_id} / 子{child.nn}" not in existing:
            approval.write_text(existing.rstrip() + "\n" + entry, encoding="utf-8")
        self.state.approvals.append(str(approval))
        self.state.events.append(f"approval: {child.nn}")
        self.ops.sync_approval(approval, self.repo_root)

    def _make_task(self, child: Child) -> Task:
        base = self.ops.base_commit(self.repo_root)
        task_id = f"{self.state.run_id}-{child.nn}"
        return Task(child, task_id, base, self.state_dir / f"{task_id}-result.json", self.state_dir / f"{task_id}-manifest.json")

    def _implement_wave(self, children: list[Child]) -> None:
        for index, left in enumerate(children):
            for right in children[index + 1:]:
                if worktree.scopes_overlap(list(left.allowed_paths), list(right.allowed_paths)):
                    raise ProgramRunBlocked(f"子{left.nn}と子{right.nn}の変更可能範囲が衝突します")
        for offset in range(0, len(children), 2):
            batch = children[offset:offset + 2]
            self.state.events.append("implement: " + ",".join(child.nn for child in batch))
            tasks = [self._make_task(child) for child in batch]
            for task in tasks:
                self.ops.prepare(task, self.repo_root, self.state_dir, self.worktree_root)
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                futures = [pool.submit(self.ops.implement, task, self.repo_root, self.state_dir, self.worktree_root) for task in tasks]
                for future in futures:
                    task = future.result()
                    self.tasks[task.child.nn] = task
                    if task.worktree_path:
                        self.state.held_worktrees[task.child.nn] = str(task.worktree_path)
                    if not task.result:
                        raise ProgramRunBlocked(f"子{task.child.nn}のresult packetがありません")
                    manifest.validate_result(task.result)
                    if task.result.get("status") != "done":
                        raise ProgramRunBlocked(f"子{task.child.nn}のresult packetがblockedです")

    def _evaluate_and_integrate(self, child: Child) -> None:
        task = self.tasks[child.nn]
        for attempt in range(3):  # 初回 + 修正2回
            evaluation = self.ops.evaluate(task, self.repo_root, self.state_dir)
            self.state.events.append(f"evaluation: {child.nn}:{'PASS' if evaluation.passed else 'FAIL'}")
            if evaluation.passed:
                self.ops.apply(task, evaluation, self.repo_root)
                self.ops.commit_sync(task, self.repo_root)
                self.ops.merge(task, self.repo_root)
                self.ops.smoke(task, self.repo_root, self.smoke_commands)
                self.ops.cleanup(task, self.repo_root)
                self.state.held_worktrees.pop(child.nn, None)
                self.state.completed.append(child.nn)
                self.state.integration_evaluation[child.nn] = {
                    "status": "PASS", "evaluation": str(evaluation.evaluation_path) if evaluation.evaluation_path else "",
                    "result_commit": str(task.result.get("result_commit", "")) if task.result else "",
                }
                self.state.events.append(f"integrated: {child.nn}")
                return
            if attempt == 2:
                raise ProgramRunBlocked(f"子{child.nn}は修正上限（2回）を超過しました")
            task = self.ops.resume(task, evaluation.reason)
            self.tasks[child.nn] = task
            self.state.events.append(f"resume: {child.nn}:{attempt + 1}")

    def run(self) -> dict[str, Any]:
        try:
            self.ops.lint(self.program, program=True)
            children = read_program(self.program)
            for child in children:
                self.ops.lint(child.plan)
            self.ops.ensure_integration_branch(self.repo_root)
            for number, wave in enumerate(waves(children), 1):
                self.state.events.append(f"wave: {number}")
                self._implement_wave(wave)
                for child in wave:
                    self._approval(child)
                    self._evaluate_and_integrate(child)
            self.state.status = "completed"
            self.state.events.append("completed")
            self._save()
            return self.state.as_dict() | {"state_path": str(self.state_path), "approval_set": str(self.program.parent / "承認セット.md"), "integration_evaluation": self.state.integration_evaluation}
        except (ProgramRunBlocked, manifest.ValidationError, worktree.HarnessConflict) as exc:
            return self._stop(str(exc))


def main() -> None:
    parser = argparse.ArgumentParser(description="program.mdをWave順に実行する")
    parser.add_argument("--program", required=True)
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--state-dir")
    parser.add_argument("--run-id")
    parser.add_argument("--smoke-command", action="append", default=[])
    parser.add_argument("--evaluation-runtime", choices=sorted(manifest.RUNTIMES), default="claude")
    args = parser.parse_args()
    repo = Path(args.repo_root)
    state = Path(args.state_dir) if args.state_dir else repo / ".planops-state"
    result = ProgramRunner(Path(args.program), repo, state, operations=Operations(args.evaluation_runtime), run_id=args.run_id, smoke_commands=tuple(args.smoke_command)).run()
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0 if result["status"] == "completed" else 1)


if __name__ == "__main__":
    main()
