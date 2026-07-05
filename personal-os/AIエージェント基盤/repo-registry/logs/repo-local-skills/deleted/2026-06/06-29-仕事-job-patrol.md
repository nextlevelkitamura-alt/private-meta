# job-patrol

- 日付時刻: 2026-06-29 12:44 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 削除Skill: `.agents/skills/job-patrol`
- 概要: 掲載中求人の巡回・月別スプシ更新のSkill入口を削除した。
- 削除理由: 求人巡回は求人作成ではなく既存求人運用の保守workflowとして扱うほうが自然で、Skill入口を分ける必要がないため。
- 統合先: `.agents/skills/job-update/workflows/求人巡回.md`
- 残すもの: CLIコマンド `scripts/job-create/src/index.ts job-patrol`、launchd `com.nextlevel.job-patrol` は運用実体として残す。
- 引き継ぎ履歴: 統合元ログなし。
- 復旧方針: Skillとしては復旧しない。巡回は `job-update` から実行する。
