# Money Area

このareaは、お金、資産、家計、収入、支出、投資、トレードに関する考えと計画を置く場所。

## 1. 置くもの

1. お金や資産に関する判断軸は `identity.md` に置く。
2. 調査、仮説、未整理の考えは `thinking/` に置く。
3. 実行する計画は `plans/active/<YYYY-MM-short-name>/plan.md` に作り、状態に応じてバケット（active/paused/done/archive）間を移す（規約は `../AGENTS.md`）。
4. 計画から派生する作業は、同じ計画フォルダ内の `ops/<種別>/<作業名>.md` に置く（種別・状態の定義は `../AGENTS.md` 参照）。

## 2. 置かないもの

1. secret、token、credential、口座・カード番号、残高の生データ。
2. 実装repo本体（必要なら `/Users/kitamuranaohiro/Private/projects/` に置く）。
3. Skill本文、registry、logs。

## 3. 作業ルール

1. 新しい計画を作る前に、既存の `thinking/` と `plans/` を確認する。
2. まず `plan.md` に全体像を書く。
3. 計画を作ったら `ops/` に種別5フォルダ（`.gitkeep`付き）を作る。
4. 金額の生データや認証情報は書かない。方針と判断だけ残す。
