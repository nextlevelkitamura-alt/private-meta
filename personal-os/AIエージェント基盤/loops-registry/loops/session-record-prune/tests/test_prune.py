#!/usr/bin/env python3
# session-record-prune のテスト（env差し替え・実運用に非接触）。
# フック言語規約: ロジックの検証は Python で prune.py を import して直接テストする。
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import prune  # noqa: E402

PASS = 0
FAIL = 0


def ok(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"PASS: {name}")
    else:
        FAIL += 1
        print(f"FAIL: {name}")


def touch(path, age_days):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("x")                       # 中身は使わない（サイズ1）
    t = time.time() - age_days * 86400
    os.utime(path, (t, t))


def main():
    now = time.time()
    with tempfile.TemporaryDirectory() as tmp:
        codex = os.path.join(tmp, "codex")
        claude = os.path.join(tmp, "claude")
        outside = os.path.join(tmp, "outside")   # 対象外ディレクトリ
        trash = os.path.join(tmp, "trash")
        targets = [codex, claude]

        touch(os.path.join(codex, "old.jsonl"), 40)          # 消える
        touch(os.path.join(codex, "sub", "old2.jsonl"), 31)  # 再帰・消える
        touch(os.path.join(codex, "fresh.jsonl"), 5)         # 残る（新しい）
        touch(os.path.join(codex, "boundary.jsonl"), 30)     # ちょうど30日＝残る（strict）
        touch(os.path.join(codex, "note.txt"), 99)           # .jsonl でない＝残る
        touch(os.path.join(claude, "old3.jsonl"), 60)        # 消える
        touch(os.path.join(outside, "old4.jsonl"), 99)       # 対象外＝残る

        old = prune.find_old(now, 30, targets)
        names = sorted(os.path.basename(f) for f, _ in old)
        ok("30日超の.jsonlだけ検出", names == ["old.jsonl", "old2.jsonl", "old3.jsonl"])
        ok("新しいファイルは対象外", "fresh.jsonl" not in names)
        ok("ちょうど30日は残す(strict)", "boundary.jsonl" not in names)
        ok(".jsonl以外は対象外", "note.txt" not in names)
        ok("対象2ディレクトリ外は検出しない", "old4.jsonl" not in names)

        # dry-run 相当（find_old のみ・move しない）＝ファイルはそのまま
        ok("dry-runでは何も動かない(old.jsonl残存)",
           os.path.exists(os.path.join(codex, "old.jsonl")))

        # apply 相当: move_to_trash
        for f, _ in old:
            prune.move_to_trash(f, trash)
        ok("古いものはTrashへ移動された",
           not os.path.exists(os.path.join(codex, "old.jsonl"))
           and os.path.exists(os.path.join(trash, "old.jsonl")))
        ok("新しいものは残る", os.path.exists(os.path.join(codex, "fresh.jsonl")))
        ok("対象外ディレクトリのファイルは無傷",
           os.path.exists(os.path.join(outside, "old4.jsonl")))

        # 名前衝突: 同名を2つ移すと連番が付く
        touch(os.path.join(codex, "dup.jsonl"), 40)
        prune.move_to_trash(os.path.join(codex, "dup.jsonl"), trash)
        touch(os.path.join(claude, "dup.jsonl"), 40)
        d2 = prune.move_to_trash(os.path.join(claude, "dup.jsonl"), trash)
        ok("同名衝突は連番付与", os.path.basename(d2) == "dup-1.jsonl")

        # symlink 逃げ: 対象dir内に外部へのsymlinkがあっても realpath 判定で対象外
        ext = os.path.join(tmp, "ext_real.jsonl")
        touch(ext, 99)
        link = os.path.join(codex, "escape.jsonl")
        os.symlink(ext, link)
        old2 = prune.find_old(now, 30, targets)
        ok("symlinkで外へ逃げる実体は対象外",
           all("escape.jsonl" not in os.path.basename(f) for f, _ in old2))

    print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
