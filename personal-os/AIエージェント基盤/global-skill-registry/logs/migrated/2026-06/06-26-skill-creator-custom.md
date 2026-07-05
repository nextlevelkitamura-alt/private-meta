# skill-creator-custom

- 日付時刻: 2026-06-26 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.claude/skills/skill-creator-custom`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-creator-custom`
- 概要: Skill作成・改善・分解・レビューを行うメタSkill。AIエージェント基盤方針に沿った正本配置レビューも扱う。
- 移行理由: runtime露出先を長期正本にせず、Skillライフサイクル窓口をAIエージェント基盤のGlobal Skill正本へ移すため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/.claude/skills/skill-creator-custom` を採用。移行後の旧正本pathは新正本へのdirect symlink。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。
- 備考: 旧正本パスは現在、新正本へのsymlink。
