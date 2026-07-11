#!/usr/bin/env python3
"""common.py 注入文の判定表テスト（2026-07-11 拡張1/1b: 実装リマインド・評価NN.md文言）。
実行: python3 tests/test_common.py（session-board ディレクトリから）"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import common  # noqa: E402

PASS = FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
    else:
        FAIL += 1
        print(f"FAIL: {name}")


def mirror_lines(typ, plan):
    return common._mirror("k", {"goal": "g", "now": "n", "type": typ, "plan": plan}).split("\n")


# (a) 種別=実装・計画=? → 実装リマインド行（3条件＋評価NN.md）が出る
out = mirror_lines("実装", None)
check("(a) 実装×計画? にリマインド行", len(out) == 3 and "サクッと3条件" in out[2] and "評価NN.md" in out[2])

# (b) 種別=実装・計画=なし → 同様に出る
out = mirror_lines("実装", "なし")
check("(b) 実装×なし にリマインド行", len(out) == 3 and "計画:なし" in out[2] and "評価NN.md" in out[2])

# (c) 種別=実装・計画=実値 → リマインド行が出ない（2行のみ）
out = mirror_lines("実装", "実装評価修正ループ")
check("(c) 実装×実値 は2行のみ", len(out) == 2)

# (d) 種別=計画 → 3判定行に評価NN.md採点の文言を含む
out = mirror_lines("計画", None)
check("(d) 計画種別の③に評価NN.md", len(out) == 3 and out[2].startswith("計画3判定") and "評価NN.mdで採点" in out[2])

# (d2) 計画以外×計画=? は従来の催促（実装リマインドに横取りされない）
out = mirror_lines("リサーチ", None)
check("(d2) リサーチ×? は従来催促", len(out) == 3 and out[2].startswith("計画:?"))

# (e) _first_guide の③完了条件行に評価NN.md文言を含む
guide = common._first_guide("k", "repo", "claude")
check("(e) _first_guideの③に評価NN.md", "評価NN.mdで採点（全PASS=done" in guide and "書いてから着手" in guide)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
