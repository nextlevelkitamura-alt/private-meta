#!/usr/bin/env python3
"""plan-ops / plan-lint の読み取り専用コア。"""
import argparse
import os
import re
import sys
from pathlib import Path

from _planops_map import find_blocks, find_field_line, find_section, read_lines
import bucketctl_core

PLAN_SECTIONS = ["目的", "非対象", "現状", "実行契約", "方針", "完了条件"]
CONTRACT_FIELDS = [
    "対象repo:", "実行形:", "最初に読む順番:", "依存成果:",
    "変更可能範囲:", "変更禁止範囲:", "維持する契約:", "検証:",
    "停止・エスカレーション条件:", "完了時に返す情報:",
]
PROGRAM_SECTIONS = ["目的", "非対象", "正本境界", "全体像・実行Wave", "子計画マップ", "人間ゲート", "完了条件", "終了記録"]
MAP_FIELDS = ["役割:", "対象repo:", "並列:", "レビュー:", "人間ゲート:", "次:", "場所:", "依存:", "参照:"]
PLACEHOLDER_RE = re.compile(r"<[^>]+>")


def field_value(lines, section, label):
    if section is None:
        return None
    _, start, end = section
    for idx in range(start, end):
        stripped = lines[idx].lstrip(" \t").removeprefix("- ")
        pos = stripped.find(label)
        if pos >= 0:
            value = stripped[pos + len(label):].strip()
            return value.split(" ／", 1)[0].strip(), idx + 1
    return None


def report(path, line, message, out):
    out.append(f"{path}:{line}: {message}")


def parse_top_field(lines, label):
    for idx, line in enumerate(lines[:8]):
        if label in line:
            return line.split(label, 1)[1].split("／", 1)[0].strip(), idx + 1
    return None


def lint_plan(path, lines, allow_placeholders, out):
    for heading in PLAN_SECTIONS:
        if find_section(lines, heading) is None:
            report(path, 1, f"必須セクションが無い: ## {heading}", out)

    contract = find_section(lines, "実行契約")
    if contract is not None:
        for label in CONTRACT_FIELDS:
            found = field_value(lines, contract, label)
            if found is None:
                report(path, contract[0] + 1, f"実行契約の必須項目が無い: {label}", out)
        for label in ("変更可能範囲:", "変更禁止範囲:", "対象repo:"):
            found = field_value(lines, contract, label)
            if found is not None and not found[0]:
                report(path, found[1], f"{label} が空（理由または値を記載）", out)
        execution = field_value(lines, contract, "実行形:")
        if execution is not None and execution[0] == "delegated-parallel":
            for label in ("ファイル担当マップ:", "worktree方針:"):
                found = field_value(lines, contract, label)
                if found is None or not found[0] or PLACEHOLDER_RE.search(found[0]):
                    report(path, execution[1], f"delegated-parallelには{label}が必須", out)

    completion = find_section(lines, "完了条件")
    if completion is not None:
        _, start, end = completion
        if not any(re.match(r"\s*- \[[ x]\]", lines[idx]) for idx in range(start, end)):
            report(path, completion[0] + 1, "完了条件が1件以上必要", out)

    if not allow_placeholders:
        for idx, line in enumerate(lines, 1):
            if PLACEHOLDER_RE.search(line):
                report(path, idx, "placeholderが残っている", out)
    if Path(path).parent.parent.name == "archive":
        for error in bucketctl_core.archive_errors(Path(path).parent):
            report(path, 1, f"archive lint: {error}", out)


def map_value(lines, block, label):
    for idx in range(block.start + 1, block.end):
        stripped = lines[idx].lstrip(" \t")
        pos = stripped.find(label)
        if pos >= 0:
            value = stripped[pos + len(label):].strip()
            return value.split(" ／", 1)[0].strip(), idx + 1
    return None


