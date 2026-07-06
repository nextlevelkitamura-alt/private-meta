# codex/ — Codex 用受け口（実装・登録・trust 済み）

Codex（Codex.app / `codex-cli 0.142.5`）は **SessionStart / UserPromptSubmit / Stop /
SubagentStart / SubagentStop** の正式な hooks を持つ（2026-07-05 調査で確定）。
入力＝stdin JSON、注入＝`hookSpecificOutput.additionalContext`＝Claude とほぼ同型。
Claude との差は **prompt 型フックが無い**こと（節目判定の `milestone` 相当は原理的に作れない）と、
**trust 承認が要る**こと。

## 受け口（`board.py`・手順md は `../` を共有）

- `session-start.py` … SessionStart: ボードキー＋`../session-start.md` を additionalContext で注入
- `prompt-register.py` … UserPromptSubmit: 未登録なら🟢登録／⏸→🟢復帰（sub は触らない）
- `session-end.py` … Stop: run のときだけ⏸へ機械flip
- `subagent.py` … SubagentStart→🔵 / SubagentStop→🟢（Codex は自動flip・Claude の自己申告に相当）
- `hooks.json` … `~/.codex/hooks.json` へ merge する登録スニペット雛形

## 登録（実施済み・一部実測PASS）

- `~/.codex/hooks.json` に5イベント反映済み・`~/.codex/config.toml` の `[hooks.state]` に trust 済み。
- 実 Codex で **開始🟢 / Stop⏸ を実測PASS**（session `019f3107`・2026-07-05）。
- **未実測**: サブ🔵自動（`subagent.py` の SubagentStart/Stop）は未確認。実 Codex でサブ起動して要確認。
- **hook を編集したら `/hooks` で再 trust が要る**（hash 変更で信頼が外れるため）。

## 使う hook の型

- `command` 型のみ（Codex は command 以外を実行しない）。prompt 型が無いので節目判定は持たない。
- Codex hook の一般知識（イベント/スキーマ/Stop注入不可/trust/読み込み順）は
  `../../references/codex-hooks.md`。ここでは重複させない。

構造と共通運用は `../AGENTS.md`、Codex hooks の契約は `../../references/codex-hooks.md`、
対の Claude 受け口は `../claude/AGENTS.md`。`CLAUDE.md` は `AGENTS.md` への相対symlink。
