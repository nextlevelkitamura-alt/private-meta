"""デイリー日付の解決と、実トランスクリプトによる生存照合の日付/ファイルユーティリティ。

2026-07-21 正本反転（program「当日ボードSQL化」子03・案b）で、当日デイリーMarkdownへの
描画・parse・原子的置換は廃止した。session-board の運用データ正本はDB（board）に一本化し、
board.py は MD を一切読み書きしない。このモジュールは MD I/O を持たず、次の2種の純ユーティリティだけを残す:

  1. daily_path(): 当日デイリーの日付・path 解決（date_s は session_events/logs の session_date に使う）。
  2. tx_roots / list_transcripts / newest_for / minutes_between: reconcile の生存照合が使う
     トランスクリプト探索と時刻差の純関数（DB上の run/sub 行が実セッションで生きているかの照合に流用）。

HTTP・keychain・secret・DB送信には依存しない（board.py・送信層が持つ）。行形式・描画・ロックは持たない。
"""
import datetime
import glob
import os

# 状態の3値（🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中）。board.py・送信層(store) が語彙変換に使う。
RUN, WAIT, SUB = "🟢", "⏸", "🔵"
STATE_WORD = {RUN: "run", WAIT: "wait", SUB: "sub"}
# 生存照合の沈黙しきい値（分）。mtime 経路=STALE_MIN(通常)/STALE_MIN_SUB(サブ)、
# ファイル皆無経路=STALE_MIN_NOFILE(通常)/STALE_MIN_SUB(サブ)。NOFILE_MAX は旧判定の互換定数。
# 現在の reconcile は12時間超の ghost も降格し、未来時刻は負の age で除外する。
STALE_MIN, STALE_MIN_SUB, STALE_MIN_NOFILE, NOFILE_MAX = 10, 30, 15, 720
PLACEHOLDER = "?"


def daily_path():
    base = os.environ.get("GOAL_BASE") or os.path.expanduser("~/Private/personal-os/my-brain/ゴール/デイリー")
    date_s = os.environ.get("SESSION_BOARD_DATE") or datetime.datetime.now().strftime("%Y-%m-%d")
    year, month, _ = date_s.split("-")
    return os.path.join(base, year, month, f"{date_s}.md"), date_s


def clean(value):
    """目標・今などの1行値を正規化（改行/連続空白を1つに・両端trim）。DBへ入れる前の共通掃除。"""
    import re
    return re.sub(r"\s+", " ", value or "").replace("|", "／").strip()


def tx_roots():
    env = os.environ.get("SESSION_BOARD_TX_ROOTS")
    return [p for p in env.split(":") if p] if env else [os.path.expanduser("~/.claude/projects"), os.path.expanduser("~/.codex/sessions")]


def list_transcripts():
    files = []
    for root in tx_roots():
        try: files += glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True)
        except OSError: pass
    return files


def newest_for(key, files):
    candidates = [f for f in files if key in f and os.path.exists(f)]
    try: return max(candidates, key=os.path.getmtime) if candidates else None
    except OSError: return None


def minutes_between(t0, t1):
    """HH:MM 2点間の分（日跨ぎは +1440 補正）。純関数。"""
    h0, m0 = map(int, t0.split(":")); h1, m1 = map(int, t1.split(":"))
    delta = (h1 * 60 + m1) - (h0 * 60 + m0)
    return delta + (1440 if delta < 0 else 0)
