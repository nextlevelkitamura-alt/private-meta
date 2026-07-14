#!/usr/bin/env python3
"""plan-ops / program-lint の静的整合チェックコア。

program.md の「子計画マップ」を静的に検査し、違反を `<file>:<行>: <メッセージ>` 形式で
stdoutへ出す（違反1件以上で非0 exit）。ライブなレーン状態（cockpit/watch.sh）は見ない。

検査6種:
  1. 「子計画マップ」に子計画ブロックが1件以上あること（パーサの形式不追従による
     0件検出を「違反なし」と誤合格させない）。
  2. マップNN ↔ plans/NN-*.md 実ファイルの実在（「場所:」が plans/ を指す場合のみ。
     卒業先・program.md内セクション参照など plans/ 以外を指す場合は対象外）。
  3. 見出し行のNNと「場所: plans/NN」のNNが一致しているか（コピペミスで別NNの子を指す事故を検出）。
  4. 実在する子ファイルのfrontmatter「親計画:」backlinkが対象program.mdへ解決するか。
  5. 見出し行の状態語彙（GLOBAL_AGENTS.md §7の段階語彙 ＋ 実運用のマップ状態語 との完全一致・
     括弧注記「実装中（...）」の「（...）」部分だけは付帯説明として許容し先頭トークンで判定）。
  6. 状態が「完了」の子について、その子ファイル自身の
     「## 完了条件（レビュー項目）」に未チェック（`- [ ]`）が残っていないか。
"""
import glob
import os
import re
import sys

from _planops_map import (
    read_lines, find_section, find_blocks, get_state, find_field_line, checkbox_mark,
)

MAP_HEADING = "子計画マップ"
COMPLETION_HEADING = "完了条件"

# 状態語彙の正本: GLOBAL_AGENTS.md §7 の段階語彙（企画/計画/計画レビュー/実装/実装レビュー/修正/人間確認/完了）
# ＋ 実運用のマップ状態語（完了/実装中/計画レビュー待ち/保留 等）。完全一致で判定する
# （前方一致だと「実装破綻」のような誤記が「実装」にマッチして通ってしまうため）。
STATE_VOCAB = {
    "企画", "計画", "計画レビュー", "実装", "実装レビュー", "修正", "人間確認", "完了",
    "実装中", "計画レビュー待ち", "保留",
}


def state_base(state_text):
    """状態文言から先頭の括弧注記より前だけを取り出す（例: '完了（マージ99a9d64）' → '完了'）。"""
    m = re.search(r"[（(]", state_text)
    return (state_text[: m.start()] if m else state_text).strip()


def resolve_child_path(base_dir, path_part):
    """'plans/07' 短縮形 → glob解決 / 'plans/07-x.md' 直接形 → 実在チェック。見つからなければNone。"""
    m = re.match(r"^plans/(\d{2})$", path_part)
    if m:
        candidates = sorted(glob.glob(os.path.join(base_dir, "plans", f"{m.group(1)}-*.md")))
        return candidates[0] if candidates else None
    p = os.path.join(base_dir, path_part)
    return p if os.path.isfile(p) else None


def check_backlink(child_path, program_path, out):
    lines = read_lines(child_path)
    if not lines:
        out.append(f"{child_path}:1: 子ファイルが空")
        return
    m = re.search(r"親計画:\s*([^\s／]+)", lines[0])
    if not m:
        out.append(f"{child_path}:1: 「親計画:」フィールドが無い")
        return
    raw = m.group(1)
    child_dir = os.path.dirname(child_path)
    resolved = raw if os.path.isabs(raw) else os.path.normpath(os.path.join(child_dir, raw))
    if not os.path.isfile(resolved):
        out.append(f"{child_path}:1: 親計画backlinkが解決しない: {raw}")
        return
    if os.path.realpath(resolved) != os.path.realpath(program_path):
        out.append(f"{child_path}:1: 親計画backlinkが対象program.mdと不一致: {raw}")


def check_completion_checked(child_path, out):
    lines = read_lines(child_path)
    section = find_section(lines, COMPLETION_HEADING)
    if section is None:
        out.append(f"{child_path}:1: 「## {COMPLETION_HEADING}」セクションが無い")
        return
    _, body_start, body_end = section
    for i in range(body_start, body_end):
        if re.match(r"^- \[ \]", lines[i]):
            out.append(f"{child_path}:{i + 1}: 「完了」なのに完了条件が未チェック")


def lint(program_path):
    base_dir = os.path.dirname(program_path)
    lines = read_lines(program_path)
    out = []

    section = find_section(lines, MAP_HEADING)
    if section is None:
        return [f"{program_path}:1: 「## {MAP_HEADING}」見出しが見つからない"]
    _, body_start, body_end = section
    blocks = find_blocks(lines, body_start, body_end)
    if not blocks:
        return [f"{program_path}:{body_start}: 「{MAP_HEADING}」に子計画ブロックが無い"]

    for b in blocks:
        header_line_no = b.start + 1
        state = get_state(lines[b.start])
        if state is None:
            out.append(f"{program_path}:{header_line_no}: NN={b.nn} 見出し行に区切り「 … 」が無い")
            continue

        base = state_base(state)
        if base not in STATE_VOCAB:
            out.append(f"{program_path}:{header_line_no}: NN={b.nn} 状態語彙に無い状態: 「{base}」")

        mark = checkbox_mark(lines[b.start])
        if mark is not None and ((mark == "x") != (base == "完了")):
            expected = "[x]" if base == "完了" else "[ ]"
            actual = "[x]" if mark == "x" else "[ ]"
            out.append(
                f"{program_path}:{header_line_no}: NN={b.nn} チェックボックスと状態が不整合: "
                f"{actual} / {base}（期待: {expected}）"
            )

        basho_idx = find_field_line(lines, b, "場所:")
        if basho_idx is None:
            out.append(f"{program_path}:{header_line_no}: NN={b.nn} 「場所:」行が無い")
            continue
        basho_value = lines[basho_idx].lstrip(" \t")[len("場所:"):].strip()
        path_part = basho_value.split("／")[0].strip()

        if not path_part.startswith("plans/"):
            continue  # 卒業先・program.md内セクション参照など → 対象外

        nn_in_path = re.match(r"^plans/(\d{2})", path_part)
        if nn_in_path and nn_in_path.group(1) != b.nn:
            out.append(
                f"{program_path}:{basho_idx + 1}: NN={b.nn} 場所のNNが見出しと不一致: {path_part}"
            )
            continue  # 誤ったNNの子ファイルへ解決してしまうため以降のチェックは行わない

        child_path = resolve_child_path(base_dir, path_part)
        if child_path is None:
            out.append(f"{program_path}:{basho_idx + 1}: NN={b.nn} 実ファイルが無い: {path_part}")
            continue

        check_backlink(child_path, program_path, out)
        if base == "完了":
            check_completion_checked(child_path, out)

    return out


def main():
    if len(sys.argv) != 2:
        print("usage: program_lint_core.py <program.mdの絶対パス>", file=sys.stderr)
        sys.exit(2)
    program_path = os.path.abspath(sys.argv[1])
    violations = lint(program_path)
    if violations:
        print("\n".join(violations))
        print(f"── 違反 {len(violations)} 件（{program_path}）")
        sys.exit(1)
    print(f"違反なし（{program_path}）")
    sys.exit(0)


if __name__ == "__main__":
    main()
