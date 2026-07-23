# codex/ — Codex の hook 登録正本

Codexの実行本体は `../events/` に1セットだけある。このフォルダでは `hooks.json` が登録の正本で、`trust-current.py` が現在hashをCodex公式APIから取得してlocal trustを更新する。runtime別のイベントPython実装は置かない。

`~/.codex/hooks.json` は `hooks.json` へのsymlink。各コマンドは `~/.codex/agent-hooks/events/... --runtime codex` を指し、親の `agent-hooks` 窓は `hooks-registry/` 全体へ繋がる。

## 変更時

1. 先に対象イベントの `.py` と同名 `.md` をそろえる。
2. `hooks.json` を更新し、JSON検証と `../shared/session-board/registered.sh` を実行する。
3. `./trust-current.py` を実行し、Codex app-serverの `hooks/list` → `config/batchWrite` → 再読込で変更後のhookを自動trustする。

`hooks.json` は内容またはパスが変わると信頼hashが変わる。`trust-current.py` はCodexが返す `currentHash` だけを同じhook keyの `trusted_hash` へ保存し、hookのcommand・matcher・enabled状態は変更しない。`[hooks.state]` と `notify` はローカル `~/.codex/config.toml` の状態であり、repoへ移さない。

子04の追加候補は`../registration-diff-04-plan-closeout.md`に記録する。登録変更時はJSON検証・診断・自動trust・readbackを同じ変更単位で行う。

イベント内容は `../events/<イベント>/AGENTS.md`、runtime契約は `../references/codex-hooks.md` を読む。Claudeは別の登録表 `~/.claude/settings.json` を直接使うので、ここへClaude設定を混ぜない。`CLAUDE.md` は `AGENTS.md` への相対symlink。
