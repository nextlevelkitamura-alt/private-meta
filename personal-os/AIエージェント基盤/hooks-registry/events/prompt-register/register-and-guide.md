# register-and-guide.py

## 何をするか

最初の意味ある入力で session-board の枠を登録する。以降は状態を壊さず、必要な開始ガイドまたは短いミラーだけを注入する。

## 入力と出力

- 入力: stdin JSON と `--runtime claude|codex`。
- 処理: `common.register_prompt()`。
- 出力: Claude は plain text、Codex は `additionalContext` JSON。空入力・スラッシュコマンド・subagent・headless は何もしない。

## 登録

- Claude: `~/.claude/settings.json` の `hooks` 項目が `agent-hooks/events/prompt-register/` 経由でこの `.py` を `--runtime claude` 付きで呼ぶ。
- Codex: `../../codex/hooks.json` が同じ `.py` を `--runtime codex` 付きで呼ぶ。

## 副作用

当日デイリーのボードに枠を追加または更新する。失敗しても hook はブロックしない。
