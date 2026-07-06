# codex/ — Codex 受け口の箱（イベント別）

Codex（Codex.app / `codex-cli`）は **SessionStart / UserPromptSubmit / Stop /
SubagentStart / SubagentStop** の hooks を持つ。受け口を **イベント別フォルダ**に置き、
登録リスト `hooks.json` を箱の直下に置く（`runtime → イベント → 機構ファイル`）。

## レイアウト

- `session-start/session-board-session-start.py` … SessionStart: 手順注入（**JSON**）
- `prompt-register/session-board-prompt-register.py` … UserPromptSubmit: 未登録→🟢登録／⏸→🟢復帰
- `session-end/session-board-session-end.py` … Stop: run のとき⏸へ flip
- `subagent/session-board-subagent.py` … SubagentStart→🔵 / SubagentStop→🟢（**Codex専用**・自動flip）
- `hooks.json` … **Codex 登録の索引**（イベント→受け口）。`~/.codex/hooks.json` はこれへの symlink。
  受け口ではなく全イベントを束ねる索引なので、イベントfolderに入れず**箱の直下**に置く。

ファイル名は `<機構>-<イベント>` で自己記述。将来フックは同イベントfolderに追加。

## 受け口の共通ルール

- 各 `.py` は `realpath` で実体を解決し `../../hooks/session-board/common.py` を import
  （`~/.codex/agent-hooks` 窓越しで起動されても `board.py` を正しく指す）。
- Codex hook の一般知識（イベント/スキーマ/Stop注入不可/trust/読み込み順）は `../references/codex-hooks.md`。

## 登録（実施済み・要再trust）

- `~/.codex/hooks.json` → `codex/hooks.json`（このファイル）への **symlink**。
  パスは窓 `~/.codex/agent-hooks/<イベント>/<機構>-<イベント>.py`。`[hooks.state]` に trust。
- **hooks.json を変えたら `/hooks` で再 trust**（hash 変化で信頼が外れる）。※ イベントfolder再編（2026-07-06）で**要再 trust**。
- 実測: 開始🟢 / Stop⏸ PASS（`019f3107`・2026-07-05）。サブ🔵自動は未実測。

対の Claude 箱は `../claude/AGENTS.md`、共有本体は `../hooks/session-board/AGENTS.md`、Codex hooks 契約は `../references/codex-hooks.md`。`CLAUDE.md` は `AGENTS.md` への相対symlink。
