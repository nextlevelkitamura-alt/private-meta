#!/usr/bin/env bash
# daily-start / fetch-context.sh
# 朝会（計画確認→選択→AI割り振り→承認）に必要な「決定的に集められる文脈」をJSONで1回だけ吐く収集スクリプト。
# 2026-07-22 子03（朝会刷新）で orientation を変更: 作文起票のための材料集めではなく、
# 「active計画の工程進捗の要約」を中心に据える。テーマ/やることをAIが作文する前提を廃止し、
# 起票は選択計画の「## 工程」節を読んで board.py steps へ流す（作文ゼロ）。
#
# 集めるもの:
#   - active計画の一覧と「## 工程」節の進捗要約（済/全ステップ数・未消化ステップ文＝子03で追加）
#   - 当日/前日/月間計画のパス解決（存在フラグ付き）
#   - 繰越し候補 todos（inbox DB: do_date < today AND status='open'）
#   - 既存の active テーマ（inbox DB: 紐付け候補＝新規作成の重複回避に使う。作文の種ではない）
#   - 前日 session_logs（board DB: session_date = 前日＝繰越し・滞留判断の文脈）
# 送信層は session-board の turso/store.py を import 再利用する（plansync と同じ sys.path 方式・二重実装しない）。
#
# 契約:
#   - secret / token / DB URL の auth 部は絶対に出力しない（store.read が Keychain 経由で扱い値は表に出ない）。
#   - Turso 不通・SESSION_BOARD_NO_TURSO 時は read()=None。該当配列は空、turso.*_read="unavailable" と明示する（黙って空にしない）。
#   - md 本文の扱い: 当日/前日/月間デイリーmd はパス解決だけ（本文は呼び出し元スキルが Read）。
#     active計画の「## 工程」/「## 実行ライン」節だけは、選択のための軽量要約としてここで読む（子03で contract を緩和）。
#     選択後の確定起票では、呼び出し元スキルが選択計画を Read して工程節の正文を board.py steps へ渡す（作文ゼロの担保）。
#
# 使い方:
#   fetch-context.sh [--date YYYY-MM-DD]
#   環境変数 GOAL_BASE / AREAS_BASE / PLAN_ACTIVE_ROOTS / SESSION_BOARD_DATE / SESSION_BOARD_NO_TURSO を尊重する（テスト時の注入点）。
set -euo pipefail

# スクリプト実体のディレクトリを python へ渡す（heredoc 実行では __file__ が無いため）。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DAILY_START_SCRIPTS_DIR="$SCRIPT_DIR"

exec python3 - "$@" <<'PY'
import datetime
import glob
import json
import os
import re
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

# --- active計画の「## 工程」節の進捗要約（子03・朝会刷新の中核） ---
# roots: PLAN_ACTIVE_ROOTS（:区切り・各 plans/active ディレクトリ）で差し替え可。
# 既定は areas/*/plans/active（my-brain の領域別計画）。repo-local の active 計画はここでは
# 自動走査しない（構造が repo ごとに異なるため。必要なら PLAN_ACTIVE_ROOTS で明示追加する）。
# 節名は移行期の別名を許す: 旧「## 工程」(テンプレv2) と 新「## 実行ライン」(テンプレv3・直列化)。
_PROC_HEADS = ("## 工程", "## 実行ライン")
_DONE_RE = re.compile(r"^- \[[xX]\]\s+(.*)$")
_OPEN_RE = re.compile(r"^- \[ \]\s+(.*)$")
_PRIO_RE = re.compile(r"^優先[:：]\s*(\S+)")


def _read_head(path, n=40000):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read(n)
    except Exception:
        return ""


def _priority(text):
    for line in text.splitlines()[:25]:
        m = _PRIO_RE.match(line.strip())
        if m:
            return m.group(1)
    return None


def _scan_process(text):
    """md本文から「## 工程」節を切り出し、済/全ステップ数と未消化ステップ文を返す。
    次の `## ` 見出しで節終了。工程節が無ければ has_section=False・total0。"""
    in_sec = False
    total = done = 0
    open_steps = []
    for raw in text.splitlines():
        s = raw.strip()
        if s.startswith("## "):
            if any(s.startswith(h) for h in _PROC_HEADS):
                in_sec = True
                continue
            if in_sec:
                break
        if not in_sec:
            continue
        md = _DONE_RE.match(s)
        if md:
            total += 1
            done += 1
            continue
        mo = _OPEN_RE.match(s)
        if mo:
            total += 1
            open_steps.append(mo.group(1).strip())
    return in_sec, total, done, open_steps


def _plan_active_roots():
    env = os.environ.get("PLAN_ACTIVE_ROOTS")
    if env:
        return [r for r in env.split(":") if r]
    areas_base = os.environ.get("AREAS_BASE") or os.path.expanduser("~/Private/personal-os/my-brain/areas")
    return sorted(glob.glob(os.path.join(areas_base, "*", "plans", "active")))


def _area_of(root):
    # root = <...>/areas/<area>/plans/active → area = 2つ上のフォルダ名
    parts = os.path.normpath(root).split(os.sep)
    try:
        return parts[parts.index("plans") - 1]
    except ValueError:
        return None


active_plans = []
for root in _plan_active_roots():
    if not os.path.isdir(root):
        continue
    area = _area_of(root)
    for entry in sorted(os.listdir(root)):
        pdir = os.path.join(root, entry)
        if not os.path.isdir(pdir):
            continue
        program_md = os.path.join(pdir, "program.md")
        plan_md = os.path.join(pdir, "plan.md")
        is_program = os.path.isfile(program_md)
        doc = program_md if is_program else (plan_md if os.path.isfile(plan_md) else None)
        if doc is None:
            continue
        prio = _priority(_read_head(doc))
        if is_program:
            # program の工程節は子 plans/*.md 側にある。子ごとに要約し親で集計する。
            children = []
            total = done = 0
            has_any = False
            for child in sorted(glob.glob(os.path.join(pdir, "plans", "*.md"))):
                c_has, c_total, c_done, c_open = _scan_process(_read_head(child))
                has_any = has_any or c_has
                total += c_total
                done += c_done
                children.append({
                    "name": os.path.splitext(os.path.basename(child))[0],
                    "path": child,
                    "has_process_section": c_has,
                    "steps_total": c_total,
                    "steps_done": c_done,
                    "next_steps": c_open,
                })
            active_plans.append({
                "name": entry, "area": area, "doc_path": doc, "is_program": True,
                "priority": prio, "has_process_section": has_any,
                "steps_total": total, "steps_done": done,
                "next_steps": [], "children": children,
            })
        else:
            has_sec, total, done, open_steps = _scan_process(_read_head(doc))
            active_plans.append({
                "name": entry, "area": area, "doc_path": doc, "is_program": False,
                "priority": prio, "has_process_section": has_sec,
                "steps_total": total, "steps_done": done,
                "next_steps": open_steps, "children": [],
            })

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
    # 既存 active テーマ（紐付け候補＝新規テーマ作成の重複回避に使う。作文の種ではない）。
    # board.py に theme一覧の読み取りコマンドが無いので、ここで決定的に集める（board.py は変更しない）。
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
    "active_plans": active_plans,
    "active_plans_count": len(active_plans),
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
