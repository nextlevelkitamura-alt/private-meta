# skill-creator-codex

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/Downloads/skill-creators-20260627-101457/skill-creator-codex`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-creator-codex`
- 概要: OpenAI/Codex公式 `skill-creator` を日本語運用向けに改編した、Codex用Skill作成・更新支援Skill。
- 移行理由: 取得したCodex公式Skillを北村環境のGlobal Skillとして長期運用し、runtime露出先を正本にしないため。
- 正本選定: upstream取得物 `/Users/kitamuranaohiro/Downloads/skill-creators-20260627-101457/skill-creator-codex` を採用し、名称と内容を日本語運用向けに改編。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。
- 備考: upstreamは `openai/skills` の `skills/.system/skill-creator`、取得commitは `49f948faa9258a0c61caceaf225e179651397431`。`name` は `skill-creator-codex` に変更し、`SKILL.md`、`agents/openai.yaml`、`references/openai_yaml.md` を日本語向けに改編。既存の `skill-creator-custom` は変更なし。
