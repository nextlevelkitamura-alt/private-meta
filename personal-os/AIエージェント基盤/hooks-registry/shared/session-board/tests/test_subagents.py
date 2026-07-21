#!/usr/bin/env python3
# 子08 サブエージェント入れ子可視化（session_subagents）のネットワーク非依存テスト。
# (1) SQL builder（stmt_subagent_start/end/label）の文と引数の形。
# (2) board.main() 経由の sub-label コマンドと、存在しないkeyへのsub-startが個体行を作らないガード。
# _turso_execute をモックして送信文をキャプチャする（本番Tursoへは一切飛ばない）。
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-subagents-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-03-01"
os.environ["SESSION_BOARD_TX_ROOTS"] = os.path.join(SP, "tx")
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)   # fake DB を使うので NO_TURSO は必ず外す

import board  # noqa: E402
import _fakedb  # noqa: E402

# 正本反転（子03）後は sub-start が実在セッション行を board DB から読む（_load_row）ため、
# fake DB を差し込んで add→update→sub-start の状態を保持させる（本番Tursoへは飛ばない）。
fake = _fakedb.install(board)


def captured():
    return fake.flat()


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


def clear():
    fake.clear()


def run(*argv):
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    try:
        board.main()
    except SystemExit:
        pass
    finally:
        sys.argv = old


def vals(args):
    return [a.get("value") for a in args]


DATE = "2099-03-01"

# ---- 1. stmt_subagent_start: INSERT・sub_seqはMAX+1・labelはNULL・running ----
stmt = board._stmt_subagent_start("s:aaaa0001", DATE)
sql, args = stmt
ok("start: INSERT INTO session_subagents", sql.startswith("INSERT INTO session_subagents"))
ok("start: sub_seqはMAX+1採番", "COALESCE(MAX(sub_seq), 0) + 1" in sql)
ok("start: labelはNULLリテラル・statusはrunningリテラル", "NULL, 'running'" in sql)
ok("start: 引数6本(id/key/key/date/started/date)", len(args) == 6)
ok("start: session_keyはs:形式", vals(args)[1] == "s:aaaa0001" and vals(args)[2] == "s:aaaa0001")
ok("start: session_dateを2箇所へ", vals(args)[3] == DATE and vals(args)[5] == DATE)
ok("start: started_atはISO秒", isinstance(vals(args)[4], str) and "T" in vals(args)[4])
ok("start: idはuuid hex(32字)", len(vals(args)[0]) == 32)
ok("start: key欠落はNone", board._stmt_subagent_start("", DATE) is None)
ok("start: date欠落はNone", board._stmt_subagent_start("s:x", "") is None)

# ---- 2. stmt_subagent_end: 最古のrunningを1本close（FIFO）----
sql, args = board._stmt_subagent_end("s:aaaa0001", DATE)
ok("end: UPDATE…status='done', ended_at", sql.startswith("UPDATE session_subagents SET status = 'done', ended_at = ?"))
ok("end: running限定・最古1本(ORDER BY started_at, sub_seq LIMIT 1)",
   "status = 'running'" in sql and "ORDER BY started_at, sub_seq LIMIT 1" in sql)
ok("end: 引数3本(ended/key/date)", len(args) == 3 and vals(args)[1] == "s:aaaa0001" and vals(args)[2] == DATE)
ok("end: key欠落はNone", board._stmt_subagent_end("", DATE) is None)

# ---- 3. stmt_subagent_label: --seq未指定=最新running / 指定=その連番 ----
sql, args = board._stmt_subagent_label("s:aaaa0001", DATE, "計画を精査中")
ok("label(seq無): SET label=?", sql.startswith("UPDATE session_subagents SET label = ?"))
ok("label(seq無): 最新running(ORDER BY started_at DESC, sub_seq DESC LIMIT 1)",
   "status = 'running'" in sql and "ORDER BY started_at DESC, sub_seq DESC LIMIT 1" in sql)
ok("label(seq無): 引数3本", len(args) == 3 and vals(args)[0] == "計画を精査中" and vals(args)[1] == "s:aaaa0001")
sql2, args2 = board._stmt_subagent_label("s:aaaa0001", DATE, "手直し中", seq=2)
ok("label(seq指定): sub_seq=?で直接指定", "AND sub_seq = ?" in sql2 and "ORDER BY" not in sql2)
ok("label(seq指定): 引数4本(label/key/date/seq)", len(args2) == 4 and args2[3] == {"type": "integer", "value": "2"})
ok("label: 空labelはNone", board._stmt_subagent_label("s:x", DATE, "  ") is None)
ok("label: key欠落はNone", board._stmt_subagent_label("", DATE, "x") is None)

# ---- 4. board.main() sub-label コマンド（board DBへUPDATE 1本・MD/体数に触れない）----
clear()
run("sub-label", "--key", "s:bbbb0002", "--label", "リサーチ委任中")
subs = [(s, a) for s, a in captured() if "session_subagents" in s]
ok("sub-label: session_subagents UPDATE 1本を送る", len(subs) == 1 and subs[0][0].startswith("UPDATE"))
ok("sub-label: label文言が引数に乗る", vals(subs[0][1])[0] == "リサーチ委任中")
ok("sub-label: sessions/eventsは送らない(board DB限定列のみ)",
   not any("INTO sessions" in s or "session_events" in s for s, _ in captured()))
