#!/usr/bin/env python3
"""session-board CLI調停。MD確定後にTursoをベストエフォート送信する。"""
import datetime
import os
import re
import sys
import urllib.request  # 既存テスト・外部モック向け互換露出
import uuid  # 子09 theme-add のテーマID採番

from md import store as md_store
from turso import spool as turso_spool
from turso import store as turso_store

# MD公開名の互換re-export（board-sweep・既存テストがimportする）。
RUN, WAIT, SUB = md_store.RUN, md_store.WAIT, md_store.SUB
STATE_RANK, RANK_STATE, STATE_WORD = md_store.STATE_RANK, md_store.RANK_STATE, md_store.STATE_WORD
STALE_MIN, STALE_MIN_SUB = md_store.STALE_MIN, md_store.STALE_MIN_SUB
STALE_MIN_NOFILE, NOFILE_MAX = md_store.STALE_MIN_NOFILE, md_store.NOFILE_MAX
PLACEHOLDER, AGENTS_H, DONE_H = md_store.PLACEHOLDER, md_store.AGENTS_H, md_store.DONE_H
GS_OPEN, GS_CLOSE = md_store.GS_OPEN, md_store.GS_CLOSE
LINE_RE, V2_LINE_RE, OLD_LINE_RE = md_store.LINE_RE, md_store.V2_LINE_RE, md_store.OLD_LINE_RE
OLD_STATE, CHILD_RE, PLAN_MARK = md_store.OLD_STATE, md_store.CHILD_RE, md_store.PLAN_MARK
daily_path, template_text = md_store.daily_path, md_store.template_text
clean, section_bounds, parse_line = md_store.clean, md_store.section_bounds, md_store.parse_line
fmt, find_line, render_body = md_store.fmt, md_store.find_line, md_store.render_body
strip_plan_mark = md_store.strip_plan_mark
add_children, annotate_parent_plan = md_store.add_children, md_store.annotate_parent_plan
_tx_roots, _list_transcripts, _newest_for = md_store.tx_roots, md_store.list_transcripts, md_store.newest_for
_minutes_between, _fmt_elapsed, _base_time_for = md_store.minutes_between, md_store.fmt_elapsed, md_store.base_time_for

# Turso公開名の互換re-export。送信ラッパーはmonkeypatch可能性を保つ。
TURSO_DB_URL, TURSO_KEYCHAIN_SERVICE = turso_store.DB_URL, turso_store.KEYCHAIN_SERVICE
TURSO_INBOX_DB_URL, TURSO_INBOX_KEYCHAIN_SERVICE = turso_store.INBOX_DB_URL, turso_store.INBOX_KEYCHAIN_SERVICE
TURSO_TIMEOUT, TURSO_SPOOL_LIMIT = turso_store.TIMEOUT, turso_spool.LIMIT
_ta, _ia = turso_store.text_arg, turso_store.int_arg
_stmt_session_upsert = turso_store.stmt_session_upsert
_stmt_session_delete = turso_store.stmt_session_delete
# 子09: セッション所属先の宣言（sessions.todo_id/theme_id）と大課題テーマの作成（inbox themes）。
_stmt_session_affiliation = turso_store.stmt_session_affiliation
_stmt_theme_insert = turso_store.stmt_theme_insert
# 子03: 今日やること todo を inbox todos へ確定起票（board.py todo-add・daily-start が使う）。
_stmt_todo_insert = turso_store.stmt_todo_insert
# 子08: サブエージェント入れ子可視化（board DB: session_subagents の開始/終了/ラベル）。
_stmt_subagent_start, _stmt_subagent_end = turso_store.stmt_subagent_start, turso_store.stmt_subagent_end
_stmt_subagent_label = turso_store.stmt_subagent_label
_stmts_logs, _stmts_events = turso_store.stmts_logs, turso_store.stmts_events
_stmts_reconcile, _stmt_goal_insert = turso_store.stmts_reconcile, turso_store.stmt_goal_insert
_spool_paths, _spoolable_statements = turso_spool.paths, turso_spool.spoolable
_spool_append_unchecked, _spool_append = turso_spool.append_unchecked, turso_spool.append
_turso_token = turso_store.token
# 子05 タスク入れ子・2層チェック（inbox DB書込みのSQL builder）。
_stmts_todo_steps, _stmt_step_status = turso_store.stmts_todo_steps, turso_store.stmt_step_status
_stmt_ask, _stmt_flow_done = turso_store.stmt_ask, turso_store.stmt_flow_done
_stmt_unconsumed_answers = turso_store.stmt_unconsumed_answers
_stmt_mark_answers_consumed = turso_store.stmt_mark_answers_consumed
_turso_read = turso_store.read

