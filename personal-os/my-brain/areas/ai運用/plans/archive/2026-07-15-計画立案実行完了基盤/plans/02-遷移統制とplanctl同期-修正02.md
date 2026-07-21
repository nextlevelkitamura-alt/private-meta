出所評価: 02-遷移統制とplanctl同期-評価02.md ／ ラウンド: 02（フル上限=2の最終ラウンド） ／ 宛先: 子02実装担当（codex・task/pf02）

# 修正02: 遷移統制とplanctl同期

※ 実装の挙動は評価02で全て対応確認済み。残りは**回帰テストの追加のみ**。実装を緩和せず、`__tests__/test_planctl.sh`・`test_bucketctl.sh` へ次の5系統を追加する。全てworktree（task/pf02）内・パス指定commit。

## 追加するテスト

1. Program子の `apply-evaluation` lint失敗fixtureで、子本文と親Programマップの**両方**を事前・事後でバイト比較（双方不変）。
2. bucketctlの全許可遷移（active→paused／paused→planning・active／done→active／非completed直接archive）と、誤遷移拒否・既存超過バケットの `check` 非0・超過バケットからの退出成功。
3. `completed` archiveの拒否2種を個別に: 完了条件が未チェック／最終評価が全PASSでない。
4. `apply-evaluation` の拒否4種を個別に: 対象計画不一致・完了条件の文言不一致・誤った子番号・存在しないresult commit。
5. `sync-check`: 整合済み計画でJSON出力かつexit 0、代表的な不整合（マップと子状態の乖離等）でJSON出力かつ非0。

## 完了時

- `bash skills/plan-ops/__tests__/run.sh` 全緑（件数増を確認）→ パス指定commit → 最終メッセージに「## 実装結果」（最終commit・追加テスト件数・全suite結果）。
