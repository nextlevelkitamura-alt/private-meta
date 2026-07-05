# job-create-flow

- 日付時刻: 2026-06-29 12:44 JST
- repo-id: `仕事`
- repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 旧Skill: `.agents/skills/job-flow`
- 新Skill: `.agents/skills/job-create-flow`
- 概要: 求人系の旧統合ハブ `job-flow` を、求人作成専用の `job-create-flow` に改名した。
- 移行理由: 求人作成、既存求人更新、リンク確定、巡回が混在してSkill選定が曖昧になっていたため。
- 移行内容: `求人作成.md` と `月次複製.md` の2workflowへ整理し、複製元リンク、登録前ゲート、作成後リンク確定を `求人作成.md` に統合した。
- 移行先: 既存求人の編集・募集・画像差し替え・時間帯追加・更新戦略・求人巡回は `.agents/skills/job-update` へ移管。
- 所有repo側の導線: `AGENTS.md`、`work-skill-guide`、`CATALOG.md` を更新済み。
- 備考: 旧 `job-flow` ディレクトリは削除扱いではなく、`job-create-flow` へのリネームとして扱う。
