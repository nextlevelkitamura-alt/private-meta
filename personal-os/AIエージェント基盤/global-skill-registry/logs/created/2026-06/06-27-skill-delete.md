# skill-delete

- 日付時刻: 2026-06-27 20:51 JST
- 正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-delete`
- 概要: Skill削除前に対象path、runtime露出、削除理由、人間承認を確認し、削除後にdeletedログを残すための薄い安全ゲート。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 備考: `global-skill-governance` 削除後の削除専用入口として作成。旧名 `global-skill-delete` から `skill-delete` へ改名。
