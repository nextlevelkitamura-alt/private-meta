#!/usr/bin/env python3
"""PreToolUse: 計画バケットへの生 mv / git mv だけをdenyする。"""
import json
import re
import shlex
import sys


PLAN_BUCKET = re.compile(r"(?:^|[\s'\"])(?:[^\s'\"]*/)?plans/(?:planning|active|paused|done|archive)(?:/|\b)")
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}


def command_of(payload):
    tool = payload.get("tool_input") or payload.get("toolInput") or {}
    return tool.get("command", "") if isinstance(tool, dict) else ""


def segments(command):
    """連結演算子ごとに分ける。解析不能なら疑わしい生mvを見落とさない。"""
    try:
        lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        return [[command]]
    result, current = [], []
    for token in tokens:
        if token and set(token) <= {";", "&", "|"}:
            if current:
                result.append(current); current = []
        else:
            current.append(token)
    if current:
        result.append(current)
    return result


def git_subcommand(tokens):
    """gitのグローバルオプションを飛ばし、最初のsubcommandを返す。"""
    index = 1
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            index += 1
            break
        if token in GIT_OPTIONS_WITH_VALUE:
            index += 2
            continue
        if token.startswith("--git-dir=") or token.startswith("--work-tree=") or token.startswith("--namespace=") or token.startswith("--config-env="):
            index += 1
            continue
        if token.startswith("-"):
            index += 1
            continue
        return token
    return tokens[index] if index < len(tokens) else ""


def raw_move_targets_plan_bucket(tokens):
    if not tokens:
        return False
    if tokens[0] == "mv":
        paths = tokens[1:]
    elif tokens[0] == "git" and git_subcommand(tokens) == "mv":
        paths = tokens[1:]
    else:
        return False
    return bool(PLAN_BUCKET.search(" " + " ".join(paths)))


def denial(payload):
    command = command_of(payload)
    if not isinstance(command, str):
        return None
    if not any(raw_move_targets_plan_bucket(part) for part in segments(command)):
        return None
    return "計画バケットへの生 mv / git mv は使えません。bucketctl check --json で件数・上限・対象一覧を確認し、必要な人間判断を返してから bucketctl を使ってください。"


def main():
    try:
        payload = json.load(sys.stdin)
        reason = denial(payload)
        if reason:
            print(json.dumps({"hookSpecificOutput": {"permissionDecision": "deny", "permissionDecisionReason": reason}}, ensure_ascii=False))
    except Exception:
        pass


if __name__ == "__main__":
    main()
