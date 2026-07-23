親計画: ../program.md ／ 分類: 横断 ／ 種別: 実装
テンプレ: v2
規模: フル
形態判定: Program子 ／ 理由: 子11の観測データをDailyの表示構造へ接続する
並列: 不可 ／ 差し戻し上限: フル=2
自律実行: origin/main push・本番反映・本番readback

# Dailyのrepo選択とTheme内作業

## 目的

Dailyヘッダーにsession由来のrepo selectorを表示し、Theme直下にPlanではない「テーマ内作業」を分離表示する。

## 非対象

- 人間採用・archive書込み
- 既存Project切替の置換

## 現状

repo chipはPlanカードのrepoだけから作られ、session-only repoが出ない。Theme-only作業はbuild層で先頭Planへ入る場合がある。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
- 実行形: integration
- 最初に読む順番:
  1. focusmapの最寄りAGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この計画
  5. harness-registry/focusmap-daily.md
- 依存成果: 子11のsession_execution_contextsとroute proposal読取契約
- 変更可能範囲: focusmapのboard API・board-v2 types/build/theme-plan-boardと関連test
- 変更禁止範囲: 既存Project切替・カレンダー・Plan本文編集
- ファイル担当マップ: 不要
- worktree方針: task-scoped（対象repo所有sessionへhandoff後に決定）
- 維持する契約: Theme進捗%=正式Plan工程のみ、未登録repoをregistryへ自動登録しない
- 検証: UI unit/build test、desktop/375px目視、空DB・legacy fallback
- 停止・エスカレーション条件: 子11のrepo_key契約が未確定、既存Project切替との責務衝突
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

repo optionsはPlan repoとsession execution contextの和集合にする。ThemeGroupにthemeWorkを追加し、Plan配列へ押し込まない。

## 工程

<!-- 1行1工程。NNは連番、種別は 実装|レビュー|修正、評価は 都度|まとめ。まとめ評価が既定。 -->
- [ ] 01 実装: repo scope APIとselectorを追加する  評価: まとめ
- [ ] 02 実装: ThemeGroupへthemeWorkを追加する  評価: まとめ
- [ ] 03 実装: Theme内作業帯と未分類fallbackを表示する  評価: まとめ

## 完了条件

- [ ] session-only未登録repoがメニューへ出る
- [ ] linked worktreeが同一repoへまとまる
- [ ] Theme-only作業が先頭Planへ混入しない
- [ ] ThemeのPlan進捗%と単発件数が別表示される

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
