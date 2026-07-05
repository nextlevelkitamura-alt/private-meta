# repo-relocation

- 日付時刻: 2026-06-28 20:51 JST
- 正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/repo-relocation`
- 概要: 既存repoを別フォルダへ移動し、旧パス互換symlinkを残さず、参照更新、launchd再登録、移動後テスト、repo-registry記録まで扱うGlobal Skill。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 備考: 小さく始めるため、初期構成は `SKILL.md` と `workflows/move-repo.md` のみにした。
