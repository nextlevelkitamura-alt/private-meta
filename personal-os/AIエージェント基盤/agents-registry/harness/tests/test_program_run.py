from __future__ import annotations

import shutil
import tempfile
import threading
import time
import unittest
import json
import os
import subprocess
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

    def sync_approval(self, _approval: Path, _repo_root: Path) -> None:
        self.events.append("approval-sync")

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
        # 見出しは正本テンプレ（skills/plan-ops/templates/program.md）と同じ注記付き形式にする。
        program.write_text("# 合成program\n\n## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新\n\n" + "\n".join(blocks), encoding="utf-8")
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

    def test_roles_have_no_fixed_runtime_or_model_binding(self) -> None:
        for role in (HARNESS.parent / "roles").glob("*.md"):
            text = role.read_text(encoding="utf-8")
            self.assertNotRegex(text, r"(?im)^.*(?:/Users/|plan-task/|gpt-[\w.-]+|claude-[\w.-]+).*$")

    def test_evaluation_parser_accepts_only_explicit_all_pass(self) -> None:
        folder = Path(tempfile.mkdtemp(prefix="evaluation-parser-"))
        try:
            target = folder / "評価.md"
            target.write_text("## 総合判定\n全PASS\n", encoding="utf-8")
            self.assertTrue(program_run.parse_evaluation(target).passed)
            target.write_text("## 項目別採点\n- [FAIL] 条件\n\n## 総合判定\n全PASS\n", encoding="utf-8")
            failed = program_run.parse_evaluation(target)
            self.assertFalse(failed.passed)
            self.assertIn("FAIL", failed.reason)
            target.write_text("## 総合判定\n確認中\n", encoding="utf-8")
            self.assertFalse(program_run.parse_evaluation(target).passed)
            target.write_text("# 評価\n", encoding="utf-8")
            self.assertFalse(program_run.parse_evaluation(target).passed)
        finally:
            shutil.rmtree(folder, ignore_errors=True)


