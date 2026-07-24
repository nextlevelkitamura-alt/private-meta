親計画: ../program.md ／ 分類: 横断 ／ 種別: 実装
テンプレ: v2
規模: フル
形態判定: Program子 ／ 理由: 子11の観測データをDailyの表示構造へ接続する
並列: 不可 ／ 差し戻し上限: フル=2
自律実行: origin/main push・本番反映・本番readback

# Dailyのrepo選択・Theme日次継承・Plan紐付け

## 目的

Dailyヘッダーにsession由来のrepo selectorを表示し、Theme直下にPlanではない「テーマ内作業」を分離表示する。Themeは毎朝作り直さず、未完了なら翌日に自動継承し、前日の採用状態も参照できるようにする。ThemeとPlanの紐付けは正規化した参照表で保持し、Daily上のドラッグ&ドロップで安全に変更できるようにする。

## 非対象

- 人間採用・session所属の確定（子13）
- 既存Project切替の置換
- Plan本文・Plan状態のDB正本化

## 現状

repo chipはPlanカードのrepoだけから作られ、session-only repoが出ない。Theme-only作業はbuild層で先頭Planへ入る場合がある。Themeは日付を持たず、repo filterが`plan_docs.path`だけを見るためPlan未紐付けThemeが消える。`themes.plan_refs` JSONはDnD・並び替え・重複防止に弱く、前日Themeの正確なsnapshotも存在しない。

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
- 変更可能範囲: focusmapのadditive migration・themes domain service・board API・board-v2 types/build/theme-plan-board・plansyncのplanning読取契約と関連test
- 変更禁止範囲: 既存Project切替・カレンダー・Plan本文編集
- ファイル担当マップ: 不要
- worktree方針: task-scoped（対象repo所有sessionへhandoff後に決定）
- 維持する契約: Theme本体は毎日複製しない、Plan本文/状態はrepo Markdown/フォルダ正本、Theme進捗%=正式Plan工程のみ、未登録repoをregistryへ自動登録しない
- 検証: UI unit/build test、desktop/375px目視、空DB・legacy fallback
- 停止・エスカレーション条件: 子11のrepo_key契約が未確定、既存Project切替との責務衝突
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

repo optionsはPlan repoとsession execution contextの和集合にする。ThemeGroupにthemeWorkを追加し、Plan配列へ押し込まない。`theme_days`を日別membership、`theme_plan_links`をTheme–Plan参照、`theme_repos`をworkspace所属の正本として追加する。今日の初回読込で前日activeを冪等継承し、Theme本体は複製しない。Planのbucket移動はDB更新で偽装せず、Mac側typed commandから`bucketctl → plansync → readback`で行う。

## 工程

<!-- 1行1工程。NNは連番、種別は 実装|レビュー|修正、評価は 都度|まとめ。まとめ評価が既定。 -->
- [ ] 01 実装: `theme_days`・`theme_plan_links`・`theme_repos`とdomain APIを追加する  評価: 都度
- [ ] 02 実装: 前日active Themeの冪等継承と今日/昨日表示を追加する  評価: まとめ
- [ ] 03 実装: repo scope APIとselectorをTheme repo所属へ接続する  評価: まとめ
- [ ] 04 実装: ThemeGroupへthemeWorkを追加する  評価: まとめ
- [ ] 05 実装: Theme内作業帯と未分類fallbackを表示する  評価: まとめ
- [ ] 06 実装: PlanのTheme間DnD・キーボード代替・失敗rollbackを追加する  評価: まとめ
- [ ] 07 実装: planning mirrorとtyped Plan bucket遷移bridgeを追加する  評価: 都度

## 完了条件

- [ ] session-only未登録repoがメニューへ出る
- [ ] linked worktreeが同一repoへまとまる
- [ ] Theme-only作業が先頭Planへ混入しない
- [ ] ThemeのPlan進捗%と単発件数が別表示される
- [ ] 未完了Themeが翌日に自動継承され、Theme本体の重複行は増えない
- [ ] 前日のTheme・目的・進捗・持越し結果を参照できる
- [ ] Plan未紐付けThemeがrepo filterで消えない
- [ ] Plan DnDは即時反映され、失敗時に元へ戻り、同一Planが複数Themeへ重複しない
- [ ] Plan bucket変更はbucketctlの検証を通り、plansync readback後に確定する

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
