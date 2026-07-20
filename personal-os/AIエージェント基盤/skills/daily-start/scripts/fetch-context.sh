#!/usr/bin/env bash
# daily-start / fetch-context.sh
# 朝の起票に必要な「決定的に集められる文脈」をJSONで1回だけ吐く収集スクリプト。
#
# 集めるもの:
#   - 当日/前日/月間計画のパス解決（存在フラグ付き）
#   - 繰越し候補 todos（inbox DB: do_date < today AND status='open'）
#   - 前日 session_logs（board DB: session_date = 前日）
# 送信層は session-board の turso/store.py を import 再利用する（plansync と同じ sys.path 方式・二重実装しない）。
#
# 契約:
#   - secret / token / DB URL の auth 部は絶対に出力しない（store.read が Keychain 経由で扱い値は表に出ない）。
#   - Turso 不通・SESSION_BOARD_NO_TURSO 時は read()=None。該当配列は空、turso.*_read="unavailable" と明示する（黙って空にしない）。
#   - md 本文は読まない・書かない（パス解決だけ）。本文の解釈は呼び出し元スキルが Read で行う。
#
# 使い方:
#   fetch-context.sh [--date YYYY-MM-DD]
#   環境変数 GOAL_BASE / SESSION_BOARD_DATE / SESSION_BOARD_NO_TURSO を尊重する（テスト時の注入点）。
set -euo pipefail

# スクリプト実体のディレクトリを python へ渡す（heredoc 実行では __file__ が無いため）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DAILY_START_SCRIPTS_DIR="$SCRIPT_DIR"

exec python3 - "$@" <<'PY'
import datetime
import json
import os
import sys

# --- 引数 ---
date_override = None
argv = sys.argv[1:]
i = 0
while i < len(argv):
    if argv[i] == "--date" and i + 1 < len(argv):
        date_override = argv[i + 1]
        i += 2
    else:
        sys.stderr.write(f"unexpected arg: {argv[i]}\n")
        sys.exit(2)

# --- session-board turso 層の import（plansync と同じ相対解決） ---
# scripts -> daily-start -> skills -> AIエージェント基盤 -> hooks-registry/shared/session-board
_scripts_dir = os.environ.get("DAILY_START_SCRIPTS_DIR", "")
_SB = ""
if _scripts_dir:
    _SB = os.path.normpath(os.path.join(_scripts_dir, "..", "..", "..",
                                        "hooks-registry", "shared", "session-board"))
# scripts_dir が無い/解決できない環境では既知の基盤ルートから解決する。
if not (_SB and os.path.isdir(_SB)):
    _base = os.path.expanduser("~/Private/personal-os/AIエージェント基盤")
    _SB = os.path.join(_base, "hooks-registry", "shared", "session-board")

store = None
if os.path.isdir(_SB) and _SB not in sys.path:
    sys.path.insert(0, _SB)
try:
    from turso import store as _store  # noqa: E402
    store = _store
except Exception:
    store = None

# --- 日付解決（JST・SESSION_BOARD_DATE / --date で注入可） ---
JST = datetime.timezone(datetime.timedelta(hours=9))
today_s = date_override or os.environ.get("SESSION_BOARD_DATE") or datetime.datetime.now(JST).strftime("%Y-%m-%d")
today = datetime.date.fromisoformat(today_s)
yesterday = today - datetime.timedelta(days=1)
yesterday_s = yesterday.isoformat()

# --- パス解決（daily_path と同じ規約: <base>/<年>/<月>/<YYYY-MM-DD>.md） ---
goal_base = os.environ.get("GOAL_BASE") or os.path.expanduser("~/Private/personal-os/my-brain/ゴール/デイリー")


def daily_md(d):
    return os.path.join(goal_base, f"{d.year:04d}", f"{d.month:02d}", f"{d.isoformat()}.md")


def monthly_md(d):
    return os.path.join(goal_base, f"{d.year:04d}", f"{d.month:02d}", "月間計画.md")


today_daily = daily_md(today)
yest_daily = daily_md(yesterday)
monthly_plan = monthly_md(today)

# --- Turso 読み取り（best-effort・値としての token は一切出さない） ---
INBOX_DB_URL = getattr(store, "INBOX_DB_URL", None) if store else None
INBOX_SVC = getattr(store, "INBOX_KEYCHAIN_SERVICE", None) if store else None
BOARD_DB_URL = getattr(store, "DB_URL", None) if store else None
BOARD_SVC = getattr(store, "KEYCHAIN_SERVICE", None) if store else None

carried_todos = []
active_themes = []
inbox_read = "unavailable"
if store and INBOX_DB_URL:
    sql = ("SELECT id, title, note, do_date, due_date, repo, assignee, status, ai_status, goal_ref "
           "FROM todos WHERE do_date < ? AND status = 'open' ORDER BY do_date, created_at")
    rows = store.read((sql, [store.text_arg(today_s)]),
                      db_url=INBOX_DB_URL, service=INBOX_SVC, token_getter=store.token)
    if rows is not None:
        carried_todos = rows
        inbox_read = "ok"
    # 既存 active テーマ（themes照合の入力＝重複作成を避けるため）。board.py に theme一覧の
    # 読み取りコマンドが無いので、ここで決定的に集める（board.py は変更しない）。
    tsql = ("SELECT id, name, purpose, done_criteria, goal_ref, sort_order "
            "FROM themes WHERE status = 'active' ORDER BY sort_order")
    trows = store.read((tsql, []),
                       db_url=INBOX_DB_URL, service=INBOX_SVC, token_getter=store.token)
    if trows is not None:
        active_themes = trows

yesterday_logs = []
board_read = "unavailable"
if store and BOARD_DB_URL:
    sql = ("SELECT repo, parent, entry, todo_id, session_key, created_at "
           "FROM session_logs WHERE session_date = ? ORDER BY created_at")
    rows = store.read((sql, [store.text_arg(yesterday_s)]),
                      db_url=BOARD_DB_URL, service=BOARD_SVC, token_getter=store.token)
    if rows is not None:
        yesterday_logs = rows
        board_read = "ok"

out = {
    "date": today_s,
    "yesterday": yesterday_s,
    "paths": {
        "monthly_plan": monthly_plan,
        "monthly_plan_exists": os.path.exists(monthly_plan),
        "yesterday_daily": yest_daily,
        "yesterday_daily_exists": os.path.exists(yest_daily),
        "today_daily": today_daily,
        "today_daily_exists": os.path.exists(today_daily),
    },
    "carried_todos": carried_todos,
    "carried_todos_count": len(carried_todos),
    "active_themes": active_themes,
    "active_themes_count": len(active_themes),
    "yesterday_session_logs": yesterday_logs,
    "yesterday_session_logs_count": len(yesterday_logs),
    "turso": {
        "inbox_read": inbox_read,
        "board_read": board_read,
        "store_imported": store is not None,
    },
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
