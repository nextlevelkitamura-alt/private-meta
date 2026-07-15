対象計画: 02-遷移統制とplanctl同期.md ／ ラウンド: 02  
diff範囲: `5583899..b902f36` ／ 評価者: read-only reviewer

# 評価02: 遷移統制とplanctl同期

## 修正01の項目別対応確認

- [PASS] 1. 明示path契約 — 全主要サブコマンドで `--plans-root` が必須になり、`plan`・`plans-root`・`repo-root` の包含関係を検証する。合成repoの `plans/` root を明示した E2E が通過した。

- [PASS] 2. 実commit差分・禁止範囲照合 — `apply-evaluation` は `base_commit..result_commit` の実差分と `changed_paths` の完全一致、変更可能範囲、変更禁止範囲を順に検証する。禁止範囲の差分を拒否する回帰テストも通過した。

- [PASS] 3. progressの対象外バイト不変 — `progress` から大幅更新日の書換えを外し、`progctl_core.py` の対象NN限定更新を利用する。対象外行の不変確認テストが通過した。

- [PASS] 4. `rename --check` — `--date` 不要の読み取り専用JSON出力へ分離された。本体dry-runは `git mv` 候補と参照更新予定を表示し、該当テストも通過した。

- [PASS] 5. phase遷移 — manifest必須キー・型・遷移表を検証し、`running → implemented → review_passed → synced → closed` をE2Eで確認した。

- [FAIL] 6. `apply-evaluation` 失敗時の本文・マップ不変 — 実装は候補を書戻してlint失敗時に本文・親Programを復元する構造であり、本文不変のテストは通る。ただし、親Programマップを伴う失敗fixtureで「本文・マップ双方のバイト不変」を確認する回帰テストがない。修正01の期待テストを満たしていない。

- [PASS] 7. 原子性の基本処理 — lint失敗時に本文を反映しないことはテスト済み。上記6の親マップ同時検証不足は残る。

## 前回PASS項目の退行確認

- [PASS] 遷移ゲート — `ALLOWED` とarchive検証により、許可外遷移、評価未達のdone化、終了記録不足のarchive化を拒否する。

- [PASS] 終了区分 — 5区分を定義し、`completed` の完了条件・最終評価、`superseded` 等の後継・統合先を検証する。

- [PASS] 容量 — `LIMITS` に active=3、paused=3、done=8、planning/archive無制限を一元定義し、`--force` と自動退避はない。

- [PASS] 変更禁止範囲 — 全diffに `hooks-registry/`、`agents-registry/`、session-board本体、テンプレ本文、既存計画フォルダ移動・改名、`progctl`／`program-lint` 実装への変更はない。

## 完了条件の再採点

- [PASS] 規約の `done`・`archive` 定義が一本道と一致し、終了区分5種が規約側にある。通常のcompletedを `active→archive` へ直接案内していない。

- [FAIL] 全許可遷移・容量の回帰テスト網羅性。実装上は遷移表・容量定義とも存在するが、`active→paused`、`paused→planning/active`、`done→active`、直接archive、誤バケットの `move`、既存超過状態の `check` 非0、超過バケットからの退出のテストがない。

- [FAIL] archiveゲートの回帰テスト網羅性。終了記録なし拒否、`cancelled` 成功、後継なし `superseded` 拒否、archive lint は確認済み。しかし、`completed` を「未チェック」または「最終評価なし」で拒否する独立テストがない。

- [PASS] `prepare` は明示引数でmanifestをgitignore配下へ生成し、`progress` は対象外を保持する。合成repoで確認済み。

- [FAIL] `apply-evaluation` の拒否ケース網羅性。FAIL評価は確認済みだが、対象外、文言不一致、誤子番号、result commit欠落の各拒否テストがない。本文・マップの同時不変テストもない。

- [FAIL] `close`・`sync-check` の回帰テスト網羅性。`close` のbucketctl経由と不正result packet検出は確認済みだが、整合済み `sync-check` のJSON・exit 0、および代表的な不整合JSONのテストがない。

- [PASS] `bash personal-os/AIエージェント基盤/skills/plan-ops/__tests__/run.sh` は **148 pass / 0 fail**。`progctl`／`program-lint` 実装は差分なし。合成repoで容量・apply-evaluation・renameを明示 `--plans-root` 指定で実行している。状態はバケット・本文・短命manifestに分離され、第2の状態台帳は追加していない。

## 検証結果

- `bash personal-os/AIエージェント基盤/skills/plan-ops/__tests__/run.sh`: 148 pass / 0 fail
- `git diff --check 5583899..b902f36`: exit 0
- 変更禁止範囲へのdiff: なし
- 評価作業後のworktree: クリーン

## 総合判定

**FAILあり。**

### 修正指示ドラフト

`test_planctl.sh` と `test_bucketctl.sh` に、実装を緩和せず次を追加する。

1. Program子の `apply-evaluation` lint失敗fixtureで、子本文と親Programマップの両方を事前・事後でバイト比較する。
2. 全許可遷移、誤遷移、既存超過、超過バケットからの退出をbucketctlで検証する。
3. `completed` の未チェック完了条件・最終評価なし拒否をarchive遷移で個別に検証する。
4. `apply-evaluation` の対象外、文言不一致、誤子番号、存在しないresult commitを個別に拒否確認する。
5. 整合済み `sync-check` のJSON・exit 0と、不整合時JSON・非0を確認する。