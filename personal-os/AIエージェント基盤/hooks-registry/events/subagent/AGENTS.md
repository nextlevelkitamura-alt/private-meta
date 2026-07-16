# subagent — サブエージェント稼働数を同期する

`SubagentStart` と `SubagentStop` はともに `sync-subagent-status.py` を実行する。親セッションのキーを使い、開始で🔵・体数+1、終了で体数-1・0なら🟢へ戻す。

承認後に別handlerとして追加する`verify-plan-worker.py`は、manifestのworktree割当とresult/evaluationの有無だけを検査する。体数同期、計画本文、バケット、worktreeの作成・削除は所有しない。

詳細は [sync-subagent-status.md](sync-subagent-status.md)。状態更新は `../../shared/session-board/common.py` が正本。

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` からこの `.py` を呼ぶ。`.py` を変える前に同名 `.md` を更新し、runtime別の実装コピーは作らない。
