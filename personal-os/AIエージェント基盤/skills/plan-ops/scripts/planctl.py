#!/usr/bin/env python3
"""plan-ops の明示path専用 façade。

planctl は状態を保存しない。計画の状態はバケット、実行時の短命な情報だけを
gitignore 配下の manifest に置く。
"""
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date, datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from _planops_map import find_blocks, find_section, read_lines
import bucketctl_core

PHASES = {"running", "implemented", "review_passed", "synced", "closed", "blocked"}
STATUSES = {"done", "blocked", "partial", "failed"}
REQUIRED_RESULT = {"version", "task_id", "status", "base_commit", "result_commit", "changed_paths", "tests", "assumptions", "blockers", "remaining_risks", "out_of_scope_findings"}


def fail(message, code=1):
    print(f"planctl: {message}", file=sys.stderr)
    raise SystemExit(code)


def load_json(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"JSONを読めない: {path}: {exc}")
    return value


def validate_result(path):
    value = load_json(path)
    missing = REQUIRED_RESULT - set(value)
    if missing:
        fail("result packetの必須項目が無い: " + ", ".join(sorted(missing)))
    if value.get("version") != 1 or value.get("status") not in STATUSES:
        fail("result packetのversionまたはstatusが不正")
    if not isinstance(value.get("changed_paths"), list) or not isinstance(value.get("tests"), list):
        fail("result packetのchanged_paths/testsは配列が必要")
    for test in value["tests"]:
        if not isinstance(test, dict) or not {"command", "status", "summary"} <= set(test):
            fail("result packetのtests要素が不正")
        if test["status"] not in {"passed", "failed", "skipped", "not_run"}:
            fail("result packetのtests.statusが不正")
        if test["status"] == "passed" and (not test["command"].strip() or not test["summary"].strip()):
            fail("未実行テストをpassedにできません（command/summary必須）")
    return value


def section_checks(lines):
    section = find_section(lines, "完了条件")
    if not section:
        fail("完了条件セクションが無い")
    _, start, end = section
    result = []
    for idx in range(start, end):
        m = re.match(r"^(\s*- \[)([ x])(\]\s*)(.+?)(\n?)$", lines[idx])
        if m:
            result.append((idx, m.group(4).strip(), m.group(2)))
    if not result:
        fail("完了条件のチェック項目が無い")
    return result


def parse_evaluation(path, plan):
    text = Path(path).read_text(encoding="utf-8")
    target = re.search(r"^対象計画:\s*([^／\n]+)", text, re.M)
    if not target:
        fail("評価MDに対象計画: が無い")
    raw = target.group(1).strip()
    expected = Path(plan).resolve()
    candidate = (Path(path).parent / raw).resolve() if not os.path.isabs(raw) else Path(raw).resolve()
    if candidate != expected and raw not in {expected.name, str(expected)}:
        fail("評価MDの対象計画が一致しない")
    entries = re.findall(r"^\s*- \[(PASS|FAIL|対象外)\]\s+(.+?)\s*$", text, re.M)
    if not entries:
        fail("評価MDに項目別採点が無い")
    checks = [item for _, item, _ in section_checks(read_lines(plan))]
    if len(entries) != len(checks):
        fail("評価項目数が完了条件と一致しない")
    for (status, wording), required in zip(entries, checks):
        if status != "PASS":
            fail(f"評価が全PASSではない: {status} {wording}")
        if wording != required:
            fail("評価項目の文言が完了条件と完全一致しない")
    if "全PASS" not in text:
        fail("評価MDの総合判定が全PASSではない")
    return entries


def manifest(path):
    value = load_json(path)
    if value.get("phase") not in PHASES:
        fail("manifest phaseが不正")
    return value


