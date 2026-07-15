親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 都度
人間ゲート: なし

# planctlと計画同期

## 目的

実装結果（result packet）と評価結果（評価NN.md）から、計画本文の完了条件チェックボックス・実装結果・Programマップ・バケットを決定的に同期する `planctl` を追加する。「実装が終わったのに子計画・チェックボックス・Programマップが古い」という手動更新の穴を塞ぐ。

## 非対象

- バケット移動の遷移・容量検証そのもの（01の `bucketctl` を呼んで使う。再実装しない）
- worktree作成・runtime起動（08のharness）
- Hookからの自動実行（10はsync-checkを「案内」するだけで、編集はしない）

## 現状

現行 `progctl` は、既存Program子ブロックの 状態・次の一手・参照commit だけを更新できる。評価結果から 子計画の完了条件 `[ ]→[x]`・実装結果の追記・Programマップの状態とチェックボックス・終了区分 を同期する機能は無く、大部分が手動更新である（references/2026-07-15-計画実行基盤/01 §2.2）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/skills/plan-ops/SKILL.md`・`references/script-map.md`・`scripts/progctl_core.py`・`scripts/_planops_map.py`
  2. `../program.md`・この計画
  3. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §11-12（planctlサブコマンド仕様・result packet）
  4. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §10-11（同期の安全条件・run manifest・phase語彙）
- 依存成果: 01の `bucketctl` 拡張（遷移・容量・終了記録検証）、05のテンプレ（実行指示.md・実行結果.json・終了記録.md）
- 変更可能範囲: `skills/plan-ops/scripts/planctl.py`（新規）と必要な共通core、`skills/plan-ops/__tests__/`、`SKILL.md`・`references/script-map.md` の該当節
- 変更禁止範囲: `progctl`・`bucketctl`・`program-lint` の既存挙動（planctlからの呼び出しは可）、`hooks-registry/`、`agents-registry/`、既存計画本文
- 維持する契約: 推測で対象planを探さず常に明示pathを受ける／state（run manifest・process output）はgitignore配下／既存 `progctl`・`bucketctl` の単体利用互換
- 検証: plan-opsの全テスト＋evaluation sync の正常系・拒否系テスト
- 停止・エスカレーション条件: 評価.mdの現行書式では完了条件の文言一致判定が機械的に成立しない場合（書式変更が必要なら05へ差し戻す）／manifest schemaが08と矛盾する場合
- 完了時に返す情報: 02指示書§24の完了報告形式

## 方針

1. `planctl.py` を新設し、既存 `progctl`・`bucketctl` は互換維持のまま、上位操作をまとめるfaçadeにする。
2. サブコマンドは5つ。`prepare`（plan/program/childを明示引数で受け、task_id・runtime・repo・base SHA・worktree・branchをrun manifestへ書き、実行指示を生成。stateはgitignore配下）／`progress`（Program既存子ブロックの状態・次・参照を更新。対象子以外はバイト不変）／`apply-evaluation`（下記4）／`close`（終了区分と人間確認を記録し、終了条件を検証し、bucketctl経由でarchiveへ移動。Programは親全体の整合を検査）／`sync-check`（result packet・評価MD・完了条件・子状態・Programマップ・bucket・終了記録の整合をJSONと人間向け出力で返す）。
3. run manifestは実行時だけのJSON（version・task_id・role・runtime・repo_root・plan_path・program_path・child_id・base_commit・worktree_path・branch・result_path・evaluation_path・phase）とし、git管理しない。phase語彙は `running／implemented／review_passed／synced／closed／blocked`。
4. `apply-evaluation` の安全条件: 評価MDの対象計画が一致する／完了条件の文言が計画と完全一致する／全項目がPASS／`対象外`・未採点が無い／result commitが存在する／禁止範囲違反が無い／Program子は親backlinkと子番号が一致する。一つでも満たさなければ自動で完了にせず、FAIL・対象外・文言不一致を理由付きで返す。満たす場合だけ `[x]` 同期・実装結果追記・Programマップ同期・参照commit記録・lint実行・manifest phaseを `synced` にする。
5. result packet（実行結果.json）のschema検証を行い、`status=done|blocked|partial|failed`、未実行テストのpassed偽装を検出できる形にする。

## 完了条件（レビュー項目）

- [ ] `planctl prepare` が明示引数からrun manifestと実行指示を生成し、manifest・process outputがgit追跡されない。
- [ ] `apply-evaluation` が全PASS時のみ完了条件を `[x]` にし、FAIL／対象外／文言不一致／誤った子番号／result commit欠落 をそれぞれ拒否するテストがある。
- [ ] 同期後に 子計画の実装結果・Programマップの状態とチェックボックス・参照commit が一致し、`progress` は対象子以外をバイト不変に保つ。
- [ ] `close` が終了区分・人間確認の記録なしにarchive移動を実行せず、bucketctl（01）の遷移・容量・終了記録検証を迂回しない。
- [ ] `sync-check` が result／評価／完了条件／子状態／マップ／bucket／終了記録 の不整合をJSONで返し、整合時は0で終了する。
- [ ] result packetのschema検証が不正JSON・必須欠落・不正statusを検出する。
- [ ] plan-opsの全テストが通り、既存 `progctl`・`bucketctl` の単体利用が変更前と同じ挙動である。
