# register-and-guide.py

## 何をするか

最初の意味ある入力で session-board の枠を登録する（＝この UserPromptSubmit が「動いているエージェント」の入口）。以降は状態を壊さず、開始ガイドまたは短いミラーに加え、Focusmap分類用の短い動的packetを注入する。

毎Promptで次を同じhandler内で直列実行する。

1. ambient contextを除いて実依頼を正規化する。`/compact`等のruntime保守コマンドは除外するが、明示Skill実行は記録対象にする。
2. `routing.py`でGit common-dir由来repo key、canonical repo、worktree root、実cwd、branchを判定する。
3. `route-prepare`の1呼び出しでContext upsertとturn pendingを同一batchへ直列化する。Prompt全文やPrompt由来hashは保存せず、session/turn/runtime由来event fingerprintとsecret・連絡先マスク済み80文字要約だけを持つ。
4. 今日かつ対象repoのTodoを持つThemeと、そのThemeが参照するactive/planning Planだけを最大3件ずつ返す。既存所属があっても対象turnの書戻し契約は返す。
5. AIへ`route-propose`の書戻し契約を渡す。意味の類似だけなら`proposed`、明示証拠がある時だけ`accepted`を許す。

初回ガイド（`common._first_guide`・最初の意味あるPromptだけ）は、着手前に必ず1回判断する2分岐を明示する（program「計画立案システム刷新」子05）。AIがsession行を更新し損ねても2回目は短いミラーへ落とし、同じ長文を繰り返さない:
- サクッと（3条件全YES）= 計画不要 → そのまま実行し節目を log で記録するだけ（`--plan なし`）。
- 1つでもNO = 計画が要る → 規定の場所に plan を作り commit して focusmap 反映 → `update --plan` で宣言（このセッションが focusmap の「計画外エージェント」からその計画内へ入る）。

判断は入口（作業開始時＝ここ）で行うのが正しい。編集時の `pre-tool-use/guard-plan-gate`（未登録・段階1）は、この入口ガイドの補助（編集時の弱いリマインド）に過ぎない。

## 入力と出力

- 入力: stdin JSON と `--runtime claude|codex`。
- 処理: `common.register_prompt()`。
- 出力: Claude は plain text、Codex は `hookSpecificOutput.additionalContext` JSON。空入力・runtime保守コマンド・subagent・headless は何もしない。

## 登録

- Claude: `~/.claude/settings.json` の `hooks` 項目が `agent-hooks/events/prompt-register/` 経由でこの `.py` を `--runtime claude` 付きで呼ぶ。
- Codex: `../../codex/hooks.json` が同じ `.py` を `--runtime codex` 付きで呼ぶ。

## 副作用

board DBのsession枠、`session_execution_contexts`、`session_route_proposals`をbest-effort更新する。Theme/Plan候補はinbox DBから今日＋対象repoに絞って読む。分類追加処理は4.5秒でfail-openする。migration未適用・オフライン・内部失敗では分類記録・候補は欠けうるが、既存session-boardとAI本体は止めない。

Skill全文は注入しない。人間が未分類整理を明示した時だけ`skills/session-routing/SKILL.md`を通常のSkill経路で使う。
