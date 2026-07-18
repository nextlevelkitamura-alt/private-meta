分類: 横断 ／ 種別: 新規作成 ／ 形態: program
規模: フル
優先: ◎

# 当日ボードSQL化

人間確認方針: 最終一括（危険操作は実行前に個別承認）
差し戻し上限: フル=2・ライト=1（超過は人間へエスカレーション。正本は plan-registry/AGENTS.md）

## 目的

当日の仕事情報（やること・エージェント状態・終わったこと・時間サマリ）を focusmap のURL上でリアルタイムに一元管理し、スマホからでも「起票 → AIが検知・実行 → 確認待ち → 人間承認」まで回せる状態にする。あわせて、機械が高頻度に書く運用データの正本をデイリーmdからDB（Turso）へ段階的に反転し、最終的にミラー二重書きを廃止する。

## 非対象

- focusmap既存のSupabase系機能（カレンダー・タスク・習慣・ノート等）の改修
- 3年/年間/月間の的の文面・計画書のDB化（md正本のまま。DBは参照のみ）
- Notionインボックスなど他の起票入口の廃止判断
- kimi-webbridge等ブラウザ操作基盤の改修

## 正本境界

- 仕様の正本: この program.md と plans/ の子計画。合意図解は `explain/program.html`、画面モックは `references/`
- 運用データ（sessions・events・logs・goals・新設やること）: 反転完了（子03）後は Turso が正本。それまでの正本はデイリーmd
- 計画書・的の文面・知識: md（git）が正本のまま。DBには参照（slug・計画名）だけ置く
- repo選択肢の正本: `AIエージェント基盤/repo-registry/repo概要.md`（DBのreposマスタは参照コピー）
- session-board実装の正本: `AIエージェント基盤/hooks-registry/shared/session-board/`
- focusmap実装の正本: `~/Private/projects/active/focusmap/`

## 役割別コンテキスト

- `実装/共通.md`: 実装担当が全子で守ること（規約・契約・テスト・触るな領域）
- `レビュー/共通.md`: レビュアーが気をつけること（観点・厳しさ・束ね方針）
- `評価/`: 評価・修正の置き場（子は `NN-〈子名〉-評価RR.md`、programの統合評価は `評価RR.md`）

## 全体像・実行Wave

```text
01 やること箱と今日ボード（focusmap・新規追加のみ）
  ├→ 02 月カレンダーとAI起票キュー（focusmap＋検知導線）
  ├→ 05 タスク入れ子と2層チェック（focusmap＋board.py拡張）  ※02と並列可・03とはboard.py交差のため直列調整
  └→ 03 セッション状態ログの正本反転（session-board）   ※02と並列可
        ↓（02・03の両方完了後）
04 方向修正ビューとミラー廃止（focusmap＋session-board・統合）
```

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01 やること箱と今日ボード … 完了
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 不可 ／ レビュー: 都度
    人間ゲート: Turso migration適用・origin/main push・本番反映
    次: デプロイ1完了（push・env・本番migration適用済み）。本番URLで全機能開通
    場所: plans/01 ／ 依存: ―
    参照: focusmap@be8e13f8
- [ ] 02 月カレンダーとAI起票キュー … 計画
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 03と可（対象repoが異なりファイル非交差） ／ レビュー: 都度
    人間ゲート: loop/launchd登録・origin/main push・本番反映
    次: 01完了後に着手
    場所: plans/02 ／ 依存: 01
    参照: ―
- [ ] 03 セッション状態ログの正本反転 … 計画
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤
    並列: 02と可（対象repoが異なりファイル非交差） ／ レビュー: 都度
    人間ゲート: hook挙動変更の承認・デイリーmd「動いているエージェント」「終わったこと」2節の生成化/廃止の承認
    次: 01完了後に着手
    場所: plans/03 ／ 依存: 01
    参照: ―
