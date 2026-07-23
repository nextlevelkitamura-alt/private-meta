#!/usr/bin/env python3
"""session-board CLI調停。MD確定後にTursoをベストエフォート送信する。"""
import datetime
import json
import os
import re
import sys
import urllib.request  # 既存テスト・外部モック向け互換露出
import uuid  # 子09 theme-add のテーマID採番

from md import store as md_store
from turso import spool as turso_spool
from turso import store as turso_store
from sanitize import sanitize_text

# 2026-07-21 正本反転（子03・案b）: board.py は当日デイリーMDを一切読み書きしない。
# 運用データ（sessions/events/logs/subagents）の正本は Turso（board DB）。md_store は
# 日付解決と生存照合の純ユーティリティだけを提供する（MD描画・行parse・原子的置換は廃止）。
RUN, WAIT, SUB = md_store.RUN, md_store.WAIT, md_store.SUB
STATE_WORD = md_store.STATE_WORD
STALE_MIN, STALE_MIN_SUB = md_store.STALE_MIN, md_store.STALE_MIN_SUB
STALE_MIN_NOFILE, NOFILE_MAX = md_store.STALE_MIN_NOFILE, md_store.NOFILE_MAX
PLACEHOLDER = md_store.PLACEHOLDER
daily_path = md_store.daily_path
clean = md_store.clean
_tx_roots, _list_transcripts, _newest_for = md_store.tx_roots, md_store.list_transcripts, md_store.newest_for
_minutes_between = md_store.minutes_between
# 状態語彙 word→emoji（DB上の run/wait/sub を内部rowの絵文字へ戻す）。
_WORD_STATE = {"run": RUN, "wait": WAIT, "sub": SUB}

# Turso公開名の互換re-export。送信ラッパーはmonkeypatch可能性を保つ。
TURSO_DB_URL, TURSO_KEYCHAIN_SERVICE = turso_store.DB_URL, turso_store.KEYCHAIN_SERVICE
TURSO_INBOX_DB_URL, TURSO_INBOX_KEYCHAIN_SERVICE = turso_store.INBOX_DB_URL, turso_store.INBOX_KEYCHAIN_SERVICE
TURSO_TIMEOUT, TURSO_SPOOL_LIMIT = turso_store.TIMEOUT, turso_spool.LIMIT
_ta, _ia = turso_store.text_arg, turso_store.int_arg
_stmt_session_upsert = turso_store.stmt_session_upsert
_stmt_session_delete = turso_store.stmt_session_delete
# 子03 正本反転: sessions のDB読み（単体/生存中全件/目標一覧）。board.py はここから状態を得る。
_stmt_session_read = turso_store.stmt_session_read
_stmt_sessions_alive = turso_store.stmt_sessions_alive
_stmt_goals_distinct = turso_store.stmt_goals_distinct
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
_stmt_execution_context_upsert = turso_store.stmt_execution_context_upsert
_stmt_route_pending = turso_store.stmt_route_pending
_stmt_route_propose = turso_store.stmt_route_propose
_stmt_execution_context_read = turso_store.stmt_execution_context_read
_stmt_session_route_read = turso_store.stmt_session_route_read
_stmt_latest_route_read = turso_store.stmt_latest_route_read
_stmt_route_turn_read = turso_store.stmt_route_turn_read
_stmt_theme_candidates = turso_store.stmt_theme_candidates
_stmt_plan_candidates = turso_store.stmt_plan_candidates
_turso_read = turso_store.read
_turso_read_many = turso_store.read_many

# board.py自身の実体ディレクトリ（route宣言スキャンの既定ルート算出に使う）。
_SB_DIR = os.path.dirname(os.path.abspath(__file__))
# frontmatterの `board_route: routine` 宣言（skill/loop正本の1行が正本・第2の台帳を作らない）。
_ROUTE_RE = re.compile(r"^board_route:\s*routine\s*$", re.M)

