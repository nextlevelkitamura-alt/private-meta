対象計画: 02-遷移統制とplanctl同期.md ／ ラウンド: 05（子06のE2Eによる横断検出）
diff範囲: 統合branch（a181adf時点） ／ 評価者: 子06 E2E担当（sonnet5）＋指揮官

# 評価05: E2E欠陥B（planctlの範囲書式解釈）

## 検出（E2E系統1・2 / 2026-07-16）

- [FAIL] `planctl.py` の `range_items()`/`matches_range()` が、backtick付き・`・`区切り・日本語注記混在の実際の「変更可能範囲:」書式（本program自身の子計画で使用中の形式）を解釈できず、正当な差分を範囲外として拒否しうる。`program_run.py::_contract()` はbacktick対応済みでモジュール間の解釈が不一致。
- 原因はテストfixtureが簡略書式のみだったこと（テストは通るが実データで動かない乖離）。

## 対応（修正03相当・子06統合ラウンドで実施）

- 修正: backtick優先抽出＋`,`/`、`/`・`区切り＋注記語除外のフォールバックへ（範囲外パスの拒否は不変）。修正commit: `34b7749`（task/pf06→統合branchへmerge済み）。
- 再発防止: `test_planctl.sh` へbacktick+・区切りの実書式ケース4件を追加（44→48）。
- 回帰実証: 修正をstashで一時的に戻すと新規4件中2件が実際にFAILすることを確認のうえ復元。

## 再検証

- plan-ops全suite **182 pass / 0 fail**（planctl 48含む）。E2E系統1・2が修正後 `status: completed`（全項目PASS）。

## 総合判定

**全PASS（修正後）**。子02の完了条件への影響なし（評価04の全PASSは維持・本件は横断E2Eでのみ露出する解釈不一致）。
