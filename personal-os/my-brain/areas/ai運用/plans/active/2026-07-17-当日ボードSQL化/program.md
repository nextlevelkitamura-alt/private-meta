分類: 横断 ／ 種別: 新規作成 ／ 形態: program
規模: フル
優先: ◎

# 当日ボードSQL化

完了方針: 子と統合評価が全PASSならAIがDB反映・commit・push・本番readback・終了記録まで自律実行
差し戻し上限: フル=2・ライト=1（超過は人間へエスカレーション。正本は plan-registry/AGENTS.md）

## 目的

当日の仕事情報（やること・エージェント状態・終わったこと・時間サマリ）を focusmap のURL上でリアルタイムに一元管理し、スマホからでも「起票 → AIが検知・実行 → 確認待ち → 人間承認」まで回せる状態にする。あわせて、機械が高頻度に書く運用データの正本をデイリーmdからDB（Turso）へ段階的に反転し、最終的にミラー二重書きを廃止する。

## 非対象

- focusmap既存のSupabase系機能（カレンダー・タスク・習慣・ノート等）の改修
- 3年/年間/月間の的の文面・知識のDB化（md正本のまま。DBは参照のみ）。計画書は2026-07-18の人間指示により例外化し、読み取り専用の表示キャッシュとしてのDBミラーだけを子06で行う（正本境界の項を参照）
- Notionインボックスなど他の起票入口の廃止判断
- kimi-webbridge等ブラウザ操作基盤の改修

## 正本境界

- 仕様の正本: この program.md と plans/ の子計画。合意図解は `explain/program.html`、画面モックは `references/`
- 運用データ（sessions・events・logs・goals・新設やること）: 反転完了（子03）後は Turso が正本。それまでの正本はデイリーmd
- 的の文面・知識: md（git）が正本のまま。DBには参照（slug・計画名）だけ置く
- 計画書: md（git）が正本。DBはactive計画の読み取り専用表示キャッシュのみ許可（一方向同期・編集はmd側だけ・ボードから本文編集UIは作らない。2026-07-18人間指示で改定・実装は子06/07）
- 大課題テーマ: inbox DBの themes が正本（todosと同格の運用データ・ボード編集可）。的・計画へは参照slugのみ持ち、本文コピー・進捗の重複描画をしない（2026-07-19人間採用・実装は子09）
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

06 計画ミラー同期（AIエージェント基盤）   ※01〜05と独立・03/05とファイル調整
  └→ 07 計画スマホ表示（focusmap）

05 ─→ 08 サブエージェント入れ子可視化（focusmap＋hook）  ※05のUI部品依存・03とはhook交差のため直列調整
05 ─→ 09 大課題テーマ階層と横断表示（focusmap）  ※02/03/08と表示surface交差のため直列調整・04と的slug集計を共有

09 ─→ 10 セッション分類契約と明示Skill（AIエージェント基盤）
       └→ 11 Hook順序とrepo実行Context（Codex先行→Claude互換確認）
            └→ 12 Dailyのrepo選択とTheme内作業（focusmap）
                 └→ 13 人間採用と単発完了導線（focusmap＋session-board）
                      └→ 14 分類統合評価と段階展開
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
- [ ] 05 タスク入れ子と2層チェック … 人間確認（評価02=FAIL0・保留は人間ゲート後に再検証）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤 hooks-registry/shared/session-board のboard.pyコマンド追加）
    並列: 02と可（画面領域が非交差）・03とはboard.py交差のため直列調整 ／ レビュー: 都度
    人間ゲート: Turso migration適用（todo_steps・session_logs.todo_id・todos質問カラム）・origin/main push・本番反映・skill/loop正本への board_route 宣言追記
    次: 親の最終一括確認（実機目視・375px・付け替えUI含む）待ち。ゲート実行記録=評価/05-…-評価03.md
    場所: plans/05 ／ 依存: 01（03とはboard.py調整）
    参照: explain/ボード入れ子と進捗率の提案.html（設計正本）／評価/05-…-評価02.md ／ 実装 focusmap@b8bbf058
- [ ] 04 方向修正ビューとミラー廃止 … 計画
    役割: 統合
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤のミラー廃止）
    並列: 不可 ／ レビュー: 都度
    人間ゲート: md→DBミラー送信の廃止（不可逆）・origin/main push・本番反映
    次: 02・03完了後に着手
    場所: plans/04 ／ 依存: 02・03
    参照: ―
- [ ] 06 計画ミラー同期 … 人間確認（評価01=FAIL0・PASS4・保留4）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤（plan-ops・session-board turso）＋~/Private git hook
    並列: 05と可（対象repoが異なる）・03とはspool交差のため直列調整 ／ レビュー: 都度
    人間ゲート: inbox migration適用（plan_docs・plan_progress）・post-commit hook登録・初回一括投入GO
    次: 親の最終一括確認待ち（保留再検証済み=評価02。フックバグ2件を発見・修正し自動同期E2E実測PASS）
    場所: plans/06 ／ 依存: ―（03/05とファイル調整）
    参照: 評価/06-計画ミラー同期-評価01.md ／ 実装 Private@a2c730d9
