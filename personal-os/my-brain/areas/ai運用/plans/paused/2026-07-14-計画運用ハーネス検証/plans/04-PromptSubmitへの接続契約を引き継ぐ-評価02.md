親計画: ../program.md ／ 対象計画: `plans/04-PromptSubmitへの接続契約を引き継ぐ.md` ／ ラウンド: 02 ／ 規模: フル ／ 評価者: review_handoff_contract（独立レビュー担当）
diff範囲: 子04、既存program「完了判定とアーカイブ運用」の `program.md` と `plans/02-PromptSubmit計画注入の再設計.md`

# 評価02: Prompt Submitへの接続契約を引き継ぐ

## 項目別採点   ※ 子計画の完了条件と同順

- [PASS] 既存program子02に、この子計画への依存と短い計画ゲートの文言が記録され、hook変更を二重所有していない。
  根拠: 子02の依存元 `../../../active/.../04-PromptSubmitへの接続契約を引き継ぐ.md` は実在し、最小ゲート、既存plan優先、最寄りAGENTS.mdの宣言箱が同じ接続契約に記録されている。
- [PASS] 注入文が `plan-management` を入口として案内するだけで、hook自身が計画の置き場や合否を決めていない。
  根拠: 子02は `plan-triage` を実行せず、repo・AGENTS・計画箱・レビュー合否・バケット遷移・plan本文・状態を決めないと明記する。
- [PASS] 動的な注入本文は `common.py` の唯一の生成元に残り、runtime別のコピーを増やしていない。
  根拠: 子02は `shared/session-board/common.py` を唯一の生成元に固定し、runtimeシム・event説明MD・AGENTSへの本文コピーを禁じる。テストと5イベントE2Eも子02の将来実装責務に残る。
- [PASS] 既存program子02に、変更時の `test_common.py` と既存event E2E、runtime登録・symlink・再trustの人間ゲートが実装責務として記録されている。この子はhook本体とruntimeを変更しない。
  根拠: `plan-management` が未露出のruntimeには有効な実行導線として注入せず、再編安定と対象runtimeへの露出の人間承認・確認後だけ実装を有効化する。現行 `test_common.py` は10 PASSである。
- [PASS] hooks再編の既存dirty差分を巻き戻し、混在させ、または旧構造を復活させていない。
  根拠: 今回の修正差分は両programの計画MDのみで、hook本体・runtime設定には変更がない。両program-lintも違反なし。

## 総合判定

全PASS。子04はフル計画の人間確認へ進める。Prompt Submit本体、runtimeへのSkill露出、hook登録、Codex再trustは未実施であり、既存program子02と別の人間承認を待つ。