class RealGitProgramRunTest(unittest.TestCase):
    """本物のgitだけを使い、runtimeはPATH上の一時fake CLIへ閉じ込める。"""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="program-run-real-git-"))
        self.repo = self.tmp / "repo"
        self.repo.mkdir()
        self.git("init")
        self.git("config", "user.email", "program-run@example.invalid")
        self.git("config", "user.name", "Program Run Test")
        (self.repo / ".gitignore").write_text(".planops-state/\n", encoding="utf-8")
        (self.repo / "README.md").write_text("fixture\n", encoding="utf-8")
        self.git("add", ".gitignore", "README.md")
        self.git("commit", "-m", "初期化")
        self.git("branch", "-M", "main")
        self.main_before = self.git("rev-parse", "main").strip()
        self.git("checkout", "-b", "integration")
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self._write_fake_runtime("codex", self._codex_script())
        self._write_fake_runtime("claude", self._claude_script())
        self.old_path = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.bin) + os.pathsep + self.old_path

    def tearDown(self) -> None:
        os.environ["PATH"] = self.old_path
        shutil.rmtree(self.tmp, ignore_errors=True)

    def git(self, *args: str) -> str:
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True, text=True).stdout

    def _write_fake_runtime(self, name: str, source: str) -> None:
        target = self.bin / name
        target.write_text(source, encoding="utf-8")
        target.chmod(0o755)

    @staticmethod
    def _codex_script() -> str:
        return """#!/usr/bin/env python3
import json, os, pathlib, subprocess, sys
manifest = json.load(open(os.environ['PLAN_RUN_MANIFEST'], encoding='utf-8'))
root = pathlib.Path.cwd()
if manifest['role'] == 'reviewer':
    lines = pathlib.Path(manifest['plan_path']).read_text(encoding='utf-8').splitlines()
    start = lines.index('## 完了条件（レビュー項目）') + 1
    items = []
    for line in lines[start:]:
        if line.startswith('## '): break
        if line.startswith('- ['):
            items.append(line.split('] ', 1)[1])
    sequence = os.environ.get('FAKE_REVIEW_SEQUENCE', 'PASS').split(',')
    counter_path = os.environ.get('FAKE_REVIEW_COUNTER')
    count = int(pathlib.Path(counter_path).read_text()) if counter_path and pathlib.Path(counter_path).exists() else 0
    if counter_path: pathlib.Path(counter_path).write_text(str(count + 1))
    verdict = sequence[min(count, len(sequence) - 1)].strip()
    mark = 'FAIL' if verdict == 'FAIL' else 'PASS'
    summary = 'FAILあり' if verdict == 'FAIL' else '全PASS'
    body = '対象計画: ' + manifest['plan_path'] + ' ／ ラウンド: 01\\n\\n# 評価\\n\\n## 項目別採点\\n' + ''.join('- [' + mark + '] ' + item + '\\n  根拠: fake Codexで実物を確認\\n' for item in items) + '\\n## 総合判定\\n' + summary + '\\n'
    output = pathlib.Path(sys.argv[sys.argv.index('-o') + 1])
    output.write_text(body, encoding='utf-8')
    json.dump({'version':1,'task_id':manifest['task_id'],'status':'done','base_commit':manifest['base_commit'],'result_commit':manifest['base_commit'],'changed_paths':[],'tests':[],'assumptions':[],'blockers':[],'remaining_risks':[],'out_of_scope_findings':[]}, open(manifest['result_path'], 'w', encoding='utf-8'), ensure_ascii=False)
    print(json.dumps({'type':'thread.started','thread_id':'fake-thread-' + manifest['task_id']}))
    raise SystemExit(0)
if 'resume' in sys.argv:
    log = os.environ.get('FAKE_RESUME_LOG')
    if log: pathlib.Path(log).write_text(' '.join(sys.argv), encoding='utf-8')
else:
    path = root / manifest['allowed_paths'][0]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('worker\\n', encoding='utf-8')
    subprocess.run(['git', 'add', '--', str(path.relative_to(root))], cwd=root, check=True)
    subprocess.run(['git', 'commit', '-m', 'worker change'], cwd=root, check=True, stdout=subprocess.DEVNULL)
commit = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=root, check=True, capture_output=True, text=True).stdout.strip()
json.dump({'version':1,'task_id':manifest['task_id'],'status':'done','base_commit':manifest['base_commit'],'result_commit':commit,'changed_paths':manifest['allowed_paths'],'tests':[],'assumptions':[],'blockers':[],'remaining_risks':[],'out_of_scope_findings':[]}, open(manifest['result_path'], 'w', encoding='utf-8'), ensure_ascii=False)
print(json.dumps({'type':'thread.started','thread_id':'fake-thread-' + manifest['task_id']}))
"""

    @staticmethod
    def _claude_script() -> str:
        return """#!/usr/bin/env python3
import json, os, pathlib, sys
if '--help' in sys.argv:
    print('--print --output-format')
    raise SystemExit(0)
manifest = json.load(open(os.environ['PLAN_RUN_MANIFEST'], encoding='utf-8'))
lines = pathlib.Path(manifest['plan_path']).read_text(encoding='utf-8').splitlines()
start = lines.index('## 完了条件（レビュー項目）') + 1
items = []
for line in lines[start:]:
    if line.startswith('## '): break
    if line.startswith('- ['):
        items.append(line.split('] ', 1)[1])
body = '対象計画: ' + manifest['plan_path'] + ' ／ ラウンド: 01\\n\\n# 評価\\n\\n## 項目別採点\\n' + ''.join('- [PASS] ' + item + '\\n  根拠: fake CLIで実物を確認\\n' for item in items) + '\\n## 総合判定\\n全PASS\\n'
json.dump({'version':1,'task_id':manifest['task_id'],'status':'done','base_commit':manifest['base_commit'],'result_commit':manifest['base_commit'],'changed_paths':[],'tests':[],'assumptions':[],'blockers':[],'remaining_risks':[],'out_of_scope_findings':[]}, open(manifest['result_path'], 'w', encoding='utf-8'), ensure_ascii=False)
print(json.dumps({'result': body}, ensure_ascii=False))
"""

    def write_program(self, children: list[dict[str, str]]) -> Path:
        root = self.repo / "plans" / "active" / "2026-07-15-real"
        plans = root / "plans"
        plans.mkdir(parents=True)
        blocks: list[str] = []
        for item in children:
            nn = item["nn"]
            review = item.get("review", "都度")
            gate = item.get("gate", "なし")
            blocks.append(f"- [ ] {nn}  子{nn} … 実装\n    役割: 実装\n    対象repo: fixture\n    並列: 不可\n    レビュー: {review}\n    人間ゲート: {gate}\n    次: fixture\n    場所: plans/{nn}\n    依存: {item.get('dependencies', '―')}\n    参照: ―\n")
            (plans / f"{nn}-子.md").write_text(
                f"親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成\n並列: 不可 ／ レビュー: {review}\n人間ゲート: {gate}\n\n# 子{nn}\n\n## 目的\n\nfixture\n\n## 非対象\n\nなし\n\n## 現状\n\nなし\n\n## 実行契約\n\n- 対象repo: fixture\n- 実行形: delegated-single\n- 最初に読む順番: fixture\n- 依存成果: なし\n- 変更可能範囲: src/{nn}.py\n- 変更禁止範囲: なし\n- 維持する契約: なし\n- 検証: fixture\n- 停止・エスカレーション条件: blocked\n- 完了時に返す情報: result\n\n## 方針\n\nfixture\n\n## 完了条件（レビュー項目）\n\n- [ ] src/{nn}.pyが実装されている\n",
                encoding="utf-8",
            )
        program = root / "program.md"
        # 見出しは正本テンプレ（skills/plan-ops/templates/program.md）と同じ注記付き形式にする。
        program.write_text("# 合成program\n\n## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新\n\n" + "\n".join(blocks), encoding="utf-8")
        self.git("add", "plans")
        self.git("commit", "-m", "合成計画")
        return program

    def test_real_git_lifecycle_reviewer_output_and_approval_sync(self) -> None:
        program = self.write_program([
            {"nn": "01", "gate": "hook登録は承認セットへ"},
            {"nn": "02", "dependencies": "01", "review": "一括"},
        ])
        result = program_run.ProgramRunner(program, self.repo, self.repo / ".planops-state", run_id="real").run()
        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["completed"], ["01", "02"])
        self.assertEqual(set(result["integration_evaluation"]), {"01", "02"})
        self.assertTrue((program.parent / "承認セット.md").is_file())
        self.assertEqual(self.git("rev-parse", "main").strip(), self.main_before)
        self.assertEqual(self.git("branch", "--show-current").strip(), "integration")
        self.assertIn("Merge branch", self.git("log", "--merges", "--format=%s"))
        self.assertFalse((self.tmp / ".repo-planops-worktrees" / "repo" / "real-01").exists())
        self.assertFalse((self.tmp / ".repo-planops-worktrees" / "repo" / "real-02").exists())
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_real_codex_reviewer_writes_evaluation_body(self) -> None:
        program = self.write_program([{"nn": "01"}])
        result = program_run.ProgramRunner(program, self.repo, self.repo / ".planops-state", operations=program_run.Operations("codex"), run_id="codex-review").run()
        evaluation = program.parent / "評価" / "01-子-評価01.md"
        self.assertEqual(result["status"], "completed")
        self.assertIn("全PASS", evaluation.read_text(encoding="utf-8"))
        self.assertFalse((program.parent / "plans" / "評価01.md").exists())
        data = json.loads((self.repo / ".planops-state" / "codex-review-01-manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(data["program_path"], str(program.resolve()))

    def test_real_subprocess_resume_after_fail_then_pass(self) -> None:
        program = self.write_program([{"nn": "01"}])
        counter, log = self.tmp / "review-count", self.tmp / "resume-command"
        previous = {key: os.environ.get(key) for key in ("FAKE_REVIEW_SEQUENCE", "FAKE_REVIEW_COUNTER", "FAKE_RESUME_LOG")}
        os.environ.update({"FAKE_REVIEW_SEQUENCE": "FAIL,PASS", "FAKE_REVIEW_COUNTER": str(counter), "FAKE_RESUME_LOG": str(log)})
        class ObserveOperations(program_run.Operations):
            def __init__(self) -> None:
                super().__init__("codex")
                self.apply_calls = 0
            def apply(self, task: program_run.Task, review: program_run.Review, repo_root: Path) -> None:
                self.apply_calls += 1
                super().apply(task, review, repo_root)
        ops = ObserveOperations()
        try:
            result = program_run.ProgramRunner(program, self.repo, self.repo / ".planops-state", operations=ops, run_id="resume-pass").run()
        finally:
            for key, value in previous.items():
                if value is None: os.environ.pop(key, None)
                else: os.environ[key] = value
        self.assertEqual(result["status"], "completed")
        self.assertEqual(ops.apply_calls, 1)
        self.assertIn("resume: 01:1", result["events"])
        self.assertLess(result["events"].index("review: 01:FAIL"), result["events"].index("integrated: 01"))
        self.assertTrue((program.parent / "評価" / "01-子-評価01.md").is_file())
        self.assertTrue((program.parent / "評価" / "01-子-評価02.md").is_file())
        command = log.read_text(encoding="utf-8")
        self.assertIn("exec resume fake-thread-resume-pass-01", command)
        self.assertNotIn("--last", command)

    def test_real_subprocess_resume_limit_keeps_worktree_and_state(self) -> None:
        program = self.write_program([{"nn": "01"}])
        counter, log = self.tmp / "review-count", self.tmp / "resume-command"
        previous = {key: os.environ.get(key) for key in ("FAKE_REVIEW_SEQUENCE", "FAKE_REVIEW_COUNTER", "FAKE_RESUME_LOG")}
        os.environ.update({"FAKE_REVIEW_SEQUENCE": "FAIL,FAIL,FAIL", "FAKE_REVIEW_COUNTER": str(counter), "FAKE_RESUME_LOG": str(log)})
        try:
            result = program_run.ProgramRunner(program, self.repo, self.repo / ".planops-state", operations=program_run.Operations("codex"), run_id="resume-limit").run()
        finally:
            for key, value in previous.items():
                if value is None: os.environ.pop(key, None)
                else: os.environ[key] = value
        held = self.tmp / ".repo-planops-worktrees" / "repo" / "resume-limit-01"
        thread_state = self.repo / ".planops-state" / "resume-limit-01-thread.json"
        self.assertEqual(result["status"], "blocked")
        self.assertIn("上限", result["reason"])
        self.assertEqual(sum(event.startswith("resume: 01:") for event in result["events"]), 2)
        self.assertTrue(held.is_dir())
        self.assertTrue(thread_state.is_file())
        self.assertIn("fake-thread-resume-limit-01", log.read_text(encoding="utf-8"))
        self.assertNotIn("--last", log.read_text(encoding="utf-8"))

    def test_real_git_conflict_is_not_auto_resolved_and_worktree_is_retained(self) -> None:
        (self.repo / "conflict.txt").write_text("base\n", encoding="utf-8")
        self.git("add", "conflict.txt")
        self.git("commit", "-m", "conflict base")
        base = self.git("rev-parse", "HEAD").strip()
        path, branch = program_run.worktree.create_task_worktree(self.repo, self.tmp / "worktrees", "conflict", base)
        (path / "conflict.txt").write_text("worker\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(path), "add", "conflict.txt"], check=True)
        subprocess.run(["git", "-C", str(path), "commit", "-m", "worker conflict"], check=True, stdout=subprocess.DEVNULL)
        (self.repo / "conflict.txt").write_text("integration\n", encoding="utf-8")
        self.git("add", "conflict.txt")
        self.git("commit", "-m", "integration conflict")
        child = program_run.Child("01", self.repo / "plans" / "none.md", "delegated-single", "都度", ("conflict.txt",), (), None, "なし")
        task = program_run.Task(child, "conflict", base, self.repo / ".planops-state/result.json", self.repo / ".planops-state/manifest.json", path, branch)
        with self.assertRaisesRegex(program_run.ProgramRunBlocked, "自動解決しません"):
            program_run.Operations().merge(task, self.repo)
        self.assertTrue(path.exists())
        self.assertEqual(self.git("rev-parse", "main").strip(), self.main_before)

    def test_real_git_bulk_review_holds_worktrees_until_review(self) -> None:
        program = self.write_program([{"nn": "01", "review": "一括"}, {"nn": "02", "review": "一括"}])
        expected = self.tmp / ".repo-planops-worktrees" / "repo"
        outer = self
        class InspectOperations(program_run.Operations):
            def __init__(self) -> None:
                super().__init__()
                self.checked = False
            def review(self, task: program_run.Task, repo_root: Path, state_dir: Path) -> program_run.Review:
                if not self.checked:
                    outer.assertTrue((expected / "bulk-01").is_dir())
                    outer.assertTrue((expected / "bulk-02").is_dir())
                    self.checked = True
                return super().review(task, repo_root, state_dir)
        ops = InspectOperations()
        result = program_run.ProgramRunner(program, self.repo, self.repo / ".planops-state", operations=ops, run_id="bulk").run()
        self.assertEqual(result["status"], "completed")
        self.assertTrue(ops.checked)
        self.assertFalse((expected / "bulk-01").exists())
        self.assertFalse((expected / "bulk-02").exists())


if __name__ == "__main__":
    unittest.main()
