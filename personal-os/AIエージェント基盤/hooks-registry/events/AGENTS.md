# events/ — 共通のイベント実行本体

ClaudeとCodexが共通で実行するhook本体を、イベントごとに1つだけ置く。runtimeごとの登録表は `../claude/` と `../codex/` で異なるが、実行Pythonはここに複製しない。

## この層の読み方

- 各イベントフォルダには、実行ファイル `機能名.py` と同名の説明 `機能名.md` を必ず対に置く。
- `.py` はruntimeが実行する本体、同名 `.md` は人間とAIが変更前に読む説明書。`.md` 自体を実行しない。
- 全イベントの共通状態ロジックは `../shared/session-board/common.py`。この層にはruntime固有の状態分岐を足さない。
- SessionStartとUserPromptSubmitだけは、設定から `--runtime claude|codex` を受け、stdoutの形式を選ぶ。処理内容は共通。

| イベント | 実行ファイル | 役割 |
| --- | --- | --- |
| `session-start/` | `reconcile-and-notify.py` | 生存照合とキー通知 |
| `prompt-register/` | `register-and-guide.py` | 枠登録と開始ガイド |
| `session-end/` | `mark-wait.py` | 🟢を⏸へ更新 |
| `subagent/` | `sync-subagent-status.py` | 🔵と稼働数を同期 |

Claudeは `~/.claude/settings.json` から、Codexは `../codex/hooks.json` から、このフォルダのPythonを呼ぶ。登録だけを直す時も、ここへruntime別の実装を増やさない。`CLAUDE.md` は `AGENTS.md` への相対symlink。
