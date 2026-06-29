分類: skill
種別: 既存改善

# Skill計画種別ルーティング改善計画

- 種別: 既存改善
- 変更内容: docs反映 / workflow接続
- 目的: Skill計画書の種別を明示し、`skill-creator-custom` の新規作成・既存改善workflowから計画書の種別を使えるようにする。
- 対象: `skill-plans/AGENTS.md`、`skills/skill-creator-custom/SKILL.md`、`skills/skill-creator-custom/workflows/create-new.md`、`skills/skill-creator-custom/workflows/review-skill.md`、既存done計画
- 判断: `integrate-skills.md` は今回作らず、まず `新規作成` と `既存改善` を既存workflowへ接続する。

## 実行順

1. `skill-plans/AGENTS.md` に `種別` と `変更内容` を計画書の必須情報として追加する。
2. `skill-creator-custom/SKILL.md` に、計画種別から読むworkflowが分かる短いルーティングを追加する。
3. `create-new.md` に、計画書を使う場合は `種別: 新規作成` を明示する判断を追加する。
4. `review-skill.md` に、既存改善計画では `種別: 既存改善` を明示する判断を追加する。
5. 既存done計画に `種別` と `変更内容` を追記する。

## 完了条件

1. 計画書の冒頭を見れば、状態、種別、変更内容が分かる。
2. 新規Skill作成時に `create-new.md` から計画種別を決められる。
3. 既存Skill改善時に `review-skill.md` から計画種別を決められる。
4. `integrate-skills.md` の新設は次段の保留として扱われている。

## 結果

1. `skill-plans/AGENTS.md` に `種別` と `変更内容` を追加し、計画書冒頭で判別できるルールにした。
2. `skill-creator-custom/SKILL.md` に、計画種別から読むworkflowを決める短いルーティングを追加した。
3. `create-new.md` に、新Skill作成時は `新規作成`、既存Skill追加時は `既存改善` へ切り替える判断を追加した。
4. `review-skill.md` に、既存改善計画の `種別` と `変更内容` を決める判断を追加した。
5. 既存done計画に `種別: 既存改善` と `変更内容: docs反映` を追記した。

## logs/catalog

- logs: Skill作成・移行・削除・改名ではないため更新不要。
- catalog: Skill追加・削除・分類変更ではないため更新不要。

## 保留事項

- `統合整理` と `migrate-skill.md` / 将来の `integrate-skills.md` の整理は次段で扱う。
