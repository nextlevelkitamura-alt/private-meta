分類: skill
種別: 既存改善

# 計画バケット化

## 目的

計画の状態管理を「plan.md の `状態:` フィールド方式」から「`plans/` 直下のライフサイクルバケット
（active/paused/done/archive）方式」へ統一する。areas側は適用済み。残るは Skill 側のルーティング記述。

## 背景

1. 設計判断は `../../../thinking/plans-lifecycle.md` を参照（フォルダが状態の正本、`状態:` フィールド廃止）。
2. 直前の plans廃止移行（`../../archive/2026-06-29-plans廃止とarea一本化/`）で Codex が Skill ルーティングを
   「フィールド方式」で約12ファイルに書いた。バケット方式に直す必要がある。

## 適用済み（areas側・Claude実施 2026-06-29）

- 全area の plans/ に active/paused/done/archive（+.gitkeep）作成。
- `areas/AGENTS.md` Plan標準構成、`ai運用/AGENTS.md` 計画ルーティングをバケット方式に更新。
- 既存plan を振り分け（active←orca/career、done←done7件）、plan.md から `状態:` フィールド除去。

## Skill側（完了）

2026-06-29 Codex実施・AIエージェント基盤repoコミット済。手順は `ops/ai/codex-skill-bucket化.md`、詳細は下の「結果」。

## 完了条件

1. Skill のルーティングが「`plans/active/<name>/` に作り、状態はバケットで持つ」に統一されている。
2. 「`状態:` を書く／`状態: ready` にする」等のフィールド前提の指示が Global/ai運用 側に残っていない。
3. repo-local（所有repo内 `plans/skills/<種別>/<状態>/`）の記述は変更されていない。

## 結果

2026-06-29 Codex実施。

1. AIエージェント基盤側のGlobal計画ルーティングを `ai運用/plans/active/<name>/plan.md` へ統一した。
2. Global plan.md には `状態:` フィールドを書かず、状態を `active/paused/done/archive` バケットで持つ記述へ更新した。
3. repo-local の `plans/skills/<種別>/<状態>/` 記述は維持した。
4. 検証では、Global新規計画パスの `active/` 抜けと、`状態: planning` / `状態: ready` / `状態: active` のフィールド前提は検出されなかった。
5. 新規Skill作成・移行・削除・改名ではないため、registry logs と catalog の更新は不要。

## 関連thinking

`../../../thinking/plans-lifecycle.md`
