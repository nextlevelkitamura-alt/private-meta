分類: 横断 ／ 種別: 既存改善 ／ 形態: program
規模: フル
優先: ○

# 仕事デイリーのDB参照化

人間確認方針: 最終一括（危険操作は実行前に個別承認）

## 目的

仕事repo（nextlevel-work）の「本日やること」の参照を、毎回のデイリーmd生成・転記からDB参照へ切り替える。エージェントはセッション開始時に契約md（取り方の説明書）を読み、CLI 1クエリで当日タスクを取得する。これにより、md正本運用の三重化（schedule.md／スプシ管理表F列＋カレンダー／Focusmap）を解消し、正本を1ヶ所にする。

このprogramは2026-07-19の壁打ち・3repo調査から起案した。調査結果と設計結論は `references/` の4文書がスナップショットとして持つ。

## 進め方（このprogramの特殊事項）

**子計画は意図的に未作成。** 次にこのprogramを扱うセッションは、以下の順で子計画を立案する。

1. `references/` の4文書をすべて読む（調査2本 → 設計結論 → SQL入門）。
2. 生きた実装の現状を各正本で再確認する（referencesは2026-07-19時点のスナップショットであり、特に active program「当日ボードSQL化」の進行で状況が変わりうる）。
3. 設計結論の「未決事項」を人間と確定してから、`plans/NN-*.md` の子計画を立てる。
4. active昇格は explain/ の図解提示と人間の実行OKを得てから bucketctl で行う（planning のまま立案までは進めてよい）。

立案時に検討する候補粒度（確定ではない・参考）:

- Tursoスキーマ正本のmigrations/集約（移管の前提条件）
- 契約md＋取得スクリプトの新設（卒業先: 仕事repo `方針/`）
- /morning・/task の参照先切替（Phase 1: 読み取りのみ）
- 完了報告の書き戻しと ai-todo-sync 停止（Phase 2: 正本切替・不可逆）

## 非対象

- 運用データ正本のmd→Turso反転そのもの（active program「当日ボードSQL化」が正本。二重管理しない）
- focusmap既存のSupabase系機能（カレンダー・習慣・ノート等）の改修
- personal-os側デイリーmd（8節）の構成変更（planning「デイリー運用刷新」の領分）
- MCPサーバーの新設・改修（設計結論により取得はCLI/APIを既定とする）

## 正本境界

- 仕様の正本: この program.md と（立案後の）plans/ の子計画
- 調査・設計のスナップショット: `references/`（2026-07-19時点。生きた実装と食い違ったら実装側が正）
- 契約md・取得スクリプトの実体: 卒業先の仕事repo（`/Users/kitamuranaohiro/Private/projects/active/仕事/方針/` 想定）。このareaに実体を置かない
- Tursoスキーマ・todos実装の正本: focusmap repo `db/turso/migrations/` と session-board `turso/`
- 「今日やること」データの正本: 現状は移行期間中（当日ボードSQL化 program の正本境界に従う）

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

（未作成。上記「進め方」に従い、references読了と未決事項の確定後に立案する）

- 次: references/ 4文書の読了 → 未決事項2点（正本の最終確定・migrations集約の先行可否）の人間確認 → 子計画立案

## 人間ゲート

- active昇格（explain提示と実行OK）
- 仕事repoのスキル（/morning・/task）の参照先変更
- ai-todo-sync（md→DB同期）の停止＝正本切替（不可逆）
- Tursoへのmigration適用
- 各repoの origin/main への push

## 完了条件（レビュー項目）

子計画立案時に確定する。現時点の暫定（未確定）:

- [ ] 仕事repoの /morning・/task が「本日やること」をDBから取得し、当月schedule.mdを生成しなくても朝の運用が回る（対象: 仕事repo `.agents/skills/morning/`・`task/`）
- [ ] 契約mdと取得スクリプトが仕事repoに存在し、契約mdに秘密情報の直書きがない（対象: 仕事repo `方針/`・`scripts/`・`.env`）
- [ ] 「今日やること」の正本が1ヶ所であり、ai-todo-syncの二重書きが停止している（対象: 仕事repo `scripts/ai-todo-sync/`）
- [ ] Tursoの全テーブルのCREATE文が migrations/ に集約され、DB再構築が再現可能（対象: session-board `turso/migrations/`・focusmap `db/turso/migrations/`）

## 関連

- active program: `../../active/2026-07-17-当日ボードSQL化/program.md`（todos新設・正本反転の本体。本programはその消費側=仕事repoの参照切替を担当）
- planning: `../2026-07-09-デイリー運用刷新/program.md`（personal-os側デイリー3儀式）・`../2026-07-11-Focusmap自動処理統合/program.md`（管理画面と自動処理契約）
- 対象repo: `/Users/kitamuranaohiro/Private/projects/active/仕事/`・`/Users/kitamuranaohiro/Private/projects/active/focusmap/`
- session-board実装の正本: `../../../../../AIエージェント基盤/hooks-registry/shared/session-board/`

## 終了記録

archive時に必須。実行中は記入しない。