def lint_program(path, lines, allow_placeholders, out):
    for heading in PROGRAM_SECTIONS:
        if find_section(lines, heading) is None:
            report(path, 1, f"必須セクションが無い: ## {heading}", out)
    section = find_section(lines, "子計画マップ")
    if section is None:
        return
    _, start, end = section
    blocks = find_blocks(lines, start, end)
    if not blocks:
        report(path, section[0] + 1, "子計画マップに子ブロックが無い", out)
    for block in blocks:
        for label in MAP_FIELDS:
            if map_value(lines, block, label) is None:
                report(path, block.start + 1, f"NN={block.nn} マップ必須行が無い: {label}", out)
        location = map_value(lines, block, "場所:")
        if location is None:
            continue
        rel = location[0].split("／", 1)[0].strip()
        if not rel.startswith("plans/"):
            continue
        child = os.path.join(os.path.dirname(path), rel)
        if re.match(r"^plans/\d{2}$", rel):
            candidates = [x for x in os.listdir(os.path.join(os.path.dirname(path), "plans"))] if os.path.isdir(os.path.join(os.path.dirname(path), "plans")) else []
            matches = [x for x in candidates if x.startswith(f"{block.nn}-") and x.endswith(".md")]
            child = os.path.join(os.path.dirname(path), "plans", matches[0]) if len(matches) == 1 else None
        if not child or not os.path.isfile(child):
            continue
        child_lines = read_lines(child)
        lint_child_mapping(path, lines, block, child, child_lines, out)
    if not allow_placeholders:
        for idx, line in enumerate(lines, 1):
            if PLACEHOLDER_RE.search(line):
                report(path, idx, "placeholderが残っている", out)


def lint_child_mapping(program, program_lines, block, child, child_lines, out):
    first = child_lines[0] if child_lines else ""
    match = re.search(r"親計画:\s*([^\s／]+)", first)
    if not match:
        report(child, 1, "親計画backlinkが無い", out)
        return
    raw = match.group(1)
    target = raw if os.path.isabs(raw) else os.path.normpath(os.path.join(os.path.dirname(child), raw))
    if os.path.realpath(target) != os.path.realpath(program):
        report(child, 1, "親計画backlinkが対象program.mdと不一致", out)
    for label in ("並列:", "レビュー:", "人間ゲート:"):
        parent = map_value(program_lines, block, label)
        child_value = parse_top_field(child_lines, label)
        if parent is not None and child_value is not None and parent[0].split("／", 1)[0].strip() != child_value[0]:
            report(child, child_value[1], f"Programマップと子frontmatterが不一致: {label}", out)


def find_child_block(program, program_lines, child):
    section = find_section(program_lines, "子計画マップ")
    if section is None:
        return None
    _, start, end = section
    for block in find_blocks(program_lines, start, end):
        location = map_value(program_lines, block, "場所:")
        if location is None:
            continue
        rel = location[0]
        if re.match(r"^plans/\d{2}$", rel):
            directory = os.path.join(os.path.dirname(program), "plans")
            if os.path.basename(child).startswith(f"{block.nn}-") and os.path.dirname(child) == directory:
                return block
            continue
        candidate = os.path.normpath(os.path.join(os.path.dirname(program), rel))
        if os.path.realpath(candidate) == os.path.realpath(child):
            return block
    return None


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("path")
    ap.add_argument("--allow-placeholders", action="store_true")
    args = ap.parse_args()
    path = os.path.abspath(args.path)
    lines = read_lines(path)
    out = []
    is_program = any("形態: program" in line for line in lines[:4]) or os.path.basename(path) == "program.md"
    if is_program:
        lint_program(path, lines, args.allow_placeholders, out)
    else:
        lint_plan(path, lines, args.allow_placeholders, out)
        if lines and lines[0].startswith("親計画:"):
            match = re.search(r"親計画:\s*([^\s／]+)", lines[0])
            if not match:
                report(path, 1, "親計画backlinkが無い", out)
            else:
                target = match.group(1)
                target = target if os.path.isabs(target) else os.path.normpath(os.path.join(os.path.dirname(path), target))
                if not os.path.isfile(target):
                    report(path, 1, "親計画backlinkが解決しない", out)
                elif os.path.basename(target) != "program.md":
                    report(path, 1, "親計画backlinkがprogram.mdではない", out)
                elif not args.allow_placeholders:
                    parent_lines = read_lines(target)
                    block = find_child_block(target, parent_lines, path)
                    if block is None:
                        report(path, 1, "親program.mdの子計画マップにこの子の場所が無い", out)
                    else:
                        lint_child_mapping(target, parent_lines, block, path, lines, out)
    if out:
        print("\n".join(out))
        print(f"── 違反 {len(out)} 件（{path}）")
        raise SystemExit(1)
    print(f"違反なし（{path}）")


if __name__ == "__main__":
    main()
