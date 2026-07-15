親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 一括（Wave 4完了時に02・03・04の3子をまとめてレビュー。CLI引数・schema等の共通契約を変える修正が必要になった場合だけ即差し戻し）
人間ゲート: なし（既存計画の実移動は05が所有。ここは機構とテストのみ）

# 遷移統制とplanctl同期（Wave 2）

## 目的

計画バケットの遷移・容量・終了区分を機械の門番にし（bucketctl拡張）、実装結果（result packet）と評価結果（評価NN.md）から計画本文・Programマップを決定的に同期する `planctl` を作る。「実装が終わったのに計画が古い」「閉じた理由が残らない」の両方をこの1子で塞ぐ。

## 非対象

- 既存計画の実際のバケット移動・是正（05が所有）
- PreToolガード・Stop guard・Prompt Submit注入文（04が所有）
- テンプレ本文とplan lint（01が所有。ここは遷移・同期・終了記録の検証機構）
- worktree作成・runtime起動・ゴールコマンド（03。planctlは03から呼ばれる部品）

## 現状

`areas/AGENTS.md` は `done=完了・未評価`／`archive=評価済みOK` と定義する一方、評価ゲートは「最終評価md全PASSでdone」となっており、誰が何を確認してarchiveへ動かすかが曖昧。`bucketctl` はplanning→activeだけを扱い、active→done/archiveは手動 `git mv`。実運用では成功以外の理由（置換・統合・矛盾・中止）でも計画を閉じるが、記録する場所が無い。paused=24・done=18（2026-07-13時点）の滞留を止める機構も無い。

