親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 不可 ／ レビュー: 都度

# 実装系カナリアと全repo展開

## 目的

仕事repoで確定した業務系の制御面をfocusmapの実装系repoで再検証し、repo類型ごとの差を保ったまま残りの管理対象repoへ展開する。

## 現状

1. 仕事repoだけでは、coding repoのコード・仕様・docs・計画の境界を検証できない。
2. focusmapには複数の計画置き場、regular CLAUDE.md、dirty branch/worktreeがあり、一括移行に向かない。
3. paused repo群の一部は外部SSD不在時に監査できない。

## 方針

1. 仕事repoの二段ルーティング・領域固有plan・既存plan整理・rollbackが全PASSしてからfocusmapを第2カナリアにする。
2. focusmapのmain/upstream/worktree状態を安定させ、read-only auditから始める。
3. `docs/plans` 等を全て実行計画と決めつけず、仕様・履歴・現在計画・対象外へ分類する。
4. coding repoではinstall/dev/test/lint/build/deploy gateをAGENTSの局所契約に残し、仕事の `領域/` をコピーしない。
5. focusmapのCLAUDE固有指示の行き先を決めてから、同一repo内symlink標準へ移す。
6. focusmapパイロットPASS後、`audit-all` で管理対象repoを列挙し、各repoに導入済み・保留・対象外・再開時導入を記録する。
7. active repoはregistryで担当repoを解決し、各repo `AGENTS.md` が宣言する計画箱へ個別計画を立てて1repoずつ進める。paused/archiveへ一律変更をかけない。
8. 全repoの状態はregistry索引に持たせ、各repoの詳細・現在状態をコピーしない。

## 完了条件（レビュー項目）

- [ ] focusmapで仕様・履歴・現在計画の分類が完了し、focusmap `AGENTS.md` が正しい計画箱を一意に宣言している。
- [ ] focusmapの新規計画がroot `plans/` でE2Eを通り、既存test/lint/build/deploy gateを壊していない。
- [ ] focusmapのAGENTS/CLAUDEが同一repo内正本原則に従い、固有指示が失われていない。
- [ ] `repo-create` 監査が業務系とcoding系の両fixtureでPASSする。
- [ ] `audit-all` が全管理対象repoを導入済み・保留・対象外・未mountに分類し、理由と次の一手を持つ。
- [ ] active repoはそれぞれ所有repoの `AGENTS.md` が宣言する計画箱に独立計画を持ち、横断programは索引だけを持つ。
- [ ] registryは各repoの入口と展開状態だけを持ち、領域表・計画本文・現在状態を複製していない。
- [ ] paused/archive repoに未承認の書込み・移動・symlink変更がない。
- [ ] 全repoでGlobal本文コピー、cross-repo symlink、tracked secret、危険自動commit hookが0件である。
- [ ] 人間が業務系・実装系の双方を確認し、全repo展開完了を承認している。
