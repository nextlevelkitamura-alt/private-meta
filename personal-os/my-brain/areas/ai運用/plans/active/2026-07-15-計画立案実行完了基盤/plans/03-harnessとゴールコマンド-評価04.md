対象計画: 03-harnessとゴールコマンド.md ／ ラウンド: 04（子06のE2Eによる横断検出）
diff範囲: 統合branch（a181adf時点） ／ 評価者: 子06 E2E担当（sonnet5）＋指揮官

# 評価04: E2E欠陥A（program-runの見出し検出）

## 検出（E2E系統1・2 / 2026-07-16）

- [FAIL] `program_run.py` の独自 `_section()` が見出しを完全一致でしか判定せず、正本テンプレの注記付き見出し「## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新」（`new-plan.sh --program` の実出力・本program自身を含む全program.mdと同一）から子を検出できない。共有ヘルパ `_planops_map.find_section()`（前方一致）と不整合。
- 原因はテストfixtureがbare見出しのみだったこと（テストは通るが実データで動かない乖離）。

## 対応（修正03相当・子06統合ラウンドで実施）

- 修正: `_section()` を前方一致へ変更し `_planops_map.find_section()` と解釈を統一（bare見出しの既存挙動維持）。修正commit: `3094758`（task/pf06→統合branchへmerge済み）。
- 再発防止: `test_program_run.py` のfixtureを正本テンプレの注記付き見出しへ更新。
- 回帰実証: 修正をstashで一時的に戻すと25本中11本が実際にFAILすることを確認のうえ復元。

## 再検証

- harness unittest **25件 OK**。E2E系統1（単発plan一巡13項目）・系統2（独立2子並列→統合）が修正後 `status: completed`（全項目PASS）。

## 総合判定

**全PASS（修正後）**。子03の完了条件への影響なし（評価03の全PASSは維持・本件は実テンプレ書式でのみ露出）。
