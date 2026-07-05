# job-strategy

- 日付時刻: 2026-06-29 12:44 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 削除Skill: `.agents/skills/job-strategy`
- 概要: 求人更新戦略の短縮入口Skillを削除した。
- 削除理由: 更新戦略は新規求人作成ではなく既存求人運用の一部であり、独立Skillとして残すと求人作成Skillとの境界が曖昧になるため。
- 統合先: `.agents/skills/job-update/workflows/更新戦略.md`
- 統合内容: 来月/今月の更新計画、露出計画、掲載タイミング、求人更新スケジュール検討。
- 引き継ぎ履歴: 統合元ログなし。
- 復旧方針: 復旧しない。更新戦略は `job-update` を入口にする。
