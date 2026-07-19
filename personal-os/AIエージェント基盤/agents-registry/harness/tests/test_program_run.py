from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARNESS))
import program_run


class FakeOperations:
    """実行順だけを検証する副作用なしfixture。"""

    def __init__(self, outcomes: dict[str, list[bool]] | None = None) -> None:
        self.outcomes = outcomes or {}
        self.events: list[str] = []

    def lint(self, _path: Path, *, program: bool = False) -> None:
        self.events.append("lint:program" if program else "lint:plan")

    def ensure_integration_branch(self, _repo: Path) -> None:
        self.events.append("branch")

    def base_commit(self, _repo: Path) -> str:
        return "base"

    def prepare(self, task: program_run.Task, _repo: Path, _state: Path, _worktrees: Path) -> None:
        self.events.append(f"prepare:{task.child.nn}")

    def implement(self, task: program_run.Task, _repo: Path, _state: Path, _worktrees: Path) -> program_run.Task:
        self.events.append(f"implement:{task.child.nn}")
        task.result = {
            "version": 1, "task_id": task.task_id, "status": "done", "base_commit": "base",
            "result_commit": f"commit-{task.child.nn}", "changed_paths": list(task.child.allowed_paths),
            "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": [],
        }
        return task

    def evaluate(self, task: program_run.Task, _repo: Path, state: Path) -> program_run.Evaluation:
        passed = self.outcomes.setdefault(task.child.nn, [True]).pop(0)
        self.events.append(f"evaluation:{task.child.nn}:{'PASS' if passed else 'FAIL'}")
        return program_run.Evaluation(passed, state / f"{task.child.nn}-評価.md" if passed else None, "fixture fail")

    def resume(self, task: program_run.Task, _reason: str) -> program_run.Task:
        self.events.append(f"resume:{task.child.nn}")
        return task

    def apply(self, task: program_run.Task, _evaluation: program_run.Evaluation, _repo: Path) -> None:
        self.events.append(f"apply:{task.child.nn}")

    def commit_sync(self, task: program_run.Task, _repo: Path) -> None:
        self.events.append(f"sync:{task.child.nn}")

    def merge(self, task: program_run.Task, _repo: Path) -> None:
        self.events.append(f"merge:{task.child.nn}")

    def smoke(self, task: program_run.Task, _repo: Path, _commands: tuple[str, ...]) -> None:
        self.events.append(f"smoke:{task.child.nn}")

    def cleanup(self, task: program_run.Task, _repo: Path) -> None:
        self.events.append(f"cleanup:{task.child.nn}")

    def sync_approval(self, _approval: Path, _repo: Path) -> None:
        self.events.append("approval-sync")


class ProgramRunTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="program-run-test-"))
        self.repo = self.tmp / "repo"; self.repo.mkdir()
        self.state = self.repo / ".planops-state"
        self.program_dir = self.repo / "plans" / "active" / "2026-07-19-評価工程"
        (self.program_dir / "plans").mkdir(parents=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_program(self, children: list[dict[str, str]]) -> Path:
        blocks: list[str] = []
        for item in children:
            nn = item["nn"]
            blocks.append(
                f"- [ ] {nn}  子{nn} … 実装\n"
                "    役割: 実装\n"
                "    対象repo: fixture\n"
                "    並列: 不可\n"
                f"    人間ゲート: {item.get('gate', 'なし')}\n"
                "    次: 実装する\n"
                f"    場所: plans/{nn}\n"
                f"    依存: {item.get('dependencies', '―')}\n"
                "    参照: ―\n"
            )
            (self.program_dir / "plans" / f"{nn}-子.md").write_text(
                "親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成\n"
                "並列: 不可\n人間ゲート: なし\n\n"
                f"# 子{nn}\n\n## 目的\n\nfixture\n\n## 非対象\n\nなし\n\n## 現状\n\nなし\n\n"
                "## 実行契約\n\n"
                f"- 対象repo: fixture\n- 実行形: delegated-single\n- 最初に読む順番: fixture\n- 依存成果: なし\n- 変更可能範囲: `src/{nn}.py`\n- 変更禁止範囲: なし\n- ファイル担当マップ: 不要\n- worktree方針: 不要\n- 維持する契約: なし\n- 検証: fixture\n- 停止・エスカレーション条件: blocked\n- 完了時に返す情報: result\n\n"
                "## 方針\n\nfixture\n\n## 完了条件\n\n"
                f"- [ ] src/{nn}.pyが実装されている\n",
                encoding="utf-8",
            )
        program = self.program_dir / "program.md"
        program.write_text(
            "分類: 横断 ／ 種別: 統合整理 ／ 形態: program\n\n# program\n\n"
            "## 子計画マップ\n\n" + "\n".join(blocks) + "\n## 完了条件\n\n- [ ] 子計画が評価される\n",
            encoding="utf-8",
        )
        return program

    def runner(self, program: Path, ops: FakeOperations) -> program_run.ProgramRunner:
        return program_run.ProgramRunner(program, self.repo, self.state, operations=ops, run_id="fixture")

    def test_contract_has_no_review_field_and_reads_dependencies(self) -> None:
        program = self.write_program([{"nn": "01"}, {"nn": "02", "dependencies": "01"}])
        children = program_run.read_program(program)
        self.assertEqual([child.nn for child in children], ["01", "02"])
        self.assertEqual(children[0].dependencies, ())
        self.assertEqual(children[1].dependencies, ("01",))
        self.assertFalse(hasattr(children[0], "review"))

    def test_each_child_is_evaluated_before_the_next_dependent_child(self) -> None:
        program = self.write_program([{"nn": "01"}, {"nn": "02", "dependencies": "01"}])
        ops = FakeOperations()
        result = self.runner(program, ops).run()
        self.assertEqual(result["status"], "completed")
        self.assertLess(ops.events.index("evaluation:01:PASS"), ops.events.index("prepare:02"))
        self.assertEqual(result["completed"], ["01", "02"])
        self.assertNotIn("review_queue", result)

    def test_failed_evaluation_resumes_then_applies_once(self) -> None:
        program = self.write_program([{"nn": "01"}])
        ops = FakeOperations({"01": [False, True]})
        result = self.runner(program, ops).run()
        self.assertEqual(result["status"], "completed")
        self.assertEqual(ops.events.count("apply:01"), 1)
        self.assertLess(ops.events.index("evaluation:01:FAIL"), ops.events.index("resume:01"))
        self.assertLess(ops.events.index("resume:01"), ops.events.index("evaluation:01:PASS"))

    def test_evaluation_retry_limit_keeps_the_run_blocked(self) -> None:
        program = self.write_program([{"nn": "01"}])
        ops = FakeOperations({"01": [False, False, False]})
        result = self.runner(program, ops).run()
        self.assertEqual(result["status"], "blocked")
        self.assertIn("修正上限", result["reason"])
        self.assertEqual(ops.events.count("resume:01"), 2)


if __name__ == "__main__":
    unittest.main()