# 子03: サブエージェントへ渡すプロンプト保存前の簡易マスキング。
# `key: value` / `key=value` 形の秘密らしき値だけを [masked] へ潰す（キーと区切りは残す）。
# 規約: 過剰マスクより「取りこぼし防止」を優先する＝疑わしい形は広めに潰し、誤検知で本文の一部が
#   masked 化するのは許容する。完全な秘密検出ではない＝board DBへ全文TEXT保存する前段の粗いフィルタで、
#   UIは1行要約＋折りたたみ表示にする。secret/tokenの値そのものはここでもログにも残さない。
_SECRET_RE = re.compile(
    r"(?i)(api[_-]?key|secret[_-]?key|access[_-]?key|token|secret|password|passwd|bearer|authorization)"
    r"(\s*[:=]\s*)(\S+)")


def _mask_secrets(text):
    """プロンプト内の秘密らしき値を [masked] へ置換して返す。None/空は None。"""
    if not text:
        return None
    return _SECRET_RE.sub(lambda m: f"{m.group(1)}{m.group(2)}[masked]", text)


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


def _session_from_db(db_row):
    """board DB の sessions 1行（word状態・model列）を内部row（絵文字状態・who列）へ写す。
    正本反転後の唯一の状態入口。runtime接頭辞（claude/ 等）はDBに持たないため who=model となる
    （表示・分析はfocusmap側がmodel列を読む・接頭辞は非永続＝正本反転の帰結）。"""
    key = (db_row.get("session_key") or "").removeprefix("s:")
    state = _WORD_STATE.get(db_row.get("state") or "run", RUN)
    model = db_row.get("model") or ""
    return {"state": state, "time": "", "goal": db_row.get("goal") or PLACEHOLDER,
            "now": db_row.get("now") or PLACEHOLDER, "repo": db_row.get("repo") or "?",
            "type": db_row.get("type") or "その他", "who": model or PLACEHOLDER,
            "plan": db_row.get("plan") or PLACEHOLDER, "key": key,
            "sub": int(db_row.get("sub_n") or 0)}


def _load_row(key):
    """key の現在セッション行を board DB から読む。無い/読めない（オフライン・NO_TURSO）は None。
    best-effort＝読めない時は「新規/不明」として扱い本体セッションを止めない（自己修復は次回・reconcile）。"""
    if not key:
        return None
    rows = _turso_read(_stmt_session_read(key))
    return _session_from_db(rows[0]) if rows else None


def _minutes_since_iso(iso_s, now_dt):
    """ISO時刻から now_dt までの経過分。updated_at（最終書込）を沈黙判定の起点に使う。
    未来時刻（逆行クロック）は負値のまま返し、上限レンジ判定で弾かせる。"""
    if not iso_s:
        return None
    try:
        return (now_dt - datetime.datetime.fromisoformat(iso_s)).total_seconds() / 60
    except Exception:
        return None


def reconcile_db(now_dt=None):
    """DB上の run/sub セッション × 実トランスクリプト生存で照合し、沈黙した行を⏸へ降格する。
    降格対象の内部row（state=WAIT・sub=0）のリストを返す（main が upsert+event を送る）。
    生存判定ロジックは旧MD reconcile を流用: mtime経路（transcriptあり）は最終更新からの沈黙、
    ファイル皆無経路（transcriptなし）は updated_at からの沈黙で判定。files が皆無なら降格しない
    （探索不能時に全行を一括⏸にしない安全弁）。"""
    rows = _turso_read(_stmt_sessions_alive())
    if not rows:
        return []
    now_dt = now_dt or datetime.datetime.now()
    files, demoted = None, []
    for db_row in rows:
        row = _session_from_db(db_row)
        if row["state"] not in (RUN, SUB):
            continue
        if files is None:
            files = _list_transcripts()
        transcript = _newest_for(row["key"], files)
        demote = False
        if transcript is None:
            age = _minutes_since_iso(db_row.get("updated_at"), now_dt)
            limit = STALE_MIN_SUB if row["state"] == SUB else STALE_MIN_NOFILE
            demote = bool(files) and age is not None and limit < age < NOFILE_MAX
        else:
            limit = STALE_MIN_SUB if row["state"] == SUB else STALE_MIN
            try:
                demote = (now_dt.timestamp() - os.path.getmtime(transcript)) / 60 >= limit
            except OSError:
                pass
        if demote:
            row.update(state=WAIT, sub=0)
            demoted.append(row)
    return demoted


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


