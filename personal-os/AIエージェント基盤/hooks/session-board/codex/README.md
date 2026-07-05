# codex/ — Codex用受け口（実装済み・登録は人間ゲート）

Codex（Codex.app / `codex-cli 0.142.5`）は **SessionStart / UserPromptSubmit / Stop /
SubagentStart / SubagentStop** の正式なhooksを持つ（2026-07-05 調査で確定）。
入力＝stdin JSON、注入＝`hookSpecificOutput.additionalContext`＝Claudeとほぼ同型。

## 受け口（`board.py`・手順md は `../` を共有）

- `session-start.py` … SessionStart: ボードキー＋`../session-start.md` を additionalContext で注入
- `prompt-register.py` … UserPromptSubmit: 未登録なら🟢登録／⏸→🟢復帰（subは触らない）
- `session-end.py` … Stop: run のときだけ⏸へ機械flip
- `subagent.py` … SubagentStart→🔵 / SubagentStop→🟢（Codexは自動flip・Claudeの自己申告に相当）
- `hooks.json` … `~/.codex/hooks.json` へ merge する登録スニペット雛形

## 登録（人間ゲート・未実施）

1. `hooks.json` の内容を `~/.codex/hooks.json` へ反映（絶対パスは実機に合わせる）
2. `/hooks` で trust（hash登録・変更で再trust）
3. 実Codexで 開始🟢 / Stop⏸ / サブ🔵自動 を各1回実測

構造と共通運用は `../AGENTS.md`、Codex hooksの契約（イベント/スキーマ/注入/trust）は
`../../references/codex-hooks.md`。
