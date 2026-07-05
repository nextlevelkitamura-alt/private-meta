# job-new

- 日付時刻: 2026-06-29 12:44 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 削除Skill: `.agents/skills/job-new`
- 概要: 求人新規立案の短縮入口Skillを削除した。
- 削除理由: `job-flow` / `job-new` / `job-link` の入口が分かれており、求人作成時にどれを読むべきか曖昧だったため。
- 統合先: `.agents/skills/job-create-flow/求人作成.md`
- 統合内容: PDF/画像/壁打ちからの企画、画像確定、スプシ行整備、登録前ゲート、`prepare`、`create-jobs`、作成後リンク確定。
- 引き継ぎ履歴: 統合元ログなし。
- 復旧方針: 復旧しない。新規求人作成は `job-create-flow` を入口にする。
