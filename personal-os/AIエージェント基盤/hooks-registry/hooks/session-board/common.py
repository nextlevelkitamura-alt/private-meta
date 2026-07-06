#!/usr/bin/env python3
# session-board 受け口の共通ロジック（Claude / Codex 両受け口が import する）。
# 実体は hooks-registry/hooks/session-board/common.py（runtime非依存の共有本体）。
# 受け口（claude/・codex/ の各 .py）は realpath で自分の実体を解決し、ここを import する。
#   → symlink 窓（~/.claude/agent-hooks 等）経由で起動されても board.py を正しく指す。
# runtime 差（SessionStart 出力が plain か JSON か・Codex 専用の subagent）だけを各受け口に残す。
import json
import os
import re
import subprocess
import sys

# common.py 自身の実体ディレクトリ＝共有本体（board.py・手順md）の置き場。
CORE_DIR = os.path.dirname(os.path.realpath(__file__))
BOARD = os.path.join(CORE_DIR, "board.py")


def load_input():
    """stdin の JSON を返す。非対話（AIJOBS_RUN）・不正JSONは None。"""
    if os.environ.get("AIJOBS_RUN"):
        return None
    try:
        return json.load(sys.stdin)
    except Exception:
        return None


def session_key(d):
    """対話セッションのキー（sid 先頭8字）。未取得・subagent（agent-*）は None。"""
    sid = d.get("session_id") or d.get("sessionId") or ""
    if not sid or sid.startswith("agent-"):
        return None
    return sid[:8]


def is_subagent(d):
    """transcript が */subagents/* ならサブエージェント経路。"""
    tp = d.get("transcript_path") or d.get("transcriptPath") or ""
    return "/subagents/" in tp


def repo_of(cwd):
    """cwd の git トップ basename（無ければ cwd の basename）。"""
    if not cwd:
        return ""
    r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return os.path.basename(r.stdout.strip()) if r.returncode == 0 else os.path.basename(cwd)


def _ref(name):
    """共有本体ディレクトリ内の手順md等の絶対パス。"""
    return os.path.join(CORE_DIR, name)


def start_lines(key, repo):
    """開始時に注入する共通本文（案内3行＋空行＋session-start.md）。runtime 共通。"""
    lines = [
        f"[session-board] このセッションのボードキー: s:{key}（repo推定: {repo or '不明'}）",
        "最初の依頼を理解したら、開始手順を実行する。種別・要約を正す例:",
        f'  {BOARD} update --key {key} --repo "{repo or "<repo>"}" '
        '--type <計画|実装|レビュー|その他> --summary "<依頼の1行要約>"',
        "",
    ]
    try:
        lines.append(open(_ref("session-start.md"), encoding="utf-8").read())
    except OSError:
        pass
    return lines


def board_check(key):
    return subprocess.run([BOARD, "check", "--key", key],
                          capture_output=True, text=True).stdout.strip()


def board_add(key, repo, summary):
    subprocess.run([BOARD, "add", "--key", key, "--repo", repo or "?",
                    "--type", "その他", "--summary", summary], capture_output=True)


def board_flip(key, state):
    subprocess.run([BOARD, "flip", "--key", key, "--state", state], capture_output=True)


def _summarize(prompt):
    return re.sub(r"\s+", " ", prompt).replace("|", "／").replace("<", "＜").replace(">", "＞")[:24]


def register_prompt(d):
    """UserPromptSubmit 共通: 未登録→登録／⏸(wait)→🟢(run)。🔵(sub) は触らない。
    subagent／スラッシュ／空・添付のみは対象外。stdout は出さない。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return
    prompt = d.get("prompt") or ""
    p = prompt.strip() if isinstance(prompt, str) else ""
    if not p or p.startswith("/") or p.startswith("<"):
        return
    state = board_check(key)
    if state == "missing":
        board_add(key, repo_of(d.get("cwd") or ""), _summarize(p))
    elif state == "wait":
        board_flip(key, "run")


def stop_flip(d):
    """Stop 共通: run のときだけ⏸(wait)へ。sub／wait／missing は触らない。ブロックしない。"""
    key = session_key(d)
    if not key or is_subagent(d):
        return
    if board_check(key) == "run":
        board_flip(key, "wait")
