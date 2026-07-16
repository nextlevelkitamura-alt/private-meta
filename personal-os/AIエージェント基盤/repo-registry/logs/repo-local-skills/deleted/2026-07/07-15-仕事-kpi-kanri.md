# kpi-kanri

- 日付時刻: 2026-07-15 15:07 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 削除元: `.agents/skills/kpi-kanri/`
- 概要: 候補者管理表とKPI管理表の日次KPI入力を扱っていたrepo-local Skill。
- 理由: 統合。候補者の状態変更・管理表更新・KPI記録を `candidate` の単一workflowへ統合済みであり、別入口を残すとAIの選択が曖昧になるため削除した。
- 所有repo側の導線: 削除済み（CATALOG行・`.claude/skills` 経由のruntime露出・active計画の現行参照を更新済み）
- 引き継ぎ履歴:
  - 作成: 2026-07-09 16:42 JST／`.agents/skills/kpi-kanri/SKILL.md`
  - 移行: なし
  - 統合元ログ: `repo-local-skills/created/2026-07/07-09-仕事-kpi-kanri.md`（削除済み）
- 備考: 旧KPI判定・確認・再読込の規則は `projects/active/仕事/.agents/skills/candidate/` へ統合済み。
