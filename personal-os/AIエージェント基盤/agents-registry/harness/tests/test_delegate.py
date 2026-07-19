from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HARNESS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HARNESS))
import delegate
import manifest
import worktree


class HarnessTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="harness-test-"))
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self.git("init")
        self.git("config", "user.email", "harness@example.invalid")
        self.git("config", "user.name", "Harness Test")
        (self.repo / ".gitignore").write_text(".planops-state/\n", encoding="utf-8")
        (self.repo / "plan.md").write_text("# test\n\n## 目的\n\nテストする\n", encoding="utf-8")
        self.git("add", ".gitignore", "plan.md")
        self.git("commit", "-m", "初期化")
        self.base = self.git("rev-parse", "HEAD").strip()

    def tearDown(self) -> None:
        shutil.rmtree(self.tmp, ignore_errors=True)

    def git(self, *args: str) -> str:
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True, text=True).stdout

    def args(self, **override: object) -> argparse.Namespace:
        value: dict[str, object] = {"runtime": "codex", "role": "implementer", "plan": str(self.repo / "plan.md"), "repo_root": str(self.repo), "task_id": "sample-01", "base_commit": self.base, "program_path": None, "child_id": None, "state_dir": None, "worktree_root": str(self.tmp / "worktrees"), "allowed_path": ["src/a.py"], "purpose": None, "dry_run": False}
        value.update(override)
        return argparse.Namespace(**value)

    @staticmethod
    def result_for(env: dict[str, str]) -> Path:
        data = json.loads(Path(env["PLAN_RUN_MANIFEST"]).read_text(encoding="utf-8"))
        return Path(data["result_path"])

    def fake_done(self, command: list[str], cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
        self.assertNotIn("claude", command[0])
        packet = json.loads(Path(env["PLAN_RUN_MANIFEST"]).read_text(encoding="utf-8"))
        self.assertEqual(str(cwd), packet["worktree_path"])
        self.result_for(env).write_text(json.dumps({"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": packet["allowed_paths"], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []}), encoding="utf-8")
        return delegate.ProcessResult(0, "ok", "")

    def test_base_unspecified_for_write_is_rejected(self) -> None:
        with self.assertRaisesRegex(worktree.HarnessConflict, "base SHA"):
            delegate.delegate(self.args(base_commit=None), runner=self.fake_done)

    def test_worktree_is_task_scoped_and_parallel_scopes_do_not_cross(self) -> None:
        first = delegate.delegate(self.args(task_id="lane-a", allowed_path=["src/a.py"]), runner=self.fake_done)
        second = delegate.delegate(self.args(task_id="lane-b", allowed_path=["src/b.py"]), runner=self.fake_done)
        self.assertNotEqual(first["worktree_path"], second["worktree_path"])
        self.assertTrue(Path(str(first["worktree_path"])).is_dir())
        one = manifest.read_json(Path(str(first["manifest"])))
        two = manifest.read_json(Path(str(second["manifest"])))
        self.assertFalse(worktree.scopes_overlap(one["allowed_paths"], two["allowed_paths"]))

    def test_dirty_checkout_and_scope_conflict_stop_before_worker(self) -> None:
        (self.repo / "untracked.txt").write_text("dirty", encoding="utf-8")
        with self.assertRaisesRegex(worktree.HarnessConflict, "dirty checkout"):
            delegate.delegate(self.args(), runner=self.fake_done)
        (self.repo / "untracked.txt").unlink()
        first = delegate.delegate(self.args(task_id="running-a", dry_run=True), runner=self.fake_done)
        self.assertEqual(first["status"], "prepared")
        with self.assertRaisesRegex(worktree.HarnessConflict, "変更可能範囲"):
            delegate.delegate(self.args(task_id="running-b"), runner=self.fake_done)

    def test_schema_validation_rejects_bad_data(self) -> None:
        planctl_manifest = {"version": 1, "task_id": "prepare-01", "role": "implementer", "runtime": "codex", "repo_root": str(self.repo), "plan_path": str(self.repo / "plan.md"), "program_path": None, "child_id": None, "base_commit": self.base, "worktree_path": "/tmp/worktree", "branch": "plan-task/prepare-01", "result_path": "/tmp/result.json", "evaluation_path": None, "phase": "running"}
        self.assertEqual(manifest.validate_manifest(planctl_manifest)["task_id"], "prepare-01")
        with self.assertRaises(manifest.ValidationError):
            manifest.validate_manifest({"version": 1})
        invalid = {"version": 1, "task_id": "x", "status": "done", "base_commit": "a", "result_commit": "b", "changed_paths": [], "tests": [{"command": "", "status": "passed", "summary": ""}], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []}
        with self.assertRaisesRegex(manifest.ValidationError, "passed"):
            manifest.validate_result(invalid)
        invalid["tests"] = []
        invalid["assumptions"] = ["token=not-for-state"]
        with self.assertRaisesRegex(manifest.ValidationError, "credential"):
            manifest.validate_result(invalid)
        valid_manifest = dict(planctl_manifest)
        valid_manifest["unexpected"] = "no"
        with self.assertRaisesRegex(manifest.ValidationError, "未知"):
            manifest.validate_manifest(valid_manifest)
        valid_result = {"version": 1, "task_id": "x", "status": "done", "base_commit": "a", "result_commit": "b", "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []}
        valid_result["tests"] = [{"command": "ok", "status": "passed", "summary": "ok", "extra": "no"}]
        with self.assertRaisesRegex(manifest.ValidationError, "未知"):
            manifest.validate_result(valid_result)
        valid_result["tests"] = []
        valid_result["task_id"] = 1
        with self.assertRaisesRegex(manifest.ValidationError, "型"):
            manifest.validate_result(valid_result)

    def test_process_output_is_redacted(self) -> None:
        def leaky(_command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0, "api_key=very-secret-value", "token=another-secret")
        answer = delegate.delegate(self.args(task_id="redact"), runner=leaky)
        output = Path(str(answer["manifest"])).with_name("redact-process-output.json").read_text(encoding="utf-8")
        self.assertNotIn("very-secret-value", output)
        self.assertNotIn("another-secret", output)
        self.assertIn("[REDACTED]", output)

    def test_claude_uses_only_verified_noninteractive_flags_or_disables(self) -> None:
        calls: list[list[str]] = []
        def fake_claude(command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            calls.append(command)
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0)
        help_fixture = "Usage: claude\n  -p, --print\n  --output-format <format>"
        answer = delegate.delegate(self.args(task_id="claude-ok", runtime="claude"), runner=fake_claude, claude_help=help_fixture)
        self.assertEqual(answer["status"], "done")
        self.assertEqual(calls[0][:4], ["claude", "--print", "--output-format", "json"])
        disabled = delegate.delegate(self.args(task_id="claude-disabled", runtime="claude", allowed_path=["src/c.py"]), runner=fake_claude, claude_help="Usage: claude")
        self.assertEqual(disabled["status"], "feature-disabled")

    def test_claude_json_result_is_saved_as_evaluator_final_text(self) -> None:
        def fake_claude(_command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0, json.dumps({"result": "# 評価\n\n全PASS"}), "")
        answer = delegate.delegate(self.args(task_id="claude-final", runtime="claude", role="evaluator", base_commit=self.base, allowed_path=[]), runner=fake_claude, claude_help="--print --output-format")
        final = Path(str(answer["manifest"])).with_name("claude-final-final.md")
        self.assertEqual(final.read_text(encoding="utf-8"), "# 評価\n\n全PASS")
        self.assertEqual(answer["evaluation_path"], str(final))

    def test_evaluator_completes_with_evaluation_md_without_result_packet(self) -> None:
        """評価はread-onlyなので、実装者用result packetを要求しない。"""
        def fake_evaluator(_command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            Path(str(packet["evaluation_path"])).write_text(
                "# 評価\n\n- 対象計画: plan.md\n\n## 項目別採点\n\n- [PASS] 完了条件: diffとテスト結果を確認\n\n## 総合判定\n\n全PASS\n",
                encoding="utf-8",
            )
            return delegate.ProcessResult(0)

        answer = delegate.delegate(
            self.args(task_id="evaluation-final-only", role="evaluator", base_commit=self.base, allowed_path=[]),
            runner=fake_evaluator,
        )
        self.assertEqual(answer["status"], "done")
        self.assertTrue(Path(str(answer["evaluation_path"])).is_file())
        self.assertFalse(Path(str(answer["result_path"])).exists())
        data = manifest.read_json(Path(str(answer["manifest"])))
        self.assertEqual(data["phase"], "evaluated")

    def test_codex_resume_uses_recorded_thread_without_last(self) -> None:
        def first(_command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0, '{"type":"thread.started","thread_id":"thread-01"}', "")
        initial = delegate.delegate(self.args(task_id="resume", allowed_path=["src/resume.py"]), runner=first)
        seen: list[str] = []
        def resumed(command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            seen.extend(command)
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": [], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0, "", "")
        answer = delegate.resume(Path(str(initial["manifest"])), "修正してください", runner=resumed)
        self.assertEqual(answer["status"], "done")
        self.assertEqual(seen[:5], ["codex", "exec", "resume", "thread-01", "修正指示: 修正してください\n完了時は既存result packetをschemaどおり更新してください。"])
        self.assertNotIn("--last", seen)

    def test_changed_paths_outside_allowed_scope_are_blocked(self) -> None:
        def outside(_command: list[str], _cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            manifest.write_json(Path(packet["result_path"]), {"version": 1, "task_id": packet["task_id"], "status": "done", "base_commit": packet["base_commit"], "result_commit": packet["base_commit"], "changed_paths": ["outside.py"], "tests": [], "assumptions": [], "blockers": [], "remaining_risks": [], "out_of_scope_findings": []})
            return delegate.ProcessResult(0)
        answer = delegate.delegate(self.args(task_id="outside", allowed_path=["src/allowed.py"]), runner=outside)
        self.assertEqual(answer["status"], "blocked")
        self.assertIn("範囲外", str(answer["reason"]))

    def _program_fixture(self) -> Path:
        prog = self.repo / "prog"
        (prog / "plans").mkdir(parents=True)
        (prog / "実装").mkdir()
        (prog / "program.md").write_text("# program\n", encoding="utf-8")
        (prog / "実装" / "共通.md").write_text("# 実装共通\n", encoding="utf-8")
        child = prog / "plans" / "01-子.md"
        child.write_text("# 子\n\n## 目的\n\nテスト\n", encoding="utf-8")
        self.git("add", "prog")
        self.git("commit", "-m", "program fixture")
        self.base = self.git("rev-parse", "HEAD").strip()
        return child

    def test_reading_order_branches_by_role_and_program_presence(self) -> None:
        child = self._program_fixture()
        impl = delegate.delegate(self.args(task_id="ctx-impl", plan=str(child), base_commit=self.base, dry_run=True), runner=self.fake_done)
        packet = Path(str(impl["task_packet"])).read_text(encoding="utf-8")
        self.assertIn("実装/共通.md", packet)
        self.assertNotIn("評価テンプレ", packet)
        anchor = packet.index("最初に読む順番")
        order = [packet.index(token, anchor) for token in ("AGENTS.md", "親program", "実装/共通.md", "対象計画")]
        self.assertEqual(order, sorted(order))
        data = manifest.read_json(Path(str(impl["manifest"])))
        self.assertEqual(data["program_path"], str((self.repo / "prog" / "program.md").resolve()))
        evaluation = delegate.delegate(self.args(task_id="ctx-eval", plan=str(child), role="evaluator", base_commit=self.base, allowed_path=[], dry_run=True), runner=self.fake_done)
        packet = Path(str(evaluation["task_packet"])).read_text(encoding="utf-8")
        self.assertIn("計画の「完了条件」", packet)
        self.assertIn("## evaluatorの最終出力形式", packet)
        self.assertNotIn("実装/共通.md", packet)
        explorer = delegate.delegate(self.args(task_id="ctx-exp", plan=str(child), role="explorer", base_commit=None, allowed_path=[], dry_run=True), runner=self.fake_done)
        packet = Path(str(explorer["task_packet"])).read_text(encoding="utf-8")
        self.assertNotIn("共通.md", packet)
        single = delegate.delegate(self.args(task_id="ctx-single", allowed_path=["src/b.py"], dry_run=True), runner=self.fake_done)
        packet = Path(str(single["task_packet"])).read_text(encoding="utf-8")
        self.assertNotIn("共通.md", packet)
        self.assertIn("親program（ある場合）", packet)

    def test_read_only_task_omits_worktree(self) -> None:
        observed: dict[str, object] = {}
        def fake_readonly(command: list[str], cwd: Path, env: dict[str, str]) -> delegate.ProcessResult:
            packet = manifest.read_json(Path(env["PLAN_RUN_MANIFEST"]))
            observed["cwd"] = cwd; observed["command"] = command
            Path(str(packet["evaluation_path"])).write_text("# 評価\n\n## 項目別採点\n\n- [PASS] 完了条件: 確認済み\n\n## 総合判定\n\n全PASS\n", encoding="utf-8")
            return delegate.ProcessResult(0)
        answer = delegate.delegate(self.args(task_id="evaluation-only", role="evaluator", base_commit=self.base, allowed_path=[]), runner=fake_readonly)
        self.assertIsNone(answer["worktree_path"])
        self.assertEqual(Path(observed["cwd"]).resolve(), self.repo.resolve())
        self.assertIn("read-only", observed["command"])


if __name__ == "__main__":
    unittest.main()
