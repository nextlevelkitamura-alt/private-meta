親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
規模: フル
形態判定: Program子 ／ 理由: 計画実行の正本、生成、hookを同じ実装・評価モデルへ接続するため
並列: 可（04と） ／ 差し戻し上限: フル=2
人間ゲート: なし

# 計画実行形式を実装・評価へ統一

## 目的

planの正本、plan-opsの雛形、harness、hookを「実装して評価する」だけの一本道へ統一する。旧来の重複した判定用フォルダ・役割・段階を新規経路から除く。

## 非対象

- 新しいGlobal Skill、状態台帳、判定専用フォルダを増やさない。
- 既存planの成果物、評価記録、legacyを一括で移動しない。
- repo-createのdry-run実装を変更しない。

## 現状

現在の雛形とhookには、評価と重複する旧来の判定用語・役割・状態が残る。評価文書はすでにあるため、重複層をなくす。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private
- 実行形: direct
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この子計画
  5. 01の規約更新結果、AIエージェント基盤/skills/plan-ops/SKILL.md、hooks-registry/shared/plan-closeout
- 依存成果: 01の正本規約
- 変更可能範囲: plan-registry、areas規約、plan-ops、agents-registry/harness、hooks-registry、orca-cockpitの計画実行経路とこのprogram
- 変更禁止範囲: runtime登録表、symlink、既存planの成果物、repo物理配置、GitHub
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: plan成果物はoutputs直下の日付付き命名を使い、実行は実装と評価だけで閉じる。hookはmanifestだけを読み、計画本文を変更しない
- 検証: plan-ops、harness、plan-closeout、orca-cockpitの該当テストとplan-lint.sh、program-lint.shを実行して違反なしを確認する
- 停止・エスカレーション条件: runtime登録表、symlink、既存実行中manifestの変更が必要になる場合
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. programがある時はprogram.mdだけを親の正本とし、同階層にplan.mdを置かない。
2. programは実装/共通.mdと評価/だけを持つ。重複した判定用フォルダ、子マップ欄、役割、段階を新規経路から除く。
3. plan本文の完了条件は受入条件であり、evaluatorが評価MDでPASS又はFAILを記録する。
4. hooksはevaluated未同期、implementerのresult欠落、evaluatorの評価MD欠落だけを検査する。

## 完了条件

- [ ] 新規programがplan.mdと重複した判定用フォルダを作らず、実装/共通.mdと評価/だけを生成する。
- [ ] 雛形、harness、hook、cockpitの新規実行経路が実装・評価だけの語彙と状態へ統一されている。

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