def write_manifest(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def git_commit_exists(root, sha):
    return bool(sha) and subprocess.run(["git", "-C", str(root), "cat-file", "-e", f"{sha}^{{commit}}"], capture_output=True).returncode == 0


def program_context(plan):
    plan = Path(plan).resolve()
    if plan.name == "program.md":
        return plan, None
    lines = read_lines(plan)
    if not lines or not lines[0].startswith("親計画:"):
        return None, None
    raw = lines[0].split("親計画:", 1)[1].split("／", 1)[0].strip()
    program = (plan.parent / raw).resolve()
    if not program.is_file():
        fail("親計画backlinkが解決しない")
    nn = re.match(r"(\d{2})-", plan.name)
    if not nn:
        fail("Program子のファイル名に子番号が無い")
    return program, nn.group(1)


def map_update(program, nn, state, ref):
    lines = read_lines(program)
    sec = find_section(lines, "子計画マップ")
    if not sec:
        fail("親programに子計画マップが無い")
    _, start, end = sec
    block = next((b for b in find_blocks(lines, start, end) if b.nn == nn), None)
    if not block:
        fail("親programの子番号が一致しない")
    header = lines[block.start]
    if " … " not in header:
        fail("親programマップの状態区切りが無い")
    prefix = header.split(" … ", 1)[0]
    prefix = re.sub(r"^- \[[ x]\]", "- [x]" if state == "完了" else "- [ ]", prefix)
    lines[block.start] = prefix + " … " + state + "\n"
    for i in range(block.start + 1, block.end):
        if lines[i].lstrip().startswith("参照:"):
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            lines[i] = f"{indent}参照: {ref}\n"
            break
    else:
        lines.insert(block.end, f"    参照: {ref}\n")
    Path(program).write_text("".join(lines), encoding="utf-8")


def append_result(plan, result, evaluation):
    target = Path(plan)
    text = target.read_text(encoding="utf-8")
    entry = f"- result: {result['result_commit']} ／ 評価: {Path(evaluation).name}\n"
    heading = "## 実装結果"
    if heading not in text:
        text = text.rstrip() + f"\n\n{heading}\n{entry}"
    elif entry not in text:
        pos = text.index(heading) + len(heading)
        text = text[:pos] + "\n" + entry + text[pos:]
    target.write_text(text + ("" if text.endswith("\n") else "\n"), encoding="utf-8")


def record_major_update(plan):
    """rename --check 用の計画メタデータ。mtimeや別台帳には依存しない。"""
    target = Path(plan)
    lines = read_lines(target)
    value = date.today().isoformat()
    for i, line in enumerate(lines[:12]):
        if line.startswith("大幅更新日:"):
            lines[i] = f"大幅更新日: {value}\n"
            break
    else:
        insert = 1 if lines and lines[0].startswith("親計画:") else 1
        lines.insert(insert, f"大幅更新日: {value}\n")
    target.write_text("".join(lines), encoding="utf-8")


def cmd_prepare(args):
    plan = Path(args.plan).resolve()
    if not plan.is_file(): fail("--plan が見つからない")
    root = Path(args.repo_root).resolve()
    state = Path(args.state_dir or root / ".planops-state").resolve()
    # stateを追跡対象へ置かない。既存gitignoreに明示的な除外が無い場合は安全に停止する。
    ignored = subprocess.run(["git", "-C", str(root), "check-ignore", "-q", str(state)], capture_output=True).returncode == 0
    if not ignored:
        fail("state-dirはgitignore配下で指定してください")
    state.mkdir(parents=True, exist_ok=True)
    program, child = program_context(plan)
    result_path = state / f"{args.task_id}-result.json"
    manifest_path = state / f"{args.task_id}-manifest.json"
    packet_path = state / f"{args.task_id}-実行指示.md"
    data = {"version": 1, "task_id": args.task_id, "role": args.role, "runtime": args.runtime, "repo_root": str(root), "plan_path": str(plan), "program_path": str(program) if program else None, "child_id": child, "base_commit": args.base_commit, "worktree_path": args.worktree_path, "branch": args.branch, "result_path": str(result_path), "evaluation_path": None, "phase": "running"}
    write_manifest(manifest_path, data)
    packet_path.write_text(f"# 実行指示\n\n- Task ID: {args.task_id}\n- 対象計画: {plan}\n- manifest: {manifest_path}\n- result packet: {result_path}\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest_path), "task_packet": str(packet_path)}, ensure_ascii=False))


def cmd_progress(args):
    program = Path(args.program).resolve()
    before = program.read_bytes()
    command = [sys.executable, str(HERE / "progctl_core.py"), "--program", str(program), "--nn", args.nn]
    if args.state is not None: command += ["--state", args.state]
    if args.next is not None: command += ["--next", args.next]
    if args.ref is not None: command += ["--ref", args.ref]
    after = subprocess.run(command, capture_output=True, text=True)
    if after.returncode: fail(after.stderr.strip())
    if args.apply:
        program.write_text(after.stdout, encoding="utf-8")
        record_major_update(program)
        print("適用済み: " + str(program))
    else:
        sys.stdout.write(after.stdout if after.stdout != before.decode("utf-8") else "変更なし（冪等）\n")


def cmd_apply_evaluation(args):
    plan = Path(args.plan).resolve(); root = Path(args.repo_root).resolve()
    result = validate_result(args.result)
    if result["status"] != "done": fail("status=done 以外は同期できません")
    if not git_commit_exists(root, result["result_commit"]): fail("result commitが実在しない")
    if any(Path(p).is_absolute() or p.startswith("../") for p in result["changed_paths"]): fail("禁止範囲違反: changed_pathsがrepo相対pathではない")
    parse_evaluation(args.evaluation, plan)
    program, nn = program_context(plan)
    lines = read_lines(plan)
    for idx, _, _ in section_checks(lines): lines[idx] = lines[idx].replace("[ ]", "[x]", 1)
    plan.write_text("".join(lines), encoding="utf-8")
    append_result(plan, result, args.evaluation)
    record_major_update(plan)
    if program:
        map_update(program, nn, "完了", f"{root.name}@{result['result_commit']}")
    lint = subprocess.run([str(HERE / "plan-lint.sh"), str(plan)], capture_output=True, text=True)
    if lint.returncode: fail("同期後lint失敗: " + lint.stdout.strip())
    if args.manifest:
        data = manifest(args.manifest); data["evaluation_path"] = str(Path(args.evaluation).resolve()); data["phase"] = "synced"; write_manifest(args.manifest, data)
    print(json.dumps({"synced": str(plan), "result_commit": result["result_commit"]}, ensure_ascii=False))


def cmd_close(args):
    plan = Path(args.plan).resolve()
    directory = plan.parent
    record = directory / "終了記録.md"
    if not record.is_file() and args.apply:
        now = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M %Z")
        record.write_text(f"# 終了記録\n\n- 終了区分: {args.disposition}\n- 終了日時: {now}\n- 人間確認: {args.human_confirmation}\n- 理由: {args.reason}\n- 後継・統合先: {args.successor}\n- 実装済み範囲: {args.implemented_scope}\n- 未完了事項: {args.remaining}\n- レビュー・判断根拠: {args.evidence}\n- 関連commit/評価: {args.references}\n", encoding="utf-8")
    if args.apply:
        move_args = argparse.Namespace(command="move", source=str(directory), to="archive", apply=True, commit=False)
        bucketctl_core.move(move_args)
    else:
        print(f"── dry-run\n終了記録を生成予定: {record}\n--applyで終了記録を作成しbucketctl経由でarchiveへ移動")


def cmd_sync_check(args):
    plan = Path(args.plan).resolve(); directory = plan.parent
    problems = []
    result = None
    if args.result:
        try: result = validate_result(args.result)
        except SystemExit: problems.append("result packetが不正")
    if args.evaluation:
        try: parse_evaluation(args.evaluation, plan)
        except SystemExit: problems.append("評価MDが同期条件を満たさない")
    try:
        source, plans, bucket = bucketctl_core.infer(directory)
        if bucket == "archive": problems.extend(bucketctl_core.archive_errors(directory))
    except SystemExit: problems.append("計画が有効なバケットに無い")
    program, nn = program_context(plan)
    if program and nn:
        text = program.read_text(encoding="utf-8")
        if not re.search(rf"^- \[x\] {nn}\s.* … 完了", text, re.M) and all(mark == "x" for _, _, mark in section_checks(read_lines(plan))):
            problems.append("Programマップ未同期")
    output = {"ok": not problems, "plan": str(plan), "problems": problems, "result_commit": result.get("result_commit") if result else None}
    print(json.dumps(output, ensure_ascii=False))
    raise SystemExit(0 if not problems else 1)


def cmd_rename(args):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", args.date):
        fail("--date は YYYY-MM-DD 形式で指定してください", 2)
    plan = Path(args.plan).resolve(); folder = plan.parent
    m = re.match(r"\d{4}-\d{2}-\d{2}-(.+)", folder.name)
    if not m: fail("計画フォルダ名が YYYY-MM-DD-名前 形式ではない")
    new_name = f"{args.date}-{m.group(1)}"; target = folder.with_name(new_name)
    if args.check:
        latest = None
        for line in read_lines(plan)[:12]:
            if line.startswith("大幅更新日:"):
                latest = line.split(":", 1)[1].strip()
                break
        print(json.dumps({"rename_required": bool(latest and latest != folder.name[:10]), "folder_date": folder.name[:10], "latest_major_update": latest}, ensure_ascii=False)); return
    if target.exists(): fail("rename先が既に存在する")
    if not args.apply:
        print(f"── dry-run\ngit mv -- {folder} {target}"); return
    root = subprocess.run(["git", "-C", str(folder), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if root.returncode: fail("対象repoが見つからない")
    repo = Path(root.stdout.strip()); old = folder.name
    subprocess.run(["git", "-C", str(repo), "mv", "--", os.path.relpath(folder, repo), os.path.relpath(target, repo)], check=True)
    for p in repo.rglob("*.md"):
        if ".git" in p.parts: continue
        text = p.read_text(encoding="utf-8")
        if old in text: p.write_text(text.replace(old, new_name), encoding="utf-8")
    print(f"適用済み: {target}")


def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="command", required=True)
    p = sub.add_parser("prepare"); p.add_argument("--plan", required=True); p.add_argument("--task-id", required=True); p.add_argument("--role", required=True, choices=["explorer","implementer","reviewer"]); p.add_argument("--runtime", required=True); p.add_argument("--repo-root", required=True); p.add_argument("--base-commit", required=True); p.add_argument("--worktree-path", required=True); p.add_argument("--branch", required=True); p.add_argument("--state-dir")
    p = sub.add_parser("progress"); p.add_argument("--program", required=True); p.add_argument("--nn", required=True); p.add_argument("--state"); p.add_argument("--next"); p.add_argument("--ref"); p.add_argument("--apply", action="store_true")
    p = sub.add_parser("apply-evaluation"); p.add_argument("--plan", required=True); p.add_argument("--evaluation", required=True); p.add_argument("--result", required=True); p.add_argument("--repo-root", required=True); p.add_argument("--manifest")
    p = sub.add_parser("close"); p.add_argument("--plan", required=True); p.add_argument("--disposition", required=True, choices=sorted(bucketctl_core.DISPOSITIONS)); p.add_argument("--human-confirmation", required=True); p.add_argument("--reason", required=True); p.add_argument("--successor", default="該当なし"); p.add_argument("--implemented-scope", default="該当なし"); p.add_argument("--remaining", default="なし"); p.add_argument("--evidence", default="該当なし"); p.add_argument("--references", default="該当なし"); p.add_argument("--apply", action="store_true")
    p = sub.add_parser("sync-check"); p.add_argument("--plan", required=True); p.add_argument("--result"); p.add_argument("--evaluation")
    p = sub.add_parser("rename"); p.add_argument("--plan", required=True); p.add_argument("--date", required=True); p.add_argument("--check", action="store_true"); p.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    {"prepare": cmd_prepare, "progress": cmd_progress, "apply-evaluation": cmd_apply_evaluation, "close": cmd_close, "sync-check": cmd_sync_check, "rename": cmd_rename}[args.command](args)

if __name__ == "__main__": main()
