# claude/ — Claude の直接登録を説明する場所

Claudeの実行本体は `../events/` に1セットだけある。このフォルダは登録ファイルの置き場ではなく、Claudeのグローバル登録先と更新規則を説明する。

## 登録表はrepo外の `~/.claude/settings.json`

Claudeは、ユーザー設定ファイル `~/.claude/settings.json` の `hooks` 項目を登録表として直接読む。model・permissions・envなども同じ設定ファイルに同居するため、hooksだけを別ファイルへ切り出す機能は使わない。

- `~/.claude/settings.json` 全体をsymlinkにしない。Claudeが設定を書き戻すと、repoへ設定値が流入するおそれがある。
- repo内にClaude専用 `hooks.json`、適用スクリプト、runtime別Pythonシムは置かない。
- 登録コマンドは `~/.claude/agent-hooks/events/... --runtime claude` を直接指す。この窓は親 `hooks-registry/` へのsymlinkなので、実行本体は両runtimeで共通になる。
- 保存後は自動反映され、Claudeのtrust操作は不要。

## 現在の登録対象

| Claudeイベント | 共通実行本体 |
| --- | --- |
| `SessionStart` | `events/session-start/reconcile-and-notify.py --runtime claude` |
| `UserPromptSubmit` | `events/prompt-register/register-and-guide.py --runtime claude` |
| `Stop` | `events/session-end/mark-wait.py` |
| `SubagentStart` | `events/subagent/sync-subagent-status.py` |
| `SubagentStop` | `events/subagent/sync-subagent-status.py` |

現在のイベント内容は `../events/<イベント>/AGENTS.md`、runtime契約は `../references/claude-hooks.md`、窓の読み取り診断は `../shared/session-board/registered.sh` を読む。`CLAUDE.md` は `AGENTS.md` への相対symlink。
