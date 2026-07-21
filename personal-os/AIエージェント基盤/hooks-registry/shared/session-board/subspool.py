"""子03: PreToolUse→SubagentStart のサブエージェント詳細の一時スプール（hook間ハンドオフ）。

Claude 経路の2段構え:
  1. PreToolUse（Agent/Task ツール呼び出し）が tool_input から prompt/subagent_type/model を抜き、
     親セッションキーで push() する。
  2. 直後の SubagentStart（sync-subagent-status.py）が pop() で最古1件を取り出し、
     board.py sub-start の詳細引数へ渡して個体行に enrich する。

FIFO（session_subagents の close も started_at 昇順 FIFO 近似のため整合）。セッションキー×日で
ファイルを分ける。すべて best-effort＝例外は握り潰し、詳細が取れなくても本体・サブ起動を止めない。
lock/atomic-replace の作法は turso/spool.py と同型。secret/token の値はここでは判定せず、
マスキングは board.py 側（保存直前）が担う（このスプールは平文の中継バッファで、当日限りで消える）。
"""
import fcntl
import json
import os
import tempfile

LIMIT = 50  # 1キーあたりの滞留上限（暴走時の肥大化を防ぐ・超過分は古い順に捨てる）


def _dir():
    state_dir = os.environ.get("SESSION_BOARD_STATE_DIR") or os.path.join(os.path.dirname(__file__), "state")
    return os.path.join(state_dir, "subagent-detail")


def _paths(key):
    safe = "".join(c for c in (key or "") if c.isalnum() or c in "-_")
    base = _dir()
    return os.path.join(base, f"{safe}.jsonl"), os.path.join(base, f".{safe}.lock")


def push_unchecked(key, detail):
    """detail(dict) を key の待ち行列末尾へ追記する。滞留は LIMIT で頭を切る。"""
    if not key or not isinstance(detail, dict):
        return 0
    path, lock_path = _paths(key)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            lines = []
            if os.path.exists(path):
                lines = [ln for ln in open(path, encoding="utf-8").read().splitlines() if ln.strip()]
            lines.append(json.dumps(detail, ensure_ascii=False, separators=(",", ":")))
            lines = lines[-LIMIT:]
            fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                handle.write("\n".join(lines) + "\n")
                handle.flush(); os.fsync(handle.fileno())
            os.replace(tmp, path)
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
    return 1


def pop_unchecked(key):
    """key の待ち行列先頭(最古)の detail を1件取り出して返す。無ければ None。"""
    if not key:
        return None
    path, lock_path = _paths(key)
    if not os.path.exists(path):
        return None
    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            if not os.path.exists(path):
                return None
            lines = [ln for ln in open(path, encoding="utf-8").read().splitlines() if ln.strip()]
            if not lines:
                return None
            head, rest = lines[0], lines[1:]
            fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
            with os.fdopen(fd, "w", encoding="utf-8") as handle:
                if rest:
                    handle.write("\n".join(rest) + "\n")
                handle.flush(); os.fsync(handle.fileno())
            os.replace(tmp, path)
            return json.loads(head)
        except Exception:
            return None
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def push(key, detail):
    try:
        return push_unchecked(key, detail)
    except Exception:
        return 0


def pop(key):
    try:
        return pop_unchecked(key)
    except Exception:
        return None
