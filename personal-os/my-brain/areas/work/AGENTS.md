# Work Area

このareaは、仕事、キャリア、働き方、案件、転職、職務経歴、面談準備に関する考えと計画を置く場所。

## 1. 置くもの

1. 仕事やキャリアに関する判断軸は `identity.md` に置く。
2. 完成した恒久・再利用可能な参照mdは `知識/` に置く。未確定の構想は `identity.md` か計画の `方針`、特定計画だけの資料は計画内 `references/` に置く。
3. 新規計画は `plans/planning/<YYYY-MM-DD-日本語企画名>/plan.md` に作り、今週実行すると指揮官が決めた時だけ `../AGENTS.md` の `bucketctl` で active へ昇格する。計画に紐づく人間向けHTMLは各計画の `explain/` に置く。repo実行が要る計画は成熟後に実行repoへ卒業させる（規約・卒業手順は `../AGENTS.md`）。
4. 計画から派生する作業は `../AGENTS.md` §4.2 に従う。

## 2. 置かないもの

1. 実装repo本体は置かない。必要なら `/Users/kitamuranaohiro/Private/projects/` に置く。
2. 履歴書、職務経歴書、契約、証憑などの実データ正本は、対象repoまたは別途決めた正本に置く。
3. Skill本文、registry、logsは置かない。

## 3. 作業ルール

1. 新しい計画を作る前に、既存の `plans/` を確認する。
2. まず `plan.md` に全体像を書く。
3. 計画を作ったら `ops/` に種別5フォルダ（`.gitkeep`付き）を作り、作業が出たら `ops/<種別>/<作業名>.md` に置く。
4. confidentialな会社情報、個人情報、認証情報は書かない。
