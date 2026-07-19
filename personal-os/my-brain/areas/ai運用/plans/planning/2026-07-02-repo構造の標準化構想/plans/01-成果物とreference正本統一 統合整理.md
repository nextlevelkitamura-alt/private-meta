親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
規模: フル
形態判定: Program子 ／ 理由: 全repoに波及する格納規約を親programで段階的に確認するため
並列: 不可 ／ 差し戻し上限: フル=2
人間ゲート: なし

# 成果物とreferenceの正本統一

## 目的

成果物の出所をplanへ固定し、areaには長期・横断で再利用するreferenceだけを置く規約へ統一する。

## 非対象

- 既存の知識、legacy、成果物、フォルダを移動、削除、改名しない。
- 既存repoのAGENTSやrepo-createをこの子だけで更新しない。

## 現状

起案記録にはarea outputsと月別フォルダの案が残っている。最終方針は、plan outputs直下への日付付き命名と、area referencesのみである。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private
- 実行形: direct
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この子計画
  5. ../explain/2026-07-19-成果物運用-最終計画案.html
- 依存成果: なし
- 変更可能範囲: personal-os/my-brain/areas/AGENTS.md、personal-os/my-brain/areas/ai運用/AGENTS.md、同programの正本と説明HTML
- 変更禁止範囲: 既存の知識、legacy、他repo、repo-create、物理配置
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: explainは人間向けHTML、評価は採点と修正指示、referencesは長期・横断再利用だけを受け入れ、archiveは計画の終了状態に限定する
- 検証: plan-lint.shでこの子を検証し、対象規約にplan又はareaのoutputs採用文言が残っていないことを確認する
- 停止・エスカレーション条件: 既存知識の分類や物理移動が必要になった場合、又は複数areaへの帰属を決められない場合
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. 人間向けの説明・診断HTMLは explain に、完了条件の採点と修正指示は評価に置く。
2. references と explain は必要になった時だけ作る。空の定型ディレクトリを作らない。
3. area referencesには定義、判断基準、KPIの定義と外部正本への導線だけを置く。現在値、一時資料、個別の評価記録は置かない。
4. 計画専用の長期参照をarea referenceへ昇格する時はコピーせず、対象と理由を示して人間承認後に移動する。plan側には移動先だけを短く残す。

## 完了条件

- [ ] explain、評価、area references、archiveの4境界が対象規約に一貫して記されている。
- [ ] 既存の知識とlegacyを移動しないこと、KPIの現在値を複写しないことが明示されている。

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
