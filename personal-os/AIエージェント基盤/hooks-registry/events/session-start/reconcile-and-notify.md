# reconcile-and-notify.py

## 何をするか

`SessionStart` で古い実行中行を生存照合し、現在のセッションキーを短く通知する。
ボード行は作らない。実際の行登録は最初の意味ある入力で `register-and-guide.py` が行う。

同時に`routing.py`でrepo/worktree/branchを判定し、追加表`session_execution_contexts`へbest-effort記録する。固定分類方針`../prompt-register/session-classification-policy.md`は各SessionStartイベントで追加Contextへ入れる（startupだけでなくresume/compact後にも方針を復元）。仕事のTheme/Plan分類はまだ行わない。

## 入力と出力

- 入力: runtime が stdin に渡す JSON（`session_id`、`cwd`、`transcript_path` など）と `--runtime claude|codex`。
- 処理: `common.start_register()`。
- 出力: Claude は plain text、Codex は `additionalContext` を持つJSON。対象外・不正入力・内部失敗では何も返さず、セッションを止めない。

## 触る場所

- 状態遷移・生存照合: `../../shared/session-board/common.py` と `board.py`。
- repo/worktree判定: `../../shared/session-board/routing.py`。
- runtime登録: Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json`。どちらも `agent-hooks/events/session-start/` 経由でこの `.py` を指す。
- 全体の順番: `AGENTS.md`。

開始通知・session-boardの`finish`は計画のarchiveを承認・実行しない。計画同期とバケット遷移はplan-opsの責務である。