clear()
run("sub-label", "--key", "bbbb0002", "--label", "2件目", "--seq", "3")
subs = [(s, a) for s, a in captured() if "session_subagents" in s]
ok("sub-label --seq: sub_seq=?で直接指定のUPDATE", len(subs) == 1 and "AND sub_seq = ?" in subs[0][0])
clear()
run("sub-label", "--key", "s:bbbb0002")   # label欠落=usage停止
ok("sub-label: label欠落は送信しない(usage停止)", len([s for s, _ in captured() if "session_subagents" in s]) == 0)

# ---- 5. ガード: 存在しないkeyへの sub-start は個体行を作らない ----
clear()
run("sub-start", "--key", "nokey999")
ok("存在しないkeyのsub-startはsession_subagents行を積まない",
   len([s for s, _ in captured() if "session_subagents" in s]) == 0)

# ---- 6. 実在セッションの sub-start→sub-end で個体行が INSERT→close される（統合）----
run("add", "--key", "subb0009", "--repo", "RepoS", "--who", "claude/?")
run("update", "--key", "subb0009", "--goal", "サブ可視化", "--now", "委託")
clear()
run("sub-start", "--key", "subb0009")
ins = [s for s, _ in captured() if "INTO session_subagents" in s]
ok("実在セッションのsub-start: 個体行INSERT 1本", len(ins) == 1)
clear()
run("sub-end", "--key", "subb0009")
upd = [s for s, _ in captured() if "UPDATE session_subagents" in s]
ok("実在セッションのsub-end: 個体行close(UPDATE) 1本", len(upd) == 1)

# ---- 7. 子03: 詳細5列（後方互換＝詳細なしは狭いINSERT／詳細ありは広いINSERT）----
sql0, args0 = board._stmt_subagent_start("s:cccc0003", DATE)
ok("detail無: 狭いINSERT(runtime列を含まない)・args6本(後方互換)", "runtime" not in sql0 and len(args0) == 6)
sqlD, argsD = board._stmt_subagent_start(
    "s:cccc0003", DATE, runtime="claude", model="opus",
    agent_type="reviewer", launch_via="agent-tool", prompt="計画を精査して")
ok("detail有: 広いINSERT(5列名が乗る)",
   all(c in sqlD for c in ("runtime", "model", "agent_type", "launch_via", "prompt")))
ok("detail有: 引数11本(base6+詳細5)", len(argsD) == 11)
ok("detail有: 末尾5本の値が乗る",
   vals(argsD)[6:] == ["claude", "opus", "reviewer", "agent-tool", "計画を精査して"])
sqlP, argsP = board._stmt_subagent_start("s:cccc0003", DATE, runtime="codex")
ok("detail一部: 広いINSERTへ切替(11本)", "runtime" in sqlP and len(argsP) == 11)
ok("detail一部: 欠けはNULL型(空文字と区別)",
   argsP[7] == {"type": "null"} and argsP[6] == {"type": "text", "value": "codex"})

# ---- 8. 子03: board.main() sub-start へ詳細引数→INSERTに5列＋prompt保存前マスキング ----
run("add", "--key", "detl0010", "--repo", "RepoD", "--who", "claude/?")
run("update", "--key", "detl0010", "--goal", "詳細化", "--now", "委託")
clear()
run("sub-start", "--key", "detl0010", "--runtime", "claude", "--model", "opus",
    "--type", "reviewer", "--via", "agent-tool",
    "--prompt", "レビューして api_key=SECRET123 と token: abcdef を使う")
ins = [(s, a) for s, a in captured() if "INTO session_subagents" in s]
ok("sub-start 詳細: 広いINSERT 1本", len(ins) == 1 and "runtime" in ins[0][0])
insvals = vals(ins[0][1]) if ins else []
ok("sub-start 詳細: runtime/model/type/via が乗る",
   len(insvals) == 11 and insvals[6:10] == ["claude", "opus", "reviewer", "agent-tool"])
ok("sub-start 詳細: prompt の秘密値が[masked]化",
   bool(insvals) and "SECRET123" not in insvals[10] and "abcdef" not in insvals[10] and "[masked]" in insvals[10])
ok("sub-start 詳細: 本文の非秘密は残る", bool(insvals) and "レビューして" in insvals[10])

# ---- 9. 子03: _mask_secrets 単体（key:value / key=value を潰しキーは残す・空はNone）----
ok("mask: api_key=xxx を潰す", board._mask_secrets("api_key=xyz123") == "api_key=[masked]")
ok("mask: token: xxx を潰す", board._mask_secrets("token: abc") == "token: [masked]")
ok("mask: password=… を潰す", "[masked]" in board._mask_secrets("password=hunter2"))
ok("mask: 秘密でない本文は不変", board._mask_secrets("これは普通の依頼です") == "これは普通の依頼です")
ok("mask: 空/Noneは None", board._mask_secrets("") is None and board._mask_secrets(None) is None)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
