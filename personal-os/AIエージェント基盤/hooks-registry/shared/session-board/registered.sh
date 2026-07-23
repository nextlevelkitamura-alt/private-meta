#!/bin/bash
# session-board registered.sh — いま何が登録されているかの一覧（読み取りのみ）
echo "== Claude hooks（~/.claude/settings.json）=="
/usr/bin/env python3 - <<'PY'
import json
d = json.load(open("/Users/kitamuranaohiro/.claude/settings.json"))
hooks = d.get("hooks", {})
if not hooks:
    print("  (登録なし)")
for ev, es in hooks.items():
    for e in es:
        for h in e.get("hooks", []):
            if h.get("type") == "command":
                print(f"  {ev:<17} command  {h['command'].split('/')[-1]}")
            else:
                print(f"  {ev:<17} {h.get('type')}  ({len(h.get('prompt',''))}字の判定文)")
PY
echo ""
echo "== Codex（~/.codex/config.toml の notify / hooks.state）=="
grep -nE '^notify|^\[hooks' ~/.codex/config.toml 2>/dev/null | sed 's/^/  /' || echo "  (なし)"
echo "  ※ hooks.json の内容変更後は codex/trust-current.py で自動trustし、全hookの状態をreadbackする"
echo ""
echo "== launchd（com.kitamura.*）=="
launchctl list 2>/dev/null | grep kitamura | sed 's/^/  /' || echo "  (なし＝全停止中)"
echo ""
echo "== symlink 露出（窓） =="
for L in "$HOME/.claude/agent-hooks" "$HOME/.codex/agent-hooks" "$HOME/.codex/hooks.json"; do
  if [ -L "$L" ]; then printf '  %s -> %s [%s]\n' "$L" "$(readlink "$L")" "$([ -e "$L" ] && echo OK || echo BROKEN)"; else echo "  $L （symlinkでない）"; fi
done
echo ""
echo "注: session-board は skill廃止済み（2026-07-05）。正本は hooks-registry/（events/ に実行本体1組、shared/session-board/ に共通エンジン、Claude登録は ~/.claude/settings.json、Codex登録は codex/hooks.json）。"
