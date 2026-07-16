親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 可（F01 read-onlyは依存01、F02〜F05は依存08） ／ レビュー: Review 2へ集約

# 実装系カナリア

## 目的

仕事repoで確定した業務系の制御面をfocusmapの実装系repoで再検証し、coding repo固有の計画箱・build gateを壊さず第2カナリアを完了する。全repo監査はChild 11が所有する。

## 現状

1. 仕事repoだけでは、coding repoのコード・仕様・docs・計画の境界を検証できない。
2. focusmapには複数の計画置き場、regular CLAUDE.md、dirty branch/worktreeがあり、一括移行に向かない。
3. paused/archiveは現時点でローカル実体がなく未mountのため、検証済み・導入済みとして数えられない。

## 方針

1. 仕事repoの二段ルーティング・領域固有plan・既存plan整理・rollbackが全PASSしてからfocusmapを第2カナリアにする。
2. focusmapのmain/upstream/worktree状態を安定させ、read-only auditから始める。
3. `docs/plans` 等を全て実行計画と決めつけず、仕様・履歴・現在計画・対象外へ分類する。
4. coding repoではinstall/dev/test/lint/build/deploy gateをAGENTSの局所契約に残し、仕事の `領域/` をコピーしない。
5. focusmapのCLAUDE固有指示の行き先を決めてから、同一repo内symlink標準へ移す。
6. focusmapパイロットPASS後はChild 11へ証拠commitと評価mdを渡す。registryへrollout現在状態を持たせない。

## 実行パッケージ

1. **F01 read-only基線**: root `plans/`、`docs/ai/plans/`、`docs/plans/`、`docs/specs/`、task-router、branch/worktreeを分類する。
2. **F02 人間決定**: canonical base/worktree、実行計画箱、docsの責務、許可するtest/lint/build/diff/browserコマンド、F03/F04の正確な許可path manifestを決める。worktree削除やbranch整理は自動範囲外。
3. **F03 focusmap契約**: 承認された `AGENTS.md`・`CLAUDE.md`・計画router文書だけを編集し、`src/**`、DB、deploy、未宣言root plansを触らない。
4. **F04 E2E/rollback**: 外部副作用なしの計画fixture 1件を既存plan合流/箱不明停止込みで実行し、許可された検証だけを行う。
5. **F05 coding integration**: code/spec/docs/plan境界、local main/origin/main/本番、rollbackの証拠をIntegration担当が固定し、Review 2へ渡す。

## 直列ゲート

F01はChild 01後にread-only先行できる。F02→F03→F04→F05はChild 08 PASS後の直列。現在の複数worktreeが安定し、人間がbase・検証コマンド・許可path manifestを決めるまでF03以降を開始しない。

## 許可path・rollback

- F01はfocusmapを一切編集しない。branch/worktree、候補計画箱、AGENTS/CLAUDE、検証command候補のhash付き台帳だけを中央Child評価へ返す。
- F03の既定許可pathはfocusmap root `AGENTS.md` と `CLAUDE.md`。追加のrouter文書はF02で実在pathを1件ずつ承認し、manifest外へ書かない。`src/**`、DB、deploy設定、worktree/branch削除は禁止。
- F04はF02が承認した計画箱内のfixture 1件と、その評価証拠だけを所有する。既存planへ合流する場合は合流先planの明示pathだけを追加承認する。
- F03は専用commitをrevertし、AGENTS/CLAUDEのfile type・symlink target・content hashがF01 snapshotへ戻ることを確認する。F04はfixture commitだけをrevertし、計画箱・index・Git状態が開始snapshotへ戻ることを確認する。worktree削除、branch改名、push、本番反映はrollbackに含めず別人間gateとする。

## 実装記録

### 2026-07-13 — F01完了

- canonical repoは `/Users/kitamuranaohiro/Private/projects/active/focusmap`。開始/終了とも `temp-cleanup-branch@1c738a468fcd`、dirty 0、worktree 8件すべてclean。
- temp branchは `main@d9a898681548` に対して162 behind / 9 ahead、upstreamなし。mainをcheckout中のworktreeは0。F02推奨はmainから本用途専用worktreeを人間承認で作ること。既存8 worktreeは削除しない。
- `AGENTS.md` はregular（SHA-256 `cf24b01b…`）、`CLAUDE.md` は固有本文を持つregular（`24f346d3…`）。F03は固有内容をAGENTSへlossless統合後、同commitで `CLAUDE.md -> AGENTS.md` とする。
- 現行AGENTSが宣言する新規実行計画箱は `docs/ai/plans/active/`。`docs/plans/**` はproduct設計、`docs/specs/**` は仕様。temp branchだけのroot `plans/` は未統合legacy候補で、移動・正本昇格しない。
- `focusmap-worktrees` はcontainerでrepo数に含めず、linked worktreeはcanonical identityへdedupeする。paused実体は未mountとしてdeferredにする。
- F02推奨許可pathは `AGENTS.md`、`CLAUDE.md`、`docs/ai/plans/active/README.md`。F04は人間承認したcanary plan＋`docs/ai/task-board.md` だけ。`src/**`、DB、package、deploy、root `plans/` は禁止。
- canaryはmetadata/計画導線だけのため、repo-create audit・symlink判定・route fixture・exact path `git diff --check` だけを許可候補とする。npm test/lint/build、Browser、Playwright、curl、deployは不許可のまま。
- F02以降はChild 08 PASSとbase/計画箱/許可commandの人間決定後に開始する。正式採点はReview 2へ集約する。

## 完了条件（レビュー項目）

- [ ] focusmapで仕様・履歴・現在計画の分類が完了し、focusmap `AGENTS.md` が正しい計画箱を一意に宣言している。
- [ ] focusmapの新規計画が人間承認した計画箱でE2Eを通り、既存test/lint/build/deploy gateを壊していない。
- [ ] focusmapのAGENTS/CLAUDEが同一repo内正本原則に従い、固有指示が失われていない。
- [ ] `repo-create` 監査が業務系とcoding系の両fixtureでPASSする。
- [ ] focusmapカナリアの証拠commit・評価md・rollback結果がChild 11へ引き渡されている。
