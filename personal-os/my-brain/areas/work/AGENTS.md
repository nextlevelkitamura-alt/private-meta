# Work Area

このareaは、仕事、キャリア、働き方、案件、転職、職務経歴、面談準備に関する考えと計画を置く場所。

## 1. 置くもの

1. 仕事やキャリアに関する判断軸は `identity.md` に置く。
2. 調査、仮説、方向性、未整理の考えは `thinking/` に置く。
3. 実行する計画は `plans/active/<YYYY-MM-short-name>/plan.md` に作り、状態に応じてバケット（active/paused/done/archive）間を移す（規約は `../AGENTS.md`）。
4. 計画から派生するhuman、AI、repo、Skill、loop作業は、同じ計画フォルダ内の `ops/<種別>/<作業名>.md` に置く（種別・状態の定義は `../AGENTS.md` 参照）。

## 2. 置かないもの

1. 実装repo本体は置かない。必要なら `/Users/kitamuranaohiro/Private/projects/` に置く。
2. 履歴書、職務経歴書、契約、証憑などの実データ正本は、対象repoまたは別途決めた正本に置く。
3. Skill本文、registry、logsは置かない。

## 3. 作業ルール

1. 新しい計画を作る前に、既存の `thinking/` と `plans/` を確認する。
2. まず `plan.md` に全体像を書く。
3. 計画を作ったら `ops/` に種別5フォルダ（`.gitkeep`付き）を作り、作業が出たら `ops/<種別>/<作業名>.md` に置く。
4. confidentialな会社情報、個人情報、認証情報は書かない。
