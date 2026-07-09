分類: skill
種別: 新規作成
規模: ライト

# custom-agent-creator スキル新設

Claude Code / Codex / OpenCode 向けのカスタムエージェント定義を作成・整理・レビューする Global Skill（meta）を新設する。仕様の出所はユーザー設計書 v0.4（本セッションで受領）。

## 目的

- subagent / custom agent / primary agent の定義ファイルを、目的・権限・モデル・保存先・呼び出し方に応じて設計する支援 Skill を作る。
- 対象3ツールの詳細を読み分け、必要な時だけ該当 reference を読む構造にする。
- reviewer 系は原則 read-only。secret・破壊的コマンドをテンプレに残さない。

## 現状

- 未作成（`skills/` に custom-agent-creator なし・近接 Skill と重複なしを確認済み）。skill-creator 系は「Skill を作る」、cockpit 系は「エージェントを運用する」で別レイヤ。
- 設計書 v0.4 はフォルダ直下フラット5ファイル構成だが、基盤ルール（create-rules §4）では `SKILL.md`/`SKILL.html` 以外をフォルダ直下に置けない。→ `references/` 配下へ翻訳（読み分け・必要分だけ読む意図は保存）。
- 設計書の技術記述に正確性懸念2点: ①Claude Code subagent frontmatter キー（`background`/`isolation`/`mcpServers`/`permissionMode` 等が正式 key か）②OpenCode Go の model ID（実在未確認の仮値）。

## 方針

- 構成: `SKILL.md`（router・70行以内）＋ `references/{claude-code.md, codex.md, opencode.md, checklist.md}` ＋ `SKILL.html`。`workflows/` は作らない（単一フロー・150行以内）。
- 分類 = meta / Global。正本 = `AIエージェント基盤/skills/custom-agent-creator/`。露出 = 3ランタイム（`~/.claude` `~/.codex` `~/.config/opencode`）へ direct symlink。
- 正確性: Claude Code subagent frontmatter は claude-code-guide で実仕様を確認し誤りを正す。OpenCode Go の model ID は「例・実装時に要確認」と明示し断定しない。
- 言語: 自然言語 = 日本語。frontmatter key / enum / model ID / path / コマンド / agent 名 / Skill 名 = 英語 ASCII 固定。

## 完了条件（レビュー項目）

- [ ] `skills/custom-agent-creator/` 直下の md は `SKILL.md` のみ（claude-code.md 等がフォルダ直下に無い）。詳細は `references/` 配下にある。
- [ ] `SKILL.md` は70行以内で、対象ツール判定・読み分け・言語ルール・出力ルールを持つ（subagent frontmatter の詳細列挙を含まない）。
- [ ] `references/` に claude-code.md / codex.md / opencode.md / checklist.md の4ファイルがある。
- [ ] Claude Code / Codex / OpenCode の内容が各 reference に分離し、混ざっていない。
- [ ] reviewer 系テンプレ（quality-gate / reviewer / go-quality-gate 等）が全て read-only（編集不可）になっている。
- [ ] `references/claude-code.md` の frontmatter キーが claude-code-guide 検証結果と一致し、無効・別物のキーをテンプレに残していない。
- [ ] `references/opencode.md` の model ID が「例・要確認」と明示され、実在を断定していない。
- [ ] `description` に what / when / 日本語トリガー語があり、「Skill を作る」skill-creator 系との誤爆を避ける否定トリガーがある。
- [ ] secret / token を含まない。destructive command をテンプレで許可していない。
- [ ] `SKILL.html` を生成した（固定6節）。
- [ ] 3ランタイムに symlink 露出し、スキル一覧に出現する。
- [ ] `global-skill-registry/logs/created/2026-07/07-09-custom-agent-creator.md` を書き、`catalog/meta.md` に1 block 追加した。
