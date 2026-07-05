# project-slide-workflow

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.codex/skills/project-slide-workflow` / `/Users/kitamuranaohiro/.claude/skills/project-slide-workflow`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/project-slide-workflow`
- 概要: プロジェクト型の資料・スライドを、壁打ちで内容を固めながら1枚ずつ確認して作るSkill。
- 移行理由: runtimeごとの重複実体をなくし、AIエージェント基盤のGlobal Skill正本へ一本化するため。
- 正本選定: 旧runtime 2箇所の内容は完全一致のため、差分なしとして新正本へ移設。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み、旧runtime 2箇所のdiff一致。
- 備考: 旧runtime 2箇所の内容は完全一致。移行後は各runtime入口から新正本へのdirect symlinkに統一。
