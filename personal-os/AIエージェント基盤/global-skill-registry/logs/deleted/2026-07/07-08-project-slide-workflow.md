# project-slide-workflow

- 日付時刻: 2026-07-08 14:50 JST
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/project-slide-workflow`（グローバル・5runtime窓）
- 概要: プロジェクト型の資料・スライドを壁打ちで固めながら1枚ずつ確認して作るglobal skillだった（案件/求人/キャリア/営業/LP・Codex画像生成/Claudeプロンプト化の環境分岐）。
- 承認: 2026-07-08 人間承認（Box A台帳の決定「スライド=slide土台に統合」＝ユーザー選択、および「計画実行して」）。
- 露出削除: 5露出先すべて撤去（`~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`・計5本）。機能は `slide`（5窓）から利用可。
- 理由: 統合。役割が重なる `slide` へ「モードC（案件型）」として吸収し1本化するため（重複解消）。
- 吸収部品の移動先:
  - SKILL.md本文 → `skills/slide/references/project-deck-mode.md`（モードC）
  - references/templates.md → `skills/slide/references/project-deck-templates.md`
  - references/chat-prompt-template.md → `skills/slide/references/chat-prompt-template.md`
- 引き継ぎ履歴:
  - 作成: created記録なし
  - 移行: 2026-06-27 20:51 JST・旧 `~/.codex` `~/.claude` 実体（内容一致）→ 基盤 `skills/project-slide-workflow`・5runtime露出
  - 統合元ログ: `logs/migrated/2026-06/06-27-project-slide-workflow.md`（本削除に伴い除去済）
- 備考: 退避先 `~/.skills-trash/20260708-140817/global-project-slide-workflow`（復元可）。仕事repoに同一のrepo-localコピーが残存（Box A外・follow-up）。統合先ログ `logs/migrated/2026-07/07-08-slide.md`。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