- [ ] 07 計画スマホ表示 … 人間確認（一括評価01=FAIL0）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 06完了後（データ依存）・02/05と切替ピル等の共有ファイル調整 ／ レビュー: 一括（07・08・09で束ね。末端子で後続利用なし）
    人間ゲート: 依存追加（react-markdown・remark-gfm）承認・origin/main push・本番反映
    次: 人間ゲート（push・本番反映）→375px目視は親最終一括
    場所: plans/07 ／ 依存: 06
    参照: 評価/07-計画スマホ表示-評価01.md ／ 実装 focusmap@4c37d8e9
- [ ] 08 サブエージェント入れ子可視化 … 人間確認（一括評価01=FAIL0）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤 hooks-registry subagentイベント・board.py）
    並列: 05完了後（UI部品依存）・03とはhook/board.py交差のため直列調整 ／ レビュー: 一括（07・08・09で束ね。末端子で後続利用なし）
    人間ゲート: board DBへのmigration適用（session_subagents）・origin/main push・本番反映
    次: 人間ゲート（session_subagents migration・push・本番反映）→実挙動確認
    場所: plans/08 ／ 依存: 05（03とはhook調整）
    参照: 2026-07-18人間採用（IMG_4307の議論・機械=hook/意味=AI分担）
- [ ] 09 大課題テーマ階層と横断表示 … 人間確認（一括評価01=FAIL0・指摘1修正済み）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 05完了後・02/03/08と表示surface交差のため直列調整・04と的slug集計を共有 ／ レビュー: 一括（07・08・09で束ね。2026-07-19人間指示=重要子のみ都度）
    人間ゲート: inbox migration適用（themes〔purpose・done_criteria込み〕・todos.theme_id/carried_from/awaiting_since・todo_steps.started_at）・board migration適用（sessions.todo_id/theme_id）・_first_guide宣言行の追加・origin/main push・本番反映
    次: 人間ゲート（inbox/board migration・push・本番反映）→実挙動確認と375px目視（親最終一括）
    場所: plans/09 ／ 依存: 05（02/03/08と交差調整）
    参照: references/ボード大課題階層モックv5-2026-07-19.html（UI正本）・R1/R2調査統合（2026-07-19）
- [ ] 10 セッション分類契約と明示Skill … 評価待ち
    役割: 企画・実装
    対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤
    並列: 不可 ／ レビュー: まとめ
    自律実行: Global Skill新設・runtime露出・readback
    次: 子11完了後、子14でHookとの語彙・露出を統合評価
    場所: plans/10-セッション分類契約と明示Skill.md ／ 依存: 09
    参照: AIエージェント基盤/harness-registry/focusmap-daily.md
- [ ] 11 Hook順序とrepo実行Context … 評価待ち
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤
    並列: 不可 ／ レビュー: まとめ
    自律実行: board DB migration適用・Codex公式API自動trust・readback（登録pathは維持）
    次: 追加2表migration・実DB readback・Codex自動trustは完了。SessionStart実測後に子12へ
    場所: plans/11-Hook順序とrepo実行Context.md ／ 依存: 10
    参照: hooks-registry/events/prompt-register/・hooks-registry/shared/session-board/
- [ ] 12 Dailyのrepo選択とTheme内作業 … 計画
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 不可 ／ レビュー: まとめ
    自律実行: origin/main push・本番反映・本番readback
    次: session由来repo selectorとTheme直下作業帯を追加
    場所: plans/12-Dailyのrepo選択とTheme内作業.md ／ 依存: 11
    参照: harness-registry/focusmap-daily.md
- [ ] 13 人間採用と単発完了導線 … 計画
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap（＋AIエージェント基盤 session-board）
    並列: 不可 ／ レビュー: まとめ
    自律実行: inbox/board DB本番書込み・origin/main push・本番反映・rollback検証
    次: proposal採用、Theme内Todo、完了チェック、archiveを接続
    場所: plans/13-人間採用と単発完了導線.md ／ 依存: 12
    参照: harness-registry/focusmap-daily.md
- [ ] 14 分類統合評価と段階展開 … 計画
    役割: 評価・統合
    対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤＋/Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 不可 ／ レビュー: まとめ
    自律実行: Codex/Claude本番有効化・origin/main push・本番反映・統合readback
    次: 未登録repo、worktree、非Git、DB障害、誤分類、人間訂正を統合評価
    場所: plans/14-分類統合評価と段階展開.md ／ 依存: 13
    参照: plans/10〜13の実装・評価結果

## 自律実行と検証

