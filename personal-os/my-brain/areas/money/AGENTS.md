# Money Area

このareaは、お金、資産、家計、収入、支出、投資、トレードに関する考えと計画を置く場所。

## 1. 置くもの

1. お金や資産に関する判断軸は `identity.md` に置く。
2. 完成した恒久・再利用可能な参照mdは `知識/` に置く。未確定の構想は `identity.md` か計画の `方針`、特定計画だけの資料は計画内 `references/` に置く。
3. 新規計画は `plans/planning/<YYYY-MM-DD-日本語企画名>/plan.md` に作り、今週実行すると指揮官が決めた時だけ `../AGENTS.md` の `bucketctl` で active へ昇格する。計画に紐づく人間向けHTMLは各計画の `explain/` に置く。repo実行が要る計画は成熟後に実行repoへ卒業させる（規約・卒業手順は `../AGENTS.md`）。
4. 計画から派生する作業は `../AGENTS.md` §4.2 に従う。

## 2. 置かないもの

1. secret、token、credential、口座・カード番号、残高の生データ。
2. 実装repo本体（必要なら `/Users/kitamuranaohiro/Private/projects/` に置く）。
3. Skill本文、registry、logs。

## 3. 作業ルール

1. 新しい計画を作る前に、既存の `plans/` を確認する。
2. まず `plan.md` に全体像を書く。
3. 計画を作ったら `ops/` に種別5フォルダ（`.gitkeep`付き）を作る。
4. 金額の生データや認証情報は書かない。方針と判断だけ残す。
