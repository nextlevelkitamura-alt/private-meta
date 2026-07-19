#!/usr/bin/env python3
# 子09「大課題テーマ階層と横断表示」の session-board 追加分を検証する。
#   - theme-add: inbox themes への INSERT。AI起点は目的・完了条件が必須（欠落は usage 停止＝送信なし）。
#   - update --todo/--theme: sessions.todo_id/theme_id への所属先宣言（board DB・MDには載せない）。
#   - store.py の builder（stmt_theme_insert / stmt_session_affiliation）の決定的な形。
# board.main() を in-process で叩き、_turso_sync をモックして送信文をキャプチャする
# （ネットワーク・keychainに触れない）。DB接続が要る実挙動は migration 未適用のため範囲外。
import json
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

SP = tempfile.mkdtemp(prefix="sbtest-themes-")
os.environ["GOAL_BASE"] = os.path.join(SP, "goal")
os.environ["SESSION_BOARD_DATE"] = "2099-05-01"
os.environ["SESSION_BOARD_STATE_DIR"] = os.path.join(SP, "state")
os.environ.pop("SESSION_BOARD_NO_TURSO", None)

import board  # noqa: E402
import turso.store as store  # noqa: E402

# board.py の全 Turso 送信は _turso_sync 経由。ここをモックして (statements, db_url) をキャプチャする。
synced = []   # [(statements, db_url), ...]


def _mock_sync(statements, db_url=board.TURSO_DB_URL, service=board.TURSO_KEYCHAIN_SERVICE):
    synced.append(([s for s in statements if s], db_url))


board._turso_sync = _mock_sync

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
    synced.clear()


def run(*argv):
    old = sys.argv
    sys.argv = ["board.py"] + list(argv)
    try:
        board.main()
    except SystemExit:
        pass
    finally:
        sys.argv = old


def last():
    return synced[-1] if synced else ([], None)


def vals(stmt):
    return [a.get("value") for a in stmt[1]]


def types(stmt):
    return [a.get("type") for a in stmt[1]]


# ---- theme-add: inbox themes への INSERT・目的/完了条件必須 ----
clear()
run("theme-add", "--name", "AI実行ダッシュボード作成・改善",
    "--purpose", "AIが動いている仕事と今日の完了を一画面で把握する",
    "--done", "テーマ・タスク・エージェントの紐付きが追える")
stmts, db_url = last()
ok("theme-add: 1件のINSERT INTO themes", len(stmts) == 1 and "INSERT INTO themes" in stmts[0][0])
ok("theme-add: 送信先はinbox DB", db_url == board.TURSO_INBOX_DB_URL)
ok("theme-add: sort_orderはactiveのMAX+1サブセレクト", "COALESCE(MAX(sort_order), 0) + 1" in stmts[0][0])
ok("theme-add: status='active'で作る", "'active'" in stmts[0][0])
# args順: id(0) name(1) purpose(2) done_criteria(3) goal_ref(4) plan_refs(5) created_at(6) updated_at(7)
ok("theme-add: name/purpose/doneが載る",
   vals(stmts[0])[1] == "AI実行ダッシュボード作成・改善"
   and vals(stmts[0])[2] == "AIが動いている仕事と今日の完了を一画面で把握する"
   and vals(stmts[0])[3] == "テーマ・タスク・エージェントの紐付きが追える")
ok("theme-add: goal_ref/plan_refs未指定はNULL", types(stmts[0])[4] == "null" and types(stmts[0])[5] == "null")

# theme-add はテーマIDをstdoutへ出す（AIが update --theme や紐付けに使う）
import io  # noqa: E402
import contextlib  # noqa: E402
clear()
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    run("theme-add", "--name", "仕事の求人整備", "--purpose", "候補者が迷わない求人票を整える",
        "--done", "必須項目と表現ルールが決まる", "--goal", "2026-07-17-求人整備",
        "--plan", "plan-a", "--plan", "plan-b")
printed = buf.getvalue().strip()
stmts, _ = last()
ok("theme-add: 生成したテーマIDをstdoutへ", len(printed) >= 8 and vals(stmts[0])[0] == printed)
ok("theme-add: goal_refが載る", vals(stmts[0])[4] == "2026-07-17-求人整備")
ok("theme-add: plan_refsはslugのJSON配列", json.loads(vals(stmts[0])[5]) == ["plan-a", "plan-b"])

