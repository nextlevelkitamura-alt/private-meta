# skills-root

- 日付時刻: 2026-06-29 11:51 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 旧正本: `.claude/skills/`
- 新正本: `.agents/skills/`
- 概要: 仕事repo固有のrepo-local Skill群を、Agents基準の正本配置へ移行した。
- 移行理由: `AGENTS.md` を入口正本にし、Claude側は互換symlinkとして扱う運用へ揃えるため。
- 正本選定: `.agents/skills` を実体ディレクトリ、`.claude/skills` を `.agents/skills` への相対symlinkにした。
- 検証: `.agents/skills/work-skill-guide/SKILL.md` と `.claude/skills/work-skill-guide/SKILL.md` の両方から読み込み確認済み。`find .agents/skills -maxdepth 2 -name SKILL.md` は 51 件。
- 所有repo側の導線: 更新済み
- 備考: 外部Global Skillへのsymlink 3件は `.agents/skills` 配下へ移動し、リンク先は維持した。
