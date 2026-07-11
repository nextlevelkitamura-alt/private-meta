# skill-visualizer

- 日付時刻: 2026-07-11 10:56 JST
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-visualizer`
- 概要: Codex/Claude Skillのworkflow・構造・リスクを図解し、画像生成プロンプトに整理するSkillだった。
- 承認: 2026-07-11 人間承認（meta-explain新設計画の未決事項Q1で廃止OK。計画: `my-brain/areas/ai運用/plans/` の「2026-07-11-メタ説明skillの新設」）
- 露出削除: 5露出先すべて `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`（計5本）
- 理由: 統合。図解・理解用途を `meta-explain`（説明のみモード）が吸収し、変更計画・実装前合意まで扱える理解ゲートへ一本化するため。
- 吸収部品の移動先: なし（references/diagram-patterns.md・image-prompt-templates.md は引き継がず、見せ方の型は meta-explain の `references/説明の型.md` が新規定義）
- 引き継ぎ履歴:
  - 作成: 記録なし（`~/.codex/skills` 直下で作成された旧野良Skill）
  - 移行: 2026-06-27 20:51 JST 旧正本 `~/.codex/skills/skill-visualizer` → 基盤 `skills/skill-visualizer`。5runtime露出・quick_validate成功・runtime経由読み込み確認済み。
  - 統合元ログ: `logs/migrated/2026-06/06-27-skill-visualizer.md`（本削除で撤去）
- 備考: `agents/openai.yaml` を持つCodex interface付きSkillだった。機能依存ゼロ（2026-07-11サブエージェント調査・他Skill/loop/hook/scriptからの実行導線なし・projects/配下の参照0件）。
