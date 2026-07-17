親計画: ../program.md ／ 対象計画: `plans/04-PromptSubmitへの接続契約を引き継ぐ.md` ／ ラウンド: 01 ／ 規模: フル ／ 評価者: review_handoff_contract（独立レビュー担当）
diff範囲: 子04、既存program「完了判定とアーカイブ運用」の `program.md` と `plans/02-PromptSubmit計画注入の再設計.md`

# 評価01: Prompt Submitへの接続契約を引き継ぐ

## 項目別採点   ※ 子計画の完了条件と同順

- [FAIL] 既存program子02に、この子計画への依存と短い計画ゲートの文言が記録され、hook変更を二重所有していない。
  根拠: 依存、既存plan優先、宣言済み計画箱、hookの所有境界は記録済みだが、子02の依存元 `../../../../active/...` は1階層多く実体へ解決しない。
- [PASS] 注入文が `plan-management` を入口として案内するだけで、hook自身が計画の置き場や合否を決めていない。
  根拠: 子02の接続契約は `plan-triage` を実行せず、repo・AGENTS・計画箱・レビュー合否・バケット遷移・plan本文・状態を決めないと明記する。
- [PASS] 動的な注入本文は `common.py` の唯一の生成元に残り、runtime別のコピーを増やしていない。
  根拠: 子02は `shared/session-board/common.py` を唯一の生成元に固定し、runtimeシム・event説明MD・AGENTSへの本文コピーを禁じる。現行生成関数も同ファイルに集約されている。
- [PASS] 既存program子02に、変更時の `test_common.py` と既存event E2E、runtime登録・symlink・再trustの人間ゲートが実装責務として記録されている。この子はhook本体とruntimeを変更しない。
  根拠: 子02は再編安定後にテストと5イベントE2Eを同じ実装単位で扱い、runtime操作を人間承認後に限定する。現行 `test_common.py` は10 PASSであり、子04はhook本体を変更していない。
- [PASS] hooks再編の既存dirty差分を巻き戻し、混在させ、または旧構造を復活させていない。
  根拠: 子04の差分は計画MDのみ。既存のhooks-registry再編は大規模dirtyだが、本子では変更・巻き戻し・旧構造復活を行っていない。

## 総合判定

FAILあり。`修正01.md` で依存元の相対pathを実体へ解決する最小修正に限定し、評価02で再確認する。

## 修正指示ドラフト

既存子02の依存元を `../../../active/2026-07-14-計画運用ハーネス検証/plans/04-PromptSubmitへの接続契約を引き継ぐ.md` に直す。hook、runtime、テスト、ほかの計画内容は変更しない。
