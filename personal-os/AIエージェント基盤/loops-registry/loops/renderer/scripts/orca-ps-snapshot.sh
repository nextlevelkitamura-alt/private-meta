#!/usr/bin/env python3
# renderer / orca-ps-snapshot — `orca worktree ps --json` をパースし、auto:board-now / auto:board-wait
# 向けの正規化スナップショット行(worktree×agent一件=1行、"|"区切り)を出力する。
# 区切りに"|"を使う理由: bashの `IFS=$'\t' read` はtabをIFS whitespace扱いするため連続tab（空欄
# フィールド）が畳まれてズレる（displayName/agentType等が空になり得るため実害あり・実測で確認済み）。
# "|"はIFS whitespaceではないため空欄フィールドも位置がズレない（auto:logの既存"key=value|..."形式と
# 同じ区切り文字に統一）。
#
# 出力列: path, worktree(basename), displayName, branch(refs/heads/除去), worktree状態, agentType,
# state, lastAssistantMessageの最終行のみ。prompt・toolInput・lastAssistantMessage全文は一切出力しない
# （codex-pull.shのbase_instructions非漏洩方針と同じ理由。会話本文はsecret/機微情報になり得るため）。
#
# ORCA_PS_CMD（既定 "orca worktree ps --json"）をシェル経由で実行する。テスト時は
# `cat fixture.json` 等に差し替える（cockpit-supervisor-v1 watch.sh の WATCH_PS_CMD と同じ方式）。
# orca CLI不在・実行失敗・JSON不正はビルダー失敗として非0で終了する（空出力で既存内容を消さないため。
# render.sh側の『builder失敗→applyスキップ・既存内容保持』防御に乗せる）。
import json
import os
import subprocess
import sys


def sanitize(text):
    if not text:
        return ""
    return text.replace("\t", " ").replace("\n", " ").replace("\r", " ").replace("|", "/").strip()


def last_line(text):
    if not isinstance(text, str) or not text.strip():
        return ""
    for line in reversed(text.splitlines()):
        line = line.strip()
        if line:
            return sanitize(line)
    return ""


def main():
    cmd = os.environ.get("ORCA_PS_CMD") or "orca worktree ps --json"
    try:
        proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    except Exception as e:
        print("orca worktree ps の実行に失敗した: %s" % e, file=sys.stderr)
        return 1

    if proc.returncode != 0:
        print(
            "orca worktree ps が非0終了した(rc=%d・orca CLI不在の可能性): %s"
            % (proc.returncode, (proc.stderr or "").strip()),
            file=sys.stderr,
        )
        return 1

    try:
        data = json.loads(proc.stdout)
    except ValueError as e:
        print("orca worktree ps の出力がJSONとして解釈できない: %s" % e, file=sys.stderr)
        return 1

    if not isinstance(data, dict):
        print("orca worktree ps の出力形式が不正（objectでない）", file=sys.stderr)
        return 1

    result = data.get("result")
    worktrees = result.get("worktrees") if isinstance(result, dict) else None
    if not isinstance(worktrees, list):
        print("orca worktree ps の出力に result.worktrees(list)が無い", file=sys.stderr)
        return 1

    rows = []
    for w in worktrees:
        if not isinstance(w, dict):
            continue
        path = w.get("path") or ""
        if not path:
            continue
        display = sanitize(w.get("displayName") or "")
        branch = sanitize((w.get("branch") or "").replace("refs/heads/", ""))
        wstatus = sanitize(w.get("status") or "")
        worktree_name = os.path.basename(path.rstrip("/"))
        agents = w.get("agents")
        if not isinstance(agents, list) or not agents:
            rows.append((path, worktree_name, display, branch, wstatus, "", "", ""))
            continue
        for a in agents:
            if not isinstance(a, dict):
                continue
            agent_type = sanitize(a.get("agentType") or "")
            state = sanitize(a.get("state") or "")
            lastline = last_line(a.get("lastAssistantMessage"))
            rows.append((path, worktree_name, display, branch, wstatus, agent_type, state, lastline))

    rows.sort(key=lambda r: (r[0], r[5]))
    out = "\n".join("|".join(r) for r in rows)
    if out:
        sys.stdout.write(out + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
