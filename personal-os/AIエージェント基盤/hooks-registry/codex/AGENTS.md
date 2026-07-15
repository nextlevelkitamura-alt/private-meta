# codex/ — Codex の hook 登録正本

Codexの実行本体は `../events/` に1セットだけある。このフォルダでは `hooks.json` だけが登録の正本で、runtime別のPython実装は置かない。

`~/.codex/hooks.json` は `hooks.json` へのsymlink。各コマンドは `~/.codex/agent-hooks/events/... --runtime codex` を指し、親の `agent-hooks` 窓は `hooks-registry/` 全体へ繋がる。

## 変更時

1. 先に対象イベントの `.py` と同名 `.md` をそろえる。
2. `hooks.json` を更新し、JSON検証と `../shared/session-board/registered.sh` を実行する。
3. 人間がCodexの `/hooks` で変更後のhookを再trustする。

`hooks.json` は内容またはパスが変わると信頼hashが変わる。`[hooks.state]` と `notify` はローカル `~/.codex/config.toml` の状態であり、repoへ移さない。

イベント内容は `../events/<イベント>/AGENTS.md`、runtime契約は `../references/codex-hooks.md` を読む。Claudeは別の登録表 `~/.claude/settings.json` を直接使うので、ここへClaude設定を混ぜない。`CLAUDE.md` は `AGENTS.md` への相対symlink。
