#!/usr/bin/env python3
# renderer / codex-pull — CODEX_INDEX（session_index.jsonl）から当日(JST)分のCodexセッションを
# 決定的に抽出する。
#
# 旧shell実装は行ごとに jq を複数回＋date -j を起動しており、実環境（~/.codex/session_index.jsonl
# 1185行）で1回のrenderが数分級になっていた（行数×プロセス起動のO(n)オーバーヘッド）。
# python3単一プロセスの単一パスに書き換え、行ループ内でのプロセス起動を全廃した
# （ファイル名は呼び出し元（build-done.sh/build-align.sh）互換のため .sh のまま。実体はpython3）。
#
# 仕様は旧実装と同一: 壊れJSON行はスキップ／id・updated_at欠落行はスキップ／
# updated_at(UTC)をJST変換した日付が対象日のものだけ抽出／idで重複排除（当日分の中で最新の
# updated_at採用）／epoch（時刻）昇順で出力。rollout先頭1行（session_meta）からは
# .payload.cwd / .payload.git.repository_url だけを読む。base_instructions・本文は
# 絶対に読まない・出力しない。
import glob
import json
import os
import sys
from datetime import datetime, timedelta, timezone

JST = timezone(timedelta(hours=9))


def parse_updated_at(raw):
    if not isinstance(raw, str) or not raw:
        return None
    s = raw.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def sanitize_inline(text):
    if text is None:
        return ""
    return text.replace("\r", " ").replace("\n", " ").replace("|", "/")


def resolve_rollout(sessions_base, session_id):
    pattern = os.path.join(sessions_base, "**", "rollout-*-%s.jsonl" % session_id)
    matches = glob.glob(pattern, recursive=True)
    return matches[0] if matches else None


def read_meta(rollout_path):
    # session_meta（先頭1行）だけを読む。base_instructions等の他フィールド・以降の行は一切読まない。
    cwd = ""
    repo = ""
    try:
        with open(rollout_path, "r", encoding="utf-8", errors="replace") as rf:
            first_line = rf.readline()
    except OSError:
        return cwd, repo
    first_line = first_line.strip()
    if not first_line:
        return cwd, repo
    try:
        meta = json.loads(first_line)
    except ValueError:
        return cwd, repo
    if not isinstance(meta, dict):
        return cwd, repo
    payload = meta.get("payload")
    if not isinstance(payload, dict):
        return cwd, repo
    raw_cwd = payload.get("cwd")
    if isinstance(raw_cwd, str):
        cwd = raw_cwd
    git_info = payload.get("git")
    if isinstance(git_info, dict):
        repo_url = git_info.get("repository_url")
        if isinstance(repo_url, str) and repo_url:
            base = os.path.basename(repo_url)
            if base.endswith(".git"):
                base = base[: -len(".git")]
            repo = base
    return cwd, repo


def main(argv):
    if len(argv) < 2 or not argv[1]:
        print("usage: codex-pull.sh <YYYY-MM-DD>", file=sys.stderr)
        return 2
    date_str = argv[1]

    index_file = os.environ.get("CODEX_INDEX") or os.path.expanduser("~/.codex/session_index.jsonl")
    sessions_base = os.environ.get("CODEX_SESSIONS_BASE") or os.path.expanduser("~/.codex/sessions")

    if not os.path.isfile(index_file):
        return 0

    # id -> (dt, thread_name)  当日(JST)分のみ・重複はupdated_atが新しい方を採用。
    candidates = {}
    try:
        fh = open(index_file, "r", encoding="utf-8", errors="replace")
    except OSError:
        return 0
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if not isinstance(obj, dict):
                continue
            session_id = obj.get("id")
            updated_at_raw = obj.get("updated_at")
            if not session_id or not updated_at_raw:
                continue
            dt = parse_updated_at(updated_at_raw)
            if dt is None:
                continue
            if dt.astimezone(JST).strftime("%Y-%m-%d") != date_str:
                continue
            thread_name = obj.get("thread_name") or ""
            if not isinstance(thread_name, str):
                thread_name = str(thread_name)
            prev = candidates.get(session_id)
            if prev is None or dt > prev[0]:
                candidates[session_id] = (dt, thread_name)

    if not candidates:
        return 0

    ordered = sorted(candidates.items(), key=lambda kv: kv[1][0])

    out_lines = []
    for session_id, (dt, thread_name) in ordered:
        rollout = resolve_rollout(sessions_base, session_id)
        cwd, repo = read_meta(rollout) if rollout else ("", "")
        where = repo or (os.path.basename(cwd) if cwd else "")
        hhmm = dt.astimezone(JST).strftime("%H:%M")
        safe_thread = sanitize_inline(thread_name)
        if where:
            out_lines.append(
                "- [auto] Codexセッション %s JST: %s ／ 要旨: %s ／ session=%s"
                % (hhmm, where, safe_thread, session_id)
            )
        else:
            out_lines.append(
                "- [auto] Codexセッション %s JST ／ 要旨: %s ／ session=%s" % (hhmm, safe_thread, session_id)
            )

    sys.stdout.write("\n".join(out_lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