def _turso_read_many_inbox(statements):
    """inbox DBの複数SELECTを1 pipelineで読む。失敗時は None。"""
    return _turso_read_many(
        statements,
        db_url=TURSO_INBOX_DB_URL,
        service=TURSO_INBOX_KEYCHAIN_SERVICE,
        token_getter=_turso_token,
    )


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


def _routing_context_payload(session_key, repo_label=None, date_s=None):
    """board/inboxを各1 pipelineで読み、短い分類Contextの材料だけ返す。"""
    board_batches = _turso_read_many([
        _stmt_execution_context_read(session_key),
        _stmt_session_route_read(session_key),
        _stmt_latest_route_read(session_key),
    ]) or [[], [], []]
    while len(board_batches) < 3:
        board_batches.append([])
    context_rows, session_rows, latest_rows = board_batches[:3]
    execution = context_rows[0] if context_rows else None
    label = (repo_label or (execution or {}).get("display_name") or "").strip()
    if not date_s:
        _, date_s = daily_path()
    inbox_batches = _turso_read_many_inbox([
        _stmt_theme_candidates(date_s, label, 5),
        _stmt_plan_candidates(date_s, label, 5),
    ]) or [[], []]
    while len(inbox_batches) < 2:
        inbox_batches.append([])
    return {
        "execution": execution,
        "session_route": session_rows[0] if session_rows else None,
        "latest_route": latest_rows[0] if latest_rows else None,
        "themes": inbox_batches[0],
        "plans": inbox_batches[1],
        "candidate_scope": {"date": date_s, "repo": label},
    }


def _routing_context_from_args(args):
    return {
        "runtime": args.get("runtime"),
        "repo_key": args.get("repo-key"),
        "display_name": args.get("display-name"),
        "scope_kind": args.get("scope-kind"),
        "identity_state": args.get("identity-state"),
        "canonical_repo_path": args.get("repo-path") or None,
        "worktree_root": args.get("worktree-root"),
        "cwd_path": args.get("cwd-path"),
        "branch": args.get("branch") or None,
    }