- 全子完了＋統合評価（`評価/評価01.md`）全PASS後に、AIがprogramの終了記録・commit・通常push・本番readbackまで行う。結果を変える未確定の人間判断がある時だけ停止する。
- 実行前に対象・preflight・rollbackを確認し、実行後にreadbackする操作:
  - Tursoへのmigration適用（新テーブル todos・reposマスタ）＝子01
  - loop/launchd登録（AI起票キューの検知機構）＝子02
  - session-board hookの挙動変更と、デイリーmd「動いているエージェント」「終わったこと」2節の生成化/廃止＝子03
  - md→DBミラー送信の廃止（不可逆）＝子04
  - Tursoへのmigration適用（todo_steps・session_logs.todo_id・todos質問カラム）と skill/loop正本への board_route 宣言追記＝子05
  - inbox migration適用（plan_docs・plan_progress）・~/Private post-commit hook登録・初回一括投入＝子06
  - 依存パッケージ追加（react-markdown・remark-gfm）＝子07
  - board DBへのmigration適用（session_subagents）＝子08
  - inbox migration適用（themes〔purpose・done_criteria込み〕・todos.theme_id/carried_from/awaiting_since・todo_steps.started_at）と board migration適用（sessions.todo_id/theme_id）・_first_guide宣言行の追加＝子09
  - board DBへの分類migration適用（session_execution_contexts・session_route_proposals）とCodex公式API自動trust＝子11
  - origin/main への push・Cloud Run本番反映＝子01・02・04・05・07・08・09
- planning→active昇格は、explain/program.html・目的・範囲・完了条件を確認し、bucketctlの機械検証後にAIが行う（active上限3の確認込み）

## 完了条件（レビュー項目）

- [ ] focusmap本番URLのボードで、今日のやること・動いているエージェント・終わったこと・本日サマリが1画面に表示され、スマホ幅375pxで崩れない（対象: 今日ボード画面）
- [ ] スマホの起票（右下FAB→タイトル・いつ・実行repo・任せる必須）で追加した「AIに任せる」行が、Mac側で検知され ai_status が 未検知→検知→立案中/実行中→確認待ち と進み、人間の承認タップで完了になる一連が実機で通る（対象: 起票画面・todos・検知機構・今日ボード）
- [ ] 2週間リスト⇄月カレンダーの切替が同じ「やること」箱のデータで動き、repoフィルタと〆切の赤表示が機能する（対象: 2週間/月ビュー）
- [ ] board.pyの記録がDB先書きになり、デイリーmdの該当2節が生成表示または廃止されて二重正本が存在しない（対象: session-board・デイリーテンプレ）
- [ ] md→DBミラー送信コードとspoolが廃止され、計画・的の文面の本文コピーがDBに存在しない（対象: session-board turso/・DBスキーマ）
- [ ] 各タスクにステップ入れ子・タスク別%・状態ラベルが表示され、ステップ✔=AI自動・見出し完了=人間タップの2層チェックで「終わったこと」へ移動し、AIの質問に選択肢＋自由入力でスマホ回答できる（対象: 子05・board画面）
- [ ] スマホの「計画」タブでactive計画の一覧・進捗（子N/M・完了条件x/y）・md本文が読み取り専用で確認でき、md正本を書き換える経路がDB側に存在しない（対象: 子06・07）
- [ ] ボードに大課題テーマの階層が表示され、テーマの編集・タスクの翌日引き継ぎ・エージェント行の「テーマ›タスク」位置表示・終わったことのテーマ別入れ子が動き、的・計画の本文コピーがDBに存在しない（対象: 子09・board画面）
- [ ] Codex / Claudeの全トップレベルセッションがrepo-registry登録有無に関係なく受付され、UserPromptSubmitで短い分類packetが注入される。AIが提案を書かなかった場合も判定待ちとして消えない（対象: 子10・11）
- [ ] Dailyのrepo selectorに登録済みGit・未登録Git・非Git作業フォルダが区別して表示され、linked worktreeは同じrepoへまとめられる（対象: 子11・12）
- [ ] Themeへ貢献する計画外修正がTheme直下の「テーマ内作業」に表示され、正式Plan進捗%と単発完了数が混ざらず、人間チェック後にTheme別archiveへ入る（対象: 子12・13）
- [ ] 統合評価 `評価/評価01.md` が全PASS（対象: 評価/）

## 関連

- 合意図解（壁打ちv6・計画レビュー提示物）: `explain/program.html`
- 画面モック4枚: `references/`（今日ボード・2週間リスト・月カレンダー・起票フォーム）
- 関連既存計画: `../../active/2026-07-12-loopレジストリTurso移行`（Turso運用の先行事例。対象は重ならない）
- 実装正本: `AIエージェント基盤/hooks-registry/shared/session-board/`・`projects/active/focusmap/`

## 終了記録

archive時に必須。実行中は記入しない。
