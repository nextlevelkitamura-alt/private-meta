#!/usr/bin/env python3
"""計画バケット遷移の決定的な門番。

状態はディレクトリだけで持つ。このモジュールは状態台帳を作らず、明示された
計画ディレクトリと同階層の plans/ だけを検査する。
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

BUCKETS = ("planning", "active", "paused", "done", "archive")
LIMITS = {"planning": None, "active": 5, "paused": 3, "done": 8, "archive": None}
ALLOWED = {
    "planning": {"active", "archive"}, "active": {"paused", "done", "archive"},
    "paused": {"planning", "active", "archive"}, "done": {"active", "archive"},
    "archive": set(),
}
DISPOSITIONS = {"completed", "superseded", "merged", "conflict", "cancelled"}


def fail(message, code=1):
    print(f"bucketctl: {message}", file=sys.stderr)
    raise SystemExit(code)


def plan_file(directory):
    for name in ("plan.md", "program.md"):
        p = directory / name
        if p.is_file():
            return p
    return None


def children(bucket):
    if not bucket.is_dir():
        return []
    return sorted(p for p in bucket.iterdir() if p.is_dir() and not p.name.startswith("."))


def infer(source):
    source = Path(source).resolve()
    if not source.is_dir():
        fail(f"計画フォルダが見つからない: {source}")
    current = source.parent.name
    if current not in BUCKETS:
        fail(f"plans/<bucket>/直下の計画フォルダだけを指定してください: {source}", 2)
    plans = source.parent.parent
    return source, plans, current


def all_checked(plan):
    text = plan.read_text(encoding="utf-8")
    start = re.search(r"^## 完了条件[^\n]*$", text, re.M)
    if not start:
        return False
    following = text[start.end():]
    following = re.split(r"^## ", following, maxsplit=1, flags=re.M)[0]
    checks = re.findall(r"^\s*- \[([ x])\]", following, re.M)
    return bool(checks) and all(x == "x" for x in checks)


def evaluation_files(directory):
    """計画自身の評価md。新配置（評価/ 直下・2026-07-17分離）を優先し、無ければ旧配置（計画直下）へ
    フォールバックする。まとめ評価（複数工程・複数子を1本で採点・2026-07-22）も計画自身の評価として拾う。
    子の評価（NN-子名-評価RR.md／NN-子名-まとめ評価RR.md）は数字始まりで「評価」「まとめ評価」いずれの
    globにもマッチしないため、ここには混ざらない。"""
    folder = directory / "評価"
    if folder.is_dir():
        found = sorted(list(folder.glob("評価*.md")) + list(folder.glob("まとめ評価*.md")))
        if found:
            return found
    return sorted(list(directory.glob("評価*.md")) + list(directory.glob("まとめ評価*.md")))


def evaluation_passes(directory):
    evaluations = evaluation_files(directory)
    if not evaluations:
        return False
    text = evaluations[-1].read_text(encoding="utf-8")
    entries = re.findall(r"^\s*- \[(PASS|FAIL|対象外)\]\s+(.+)$", text, re.M)
    return bool(entries) and all(status == "PASS" for status, _ in entries) and "全PASS" in text


def closure(directory):
    path = directory / "終了記録.md"
    if not path.is_file():
        return None, ["終了記録.md が無い"]
    values = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*-\s*(終了区分|終了日時|人間確認|理由|後継・統合先|実装済み範囲|未完了事項|評価・判断根拠|関連commit/評価):\s*(.*)$", line)
        if m:
            values[m.group(1)] = m.group(2).strip()
    required = ["終了区分", "終了日時", "人間確認", "理由", "実装済み範囲", "未完了事項", "評価・判断根拠", "関連commit/評価"]
    errors = [f"終了記録の必須項目が空: {key}" for key in required if not values.get(key) or "<" in values.get(key, "")]
    if values.get("終了区分") not in DISPOSITIONS:
        errors.append("終了区分が不正")
    if values.get("終了区分") in {"superseded", "merged", "conflict"} and (not values.get("後継・統合先") or values.get("後継・統合先") == "該当なし"):
        errors.append("この終了区分には後継・統合先が必要")
    return values, errors


def archive_errors(directory):
    record, errors = closure(directory)
    if errors:
        return errors
    if record["終了区分"] == "completed":
        plan = plan_file(directory)
        if not plan or not all_checked(plan):
            errors.append("completed には全完了条件の [x] が必要")
        if not evaluation_passes(directory):
            errors.append("completed には最終評価md全PASSが必要")
        if plan and plan.name == "program.md":
            text = plan.read_text(encoding="utf-8")
            if re.search(r"^- \[ \] \d{2}\s", text, re.M):
                errors.append("completed program には全子計画の完了が必要")
    return errors


def check(plans):
    result = {"plans_root": str(plans), "buckets": {}, "ok": True}
    for bucket in BUCKETS:
        items = [p.name for p in children(plans / bucket)]
        limit = LIMITS[bucket]
        exceeded = limit is not None and len(items) > limit
        result["buckets"][bucket] = {"count": len(items), "limit": limit, "items": items, "exceeded": exceeded}
        result["ok"] = result["ok"] and not exceeded
    return result


def move(args):
    source, plans, current = infer(args.source)
    destination = args.to
    if destination not in BUCKETS:
        fail(f"不正な移動先: {destination}", 2)
    if args.command == "promote" and not (current == "planning" and destination == "active"):
        fail("plans/planning/直下の計画フォルダだけを昇格できます", 2)
    if destination not in ALLOWED[current]:
        fail(f"許可されない遷移: {current} → {destination}", 2)
    if not (plans / destination).is_dir():
        fail(f"移動先バケットが見つからない: {plans / destination}")
    target = plans / destination / source.name
    if target.exists():
        fail(f"移動先が既に存在します: {target}")
    if destination == "done" and not evaluation_passes(source):
        fail("active → done には最終評価md全PASSが必要")
    if destination == "archive":
        errs = archive_errors(source)
        if errs:
            fail("archive を拒否: " + " / ".join(errs))
        record, _ = closure(source)
        if current != "done" and record["終了区分"] == "completed":
            fail("planning/active/paused → archive は非completed終了区分だけです")
    state = check(plans)
    limit = LIMITS[destination]
    count = state["buckets"][destination]["count"]
    if limit is not None and count >= limit:
        names = ", ".join(state["buckets"][destination]["items"])
        fail(f"{destination} は上限{limit}件です（現在{count}件）。人間が整理先を選んでください。対象: {names}")
    repo = subprocess.run(["git", "-C", str(source), "rev-parse", "--show-toplevel"], capture_output=True, text=True)
    if repo.returncode:
        fail(f"対象repoが見つからない: {source}")
    root = Path(repo.stdout.strip())
    src_rel, dst_rel = os.path.relpath(source, root), os.path.relpath(target, root)
    if not args.apply and not args.commit:
        print("── dry-run")
        print(f"git -C {root} mv -- {src_rel} {dst_rel}")
        print(f"{destination}: {count}/{limit if limit is not None else '無制限'} → {count + 1}/{limit if limit is not None else '無制限'}")
        return
    if args.apply and args.commit:
        fail("--apply と --commit は同時に指定できません", 2)
    if args.commit:
        dirty = subprocess.run(["git", "-C", str(root), "status", "--porcelain", "--", src_rel], capture_output=True, text=True)
        if dirty.stdout:
            fail(f"移動元に未コミット変更があるため --commit を拒否します。先に整理するか --apply を使ってください: {src_rel}")
    subprocess.run(["git", "-C", str(root), "mv", "--", src_rel, dst_rel], check=True)
    if args.apply:
        print(f"適用済み（未コミット）: {root} ({dst_rel})")
    else:
        subprocess.run(["git", "-C", str(root), "commit", "--only", "-m", f"bucketctl: {source.name} を{destination}へ移動", "--", src_rel, dst_rel], check=True)
        print(f"commit済み: {root} ({dst_rel})")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="command", required=True)
    for name in ("promote", "move"):
        p = sub.add_parser(name)
        p.add_argument("source")
        p.add_argument("--to", required=True)
        p.add_argument("--apply", action="store_true")
        p.add_argument("--commit", action="store_true")
    c = sub.add_parser("check")
    c.add_argument("plans_root")
    c.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if args.command == "check":
        plans = Path(args.plans_root).resolve()
        if not plans.is_dir():
            fail(f"plans rootが見つからない: {plans}")
        result = check(plans)
        if args.json:
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        else:
            for name, value in result["buckets"].items():
                print(f"{name}: {value['count']}/{value['limit'] if value['limit'] is not None else '無制限'}  {', '.join(value['items'])}")
        raise SystemExit(0 if result["ok"] else 1)
    move(args)


if __name__ == "__main__":
    main()
