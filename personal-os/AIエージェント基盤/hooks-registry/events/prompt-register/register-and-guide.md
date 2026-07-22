# register-and-guide.py

## 何をするか

最初の意味ある入力で session-board の枠を登録する（＝この UserPromptSubmit が「動いているエージェント」の入口）。以降は状態を壊さず、必要な開始ガイドまたは短いミラーだけを注入する。

初回ガイド（`common._first_guide`・目標未記入の間だけ）は、着手前に必ず1回判断する2分岐を明示する（program「計画立案システム刷新」子05）:
- サクッと（3条件全YES）= 計画不要 → そのまま実行し節目を log で記録するだけ（`--plan なし`）。
- 1つでもNO = 計画が要る → 規定の場所に plan を作り commit して focusmap 反映 → `update --plan` で宣言（このセッションが focusmap の「計画外エージェント」からその計画内へ入る）。

判断は入口（作業開始時＝ここ）で行うのが正しい。編集時の `pre-tool-use/guard-plan-gate`（未登録・段階1）は、この入口ガイドの補助（編集時の弱いリマインド）に過ぎない。

## 入力と出力

- 入力: stdin JSON と `--runtime claude|codex`。
- 処理: `common.register_prompt()`。
- 出力: Claude は plain text、Codex は `additionalContext` JSON。空入力・スラッシュコマンド・subagent・headless は何もしない。

## 登録

- Claude: `~/.claude/settings.json` の `hooks` 項目が `agent-hooks/events/prompt-register/` 経由でこの `.py` を `--runtime claude` 付きで呼ぶ。
- Codex: `../../codex/hooks.json` が同じ `.py` を `--runtime codex` 付きで呼ぶ。

## 副作用

当日デイリーのボードに枠を追加または更新する。失敗しても hook はブロックしない。
