"""DB書き込みの失敗再送バッファ（旧「md→DBミラー」の受け皿ではなく、正本反転後はDB先書きの耐障害部品）。

2026-07-21 正本反転（子03・案b）で当日デイリーMDは廃止し、運用データの正本はTurso（board DB）に一本化した。
mdという受け皿が消えたため、DB送信失敗時の記録喪失をここで防ぐ。ただし再送してよいのは**追記式で冪等な文**
（session_events/session_logs＝board・plan_docs/plan_progress＝inbox）だけに限る。sessions の upsert/delete は
ここに載せない＝オフライン中に古い状態を溜め込み、復帰時に「死んだ行」を復活させてしまうのを防ぐため。
sessions の整合は再送でなく、次回コマンド実行時・reconcile 時にDB状態と実トランスクリプトを突き合わせて
自己修復する（board.py reconcile_db）。spool名でファイルを分け、inbox宛は plansync が専用spool＋inbox宛senderで隔離する。"""
import fcntl
import json
import os
import tempfile

LIMIT = 50


def paths(name="turso-spool"):
    state_dir = os.environ.get("SESSION_BOARD_STATE_DIR") or os.path.join(os.path.dirname(os.path.dirname(__file__)), "state")
    return os.path.join(state_dir, f"{name}.jsonl"), os.path.join(state_dir, f".{name}.lock")


# 追記式で再送してよい文の許可リスト。board DB=session_events/session_logs（既存）。
# inbox DB=plan_docs/plan_progress（2026-07-18 子06で拡張）。DELETEも冪等に再送可。
# 注意: この許可リストは「どのDBへ送るか」を判定しない。inbox宛の再送は plansync が
#       専用spool名＋inbox宛senderで隔離して回す（board既定senderへ混ぜない）。
_SPOOLABLE_PREFIXES = (
    "insert into session_events",
    "insert into session_logs",
    "insert into plan_docs",
    "insert into plan_progress",
    "delete from plan_docs",
    "delete from plan_progress",
)


def spoolable(statements):
    return [(sql, args) for sql, args in statements
            if any(" ".join(sql.lower().split()).startswith(pfx) for pfx in _SPOOLABLE_PREFIXES)]


def append_unchecked(statements, name="turso-spool"):
    statements = spoolable(statements)
    if not statements or os.environ.get("SESSION_BOARD_NO_TURSO"): return 0
    path, lock_path = paths(name); os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(path, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"statements": [[s, a] for s, a in statements]}, ensure_ascii=False, separators=(",", ":")) + "\n")
                handle.flush(); os.fsync(handle.fileno())
        finally: fcntl.flock(lock, fcntl.LOCK_UN)
    return 1


def append(statements, name="turso-spool"):
    try: return append_unchecked(statements, name)
    except Exception: return 0


def replay_unchecked(sender, skip_tail_lines=0, limit=LIMIT, name="turso-spool"):
    if os.environ.get("SESSION_BOARD_NO_TURSO") or limit <= 0: return 0
    path, lock_path = paths(name)
    if not os.path.exists(path): return 0
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            if not os.path.exists(path): return 0
            lines = open(path, encoding="utf-8").read().splitlines()
            eligible_end = max(0, len(lines) - max(0, int(skip_tail_lines or 0)))
            selected, consumed, decoded = [], {}, {}
            for index in range(eligible_end):
                try:
                    raw = json.loads(lines[index]).get("statements")
                    batch = [(item[0], item[1]) for item in raw]
                except (AttributeError, IndexError, TypeError, ValueError, json.JSONDecodeError): return 0
                if not batch: return 0
                take = min(len(batch), limit - len(selected)); selected.extend(batch[:take])
                consumed[index], decoded[index] = take, batch
                if len(selected) >= limit: break
            if not selected or not sender(selected): return 0
            remaining = []
            for index, line in enumerate(lines):
                if index not in consumed: remaining.append(line); continue
                rest = decoded[index][consumed[index]:]
                if rest: remaining.append(json.dumps({"statements": [[s, a] for s, a in rest]}, ensure_ascii=False, separators=(",", ":")))
            fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as handle:
                    if remaining: handle.write("\n".join(remaining) + "\n")
                    handle.flush(); os.fsync(handle.fileno())
                os.replace(tmp, path)
            except Exception:
                try: os.unlink(tmp)
                except OSError: pass
                raise
            return len(selected)
        finally: fcntl.flock(lock, fcntl.LOCK_UN)


def replay(sender, skip_tail_lines=0, limit=LIMIT, name="turso-spool"):
    try: return replay_unchecked(sender, skip_tail_lines, limit, name)
    except Exception: return 0
