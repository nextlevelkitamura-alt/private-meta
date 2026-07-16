# sync-subagent-status.py

## 何をするか

`hook_event_name` を見て `SubagentStart` なら `board_sub_start()`、`SubagentStop` なら `board_sub_end()` を呼ぶ。複数のサブエージェントを数え、0になった時だけ🟢へ戻す。

## 入力と副作用

- 入力: stdin JSON の親 `session_id` と `hook_event_name`。
- 副作用: 親の当日デイリー行の `sub:N` と状態。
- 失敗時: 非ブロッキングで何もしない。runtime出力はない。

`verify-plan-worker.py`（承認後に別登録）はこの状態同期と独立して、計画taskのmanifestだけを検査する。

## 登録

Claudeの `~/.claude/settings.json` の `hooks` 項目と、Codexの `../../codex/hooks.json` が、各 `agent-hooks/events/subagent/` 経由で同じ `.py` を呼ぶ。
