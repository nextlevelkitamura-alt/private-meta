#!/usr/bin/env python3
# reconcile_rows / _minutes_between の単体テスト（board.py を import して関数を直接検証）。
# フック言語規約: ロジックの検証は Python（bashで叩いてgrepより素直）。実ボードには触れない
# （lines を直接渡し、_list_transcripts を差し替えるだけ）。W4評価の追補①③⑤の回帰を守る。
import os
import sys
import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
import board  # noqa: E402

PASS = 0
FAIL = 0


def ok(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print("PASS:", name)
    else:
        FAIL += 1
        print("FAIL:", name)


def hhmm_ago(mins):
    """いまから mins 分前（負なら未来＝逆行クロックの模擬）の HH:MM。"""
    t = datetime.datetime.now() - datetime.timedelta(minutes=mins)
    return t.strftime("%H:%M")


def row(state, mins_ago, key="aaaa0001"):
    return (f"- {state} {hhmm_ago(mins_ago)} | G | 今:N | Repo | 実装 | "
            f"claude/? | 計画:? <!-- s:{key} -->")


def make(rows):
    return ["## 動いているエージェント"] + rows + ["", "## 終わったこと", ""]


def state_of(lines, key="aaaa0001"):
    for ln in lines:
        r = board.parse_line(ln)
        if r and r["key"] == key:
            return r["state"]
    return None


RUN, WAIT, SUB = board.RUN, board.WAIT, board.SUB

# ---- _minutes_between（純関数）----
ok("_min 通常(10:00→10:20=20)", board._minutes_between("10:00", "10:20") == 20)
ok("_min 日跨ぎ(23:58→00:05=7)", board._minutes_between("23:58", "00:05") == 7)
ok("_min 逆行(10:00→09:59=+1440-1)", board._minutes_between("10:00", "09:59") == 1439)

# ---- ① files が空（探索不能）→ 幽霊掃除を抑止（全行一括⏸を防ぐ）----
_orig = board._list_transcripts
board._list_transcripts = lambda: []
ok("① files空: 🟢20分でも落とさない", state_of(board.reconcile_rows(make([row(RUN, 20)]))) == RUN)
ok("① files空: 🔵20分でも落とさない", state_of(board.reconcile_rows(make([row(SUB, 20)]))) == SUB)

# ---- files非空・key不一致 → NOFILE分岐が発火する状況 ----
board._list_transcripts = lambda: ["/tmp/other-session-9999.jsonl"]
# ③ 🟢は15分・🔵は30分の閾値
ok("③ 🟢20分→⏸", state_of(board.reconcile_rows(make([row(RUN, 20)]))) == WAIT)
ok("③ 🔵20分→維持(30分猶予)", state_of(board.reconcile_rows(make([row(SUB, 20)]))) == SUB)
ok("③ 🔵35分→⏸", state_of(board.reconcile_rows(make([row(SUB, 35)]))) == WAIT)
# 回帰: 15分未満は維持
ok("🟢10分→維持(15分未満)", state_of(board.reconcile_rows(make([row(RUN, 10)]))) == RUN)
# ⑤ 逆行クロック（未来時刻→_minutes_between が +1440≈1437）→ 上限NOFILE_MAXで弾く
ok("⑤ 逆行クロック(3分未来)→降格しない", state_of(board.reconcile_rows(make([row(RUN, -3)]))) == RUN)

board._list_transcripts = _orig

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
