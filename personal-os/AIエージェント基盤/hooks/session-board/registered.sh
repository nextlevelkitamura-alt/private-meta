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
echo ""
echo "== launchd（com.kitamura.*）=="
launchctl list 2>/dev/null | grep kitamura | sed 's/^/  /' || echo "  (なし＝全停止中)"
echo ""
echo "注: session-board は skill廃止済み（2026-07-05）。正本は hooks/session-board/（全py＋手順md）。"
