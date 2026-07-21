出所評価: 02-遷移統制とplanctl同期-評価01.md ／ ラウンド: 01 ／ 宛先: 子02実装担当（codex・task/pf02）

# 修正01: 遷移統制とplanctl同期

※ 修正はすべてworktree（task/pf02）内で行い、パス指定でcommitする。

## 修正項目

### 1. planctlの明示path契約（repo非依存）

- 対象: `skills/plan-ops/scripts/planctl.py`
- 今の状態: 明示 `plans/` rootを受けず、`--repo-root` から親ディレクトリを推測している。
- 期待する状態: `plans/` root・plan・program・repo rootを必要箇所で明示指定でき、指定間の整合（planがそのplans/root配下にある等）を検証する。Privateのareaでもrepo-local `plans/` でも推測なしに同じに動く。
- 修正方法: 明示引数（例: `--plans-root`）とcontainment検査を追加。既存呼び出し互換が必要なら明示引数を優先し推測を廃止。
- やらないこと: バケット語彙・遷移表の変更。

### 2. result packetの実差分・禁止範囲照合

- 対象: `planctl.py`（apply-evaluation系）
- 今の状態: `changed_paths` は絶対パス/`../` の拒否のみで、計画の変更禁止範囲との照合も `base_commit..result_commit` の実commit差分との照合もない。
- 期待する状態: apply-evaluationの安全条件として、result packetの変更パスが (a) 実差分と一致し (b) 計画の変更可能範囲内で (c) 禁止範囲に触れていないことを検証し、違反時は同期しない。
- 修正方法: git diffの実測（`--name-only base..result`）と計画実行契約の範囲記述の照合を実装し、正常・違反の回帰テストを追加。
- やらないこと: 違反時の自動修正・自動revert。

### 3. progressの対象外バイト不変

- 対象: `planctl.py`（progress）
- 今の状態: `progress --apply` がProgram先頭の `大幅更新日` を書き換え、対象子以外バイト不変の契約に反する。
- 期待する状態: progressは対象子ブロックだけを書き換え、それ以外はバイト不変。大幅更新日の記録は `rename` 系の責務（または明示フラグでのみ）に分離。
- 修正方法: 書換え範囲を子ブロックに限定し、前後バイト比較テストを追加。
- やらないこと: 大幅更新日機構そのものの削除（責務移動のみ）。

### 4. rename --check の読み取り専用化

- 対象: `planctl.py`（rename）
- 今の状態: `--check` に不要な `--date` が必須で、dry-runが参照追従差分を提示しない。
- 期待する状態: `rename --check` は引数最小（plan pathのみ）の読み取り専用でJSON（rename_required等）を返す。`rename` 本体の既定dry-runは、日付renameと参照追従の変更候補一覧を提示する。
- 修正方法: 引数解析の分離と、dry-run出力の実装＋テスト。
- やらないこと: mtime推測判定の導入（メタデータ記録日ベースを維持）。

### 5. 回帰テストの補完

- 対象: `skills/plan-ops/__tests__/test_planctl.sh`
- 今の状態: 終了記録なしarchive拒否までしか検証がない。
- 期待する状態: rename（--check含む）／禁止範囲違反拒否／非completed archiveの正常・拒否／archive lint検出／repo-local合成 `plans/` rootでの動作、の回帰テストが揃い全緑。
- 修正方法: 合成repofixtureを使ったケース追加。
- やらないこと: 既存テストの削除・緩和。

### 6.（追加指摘対応・小）manifest phase遷移とcloseの経路

- 対象: `planctl.py`
- 今の状態: manifest読込がphase以外を検証せず、`close` がmanifestを受けず `closed` へ遷移できない。implemented/review_passed/blockedへ進める経路が無い。
- 期待する状態: manifest読込は必須キー・型を検証（不正はエラー）。phaseを進める明示手段（例: `planctl phase --to implemented|review_passed|blocked` または各サブコマンドが対応phaseを更新）と、closeでのclosed遷移が成立する。
- 修正方法: 最小のphase更新経路を追加しテストで遷移列（running→implemented→review_passed→synced→closed）を検証。
- やらないこと: 03のharness側manifest生成の変更（schema契約は03と共有・矛盾させない）。

### 7.（追加指摘対応・小）apply-evaluationの原子性

- 対象: `planctl.py`
- 今の状態: 本文・マップ書換え後にlintし、失敗時に途中変更が残る。
- 期待する状態: 事前検証（一時生成でのlint）を通してから原子的に反映し、失敗時に本文・マップを変更しない。
- 修正方法: tempへ生成→lint→OK時のみ書き戻し。失敗時不変のテストを追加。

## 完了時

- `bash skills/plan-ops/__tests__/run.sh` 全緑を確認し、論理単位でcommit（パス指定・日本語メッセージ）。
- 最終メッセージに「## 実装結果」（状態／最終commit／変更ファイル／テスト結果／既存互換性）を返す。