def _run_routing_command(cmd, args):
    """分類用のadditive表を操作する。migration未適用時もbest-effortで本体を止めない。"""
    session_key = args.get("key") or ""
    session_key = session_key if session_key.startswith("s:") else ("s:" + session_key if session_key else "")
    if cmd == "context-upsert":
        statement = _stmt_execution_context_upsert(session_key, _routing_context_from_args(args))
        if statement:
            _turso_sync([statement])
        return True
    if cmd == "route-pending":
        statement = _stmt_route_pending(
            args.get("id"), session_key, args.get("turn"), args.get("runtime"),
            args.get("repo-key"), args.get("event-fingerprint") or args.get("fingerprint"),
            sanitize_text(args.get("summary"), 80))
        if statement:
            _turso_sync([statement])
        return True
    if cmd == "route-prepare":
        context = _routing_context_from_args(args)
        statements = [
            _stmt_execution_context_upsert(session_key, context),
            _stmt_route_pending(
                args.get("id"), session_key, args.get("turn"), args.get("runtime"),
                args.get("repo-key"), args.get("event-fingerprint"),
                sanitize_text(args.get("summary"), 80),
            ),
        ]
        _turso_sync([statement for statement in statements if statement])
        print(json.dumps(_routing_context_payload(
            session_key,
            repo_label=context.get("display_name"),
            date_s=args.get("date"),
        ), ensure_ascii=False))
        return True
    if cmd == "route-propose":
        safe_summary = sanitize_text(args.get("summary"), 80) if args.get("summary") is not None else None
        safe_reason = sanitize_text(args.get("reason"), 160) if args.get("reason") is not None else None
        statement = _stmt_route_propose(
            session_key, args.get("turn"), args.get("kind"), args.get("status", "proposed"),
            args.get("theme"), args.get("plan"), safe_summary, safe_reason)
        if statement is None:
            sys.exit("usage: board.py route-propose --key <s:key> --turn <id> --kind <plan|theme_work|plan_candidate|theme_candidate|unclassified> [--status proposed|accepted|rejected|superseded] [--theme <id>] [--plan <slug>] [--summary <safe>] [--reason <safe>]")
        _turso_sync([statement])
        rows = _turso_read(_stmt_route_turn_read(session_key, args.get("turn"))) or []
        if not rows:
            print("unavailable")
        elif rows[0].get("route_kind") == args.get("kind") and rows[0].get("status") == args.get("status", "proposed"):
            print(f"recorded status={rows[0].get('status')}")
        else:
            print(f"unchanged status={rows[0].get('status')}")
        return True
    if cmd == "route-context":
        print(json.dumps(_routing_context_payload(
            session_key,
            repo_label=args.get("repo"),
            date_s=args.get("date"),
        ), ensure_ascii=False))
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


def _read_only(cmd, key):
    """check / show / goals を board DB から読む（正本反転後・MDは読まない）。
    出力フォーマットは現行互換（check=状態word1行 / show=7タブフィールド / goals=1行1目標）。
    読めない（オフライン・NO_TURSO）は check/show=missing、goals=空（best-effort・hookを止めない）。"""
    if cmd == "goals":
        rows = _turso_read(_stmt_goals_distinct())
        for db_row in rows or []:
            goal = db_row.get("goal")
            if goal and goal != PLACEHOLDER:
                print(goal)
        return
    row = _load_row(key)
    if row is None:
        print("missing")
    elif cmd == "check":
        print(STATE_WORD.get(row["state"], "wait"))
    else:
        print("\t".join([STATE_WORD.get(row["state"], "wait"), row["goal"], row["now"],
                         row["type"], row["repo"], row["who"], row.get("plan") or PLACEHOLDER]))


