# task-router

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.claude/skills/task-router`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/task-router`
- 概要: 開発依頼を即実装、詰めて一気に、単一チャット、順次、readonlyサブエージェント、複数Codexチャット、worktreeへ振り分けるSkill。
- 移行理由: runtime露出先を長期正本にしていたため、symlink chainを解消してAIエージェント基盤へ集約するため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/.claude/skills/task-router` を採用。`~/.codex` と `~/.agents` は同実体へのsymlinkだった。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。
- 備考: 旧構成では `~/.codex` と `~/.agents` が `~/.claude` 実体へsymlinkしていた。移行後はchainを解消し、各runtime入口から新正本へのdirect symlinkに統一。
