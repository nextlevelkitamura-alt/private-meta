# ai運用 Area

このareaは、Personal OS基盤、Global Skill、repo、loop、CLIの運営に関するThemeを置く。実装の正本は `../../../AIエージェント基盤/` であり、このareaへ実装コード、registry、hook、credentialは置かない。

## 正本と配置

1. 構想、調査、会話記録は `themes/<Theme>/concepts/{topics,research,discussion-logs}/` に置く。
2. Theme固有の実行計画は `themes/<Theme>/plans/<planning|active|done|archive>/<計画名>/plan-0.md` を親正本にする。独立した子の実行が必要な時だけ同じ計画フォルダに `plan-NN-<名前>/plan.md` を置く。評価は `evaluations/` に置く。
3. AI運用直下の `plans/`、`知識/`、`決定ログ.md` は廃止した。新しい計画・知識・決定ログをこれらの名前で作らない。
4. Themeに属さない実装計画は、所有repoの最寄り `AGENTS.md` が宣言する計画箱を正本にする。横断であってもai運用直下へ計画を作らない。
5. 新しい決定はThemeの `goal.md`、具体的な `plan-0.md` / 子 `plan.md`、または実際の規約を所有する `AGENTS.md` へ反映する。discussion-logsは会話記録であり、決定の第2正本にしない。

## 作業ルール

1. 最初に対象Theme最寄り `AGENTS.md` と既存の `plans/` を読む。Themeが未確定ならThemeを作る前に目的と境界を確認する。
2. 規模、評価、状態遷移、routeは `../AGENTS.md` と `../../../AIエージェント基盤/plan-registry/AGENTS.md` を正とする。
3. 具体的な計画だけに必要な資料は計画フォルダへ置けるが、汎用 `references/` を既定で作らない。Theme全体の調査・比較・根拠は `concepts/research/` に置く。
4. secret、token、credential、署名URL、DB migration、R2設定を記録しない。

## 完了条件

1. ai運用直下には `AGENTS.md`、`CLAUDE.md`、`themes/` と必要な管理ファイルだけがある。
2. Themeの構想・計画・評価の正本が上記構造内で一意である。
3. Theme外の実装計画をこのareaへ複製していない。
