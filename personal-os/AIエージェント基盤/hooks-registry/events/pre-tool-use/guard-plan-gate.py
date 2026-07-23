#!/usr/bin/env python3
"""PreToolUse: 計画なしのコード実装に「警告のみ」を返す立案ゲート（段階1）。

deny しない・ask しない・exit0。次を免除し、残った時だけ1セッション1回警告する。
  - 文書/計画系path（.md・plans/・references/・評価/・scratchpad）
  - 対象repoに active計画が1件でもある（plans/active/ に子がある＝立案済みと見なす）
  - 上記でsubagent（親計画で管理済み）もほぼ免除される（親repoにactive計画があるため）
設計根拠は同階層 guard-plan-gate.md（program「計画立案システム刷新」子04 §3.2）。
Claude=登録済み（settings.json PreToolUse ^(Edit|Write|MultiEdit)$）。Codexへ追加する場合はJSON検証・自動trust・readbackまで行う。
Codex=未登録。引数 --runtime は読まない（stdinのみ・Claude/Codex共通のadditionalContext形式）。
"""
import json
import os
import re
import sys
import tempfile

WARN = (
    "【立案ゲート】この実装に紐づく active 計画／当日起票が見当たりません。"
    "サクッと3条件（①変更1〜2ファイル ②容易に戻せる ③目的と完了条件が明確）を全て満たすなら"
    "そのまま実行し事後報告、1つでも外れるなら先に計画（plan.md／起票）を置いてください。"
)
DOC_HINT = re.compile(r"(?:^|/)(plans|references|評価|scratchpad)(?:/|$)")


def file_path_of(payload):
    tool = payload.get("tool_input") or payload.get("toolInput") or {}
    if not isinstance(tool, dict):
        return ""
    fp = tool.get("file_path") or tool.get("filePath") or ""
    return fp if isinstance(fp, str) else ""


def is_doc_path(path):
    """文書/計画系pathは免除（.md・plans/references/評価/scratchpad）。"""
    if not path:
        return True  # pathが取れない時は安全側＝免除（警告しない）
    if path.endswith(".md"):
        return True
    return bool(DOC_HINT.search(path))


def repo_root(start):
    cur = os.path.abspath(start) if start else os.getcwd()
    for _ in range(40):
        if os.path.isdir(os.path.join(cur, ".git")):
            return cur
        parent = os.path.dirname(cur)
        if parent == cur:
            break
        cur = parent
    return None


def has_active_plan(root):
    """root配下の plans/active/ に子があれば「立案済みのrepo」と見なす（best-effort・浅いglobのみ）。"""
    if not root:
        return False
    from pathlib import Path
    base = Path(root)
    for pattern in ("plans/active", "*/plans/active", "*/*/plans/active",
                    "*/*/*/plans/active", "*/*/*/*/plans/active"):
        try:
            for d in base.glob(pattern):
                if d.is_dir() and any(c.is_dir() and not c.name.startswith(".") for c in d.iterdir()):
                    return True
        except Exception:
            continue
    return False


def already_warned(session_id):
    if not session_id:
        return False
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", str(session_id))
    marker = os.path.join(tempfile.gettempdir(), f"plan-gate-{safe}.warned")
    if os.path.exists(marker):
        return True
    try:
        open(marker, "w").close()
    except Exception:
        pass
    return False


def should_warn(payload):
    path = file_path_of(payload)
    if is_doc_path(path):
        return False
    start = payload.get("cwd") or (os.path.dirname(path) if path else None)
    if has_active_plan(repo_root(start)):
        return False
    if already_warned(payload.get("session_id") or payload.get("sessionId")):
        return False
    return True


def main():
    try:
        payload = json.load(sys.stdin)
        if should_warn(payload):
            print(json.dumps(
                {"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": WARN}},
                ensure_ascii=False))
    except Exception:
        pass  # どんな失敗でも本体を止めない（非ブロッキング）


if __name__ == "__main__":
    main()