# board.py自身の実体ディレクトリ（route宣言スキャンの既定ルート算出に使う）。
_SB_DIR = os.path.dirname(os.path.abspath(__file__))
# frontmatterの `board_route: routine` 宣言（skill/loop正本の1行が正本・第2の台帳を作らない）。
_ROUTE_RE = re.compile(r"^board_route:\s*routine\s*$", re.M)


def _turso_send(statements, db_url=TURSO_DB_URL, service=TURSO_KEYCHAIN_SERVICE):
    return turso_store.send(statements, db_url, service, token_getter=_turso_token)


def _turso_execute(statements, db_url=TURSO_DB_URL, service=TURSO_KEYCHAIN_SERVICE):
    return turso_store.execute(statements, _turso_send, _spool_append, db_url, service)


def _turso_replay_unchecked(skip_tail_lines=0, limit=TURSO_SPOOL_LIMIT):
    return turso_spool.replay_unchecked(_turso_send, skip_tail_lines, limit)


def _turso_replay(skip_tail_lines=0, limit=TURSO_SPOOL_LIMIT):
    return turso_spool.replay(_turso_send, skip_tail_lines, limit)


def _turso_sync(statements, db_url=TURSO_DB_URL, service=TURSO_KEYCHAIN_SERVICE):
    spooled = _turso_execute(statements, db_url=db_url, service=service)
    _turso_replay(skip_tail_lines=spooled or 0)


def reconcile_rows(lines, changed=None):
    """互換ラッパー。board._list_transcriptsのモックをMD層へ注入する。"""
    return md_store.reconcile_rows(lines, changed, transcript_loader=_list_transcripts)


def turso_append_events(events, date_s=None):
    if not events:
        return
    if date_s is None:
        _, date_s = daily_path()
    _turso_sync(_stmts_events(events, date_s))


def _turso_send_inbox(statements):
    """子05のinbox書込み（todos/todo_steps）。board既定spoolへ載せずbest-effort送信する
    （cross-DBのspool replay汚染を避ける・失敗はドロップ＝呼び出し元を巻き戻さない）。"""
    statements = [s for s in statements if s]
    if not statements or os.environ.get("SESSION_BOARD_NO_TURSO"):
        return True
    return _turso_send(statements, db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE)


def _turso_read_inbox(statement):
    """inbox DBのbest-effort読み取り（回答注入用）。失敗・NO_TURSOは None。"""
    return _turso_read(statement, db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE, token_getter=_turso_token)


def collect_answers(key):
    """当該セッション(s:key)の未消費回答を注入文へ整形し、消費済みに落とす。
    回答が無い/読めない時は空文字（best-effort・hookをブロックしない）。"""
    session_key = f"s:{key.removeprefix('s:')}" if key else ""
    if not session_key:
        return ""
    rows = _turso_read_inbox(_stmt_unconsumed_answers(session_key))
    if not rows:
        return ""
    lines = ["[session-board] スマホから届いた未消費の回答（この依頼へ反映して続行）:"]
    for row in rows:
        question = (row.get("question") or "").strip()
        answer = (row.get("answer") or "").strip()
        title = (row.get("title") or "").strip()
        if not answer:
            continue
        head = f"「{title}」" if title else ""
        lines.append(f"  {head} Q: {question} → A: {answer}")
    if len(lines) == 1:
        return ""
    # 渡し切ったら消費済みに落とす（次回以降は再注入しない）。
    _turso_send_inbox([_stmt_mark_answers_consumed(session_key)])
    return "\n".join(lines)


