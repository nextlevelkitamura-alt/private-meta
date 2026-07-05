#!/usr/bin/env python3
"""plan-ops / progctl の書換コア。program.md の子計画マップから対象NNブロックだけを
冪等に書き換え、結果全文をstdoutへ出す（書き込みはしない・呼び出し元のprogctl.shが担当）。

マップ外・他ブロックは元の行オブジェクトをそのまま連結するため、バイト不変が保証される。
"""
import argparse
import sys

from _planops_map import (
    read_lines, find_section, find_blocks, get_state, find_field_line, SEP,
)

MAP_HEADING = "子計画マップ"
DEFAULT_INDENT = "    "


def fail(msg):
    print(f"progctl: {msg}", file=sys.stderr)
    sys.exit(1)


def rebuild_field_line(line, label, new_value):
    indent = line[: len(line) - len(line.lstrip(" \t"))]
    ending = "\n" if line.endswith("\n") else ""
    return f"{indent}{label} {new_value}{ending}"


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--program", required=True)
    ap.add_argument("--nn", required=True)
    ap.add_argument("--state")
    ap.add_argument("--next", dest="next_")
    ap.add_argument("--ref")
    args = ap.parse_args()

    have_state = args.state is not None
    have_next = args.next_ is not None
    have_ref = args.ref is not None

    try:
        lines = read_lines(args.program)
    except OSError as e:
        fail(f"program.mdが読めない: {e}")
        return

    section = find_section(lines, MAP_HEADING)
    if section is None:
        fail(f"「## {MAP_HEADING}」見出しが見つからない: {args.program}")
        return
    _, body_start, body_end = section

    blocks = find_blocks(lines, body_start, body_end)
    target = next((b for b in blocks if b.nn == args.nn), None)
    if target is None:
        fail(f"NN={args.nn} のブロックが子計画マップに無い: {args.program}")
        return

    block_lines = lines[target.start: target.end][:]  # コピー（元のlinesは変更しない）

    header = block_lines[0]
    if have_state:
        idx = header.find(SEP)
        if idx < 0:
            fail(
                f"NN={args.nn} の見出し行に区切り「 … 」が見つからない"
                "（--stateで書換不可な形式）"
            )
            return
        ending = "\n" if header.endswith("\n") else ""
        header = header[: idx + len(SEP)] + args.state + ending
    block_lines[0] = header

    def ensure_field(label, new_value):
        nonlocal block_lines
        idx = find_field_line(lines, target, label + ":")
        # find_field_line は元のlines基準のindexを返すため、block内相対indexへ変換
        rel_idx = (idx - target.start) if idx is not None else None
        if rel_idx is not None:
            block_lines[rel_idx] = rebuild_field_line(block_lines[rel_idx], f"{label}:", new_value)
            return
        # 無ければ「場所:」行の直前に挿入。場所:も無ければブロック末尾に追加。
        basho_rel = None
        for i in range(1, len(block_lines)):
            stripped = block_lines[i].lstrip(" \t")
            if stripped.startswith("場所:"):
                basho_rel = i
                break
        new_line = f"{DEFAULT_INDENT}{label}: {new_value}\n"
        insert_at = basho_rel if basho_rel is not None else len(block_lines)
        block_lines.insert(insert_at, new_line)

    if have_next:
        ensure_field("次", args.next_)
    if have_ref:
        ensure_field("参照", args.ref)

    out_lines = lines[: target.start] + block_lines + lines[target.end:]
    sys.stdout.write("".join(out_lines))


if __name__ == "__main__":
    main()
