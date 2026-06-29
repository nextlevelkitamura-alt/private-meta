分類: skill
種別: 既存改善

# Skill計画書ディレクトリ構造改善計画

- 種別: 既存改善
- 変更内容: 整理 / docs反映
- 目的: Skill計画書を `skill-plans/<種別>/<状態>/` で管理し、Finder上で新規作成・既存改善・統合整理を見分けやすくする。
- 対象: `skill-plans/`、`skill-plans/AGENTS.md`、`AGENTS.md`、`README.md`、`skills/skill-creator-custom/`、`skills/skill-creator-codex/SKILL.md`
- 判断: `planning/active/done` を最上位に置かず、`新規作成`、`既存改善`、`統合整理` の下に状態フォルダを置く。

## 実行順

1. `skill-plans/新規作成/`、`skill-plans/既存改善/`、`skill-plans/統合整理/` の下に `planning/`、`active/`、`done/` を作る。
2. 既存計画書を `skill-plans/既存改善/done/` へ移し、日付後ろに対象名と日本語の内容を入れる。
3. `skill-plans/AGENTS.md` を新しい階層と日本語ファイル名ルールに合わせる。
4. `AGENTS.md`、`README.md`、Skill Creator系の参照を新しい配置に合わせる。
5. 旧 `skill-plans/planning`、`skill-plans/active`、`skill-plans/done` を空にして廃止する。

## 完了条件

1. Finderで `skill-plans/<種別>/<状態>/` の順に辿れる。
2. 既存改善計画書のファイル名が `YYYY-MM-DD-<対象名>-日本語改善内容.md` になっている。
3. `skill-creator-custom` から新しい計画書配置に迷わず接続できる。
4. `logs/catalog` 更新不要の理由を説明できる。

## 結果

1. `skill-plans/新規作成/`、`skill-plans/既存改善/`、`skill-plans/統合整理/` の下に `planning/`、`active/`、`done/` を作った。
2. 既存計画書を `skill-plans/既存改善/done/` に移し、ファイル名を対象名入りにした。
3. `skill-plans/AGENTS.md`、`AGENTS.md`、`README.md`、Skill Creator系の参照を新しい配置に合わせた。
4. 旧 `skill-plans/planning`、`skill-plans/active`、`skill-plans/done` を廃止した。

## logs/catalog

- logs: Skill作成・移行・削除・改名ではないため更新不要。
- catalog: Skill追加・削除・分類変更ではないため更新不要。

## 保留事項

- なし
