#!/usr/bin/env python3
"""session-board CLI調停。MD確定後にTursoをベストエフォート送信する。"""
import datetime
import os
import sys
import urllib.request  # 既存テスト・外部モック向け互換露出

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
_stmts_logs, _stmts_events = turso_store.stmts_logs, turso_store.stmts_events
_stmts_reconcile, _stmt_goal_insert = turso_store.stmts_reconcile, turso_store.stmt_goal_insert
_spool_paths, _spoolable_statements = turso_spool.paths, turso_spool.spoolable
_spool_append_unchecked, _spool_append = turso_spool.append_unchecked, turso_spool.append
_turso_token = turso_store.token


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


def parse_args(argv):
    cmd, args, entries = argv[0], {}, []
    index = 1
    while index < len(argv):
        key = argv[index]
        if not key.startswith("--"):
            sys.exit(f"unexpected arg: {key}")
        value = argv[index + 1] if index + 1 < len(argv) else ""
        if key == "--entry":
            entries.append(value)
        else:
            args[key[2:]] = value
        index += 2
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
        sys.exit("usage: board.py <add|update|flip|sub-start|sub-end|finish|log|check|show|goals|reconcile|goal-add> ...")
    cmd, args, entries = parse_args(sys.argv[1:])
    if cmd == "goal-add":
        statement = _stmt_goal_insert(args.get("name"), args.get("date"), args.get("source", "chat"))
        if statement is None: sys.exit('usage: board.py goal-add --name "<目標>" [--date YYYY-MM-DD] [--source chat]')
        _turso_sync([statement], db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE); return
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
        _turso_sync(([statement] if statement else []) + _stmts_events(pending_events, date_s))
    elif cmd == "log":
        _turso_sync(_stmts_logs(context["repo"], context["parent"], entries, date_s))
    elif cmd == "finish":
        _turso_sync(_stmts_logs(context["repo"], context["parent"], entries, date_s)
                    + [_stmt_session_delete(key)] + _stmts_events(pending_events, date_s))
    elif cmd == "reconcile":
        _turso_sync(_stmts_reconcile(pending_events, date_s))


if __name__ == "__main__":
    main()