# 目的・完了条件の欠落は usage 停止＝送信なし（AI起点の機械必須化）
clear()
run("theme-add", "--name", "名前だけ")                                  # purpose/done無し
run("theme-add", "--name", "名前", "--purpose", "目的だけ")             # done無し
run("theme-add", "--purpose", "p", "--done", "d")                       # name無し
ok("theme-add: 目的・完了条件・名のいずれか欠落は送信しない", len(synced) == 0)

# ---- update --todo/--theme: sessions.todo_id/theme_id への宣言（board DB・MD不変）----
BOARD = board.BOARD if hasattr(board, "BOARD") else os.path.join(HERE, "..", "board.py")
DAILY = os.path.join(SP, "goal", "2099", "05", "2099-05-01.md")

# 先にセッション行を登録（このaddも _turso_sync に載るが、次のupdateでclearする）。
run("add", "--key", "bbbb0001", "--repo", "focusmap", "--who", "claude/?")
clear()
run("update", "--key", "bbbb0001", "--goal", "ボードUI実装", "--todo", "TODO-123", "--theme", "THEME-9")
stmts, db_url = last()
aff = [s for s in stmts if "UPDATE sessions SET" in s[0]]
ok("update --todo/--theme: 送信先はboard DB", db_url == board.TURSO_DB_URL)
ok("update --todo/--theme: affiliation UPDATEが1件混じる", len(aff) == 1)
ok("update --todo/--theme: todo_id/theme_id両方SET", "todo_id = ?" in aff[0][0] and "theme_id = ?" in aff[0][0])
ok("update --todo/--theme: 値が載る（todo, theme, session_key順）",
   vals(aff[0]) == ["TODO-123", "THEME-9", "s:bbbb0001"])
# MDには todo_id/theme_id を書かない（daily行はゴールだけ更新）
daily_text = open(DAILY, encoding="utf-8").read()
ok("update --todo: MDにtodo_id/theme_idを書かない", "TODO-123" not in daily_text and "THEME-9" not in daily_text)
ok("update --goal: ゴールはMDに反映", "ボードUI実装" in daily_text)

# --todo だけの部分宣言（theme_idはSETしない）
clear()
run("update", "--key", "bbbb0001", "--todo", "TODO-only")
aff = [s for s in last()[0] if "UPDATE sessions SET" in s[0]]
ok("update --todo単独: todo_idだけSET", len(aff) == 1 and "todo_id = ?" in aff[0][0] and "theme_id" not in aff[0][0])
ok("update --todo単独: 値はtodo, session_keyの2つ", vals(aff[0]) == ["TODO-only", "s:bbbb0001"])

# --todo/--theme を伴わない通常のupdateは affiliation を送らない（毎回の無駄書きを避ける）
clear()
run("update", "--key", "bbbb0001", "--now", "画面調整")
ok("update（宣言なし）: affiliation UPDATEを送らない",
   not any("UPDATE sessions SET" in s[0] and "todo_id" in s[0] for s in last()[0]))

# ---- store.py builder: stmt_theme_insert / stmt_session_affiliation の決定的な形 ----
st = store.stmt_theme_insert("TID", "名前", "目的", "完了条件")
ok("stmt_theme_insert: name/purpose/done_criteriaを載せる",
   st is not None and store.text_arg("名前") in st[1] and vals(st)[2] == "目的" and vals(st)[3] == "完了条件")
ok("stmt_theme_insert: idまたはnameが空はNone",
   store.stmt_theme_insert("", "n", "p", "d") is None and store.stmt_theme_insert("i", "", "p", "d") is None)

aff = store.stmt_session_affiliation("cccc", todo_id="T", theme_id="H")
ok("stmt_session_affiliation: 両指定で todo/theme/keyの3値", vals(aff) == ["T", "H", "s:cccc"])
aff = store.stmt_session_affiliation("cccc", todo_id="T")
ok("stmt_session_affiliation: todoのみで theme列を含めない", "theme_id" not in aff[0] and vals(aff) == ["T", "s:cccc"])
ok("stmt_session_affiliation: 何も指定なし/key空はNone",
   store.stmt_session_affiliation("cccc") is None and store.stmt_session_affiliation("", todo_id="T") is None)

print(f"\n== 結果: PASS={PASS} FAIL={FAIL} ==")
sys.exit(1 if FAIL else 0)