- [ ] 05 タスク入れ子と2層チェック … 計画
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤 hooks-registry/shared/session-board のboard.pyコマンド追加）
    並列: 02と可（画面領域が非交差）・03とはboard.py交差のため直列調整 ／ レビュー: 都度
    人間ゲート: Turso migration適用（todo_steps・session_logs.todo_id・todos質問カラム）・origin/main push・本番反映・skill/loop正本への board_route 宣言追記
    次: 段階1（todo_steps・入れ子+%表示・状態ラベル・即時反映）から着手
    場所: plans/05 ／ 依存: 01（03とはboard.py調整）
    参照: explain/ボード入れ子と進捗率の提案.html（設計正本・3体Opus討議の統合）
- [ ] 04 方向修正ビューとミラー廃止 … 計画
    役割: 統合
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤のミラー廃止）
    並列: 不可 ／ レビュー: 都度
    人間ゲート: md→DBミラー送信の廃止（不可逆）・origin/main push・本番反映
    次: 02・03完了後に着手
    場所: plans/04 ／ 依存: 02・03
    参照: ―

## 人間ゲート

- 最終一括確認: 全子完了＋統合評価（`評価/評価01.md`）全PASS後に、program全体を一度だけ人間確認して完了にする
- 実行前に個別承認が必要な操作（各子の `人間ゲート:` にも記載）:
  - Tursoへのmigration適用（新テーブル todos・reposマスタ）＝子01
  - loop/launchd登録（AI起票キューの検知機構）＝子02
  - session-board hookの挙動変更と、デイリーmd「動いているエージェント」「終わったこと」2節の生成化/廃止＝子03
  - md→DBミラー送信の廃止（不可逆）＝子04
  - Tursoへのmigration適用（todo_steps・session_logs.todo_id・todos質問カラム）と skill/loop正本への board_route 宣言追記＝子05
  - origin/main への push・Cloud Run本番反映＝子01・02・04・05
- planning→active昇格は、explain/program.html の提示と人間の実行OKを得てから bucketctl で行う（active上限3の確認込み）

## 完了条件（レビュー項目）

- [ ] focusmap本番URLのボードで、今日のやること・動いているエージェント・終わったこと・本日サマリが1画面に表示され、スマホ幅375pxで崩れない（対象: 今日ボード画面）
- [ ] スマホの起票（右下FAB→タイトル・いつ・実行repo・任せる必須）で追加した「AIに任せる」行が、Mac側で検知され ai_status が 未検知→検知→立案中/実行中→確認待ち と進み、人間の承認タップで完了になる一連が実機で通る（対象: 起票画面・todos・検知機構・今日ボード）
- [ ] 2週間リスト⇄月カレンダーの切替が同じ「やること」箱のデータで動き、repoフィルタと〆切の赤表示が機能する（対象: 2週間/月ビュー）
- [ ] board.pyの記録がDB先書きになり、デイリーmdの該当2節が生成表示または廃止されて二重正本が存在しない（対象: session-board・デイリーテンプレ）
- [ ] md→DBミラー送信コードとspoolが廃止され、計画・的の文面の本文コピーがDBに存在しない（対象: session-board turso/・DBスキーマ）
- [ ] 各タスクにステップ入れ子・タスク別%・状態ラベルが表示され、ステップ✔=AI自動・見出し完了=人間タップの2層チェックで「終わったこと」へ移動し、AIの質問に選択肢＋自由入力でスマホ回答できる（対象: 子05・board画面）
- [ ] 統合評価 `評価/評価01.md` が全PASS（対象: 評価/）

## 関連

- 合意図解（壁打ちv6・計画レビュー提示物）: `explain/program.html`
- 画面モック4枚: `references/`（今日ボード・2週間リスト・月カレンダー・起票フォーム）
- 関連既存計画: `../../active/2026-07-12-loopレジストリTurso移行`（Turso運用の先行事例。対象は重ならない）
- 実装正本: `AIエージェント基盤/hooks-registry/shared/session-board/`・`projects/active/focusmap/`

## 終了記録

archive時に必須。実行中は記入しない。
