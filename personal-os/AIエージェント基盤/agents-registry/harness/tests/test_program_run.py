from __future__ import annotations

import shutil
import tempfile
import threading
import time
import unittest
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
import sys
sys.path.insert(0, str(HARNESS))
import program_run


class FakeOperations(program_run.Operations):
    """外部CLIを一切起動せず、program-runの遷移だけを記録する。"""

    def __init__(self, outcomes: dict[str, list[bool]] | None = None) -> None:
        self.events: list[str] = []
        self.outcomes = outcomes or {}
        self.active = 0
        self.max_active = 0
        self.lock = threading.Lock()

    def lint(self, path: Path, *, program: bool = False) -> None:
        self.events.append(f"lint:{'program' if program else path.stem}")

    def base_commit(self, _repo_root: Path) -> str:
        return "base"

    def ensure_integration_branch(self, _repo_root: Path) -> None:
        self.events.append("branch-check")

    def prepare(self, task: program_run.Task, _repo_root: Path, _state_dir: Path, _worktree_root: Path) -> None:
        self.events.append(f"prepare:{task.child.nn}")

    def implement(self, task: program_run.Task, _repo_root: Path, state_dir: Path, _worktree_root: Path) -> program_run.Task:
        with self.lock:
            self.active += 1
            self.max_active = max(self.max_active, self.active)
        time.sleep(0.02)
        with self.lock:
            self.active -= 1
        task.worktree_path = state_dir / f"worktree-{task.child.nn}"
        task.branch = f"plan-task/{task.task_id}"
        task.result = {
            "version": 1, "task_id": task.task_id, "status": "done", "base_commit": task.base_commit,
            "result_commit": f"commit-{task.child.nn}", "changed_paths": [f"src/{task.child.nn}.py"],
            "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": [],
        }
        self.events.append(f"implement:{task.child.nn}")
        return task

    def review(self, task: program_run.Task, _repo_root: Path, state_dir: Path) -> program_run.Review:
        values = self.outcomes.setdefault(task.child.nn, [True])
        passed = values.pop(0)
        self.events.append(f"review:{task.child.nn}:{'PASS' if passed else 'FAIL'}")
        return program_run.Review(passed, state_dir / f"evaluation-{task.child.nn}.md" if passed else None, "fixture fail")

    def resume(self, task: program_run.Task, _reason: str) -> program_run.Task:
        self.events.append(f"resume:{task.child.nn}")
        return task

    def apply(self, task: program_run.Task, _review: program_run.Review, _repo_root: Path) -> None:
        self.events.append(f"apply:{task.child.nn}")

    def commit_sync(self, task: program_run.Task, _repo_root: Path) -> None:
        self.events.append(f"sync-commit:{task.child.nn}")

    def merge(self, task: program_run.Task, _repo_root: Path) -> None:
        self.events.append(f"merge:{task.child.nn}")

    def smoke(self, task: program_run.Task, _repo_root: Path, _commands: tuple[str, ...]) -> None:
        self.events.append(f"smoke:{task.child.nn}")

    def cleanup(self, task: program_run.Task, _repo_root: Path) -> None:
        self.events.append(f"cleanup:{task.child.nn}")


class ProgramRunTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="program-run-test-"))
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self.state = self.repo / ".planops-state"
        self.program_dir = self.repo / "plans" / "active" / "2026-07-15-fixture"
        (self.program_dir / "plans").mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_program(self, children: list[dict[str, str]]) -> Path:
        blocks: list[str] = []
        for item in children:
            nn = item["nn"]
            blocks.append(
                f"- [ ] {nn}  子{nn} … 実装\n"
                f"    役割: 実装\n    対象repo: fixture\n    並列: 不可\n"
                f"    レビュー: {item.get('review', '都度')}\n    人間ゲート: {item.get('gate', 'なし')}\n"
                f"    次: fixture\n    場所: plans/{nn}\n    依存: {item.get('dependencies', '―')}\n    参照: ―\n"
            )
            parallel = item.get("execution", "delegated-single")
            extra = "\n- ファイル担当マップ: A=`src/a.py`、B=`src/b.py`\n- worktree方針: レーンごとにtask-scoped worktree\n" if item.get("parallel_fields") else ""
            (self.program_dir / "plans" / f"{nn}-子.md").write_text(
                "親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成\n"
                f"並列: 不可 ／ レビュー: {item.get('review', '都度')}\n人間ゲート: {item.get('gate', 'なし')}\n\n"
                "# 子\n\n## 目的\n\nfixture\n\n## 非対象\n\nなし\n\n## 現状\n\nなし\n\n## 実行契約\n\n"
                f"- 対象repo: fixture\n- 実行形: {parallel}\n- 最初に読む順番: fixture\n- 依存成果: なし\n"
                f"- 変更可能範囲: `src/{nn}.py`\n- 変更禁止範囲: なし\n- 維持する契約: なし\n- 検証: fixture\n"
                f"- 停止・エスカレーション条件: blocked\n- 完了時に返す情報: result\n{extra}"
                "\n## 方針\n\nfixture\n\n## 完了条件\n\n- [ ] fixture\n",
                encoding="utf-8",
            )
        program = self.program_dir / "program.md"
        program.write_text("# 合成program\n\n## 子計画マップ\n\n" + "\n".join(blocks), encoding="utf-8")
        return program

    def runner(self, program: Path, ops: FakeOperations, run_id: str = "fixture") -> program_run.ProgramRunner:
        return program_run.ProgramRunner(program, self.repo, self.state, operations=ops, run_id=run_id)

    def test_wave_parallel_limit_and_declared_review_timing(self) -> None:
        program = self.write_program([
            {"nn": "01", "review": "都度"},
            {"nn": "02", "review": "一括（Wave 2完了時）"},
            {"nn": "03", "review": "都度", "dependencies": "01"},
        ])
        ops = FakeOperations()
        result = self.runner(program, ops).run()
        self.assertEqual(result["status"], "completed")
        self.assertLessEqual(ops.max_active, 2)
        self.assertEqual(ops.events.index("review:01:PASS") < ops.events.index("prepare:03"), True)
        self.assertGreater(ops.events.index("review:02:PASS"), ops.events.index("implement:03"))
        self.assertEqual(result["completed"], ["01", "03", "02"])

    def test_fail_resumes_then_only_pass_applies(self) -> None:
        program = self.write_program([{"nn": "01", "review": "都度"}])
        ops = FakeOperations({"01": [False, True]})
        result = self.runner(program, ops).run()
        self.assertEqual(result["status"], "completed")
        self.assertIn("resume:01", ops.events)
        self.assertEqual(ops.events.count("apply:01"), 1)
        self.assertLess(ops.events.index("review:01:FAIL"), ops.events.index("apply:01"))

    def test_full_retry_limit_stops_with_resume_state(self) -> None:
        program = self.write_program([{"nn": "01", "review": "都度"}])
        ops = FakeOperations({"01": [False, False, False]})
        result = self.runner(program, ops, "retry-limit").run()
        self.assertEqual(result["status"], "blocked")
        self.assertIn("上限", result["reason"])
        self.assertEqual(ops.events.count("resume:01"), 2)
        self.assertTrue(Path(result["state_path"]).is_file())
        self.assertIn("01", result["held_worktrees"])

    def test_approval_set_accumulates_without_executing_dangerous_operation(self) -> None:
        program = self.write_program([
            {"nn": "01", "gate": "hook登録とsymlinkは承認セットへ"},
            {"nn": "02", "gate": "既存計画の移動は承認セットへ"},
        ])
        result = self.runner(program, FakeOperations(), "approval").run()
        approval = self.program_dir / "承認セット.md"
        self.assertEqual(result["status"], "completed")
        self.assertTrue(approval.is_file())
        text = approval.read_text(encoding="utf-8")
        self.assertIn("子01", text)
        self.assertIn("子02", text)

    def test_preflight_rejects_parallel_without_lane_contract(self) -> None:
        program = self.write_program([{"nn": "01", "execution": "delegated-parallel"}])
        result = self.runner(program, FakeOperations()).run()
        self.assertEqual(result["status"], "blocked")
        self.assertIn("ファイル担当マップ", result["reason"])
        self.assertFalse(any(event.startswith("prepare:") for event in result["events"]))

    def test_same_wave_path_collision_stops_before_worker(self) -> None:
        program = self.write_program([{"nn": "01"}, {"nn": "02"}])
        second = self.program_dir / "plans" / "02-子.md"
        second.write_text(second.read_text(encoding="utf-8").replace("`src/02.py`", "`src/01.py`"), encoding="utf-8")
        result = self.runner(program, FakeOperations()).run()
        self.assertEqual(result["status"], "blocked")
        self.assertIn("衝突", result["reason"])
        self.assertFalse(any(event.startswith("prepare:") for event in result["events"]))

    def test_codex_impl_wrapper_shows_all_required_delegate_arguments(self) -> None:
        wrapper = (HARNESS.parent / "claude" / "commands" / "codex-impl.md").read_text(encoding="utf-8")
        for required in ("--runtime", "--role", "--plan", "--repo-root", "--task-id", "--base-commit", "--allowed-path"):
            self.assertIn(required, wrapper)


if __name__ == "__main__":
    unittest.main()
