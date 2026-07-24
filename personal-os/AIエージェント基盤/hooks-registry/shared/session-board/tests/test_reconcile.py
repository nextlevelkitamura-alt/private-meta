#!/usr/bin/env python3
# reconcile の生存照合テスト（正本反転・子03後）。
# 反転後は board.reconcile_db() が board DB の run/sub 行 × 実トランスクリプト生存を照合し、
# 沈黙した行の内部row（state=WAIT・sub=0）のリストを返す。旧MD reconcile の生存判定ロジックを流用:
#   ・files が皆無なら降格しない（探索不能時に全行一括⏸を防ぐ安全弁）
#   ・transcript あり（mtime経路）は最終更新からの沈黙で判定（🟢10分/🔵30分）
#   ・transcript なし（ファイル皆無経路）は updated_at からの沈黙で判定（🟢15分/🔵30分・12時間超も降格）
# fake DB に行を直接seedし、board._list_transcripts を差し替えて判定だけを検証する（実ボード非依存）。
import datetime
import os
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import _fakedb  # noqa: E402

fake = _fakedb.install(board)

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


def iso_ago(mins):
    return (datetime.datetime.now() - datetime.timedelta(minutes=mins)).isoformat(timespec="seconds")


def seed(key, state, updated_min_ago, sub=0):
    """fake DB に1セッションを直接 seed（reconcile の入力を作る）。"""
    fake.board.execute("DELETE FROM sessions WHERE session_key=?", (f"s:{key}",))
    fake.board.execute(
        "INSERT INTO sessions (session_key, goal, now, type, repo, model, plan, state, sub_n, updated_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        (f"s:{key}", "G", "N", "実装", "Repo", "claude", "?", state, sub, iso_ago(updated_min_ago)))
    fake.board.commit()


def demoted_keys():
    return {r["key"] for r in board.reconcile_db()}


RUN, WAIT, SUB = board.RUN, board.WAIT, board.SUB

# ---- _minutes_between（純関数・re-export維持）----
ok("_min 通常(10:00→10:20=20)", board._minutes_between("10:00", "10:20") == 20)
ok("_min 日跨ぎ(23:58→00:05=7)", board._minutes_between("23:58", "00:05") == 7)
ok("_min 逆行(10:00→09:59=+1440-1)", board._minutes_between("10:00", "09:59") == 1439)

# ---- _minutes_since_iso（updated_at 沈黙判定の起点）----
_now = datetime.datetime.now()
ok("_min_since 約16分前", 15 < board._minutes_since_iso(iso_ago(16), _now) < 17)
ok("_min_since 未来(逆行)は負値", board._minutes_since_iso(iso_ago(-3), _now) < 0)
ok("_min_since Noneは None", board._minutes_since_iso(None, _now) is None)

# ---- ① files が空（探索不能）→ 幽霊掃除を抑止（全行一括⏸を防ぐ）----
board._list_transcripts = lambda: []
seed("aaaa0001", "run", 20)
ok("① files空: 🟢20分でも落とさない", "aaaa0001" not in demoted_keys())
seed("aaaa0001", "sub", 20, sub=1)
ok("① files空: 🔵20分でも落とさない", "aaaa0001" not in demoted_keys())

# ---- files非空・key不一致 → NOFILE分岐（updated_at 沈黙で判定）----
board._list_transcripts = lambda: ["/tmp/other-session-9999.jsonl"]
seed("aaaa0001", "run", 20)
ok("③ 🟢20分(実体なし)→降格", "aaaa0001" in demoted_keys())
seed("aaaa0001", "sub", 20, sub=1)
ok("③ 🔵20分→維持(30分猶予)", "aaaa0001" not in demoted_keys())
seed("aaaa0001", "sub", 35, sub=1)
ok("③ 🔵35分→降格", "aaaa0001" in demoted_keys())
seed("aaaa0001", "run", 10)
ok("🟢10分→維持(15分未満)", "aaaa0001" not in demoted_keys())
# 12時間を超えた ghost も必ず降格（旧 NOFILE_MAX 上限で永久残留しない）
seed("aaaa0001", "run", board.NOFILE_MAX + 60)
ok("12時間超の🟢ghost→降格", "aaaa0001" in demoted_keys())
seed("aaaa0001", "sub", board.NOFILE_MAX + 60, sub=2)
ok("12時間超の🔵ghost→降格", "aaaa0001" in demoted_keys())
# ⑤ 逆行クロック（未来 updated_at）は age < 0 のため弾く
seed("aaaa0001", "run", -3)
ok("⑤ 逆行クロック(3分未来)→降格しない", "aaaa0001" not in demoted_keys())

# ---- ⑥ 🔵→⏸降格時に sub を0へクリア（幽霊ガード・子02）----
seed("subx0001", "sub", 35, sub=2)
dem = board.reconcile_db()
row = next((r for r in dem if r["key"] == "subx0001"), None)
ok("⑥ 実体皆無: 🔵35分 sub:2→降格", row is not None and row["state"] == WAIT)
ok("⑥ 実体皆無: 降格でsub=0", row is not None and row["sub"] == 0)
# 維持中（閾値内）は降格しない＝sub保持
seed("subx0001", "sub", 20, sub=2)
ok("⑥ 維持中(20分)は降格しない(sub保持)", "subx0001" not in demoted_keys())

# ---- mtime沈黙経路: 実ファイル（キーをパスに含む）の mtime で判定 ----
_td = tempfile.mkdtemp(prefix="sbtest-reconcile-")
_f = os.path.join(_td, "subx0002-tx.jsonl")
open(_f, "w").close()
_old = time.time() - 35 * 60
os.utime(_f, (_old, _old))
board._list_transcripts = lambda: [_f]
seed("subx0002", "sub", 1, sub=3)   # updated_atは新しいが transcript mtime が35分前
dem = board.reconcile_db()
row = next((r for r in dem if r["key"] == "subx0002"), None)
ok("⑥ mtime沈黙: 🔵→降格(mtime優先)", row is not None and row["state"] == WAIT)
ok("⑥ mtime沈黙: 降格でsub=0", row is not None and row["sub"] == 0)
# mtimeが新しければ維持（updated_atが古くても transcript が生きていれば落とさない）
_new = time.time() - 60
os.utime(_f, (_new, _new))
seed("subx0002", "run", 99)   # updated_at 99分前でも transcript は1分前 → 維持
ok("mtime新しい: 🟢は維持(transcript生存優先)", "subx0002" not in demoted_keys())

# ---- reconcile対象が無い（run/subが無い）→ 空 ----
fake.board.execute("DELETE FROM sessions")
fake.board.commit()
ok("run/sub 皆無→降格なし", board.reconcile_db() == [])

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
