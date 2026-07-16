# mark-wait.py

## 何をするか

`Stop` 時に、現在🟢のセッションを⏸（停止・確認待ち）へ変える。その後、古い🟢/🔵行も生存照合する。

## 入力と副作用

- 入力: stdin JSON の `session_id` など。
- 処理: `common.stop_flip()`。
- 副作用: 当日デイリーの行更新。subagent、未登録、すでに⏸/🔵の行は変えない。
- 失敗時: 何も出力せず本体セッションを止めない。

`guard-plan-closeout.py`（承認後に別登録）は計画同期を検査するが、この実行本体へ混ぜない。`finish`はarchive承認ではない。

## 登録

Claudeの `~/.claude/settings.json` の `hooks` 項目と、Codexの `../../codex/hooks.json` が、各 `agent-hooks/events/session-end/` 経由で同じ `.py` を呼ぶ。runtime別の引数や実装コピーは不要。
