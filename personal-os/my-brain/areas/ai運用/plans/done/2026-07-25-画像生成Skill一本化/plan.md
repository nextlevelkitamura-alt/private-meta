分類: skill ／ 種別: 既存改善
テンプレ: v3
規模: ライト
テーマ: 未接続

# 画像生成Skill一本化

## 目的

`images-generate` を、依頼内容を組み込み `image_gen` に直接渡すだけの一枚Skillへ縮小する。

## 完了条件

- [x] `skills/images-generate/` 直下に `SKILL.md` だけが残り、英語化・モックアップ・CLI委任の指示がない。
- [x] `SKILL.md` はユーザー指定を優先し、組み込み `image_gen` を直接使うことだけを定義する。
- [x] `catalog/applied.md` と `sns-post` の連携記述が、直接実行の内容と整合する。
- [x] 現役Skillから削除済みの `images-generate/workflows`・`references`・`agents`・`evals` への参照がない。
- [x] 4つの既存symlinkが同じ `SKILL.md` を読める。

## 実行ライン

<!-- 基本は直列、並列は区間として埋め込む。子計画への分割は既定で行わない（program化は例外）。
     並列区間の書式: 03 ⇉ 並列区間 { 03a … / 03b … / 03c … } → 04で合流
     セーブポイント評価は [SAVE] を付ける（1回。FAIL時は修正1回→再評価。再FAILのみ人間へ）。 -->
- [x] 01 承認済みの最小本文へ更新し、不要な6ファイルを削除する。
- [x] 02 現役参照とcatalogを最小更新する。
- [x] 03 [SAVE] 構成・参照・symlinkを検証し、評価結果を記録する。
- [x] 04 完了条件チェック → done 申請。

## 記録

- 2026-07-25: ユーザー承認。モデル名は固定せず、組み込み `image_gen` を「Image Gen 2」と呼ぶ運用にする。
- 2026-07-25: `SKILL.html` は作らない。ユーザーが「SKILL.mdだけ」を明示したため、設計説明は一時HTMLに分離する。
- 2026-07-25: `plan-lint.sh`、削除済みpathの参照検索、6本のsymlink読込、`git diff --check` がPASS。評価は `評価/評価01.md`。