def scan_board_routes(roots=None):
    """skill/loop正本のfrontmatterを走査し `board_route: routine` を宣言したslug集合を返す。
    slug=宣言ファイルの親ディレクトリ名。宣言1行が正本で、第2の台帳・キャッシュファイルは作らない。
    ルートは SESSION_BOARD_ROUTE_ROOTS（:区切り）で差し替え可能（既定=基盤の skills/ と loops-registry/）。"""
    if roots is None:
        env = os.environ.get("SESSION_BOARD_ROUTE_ROOTS")
        if env:
            roots = [r for r in env.split(":") if r]
        else:
            base = os.path.dirname(os.path.dirname(os.path.dirname(_SB_DIR)))
            roots = [os.path.join(base, "skills"), os.path.join(base, "loops-registry")]
    slugs = set()
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, _dirs, files in os.walk(root):
            for name in files:
                if not name.endswith(".md"):
                    continue
                try:
                    head = open(os.path.join(dirpath, name), encoding="utf-8").read(4000)
                except Exception:
                    continue
                if _ROUTE_RE.search(head):
                    slugs.add(os.path.basename(dirpath))
    return slugs


def _run_inbox_command(cmd, args, entries):
    """子05のinbox系コマンド（daily/keyに触れずtodos/todo_stepsだけを書く）。
    処理したら True を返す（未該当は False）。"""
    if cmd == "steps":
        todo = args.get("todo")
        if not todo or not entries:
            sys.exit('usage: board.py steps --todo <id> --entry "<step>" [--entry ...] [--kind step|review|fix] [--session-key s:xxxx]')
        session_key = args.get("session-key") or (f"s:{args['key'].removeprefix('s:')}" if args.get("key") else None)
        _turso_send_inbox(_stmts_todo_steps(todo, entries, args.get("kind", "step"), session_key))
        return True
    if cmd in ("step-done", "step-doing", "step-skip"):
        todo, seq = args.get("todo"), args.get("seq")
        if not todo or seq is None or not str(seq).isdigit():
            sys.exit(f"usage: board.py {cmd} --todo <id> --seq <n>")
        status = {"step-done": "done", "step-doing": "doing", "step-skip": "skipped"}[cmd]
        _turso_send_inbox([_stmt_step_status(todo, int(seq), status)])
        return True
    if cmd == "ask":
        todo = args.get("todo")
        statement = _stmt_ask(todo, args.get("q") or args.get("question"), args.get("choices"),
                              args.get("free", "1") != "0", args.get("gate") == "1")
        if statement is None:
            sys.exit('usage: board.py ask --todo <id> --q "<質問>" [--choice A --choice B --choice C] [--free 0|1] [--gate 0|1]')
        _turso_send_inbox([statement])
        return True
    if cmd == "flow-done":
        todo, skill = args.get("todo"), args.get("skill")
        if not todo or not skill:
            sys.exit("usage: board.py flow-done --todo <id> --skill <slug>")
        if skill not in scan_board_routes():
            print("not-routine")   # 宣言のない実行は自動完了しない（人間チェックへ）
            return True
        _turso_send_inbox([_stmt_flow_done(todo)])
        print("flow-done")
        return True
    if cmd == "answers":
        key = args.get("key", "")
        if not key:
            sys.exit("usage: board.py answers --key <session-key>")
        text = collect_answers(key)
        if text:
            print(text)
        return True
    return False


def parse_args(argv):
    cmd, args, entries, choices, plans = argv[0], {}, [], [], []
    index = 1
    while index < len(argv):
        key = argv[index]
        if not key.startswith("--"):
            sys.exit(f"unexpected arg: {key}")
        value = argv[index + 1] if index + 1 < len(argv) else ""
        if key == "--entry":
            entries.append(value)
        elif key == "--choice":       # 質問の選択肢は繰り返し指定を配列で受ける（最大3はbuilder側で丸める）
            choices.append(value)
        elif key == "--plan":         # theme-add は計画slugを複数受ける。update等の単一 --plan 互換のため args["plan"] も残す
            plans.append(value); args["plan"] = value
        else:
            args[key[2:]] = value
        index += 2
    if choices:
        args["choices"] = choices
    if plans:
        args["plans"] = plans
    return cmd, args, entries


