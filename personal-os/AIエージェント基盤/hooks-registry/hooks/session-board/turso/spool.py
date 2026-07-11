"""session_events/session_logsだけを保持する失敗スプール。"""
import fcntl
import json
import os
import tempfile

LIMIT = 50


def paths():
    state_dir = os.environ.get("SESSION_BOARD_STATE_DIR") or os.path.join(os.path.dirname(os.path.dirname(__file__)), "state")
    return os.path.join(state_dir, "turso-spool.jsonl"), os.path.join(state_dir, ".turso-spool.lock")


def spoolable(statements):
    return [(sql, args) for sql, args in statements
            if "insert into session_events" in " ".join(sql.lower().split())
            or "insert into session_logs" in " ".join(sql.lower().split())]


def append_unchecked(statements):
    statements = spoolable(statements)
    if not statements or os.environ.get("SESSION_BOARD_NO_TURSO"): return 0
    path, lock_path = paths(); os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            with open(path, "a", encoding="utf-8") as handle:
                handle.write(json.dumps({"statements": [[s, a] for s, a in statements]}, ensure_ascii=False, separators=(",", ":")) + "\n")
                handle.flush(); os.fsync(handle.fileno())
        finally: fcntl.flock(lock, fcntl.LOCK_UN)
    return 1


def append(statements):
    try: return append_unchecked(statements)
    except Exception: return 0


def replay_unchecked(sender, skip_tail_lines=0, limit=LIMIT):
    if os.environ.get("SESSION_BOARD_NO_TURSO") or limit <= 0: return 0
    path, lock_path = paths()
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


def replay(sender, skip_tail_lines=0, limit=LIMIT):
    try: return replay_unchecked(sender, skip_tail_lines, limit)
    except Exception: return 0