def _mutate_db(cmd, args, entries, key, row, pending_events):
    """DB-first の状態遷移計算（MDには一切触れない）。row=board DB から読んだ現在行（無ければ None）。
    session を書く系（add/update/flip/sub-*）は「upsert する最終row」を返す（None=書込み不要/対象なし）。
    log/finish は session_logs 追記が主で、repo/parent の補完だけ row を使う。context に repo/parent を返す。
    3状態（🟢⏸🔵）・体数・イベント発行の意味は正本反転前と同一。"""
    now = datetime.datetime.now().strftime("%H:%M")   # 新規addの time 既定（DBは未使用・引数互換のため保持）
    context = {"repo": None, "parent": None}

    if cmd == "add":
        if row is None:   # 新規のみ枠を作る（既存は冪等＝そのまま再upsert・event無し）
            row = {"state": RUN, "time": args.get("time") or now,
                   "goal": clean(args.get("goal") or args.get("summary")) or PLACEHOLDER,
                   "now": clean(args.get("now")) or PLACEHOLDER,
                   "repo": clean(args.get("repo")) or "?", "type": clean(args.get("type")) or "その他",
                   "who": clean(args.get("who")) or PLACEHOLDER,
                   "plan": clean(args.get("plan")) or PLACEHOLDER, "key": key, "sub": 0}
            pending_events.append((dict(row), "run", "add"))
        return row, context

    if cmd == "update":
        if row is None:
            return None, context   # 対象行が無い/読めない → best-effort no-op（非ブロッキング・次回自己修復）
        if "goal" in args or "summary" in args: row["goal"] = clean(args.get("goal") or args.get("summary")) or PLACEHOLDER
        if "now" in args: row["now"] = clean(args["now"]) or PLACEHOLDER
        if "repo" in args: row["repo"] = clean(args["repo"]) or row["repo"]
        if "type" in args: row["type"] = clean(args["type"]) or row["type"]
        if "who" in args: row["who"] = clean(args["who"]) or PLACEHOLDER
        elif "model" in args:
            base, model = (row["who"].split("/")[0] if "/" in row["who"] else ""), clean(args["model"])
            row["who"] = f"{base}/{model}" if base and model else (model or row["who"])
        if "plan" in args: row["plan"] = clean(args["plan"]) or PLACEHOLDER
        return row, context

    if cmd == "flip":
        if row is None: return None, context
        state = args.get("state")
        if state not in ("run", "wait", "sub"): return row, context   # 不明stateは現状維持のまま再upsert
        new_state = {"run": RUN, "wait": WAIT, "sub": SUB}[state]
        if new_state != row["state"]:
            row["state"] = new_state; pending_events.append((dict(row), state, "flip"))
        return row, context   # 同状態でも upsert（従来挙動・event は変化時のみ）

    if cmd in ("sub-start", "sub-end"):
        if row is None: return None, context
        count, old_state = int(row.get("sub") or 0), row["state"]
        if cmd == "sub-start":
            row.update(sub=count + 1, state=SUB)
            if old_state in (RUN, WAIT): pending_events.append((dict(row), "sub", "sub-start"))
        else:
            row["sub"] = max(0, count - 1)
            if row["sub"] == 0 and row["state"] == SUB:
                row["state"] = RUN; pending_events.append((dict(row), "run", "sub-end"))
        return row, context

    if cmd in ("log", "finish"):
        repo = clean(args.get("repo")) or (row["repo"] if row else "?")
        parent = clean(args.get("parent") or args.get("summary")) or (row["goal"] if row else "作業")
        if cmd == "finish" and row is not None:
            pending_events.append((dict(row), "done", "finish"))   # 削除前スナップショット（done event）
        context.update(repo=repo, parent=parent)
        return row, context

    if cmd == "reconcile":
        demoted = reconcile_db()
        pending_events += [(dr, "wait", "reconcile") for dr in demoted]
        return None, context

    sys.exit(f"unknown command: {cmd}")


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: board.py <add|update|flip|sub-start|sub-end|sub-label|finish|log|check|show|goals|reconcile|goal-add"
                 "|theme-add|todo-add|steps|step-done|step-doing|step-skip|ask|flow-done|answers"
                 "|context-upsert|route-pending|route-prepare|route-context|route-propose> ...")
    cmd, args, entries = parse_args(sys.argv[1:])
    if _run_routing_command(cmd, args):
        return
    if cmd == "goal-add":
        statement = _stmt_goal_insert(args.get("name"), args.get("date"), args.get("source", "chat"))
        if statement is None: sys.exit('usage: board.py goal-add --name "<目標>" [--date YYYY-MM-DD] [--source chat]')
        _turso_sync([statement], db_url=TURSO_INBOX_DB_URL, service=TURSO_INBOX_KEYCHAIN_SERVICE); return
    if cmd == "theme-add":
        # 子03（朝会刷新）: テーマ＝意図1行に簡素化。必須は --name（意図1行）だけにする。
        # 目的(--purpose)・完了条件(--done)は任意で、欠落時は builder が NULL 保存＝focusmap 側の
        # 「未記入バッジ」がそのまま出る（空テーマの扱いは不変）。完了条件の正本は計画md側へ一本化する。
        # （旧・子09: AI起点は目的・完了条件も必須にしていた＝テーマ名≒完了条件の三重コピーの一因。緩和）
        name = (args.get("name") or "").strip()
        purpose = (args.get("purpose") or "").strip()
        done = (args.get("done") or args.get("done-criteria") or "").strip()
        if not name:
            sys.exit('usage: board.py theme-add --name "<テーマ=意図1行>" '
                     '[--purpose <目的>] [--done <完了条件>] [--goal <的slug>] [--plan <計画slug> ...]  '
                     '（必須は意図1行の --name のみ。完了条件の正本は計画md側）')
        plans = args.get("plans") or ([args["plan"]] if args.get("plan") else [])
        theme_id = str(uuid.uuid4())
        statement = _stmt_theme_insert(theme_id, name, purpose, done, args.get("goal"), plans)
        if statement is None:
            sys.exit('usage: board.py theme-add --name "<テーマ=意図1行>" [--purpose <目的>] [--done <完了条件>]')
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
                 '[--theme <theme_id>] [--plan <slug#NN>] [--carried-from YYYY-MM-DD] [--source web|chat|cli]')
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
            theme_id=args.get("theme"), carried_from=args.get("carried-from"),
            plan_slug=args.get("plan"))   # 子02: 計画リンク（slug#NN）。--plan で受ける
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
    _, date_s = daily_path()   # date_s は session_events/logs の session_date に使う（MDは開かない）
    if cmd in ("check", "show", "goals"):
        _read_only(cmd, key); return

    # 正本反転（子03・案b）: MDを介さず、board DB から現在行を読んで遷移計算 → DBへ書く（best-effort）。
    # sessions の upsert/delete は spool しない（死んだ行の復活を防ぐ・追記系のみ再送）。読めない時は
    # no-op で本体を止めず、次回コマンド/reconcile がDB状態と実態を突き合わせて自己修復する。
    pending_events = []
    need_row = cmd in ("add", "update", "flip", "sub-start", "sub-end", "log", "finish")
    row = _load_row(key) if need_row else None
    final_row, context = _mutate_db(cmd, args, entries, key, row, pending_events)

    if cmd in ("add", "update", "flip", "sub-start", "sub-end"):
        statement = _stmt_session_upsert(final_row)   # final_row=None なら builder が None を返す＝送らない
        stmts = ([statement] if statement else []) + _stmts_events(pending_events, date_s)
        # 子09: update --todo/--theme は所属先の宣言。sessions.todo_id/theme_id へ追記UPDATEする
        # （upsert 後に流し、行が存在する前提。MDには載せない＝ボード表示・格納先判定だけに使う board DB 限定列）。
        if cmd == "update" and ("todo" in args or "theme" in args):
            affiliation = _stmt_session_affiliation(key, args.get("todo"), args.get("theme"))
            if affiliation:
                stmts.append(affiliation)
        # 子08: サブ体数±1に合わせて session_subagents へ個体行を積む/閉じる（同一バッチ=HTTP往復1回）。
        # 親行が在る時だけ（final_row is not None＝存在しないkeyのsub-startは無害・行を作らない）。
        # 体数±1・🔵⇄🟢 の遷移（upsert/events）はそのまま。ここは「中身の見える化」を足すだけ。
        if final_row and cmd == "sub-start":
            # 子03: 詳細5列（全て任意・後方互換）。--type=agent_type / --via=launch_via。
            # prompt は保存前に簡易マスキング。詳細が全て空なら store 側が旧来の狭いINSERTへ落ちる。
            sub_stmt = _stmt_subagent_start(
                f"s:{key}", date_s,
                runtime=clean(args.get("runtime")) or None,
                model=clean(args.get("model")) or None,
                agent_type=clean(args.get("type")) or None,
                launch_via=clean(args.get("via")) or None,
                prompt=_mask_secrets(args.get("prompt")))
            if sub_stmt:
                stmts.append(sub_stmt)
        elif final_row and cmd == "sub-end":
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
