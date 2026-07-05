# mokuteki-jisso

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.agents/skills/mokuteki-jisso`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/mokuteki-jisso`
- 概要: 目的達成のために、規模判定、調査、全体プラン、実行プロンプト、戻り報告評価、再指示、完了判定を行うSkill。
- 移行理由: runtime露出先を長期正本にしていたため、symlink chainを解消してAIエージェント基盤へ集約するため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/.agents/skills/mokuteki-jisso` を採用。`~/.codex` と `~/.claude` は同実体へのsymlinkだった。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み。
- 備考: 旧構成では `~/.codex` と `~/.claude` が `~/.agents` 実体へsymlinkしていた。移行後はchainを解消し、各runtime入口から新正本へのdirect symlinkに統一。
