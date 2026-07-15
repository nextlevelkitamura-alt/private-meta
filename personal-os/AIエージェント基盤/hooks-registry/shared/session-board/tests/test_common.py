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

# (f) 計画箱は repo AGENTS の宣言から解決し、root plans 固定へ戻らない
check("(f) _first_guideは二段ルーティング", all(s in guide for s in (
    "repo-registry/repo概要.md", "対象repoの最寄りAGENTS.md", "宣言範囲の既存planを検索",
    "root plansを推定・作成せず停止",
)))
check("(f2) _first_guideにroot plans固定なし",
      "<repo>/plans" not in guide and "ls <repo>/plans" not in guide)

# (g) Private起点は既存sessionの移管でなく対象repoの新しい可視sessionへhandoffする
check("(g) _first_guideは可視session handoff", all(s in guide for s in (
    "新しい可視sessionへhandoff", "既存session IDの移管・reparentはしない", "worktree cwd",
)))

# (h) 2回目以降の計画ミラーも repo AGENTS が宣言した箱を案内する
out = mirror_lines("計画", "企画/01")
check("(h) 計画ミラーもrepo固有箱", len(out) == 3
      and "対象repo AGENTS.md→宣言された計画箱" in out[2]
      and "<repo>/plans" not in out[2])

# (i) 承認待ちの次期Prompt Submit本文はcommon.pyだけが生成元で、責務境界を含む
candidate = common.plan_management_guide_candidate()
check("(i) 次期本文に最小ゲートと一本道", all(s in candidate for s in (
    "全YESでない、または不明なら plan-management", "planning→active→done→archive",
    "bucketctl check", "一括は束ねて", "finishはsession-boardの記録を閉じるだけ",
)))
check("(i2) 次期本文は未有効化", "plan-management" not in guide and "plan_management_guide_candidate" not in common.register_prompt.__code__.co_names)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
