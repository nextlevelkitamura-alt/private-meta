分類: 横断 ／ 種別: 統合整理 ／ 規模: フル
並列: 不可 ／ レビュー: 都度

# 説明書を責務別に移行

## 目的

`personal-os/説明書/` の3ファイル（170行）を廃止し、内容を責務を持つ既存の正本へ移す。入口・実行時の参照を解決した状態でフォルダを消し、古い説明書を読まないと運用できない構造をなくす。

## 現状

- `README.md` はPersonal OSの概要と旧cockpit説明、`運用契約.md` は状態・規模・人間ゲート・レビュー、`指揮官ロースター.md` は2026-07-03時点の編成とサブスクを混在させている。
- 現行のSkill、hook、catalog、planテンプレ規約に `説明書/`・`運用契約`・`指揮官ロースター` への参照が残る。参照を直さずに削除するとruntime導線が壊れる。
- 一方、デイリー/session-board、`AIモデル一覧.md`、`loops-registry/AGENTS.md`、`GLOBAL_AGENTS.md` は既に役割を持つ。過去のdaily、完了・paused・archive計画、registry logは当時の記録であり、現在パスへ書き換えない。
- 既存のactive計画は2件。本計画を3件目として動かす。開始時Git snapshot: `c7cbd536d66893fd15e984c01a15c4d7392cc60b`。既存の未コミット変更は対象外として保存する。

## 方針

1. `GLOBAL_AGENTS.md` に、全runtimeが参照する最小限の実行規模・人間ゲート・レビュー・headlessの原則を置く。loop/hook/manualの方式定義は `loops-registry/AGENTS.md`、日次の状態はdaily/session-boardへ残し、本文を重複させない。
2. `AIモデル一覧.md` は契約中の提供元・プランと役割別の選定だけを持つ。古い編成、使用量の実況、月額、当日の担当は移さない。
3. `morning-routine` はデイリー、session-board、モデル一覧、`GLOBAL_AGENTS.md` を参照する読む順の手順へ縮める。ロースター更新や「今」の手書き更新は廃止する。
4. 現在のruntime・正本・active/planning計画だけを新しい正本へ差し替える。履歴ファイルは変更せず、今回の正本変更を `ai運用/決定ログ.md` に追記する。
5. 新旧の参照を静的検査してから `personal-os/説明書/` を削除する。既存の未コミット変更があるファイルは、その差分を消さない狭いhunkだけを変更する。

## 完了条件（レビュー項目）

- [x] `personal-os/説明書/` が存在せず、3ファイルの現行本文が `GLOBAL_AGENTS.md`、`AIモデル一覧.md`、daily/session-board、loops-registryの責務へ重複なく分かれている。
- [x] `personal-os/AGENTS.md`、`my-brain/areas/AGENTS.md`、現行のSkill/hook/catalog/計画テンプレから、削除した説明書への参照がなく、移行先の節・ファイルを指している。
- [x] `skills/morning-routine/SKILL.md` が当日の編成・実況の正本を作らず、daily/session-boardとモデル一覧を参照する手順だけを持つ。
- [x] `AIモデル一覧.md` が提供元・プラン・役割別の選定を持ち、金額・残量・特定日の担当・過去の編成を持たない。
- [x] `my-brain/areas/ai運用/決定ログ.md` に、説明書の廃止理由・新しい正本・履歴を保持する範囲が記録されている。
- [x] `rg` による現行runtime正本の旧参照検査、`plan-ops` のテスト、対象ファイルの `git diff --check` が成功する。履歴・他作業の既存差分は変更していない。

## 実装結果

- `personal-os/説明書/` の3ファイル（170行）と追跡allowlistを削除した。
- テキスト状態・単一指揮官、規模・レビュー・人間ゲート、並列数の目安を `GLOBAL_AGENTS.md` §6-7 へ集約した。
- モデル一覧は提供元・契約プラン・役割別の選定だけを保持し、当日の状態はデイリー/session-boardへ、実行方式は loops-registry へ分離した。
- 現行のSkill、hook、catalog、active/planning計画、人向けHTMLを新しい正本へ切り替えた。過去のdecision log、完了・paused・archive計画、deleted logは履歴として保持した。

## 検証結果

- `plan-ops` 回帰テスト: 87 pass / 0 fail。
- `plan-triage` route fixture・inbox contract: pass。
- session-board: 80 pass / 0 fail、shim: 59 pass / 0 fail。
- plist lint、shell構文、`git diff --check`、現行導線の旧参照scan: pass。

## レビュー結果

- `評価01.md`: 独立reviewerがcatalogの旧参照・ロースター要約、§7の段階語彙不足、モデル正本境界を検出。`修正01.md` に対象・期待状態・非対象を固定して修正した。
- `評価02.md`: 別の独立reviewerが修正差分を再評価し、P0/P1/P2=0、全レビュー項目PASSを確認した。

## 次のゲート

実装・修正・独立レビューは完了した。active → archive の物理移動は人間承認後に行う。