def _read_only(cmd, path, key):
    if not os.path.exists(path):
        if cmd != "goals":
            print("missing")
        return
    lines = open(path, encoding="utf-8").read().split("\n")
    if cmd == "goals":
        start, end = section_bounds(lines, AGENTS_H)
        seen = []
        if start is not None:
            for index in range(start + 1, end):
                row = parse_line(lines[index])
                if row and row["goal"] != PLACEHOLDER and row["goal"] not in seen:
                    seen.append(row["goal"])
        for goal in seen:
            print(goal)
        return
    _, row = find_line(lines, key)
    if row is None:
        print("missing")
    elif cmd == "check":
        print(STATE_WORD.get(row["state"], "wait"))
    else:
        print("\t".join([STATE_WORD.get(row["state"], "wait"), row["goal"], row["now"],
                         row["type"], row["repo"], row["who"], row.get("plan") or PLACEHOLDER]))


def _mutate(cmd, args, entries, key, lines, pending_events):
    for header in (AGENTS_H, DONE_H):
        if header not in lines:
            lines += ["", header]
    index, row = find_line(lines, key) if key else (None, None)
    now = datetime.datetime.now().strftime("%H:%M")
    context = {"repo": None, "parent": None}

    if cmd == "add":
        if index is None:
            row = {"state": RUN, "time": args.get("time") or now,
                   "goal": clean(args.get("goal") or args.get("summary")) or PLACEHOLDER,
                   "now": clean(args.get("now")) or PLACEHOLDER,
                   "repo": clean(args.get("repo")) or "?", "type": clean(args.get("type")) or "その他",
                   "who": clean(args.get("who")) or PLACEHOLDER,
                   "plan": clean(args.get("plan")) or PLACEHOLDER, "key": key}
            start, end = section_bounds(lines, AGENTS_H); insert = end
            while insert > start + 1 and not lines[insert - 1].strip(): insert -= 1
            lines.insert(insert, fmt(row)); pending_events.append((dict(row), "run", "add"))
    elif cmd == "update":
        if index is None: sys.exit(f"line not found for key {key}")
        if "goal" in args or "summary" in args: row["goal"] = clean(args.get("goal") or args.get("summary")) or PLACEHOLDER
        if "now" in args: row["now"] = clean(args["now"]) or PLACEHOLDER
        if "repo" in args: row["repo"] = clean(args["repo"]) or row["repo"]
        if "type" in args: row["type"] = clean(args["type"]) or row["type"]
        if "who" in args: row["who"] = clean(args["who"]) or PLACEHOLDER
        elif "model" in args:
            base, model = (row["who"].split("/")[0] if "/" in row["who"] else ""), clean(args["model"])
            row["who"] = f"{base}/{model}" if base and model else (model or row["who"])
        if "plan" in args: row["plan"] = clean(args["plan"]) or PLACEHOLDER
        lines[index] = fmt(row)
    elif cmd == "flip":
        if index is None: return context
        state = args.get("state")
        if state not in ("run", "wait", "sub"): return context
        new_state = {"run": RUN, "wait": WAIT, "sub": SUB}[state]
        if new_state != row["state"]:
            row["state"] = new_state; pending_events.append((dict(row), state, "flip"))
        lines[index] = fmt(row)
    elif cmd in ("sub-start", "sub-end"):
        if index is None: return context
        count, old_state = int(row.get("sub") or 0), row["state"]
        if cmd == "sub-start":
            row.update(sub=count + 1, state=SUB)
            if old_state in (RUN, WAIT): pending_events.append((dict(row), "sub", "sub-start"))
        else:
            row["sub"] = max(0, count - 1)
            if row["sub"] == 0 and row["state"] == SUB:
                row["state"] = RUN; pending_events.append((dict(row), "run", "sub-end"))
        lines[index] = fmt(row)
    elif cmd in ("log", "finish"):
        repo = clean(args.get("repo")) or (row["repo"] if row else "?")
        parent = clean(args.get("parent") or args.get("summary")) or (row["goal"] if row else "作業")
        plan, time_s = (row.get("plan") if row else None) or PLACEHOLDER, args.get("time") or now
        base = _base_time_for(lines, repo, parent, row)
        mark = _fmt_elapsed(_minutes_between(base, time_s)) if base else ""
        if cmd == "finish" and index is not None:
            pending_events.append((dict(row), "done", "finish")); del lines[index]
        children = [f"{time_s} {mark} {entry}" if offset == 0 and mark else f"{time_s} {entry}" for offset, entry in enumerate(entries)]
        add_children(lines, repo, parent, children); annotate_parent_plan(lines, repo, parent, plan)
        context.update(repo=repo, parent=parent)
    elif cmd == "reconcile":
        demoted = []; reconcile_rows(lines, changed=demoted)
        pending_events += [(row, "wait", "reconcile") for row in demoted]
    else:
        sys.exit(f"unknown command: {cmd}")
    render_body(lines)
    return context


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: board.py <add|update|flip|sub-start|sub-end|sub-label|finish|log|check|show|goals|reconcile|goal-add"
                 "|theme-add|todo-add|steps|step-done|step-doing|step-skip|ask|flow-done|answers> ...")
    cmd, args, entries = parse_args(sys.argv[1:])
    if cmd == "goal-add":
        statement = _stmt_goal_insert(args.get("name"), args.get("date"), args.get("source", "chat"))
        if statement is None: sys.exit('usage: board.py goal-add --name "<目標>" [--date YYYY-MM-DD] [--source chat]')
        _turso_sync([statement], db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE); return
    if cmd == "theme-add":
        # 子09: 大課題テーマの作成（inbox themes）。AI起点は目的・完了条件を必須にし、
        # 欠落は usage 停止＝機械必須化（DB制約では縛らない・人間のボード即席作成は空可）。
        name = (args.get("name") or "").strip()
        purpose = (args.get("purpose") or "").strip()
        done = (args.get("done") or args.get("done-criteria") or "").strip()
        if not name or not purpose or not done:
            sys.exit('usage: board.py theme-add --name "<テーマ名>" --purpose "<目的>" --done "<完了条件>" '
                     '[--goal <的slug>] [--plan <計画slug> ...]  '
                     '（AI起点は目的・完了条件が必須。人間のボード即席作成はボードUI側で空可）')
        plans = args.get("plans") or ([args["plan"]] if args.get("plan") else [])
        theme_id = str(uuid.uuid4())
        statement = _stmt_theme_insert(theme_id, name, purpose, done, args.get("goal"), plans)
        if statement is None:
            sys.exit('usage: board.py theme-add --name "<テーマ名>" --purpose "<目的>" --done "<完了条件>"')
        _turso_sync([statement], db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE)
        print(theme_id)   # 呼び出し元（AI）が update --theme <id> や起票の紐付けに使う
        return
    if cmd == "todo-add":
        # 子03: 今日やること todo を inbox todos へ確定起票（daily-start が使う・theme-add と同型）。
        # CHECK制約列（assignee/source/route）は正当値のみ許可＝不正値は usage 停止（DB制約に頼らず機械保証）。
        title = (args.get("title") or "").strip()
        assignee = args.get("assignee", "self")
        source = args.get("source", "cli")
        route = args.get("route", "plan")
        usage = ('usage: board.py todo-add --title "<やること>" [--note <メモ>] [--date YYYY-MM-DD] '
                 '[--due YYYY-MM-DD] [--repo <slug>] [--assignee self|ai] [--route plan|routine|single] '
                 '[--theme <theme_id>] [--carried-from YYYY-MM-DD] [--source web|chat|cli]')
        if not title:
            sys.exit(usage)
        if assignee not in ("self", "ai"):
            sys.exit(usage + "  （--assignee は self|ai）")
        if source not in ("web", "chat", "cli"):
            sys.exit(usage + "  （--source は web|chat|cli）")
        if route not in ("plan", "routine", "single"):
            sys.exit(usage + "  （--route は plan|routine|single）")
        jst_now = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=9)))
        do_date = (args.get("date") or "").strip() or jst_now.strftime("%Y-%m-%d")
        todo_id = str(uuid.uuid4())
        statement = _stmt_todo_insert(
            todo_id, title, do_date,
            note=args.get("note"), due_date=args.get("due"),
            repo=args.get("repo", "none"), assignee=assignee, source=source, route=route,
            theme_id=args.get("theme"), carried_from=args.get("carried-from"))
        if statement is None:
            sys.exit(usage)
        _turso_sync([statement], db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE)
        print(todo_id)   # 呼び出し元（AI）がステップ登録・質問・セッション紐付けに使う
        return
    if cmd == "sub-label":
        # 子08: サブ個体行へ1行ラベルを付ける（意味づけ＝AI・board DBのsession_subagentsだけを書く）。
        # 委任直後に指揮官が叩く（--nowと同型）。hookは文面を創作せず、ラベルはここ経由のみが正。
        # --seq 未指定=直前に起動した running 行／指定=その連番。MD・体数・状態機械には触れない。
        label_key = args.get("key", "").removeprefix("s:")
        label = args.get("label")
        if not label_key or not (label or "").strip():
            sys.exit('usage: board.py sub-label --key <s:xxxx> --label "<何をやっているか1行>" [--seq <n>]')
        _, date_s = daily_path()
        seq = args.get("seq")
        seq = int(seq) if seq and str(seq).isdigit() else None
        statement = _stmt_subagent_label(f"s:{label_key}", date_s, label, seq)
        if statement:
            _turso_sync([statement])
        return
    # 子05: タスク入れ子・2層チェック（inbox DBのtodos/todo_stepsだけを書く。daily/keyには触れない）。
    if _run_inbox_command(cmd, args, entries):
        return
    key = args.get("key", "").removeprefix("s:")
    if not key and cmd not in ("reconcile", "goals"): sys.exit("--key required")
    path, date_s = daily_path()
    if cmd in ("check", "show", "goals"):
        _read_only(cmd, path, key); return
    if cmd == "reconcile" and not os.path.exists(path): return

    pending_events = []
    with md_store.edit_daily(path, date_s) as lines:
        context = _mutate(cmd, args, entries, key, lines, pending_events)
    # edit_daily正常終了=MD原子置換とflock解放済み。この後だけTursoへ送る。
    if cmd in ("add", "update", "flip", "sub-start", "sub-end"):
        _, row = find_line(lines, key); statement = _stmt_session_upsert(row)
        stmts = ([statement] if statement else []) + _stmts_events(pending_events, date_s)
        # 子09: update --todo/--theme は所属先の宣言。sessions.todo_id/theme_id へ追記UPDATEする
        # （upsert 後に流し、行が存在する前提。MDには載せない＝ボード表示・格納先判定だけに使う board DB 限定列）。
        if cmd == "update" and ("todo" in args or "theme" in args):
            affiliation = _stmt_session_affiliation(key, args.get("todo"), args.get("theme"))
            if affiliation:
                stmts.append(affiliation)
        # 子08: サブ体数±1に合わせて session_subagents へ個体行を積む/閉じる（同一バッチ=HTTP往復1回）。
        # 親行が在る時だけ（row is not None＝存在しないkeyのsub-startは無害・行を作らない）。
        # 体数±1・🔵⇄🟢 の遷移（upsert/events）はそのまま。ここは「中身の見える化」を足すだけ。
        if row and cmd == "sub-start":
            sub_stmt = _stmt_subagent_start(f"s:{key}", date_s)
            if sub_stmt:
                stmts.append(sub_stmt)
        elif row and cmd == "sub-end":
            sub_stmt = _stmt_subagent_end(f"s:{key}", date_s)
            if sub_stmt:
                stmts.append(sub_stmt)
        _turso_sync(stmts)
    elif cmd == "log":
        _turso_sync(_stmts_logs(context["repo"], context["parent"], entries, date_s, session_key=f"s:{key}", todo_id=args.get("todo")))
    elif cmd == "finish":
        _turso_sync(_stmts_logs(context["repo"], context["parent"], entries, date_s, session_key=f"s:{key}", todo_id=args.get("todo"))
                    + [_stmt_session_delete(key)] + _stmts_events(pending_events, date_s))
    elif cmd == "reconcile":
        _turso_sync(_stmts_reconcile(pending_events, date_s))


if __name__ == "__main__":
    main()
