# agents-md-governance

- 日付時刻: 2026-06-29 01:00 JST
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/agents-md-governance`
- 概要: repository の `AGENTS.md` / `CLAUDE.md` を監査・改善・再構成し、AI向け入口ルールを整理するSkillだった。
- 露出削除: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 理由: 統合。AGENTS/CLAUDE監査、rewrite、git inventory、4ブロック監査テンプレート、read-only helperを `repo-create` へ吸収し、repo関係の入口を1つにするため。
- 引き継ぎ履歴:
  - 移行: 2026-06-27。旧正本 `/Users/kitamuranaohiro/.agents/skills/agents-md-governance` からAIエージェント基盤のGlobal Skill正本へ移行し、5 runtime direct symlink/readlink確認済み。
  - 統合: 2026-06-29。旧正本 `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/agents-md-governance` から新正本 `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/repo-create` へ機能を吸収。
  - 統合元ログ: `global-skill-registry/logs/migrated/2026-06/06-27-agents-md-governance.md`
- 備考: 新規のAGENTS/CLAUDE監査、AgentMD整理、repo governance確認は `repo-create` を使う。
