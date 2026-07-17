親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 都度
人間ゲート: なし（本子はhook本体・runtimeを変更しない。外部依存の既存program子02は実行前に個別承認）

# Prompt Submitへの接続契約を引き継ぐ

## 目的

UserPromptSubmitが「サクッとでない実装を計画なしで始める」見落としを短く回収しつつ、hookが計画の置き場・規模・レビュー結果を勝手に決めない境界を確定する。実装の正本は既存program「完了判定とアーカイブ運用」の子02へ一本化する。

## 現状

- 共有本体 `hooks-registry/shared/session-board/common.py` の `_first_guide` と `_mirror` は、すでにサクッと3条件、計画箱解決、program化、評価文書を長い文字列として注入している。
- hook全体は `events/` と `shared/session-board/` へ未コミット再編中であり、旧 `hooks/session-board/` の削除と新構成が同じ作業ツリーにある。
- 既存programの子02がPrompt Submitの注入文・runtime別E2Eを所有している。ここで同じhook変更を二重に計画しない。

## 方針

1. `plan-registry` と `plan-management` が確定してから、既存子02の方針に「短い計画ゲート」を追記する。文言は「3条件が全YESでない、または不明なら実装前に `plan-management` を使い、既存計画へ合流または正しい計画箱へ起案する」とする。
2. 初回ガイド・実装で計画参照がない時のミラーだけを対象にする。hookは `plan-triage` を実行せず、repo、AGENTS、計画箱、レビュー合否、バケット遷移を決裁しない。
3. 注入本文の生成元は引き続き `shared/session-board/common.py` の1箇所に置く。eventのPython受け口とMDは入出力・責務の説明に留め、本文コピーを作らない。
4. hooks再編の未コミット差分が安定するまで本体を編集しない。安定後、既存子02の実装として `test_common.py` と既存event E2Eを更新・実行する。runtime登録や再trustが必要なら、最終差分を示して人間承認を得る。

## 実装結果（2026-07-15）

- 既存program「完了判定とアーカイブ運用」の子02へ、この子への依存、最小計画ゲート、hookが決めない境界、将来のテストとruntime人間ゲートを引き継ぐ。
- `hooks-registry/`、runtime symlink、hook登録、Codex再trustは変更しない。これらは既存子02の実装時に、再編が安定してから扱う。

## 完了条件（レビュー項目）

- [x] 既存program子02に、この子計画への依存と短い計画ゲートの文言が記録され、hook変更を二重所有していない。
- [x] 注入文が `plan-management` を入口として案内するだけで、hook自身が計画の置き場や合否を決めていない。
- [x] 動的な注入本文は `common.py` の唯一の生成元に残り、runtime別のコピーを増やしていない。
- [x] 既存program子02に、変更時の `test_common.py` と既存event E2E、runtime登録・symlink・再trustの人間ゲートが実装責務として記録されている。この子はhook本体とruntimeを変更しない。
- [x] hooks再編の既存dirty差分を巻き戻し、混在させ、または旧構造を復活させていない。
