# grill-me

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/.codex/skills/grill-me` / `/Users/kitamuranaohiro/.agents/skills/grill-me` / `/Users/kitamuranaohiro/.claude/skills/grill-me`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/grill-me`
- 概要: 計画や設計を一問ずつ深掘りし、分岐や依存関係を整理しながら理解を揃えるための対話Skill。
- 移行理由: runtimeごとの重複実体をなくし、AIエージェント基盤のGlobal Skill正本へ一本化するため。
- 正本選定: 旧runtime 3箇所の内容は完全一致のため、差分なしとして新正本へ移設。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み、旧runtime 3箇所のdiff一致。
- 備考: 旧runtime 3箇所の内容は完全一致。移行時に実ディレクトリをバックアップへ退避し、各runtime入口から新正本へのdirect symlinkに統一。
