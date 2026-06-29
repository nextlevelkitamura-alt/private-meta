分類: skill
種別: 既存改善

# 既存改善計画書命名ルール改善計画

- 種別: 既存改善
- 変更内容: 整理 / docs反映
- 目的: `既存改善` のSkill計画書で、日付の後に対象Skill名を入れ、どのSkillの改善計画か分かるようにする。
- 対象: `skill-plans/AGENTS.md`、`skills/skill-creator-custom/`、`skills/skill-creator-codex/SKILL.md`、既存改善計画書
- 判断: 単一Skillの改善は `YYYY-MM-DD-<対象Skill名>-日本語改善内容.md` にし、単一Skillに閉じない基盤docs改善だけ `基盤` を対象名にする。

## 実行順

1. 既存改善計画書のファイル名を対象名入りに変更する。
2. `skill-plans/AGENTS.md` に既存改善の命名ルールを追加する。
3. `skill-creator-custom` のレビュー・作成ルールに同じ判断を接続する。
4. `skill-creator-codex` に北村環境の既存改善計画書命名を追記する。

## 完了条件

1. `skill-plans/既存改善/done/` の計画書名から対象が分かる。
2. 既存改善の新規計画書作成時に、対象Skill名をファイル名へ入れるルールが分かる。
3. 単一Skillに閉じない基盤docs改善の例外が分かる。

## 結果

1. `2026-06-27-skill-creator-custom-計画種別ルーティング改善.md` に改名した。
2. `2026-06-27-skill-creator-custom-計画書ディレクトリ構造改善.md` に改名した。
3. 単一Skillに閉じない基盤docs改善は `2026-06-27-基盤-機能説明更新.md` にした。
4. `skill-plans/AGENTS.md` とSkill Creator系の説明に命名ルールを追加した。

## logs/catalog

- logs: Skill作成・移行・削除・改名ではないため更新不要。
- catalog: Skill追加・削除・分類変更ではないため更新不要。

## 保留事項

- なし
