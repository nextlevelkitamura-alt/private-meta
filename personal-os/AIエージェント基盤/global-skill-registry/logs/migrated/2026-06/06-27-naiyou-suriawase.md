# naiyou-suriawase

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.agents/skills/naiyou-suriawase`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/naiyou-suriawase`
- 概要: 作業開始前に、依頼の理解、ゴール、曖昧点、確認質問を短く整理する内容すり合わせSkill。
- 移行理由: runtime入口直下の実ディレクトリを長期正本にせず、Global Skill正本をAIエージェント基盤へ集約するため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/.agents/skills/naiyou-suriawase` を採用。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。
- 備考: 旧正本はruntime入口直下の実ディレクトリ。移行後は各runtime入口から新正本へのdirect symlinkに統一。