`progctl` はProgram子ブロックの状態・次・参照commitの更新のみで、評価結果からチェックボックス・実装結果・マップを同期する機能は無く、大部分が手動更新である（references/2026-07-15-計画実行基盤/01 §2.2-2.3）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/skills/plan-ops/SKILL.md`・`references/script-map.md`・`scripts/progctl_core.py`・`scripts/_planops_map.py`
  2. `../program.md`（レビュー運用と完走スキーム）・この計画
  3. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §9-12（archive再定義・bucketctl・planctl・result packet）
  4. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §9-11（終了区分・同期の安全条件・run manifest・phase語彙）
- 実行形: delegated-single（bucketctl→planctlは同一scripts群で契約が密なため内部直列）
- 依存成果: 01のテンプレ（実行指示.md・実行結果.json・終了記録.md）とplan-lint
- 変更可能範囲: `skills/plan-ops/scripts/`（bucketctl拡張・planctl.py新設・共通core）、`skills/plan-ops/__tests__/`、`SKILL.md`・`references/script-map.md` の該当節、状態意味・遷移・容量・終了区分を定義する規約箇所（`my-brain/areas/AGENTS.md` §3-4、`ai運用/AGENTS.md` §3、`GLOBAL_AGENTS.md` §7、`plan-registry/AGENTS.md` の該当行）
- 変更禁止範囲: 既存計画フォルダの移動・改名、`hooks-registry/`、`agents-registry/`、session-board本体、progctl・program-lintの既存挙動（呼び出しは可）、テンプレ本文（01所有）
- 維持する契約: 状態はフォルダだけで持つ／bucketctl・progctlの既存サブコマンド互換／planctlは明示pathのみ受け推測しない（**`plans/` rootを明示引数で受けるrepo非依存の作り。Privateのareaでもrepo-local `plans/` でも同じに動く**）／state（manifest・process output）はgitignore配下／対象path限定commit
- 検証: `skills/plan-ops/__tests__/run.sh` 全緑＋遷移・容量・終了記録・evaluation syncの正常/拒否テスト
- 停止・エスカレーション条件: 規約間の状態語彙矛盾が解消できない／評価.mdの書式で文言一致判定が機械的に成立しない（→01へ差し戻し）／manifest schemaが03と矛盾／未コミット再編差分と対象pathが衝突
- 完了時に返す情報: result packet（status・base_commit・result_commit・changed_paths・tests・assumptions・blockers・remaining_risks・out_of_scope_findings）

## 方針

### A. 状態の意味と終了区分

1. `active`=実装・修正・AIレビュー中、`done`=実装済みかつ最終評価md全PASS（人間のクローズ判断待ち）、`archive`=人間が閉じると明示確認し終了記録を残した参照専用、と正本の意味を固定する。状態はフォルダだけで持つ。
2. 終了区分を導入する: `completed`／`superseded`（後継へ置換）／`merged`（統合）／`conflict`（矛盾で終了）／`cancelled`（中止）。`completed` だけ全完了条件 `[x]`・最終評価全PASS・Program全子完了を要求。その他は未完了を許すが 理由・人間確認・未完了事項 を必須にし、`superseded/merged/conflict` は後継・統合先も必須。未完了の `completed` 偽装を機械が拒否する。
3. 終了記録（01のテンプレ）を必須にし、archive lintで 終了記録の欠落・completed偽装 を検出する。

### B. bucketctl拡張（移動の門番）

4. 許可遷移: `planning→active`、`active→paused/done`、`paused→planning/active`、`done→active/archive`、`planning/active/paused→archive`（非completed終了区分＋終了記録＋人間確認がある時だけ）。容量: `planning/archive=無制限・active=3・paused=3・done=8` を一箇所で定義し移動先にだけ適用。`--force`・自動追い出しなし。既定dry-run・`--apply`/`--commit`・`check --json`（件数・上限・対象一覧）。
5. `active→done` は最終評価全PASSの確認後だけ、`done→archive`・非completed archiveは人間の明示発言の記録＋終了記録の後だけ通す。上限超過時は非ゼロ停止し、件数・一覧・必要な人間判断を出す（規約を満たさないdone/archive化を解決策として提案しない）。

### C. planctl（実装結果→計画の同期）

6. `planctl.py` を新設し、progctl・bucketctlは互換のままfaçadeとして束ねる。サブコマンド: `prepare`（明示引数からrun manifest＋実行指示を生成。stateはgitignore配下）／`progress`（子ブロック更新・対象子以外バイト不変）／`apply-evaluation`（下記7）／`close`（終了区分・人間確認を記録しbucketctl経由でarchive）／`sync-check`（result・評価・完了条件・子状態・マップ・bucket・終了記録の整合をJSONで返す）。
7. `apply-evaluation` の安全条件: 対象計画一致・完了条件の文言完全一致・全PASS・対象外/未採点なし・result commit実在・禁止範囲違反なし・（Program子は）親backlinkと子番号一致。1つでも欠ければ完了にせず理由を返す。満たす時だけ `[x]` 同期・実装結果追記・マップ同期・参照記録・lint実行・phaseを `synced` へ。
8. run manifest（version・task_id・role・runtime・repo_root・plan_path・program_path・child_id・base_commit・worktree_path・branch・result_path・evaluation_path・phase）はgit管理しない。phase語彙: `running/implemented/review_passed/synced/closed/blocked`。result packet（実行結果.json）のschema検証で未実行テストのpassed偽装を検出する。
9. `rename` サブコマンドを追加する（2026-07-15人間指示: 計画を大幅更新したらフォルダ日付を最新化する）。`planctl rename --plan <path> --date YYYY-MM-DD` が `git mv` による日付部分の更新と、repo内の旧フォルダ名参照（program.md・子・explain・boardの計画列など、grepで検出した箇所）の追従書き換えを既定dry-runで行う。名前部分の変更や日付以外のrenameは対象外（人間ゲートのまま）。バケット移動とは独立で、上限検査は不要。あわせて `rename --check` の機械判定契約を定める: 「大幅更新日」は `progress`／`apply-evaluation` が計画メタデータへ記録した最新日付とフォルダ日付の比較で判定し、`rename_required` をJSONで返す。**ファイルmtimeによる推測判定は採用しない**（hooks設計調査 §1・04のsession-end案内はこの `--check` を呼ぶだけにする）。
10. 状態意味・遷移・容量・終了区分の規約箇所を同じ作業単位で同期し、既存の完了・アーカイブ・WIP規則の参照箇所をgrepで追従確認する。

## 完了条件（レビュー項目）

- [ ] 規約の `done`・`archive` 定義が一本道と一致し、`archive=閉じた計画`＋終了区分5種が規約側にあり、`active→archive` 直接遷移を案内していない。
- [ ] 全許可遷移と容量（active=3・paused=3・done=8・planning/archive=無制限）が一箇所で定義され、成功・評価不足・誤バケット・上限到達・既存超過・超過バケットからの退出のテストがある。`--force`・自動退避が無い。
- [ ] `done→archive`・非completed archiveが確認記録＋終了記録なしに実行できず、`completed` は全 `[x]`＋最終評価全PASSなしに通らず、`superseded/merged/conflict` は後継・統合先なしに通らないことを成功・拒否双方でテストできる。archive lintが終了記録欠落・completed偽装を検出する。
- [ ] `planctl prepare` が明示引数からmanifestと実行指示を生成し、stateがgit追跡されない。`progress` は対象子以外をバイト不変に保つ。
- [ ] `apply-evaluation` が全PASS時のみ `[x]` 同期し、FAIL／対象外／文言不一致／誤った子番号／result commit欠落 をそれぞれ拒否するテストがある。同期後に実装結果・マップ・参照commitが一致する。
- [ ] `close` がbucketctlの検証を迂回せず、`sync-check` が不整合をJSONで返し整合時0で終了する。result packetのschema検証が不正JSON・必須欠落・不正statusを検出する。
- [ ] plan-opsの全テストが通り、progctl・bucketctlの単体利用が変更前と同じ挙動である。状態・終了区分を第2の状態台帳にしていない。遷移・容量・apply-evaluation・renameが、Private以外の合成repoの `plans/` を明示指定しても同じに動く。
