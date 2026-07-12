# meta-explain

- 日付時刻: 2026-07-12 12:12 JST
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/meta-explain`
- 概要: メタ構造を人間が理解するまでHTMLで説明・反復更新する理解ゲートSkillだった。
- 承認: 2026-07-12 人間承認（「meta-explain 消して、シンボリックリンクも消して」）
- 露出削除: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`（計5本）
- 理由: 統合。理解ゲートを `html/workflows/meta-explain.md`、見せ方を `html/references/meta-explain-layout.md` へ移し、二重のSkill入口とruntime露出をなくすため。
- 吸収部品の移動先: `references/説明の型.md` → `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/html/references/meta-explain-layout.md`、手順 → `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/html/workflows/meta-explain.md`
- 引き継ぎ履歴:
  - 作成: 2026-07-11 10:53 JST。正本は上記削除元、5 runtimeへ露出。
  - 統合元ログ: `logs/created/2026-07/07-11-meta-explain.md`（本削除で削除）
  - 旧 `skill-visualizer` を2026-07-11に吸収していた。
- 備考: `html` への統合後、通常HTMLとメタ説明は別workflowとして発火する。
