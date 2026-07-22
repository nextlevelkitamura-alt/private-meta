分類: 横断 ／ 種別: 統合整理 ／ 形態: program
規模: フル
優先: ◎

# 計画立案システム刷新（工程化・まとめ評価・朝会化・triage統合・立案強制）

人間確認方針: 最終一括（危険操作は実行前に個別承認）
差し戻し上限: フル=2・ライト=1（超過は人間へエスカレーション。正本は plan-registry/AGENTS.md）

## 目的

計画の「立て方」を、作る側の仕組みから統一・強制する。2026-07-21〜22 の人間フィードバック:
① 実装と評価の文書が必ず分かれていない ② 毎回レビューは遅い＝まとめられるものはまとめる
③ daily-startが作文起票で三重コピー＝朝は「テーマの何を実行するか整理・AI割り振り・計画確認」の時間にする
④ テーマは複数計画を束ねる上位（ボード側は「ボードUI計画統合」で4段化済み・作る側もこれに合わせる）
⑤ plan-triageは露出されない軽い決定手続き（93行workflow＋テスト）で、規約(plan-registry 89行)と同じ基準を二重に持つ
＝triageをplan-registryへ統合してregistryを実体ある正本にする ⑥ 計画立案を強制するhookが無い（助言のみ）。
「見る側」（当日ボード）は 2026-07-22 に4段ドリルダウンで完成（別program「ボードUI計画統合」done）。本programは「作る側」を直す。

## 非対象

- focusmapのボードUI大改修（子07の4段構造は「ボードUI計画統合」done の所掌）。ただし子05は入口フローに伴う「計画外エージェントゾーン」1つの追加だけfocusmapに触れる（大改修はしない）。
- md＋git正本・バケット状態管理・plansync一方向ミラーの根幹変更（触らない）。
- plan-ops の実行ツール群（bucketctl/planctl/plan-lint/plansync＝15スクリプト）のskillからの移設（opsは本物のツール＝skillのまま。移すのはtriageの決定手続きだけ）。
- 既存計画への遡及適用（新規計画から適用。既存active/doneはそのまま）。

## 正本境界

- 計画フォーマットの正本＝plan-ops/templates/（生成new-plan.sh・検査plan-lint。手書きで構造を作らない）。
- 計画規約（規模・段階・評価・人間ゲート・triage決定手続き）の正本＝plan-registry/AGENTS.md（本programでtriage手続きを吸収し実体化）。各repoは参照のみ・再定義しない。
- 「工程」の正本＝計画mdの「## 工程」節（機械可読）。朝会はそれを読んでDBへ登録（作文しない）。todo_stepsはライブ状態・md工程節は文書スナップショット。
- plan-ops（ツール）と plan-registry（規約＋triage決定）は別物。ツールをregistryへ・規約をskillへ混ぜない。

## 役割別コンテキスト

- `実装/共通.md`: 実装担当が全子で守ること（規約・契約・テスト・触るな領域）
- `評価/`: 評価・修正の置き場。子は `NN-子名-評価RR.md`、programの統合評価は `評価RR.md`。

## 全体像・実行Wave

```text
Wave 1（土台・並列可）:
  ├ 子01 テンプレ工程化＋まとめ評価規約＋文書分離   … plan-ops templates/lint/new-plan ＋ plan-registry 評価規約
  └ 子02 plan-triage を plan-registry へ統合         … skill-delete承認＋9参照更新＋テスト移設（子01と非交差）
Wave 2:
  └ 子03 朝会刷新＋テーマ簡素化                      … daily-start SKILL＋fetch-context＋board.py theme-add
Wave 3:
  └ 子04 立案強制hookの要否判断と設計                … 実装系ツール前ゲートの設計 or 見送り記録
Wave 4（入口フローとボード格納・子01-04の後）:
  └ 子05 入口triageとエージェント格納フロー          … 基盤=入口ガイド強化 ＋ focusmap=計画外エージェントゾーン（2レーン並列可・別repo）
```

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01 テンプレ工程化とまとめ評価規約 … 完了（評価01=全PASS・APPROVED・都度評価済み・全体人間確認待ち）
    役割: 実装
    対象repo: ~/Private（plan-ops templates/scripts・plan-registry/AGENTS.md）
    並列: 可
    人間ゲート: なし
    次: plan.md/子計画テンプレに「## 工程」節（`- [ ] NN 実装|レビュー|修正: 内容 評価: 都度|まとめ`）を必須追加。new-plan.shが単発でも評価/分離生成。plan-lintが工程節欠落・実装/評価混在を検出。plan-registryに「まとめ評価既定・都度は後続が直接使う工程だけ」を正文化＋まとめ評価テンプレ追加
    場所: plans/01 ／ 依存: なし
- [x] 02 plan-triageをplan-registryへ統合 … 完了（移設＋skill削除・reviewer挙動不変byte-identical・まとめ評価01全PASS・2026-07-22人間承認で削除実行）
    役割: 実装
    対象repo: ~/Private（plan-registry・skills/plan-triage削除・9参照更新・global-skill-registry catalog）
    並列: 可
    人間ゲート: skill削除（plan-triage）はskill-delete承認・catalog更新
    次: triage workflow(triage.md 93行)＋検証テスト(validate-route-cases.mjs/fixtures)を plan-registry/（scripts/・本文）へ移設。plan-registry/AGENTS.mdがtriage決定手続きを吸収。「skill plan-triage」参照9箇所（kickoff/plan-create-review/morning-routine/inbox-triage/orca-cockpit/loop-creator/repo-create/custom-agent-creator）をplan-registry参照へ更新。skill-delete経由でplan-triage skillを閉じる
    場所: plans/02 ／ 依存: なし（子01と独立）
- [ ] 03 朝会刷新とテーマ簡素化 … 保留（reviewerコード全PASS・2026-07-22人間承認でcommit済み・翌朝10:03自動実走の実測2件が最終確認に残る）
    役割: 実装
    対象repo: ~/Private（skills/daily-start・morning-routine・session-board board.py theme-add）
    並列: 不可
    人間ゲート: daily-start手順書の差し替え（朝の儀式変更）
    次: daily-startを作文起票→「①active計画の工程進捗要約 ②今日進める計画の選択 ③次工程のAI割り振り案の提示と人間承認 ④繰越し・滞留質問の確認」へ全面改訂。起票は選択計画の工程節→自動steps登録（作文ゼロ）。テーマ3〜5個義務廃止。theme-addの完了条件を必須から外し意図1行に
    場所: plans/03 ／ 依存: 子01
- [ ] 04 立案強制hookの要否判断と設計 … 保留（人間判断=段階1採用・guard-plan-gate.py実装/単体検証済み・hook登録の人間承認が残る）
    役割: 実装
    対象repo: ~/Private（hooks-registry・要実装時のみ）
    並列: 可
    人間ゲート: hook登録（実装する場合のみ）
    次: 「ライト以上の実装を計画なしで始めたら警告/停止」hookの要否判断。現状は助言のみ（register-and-guideはexit0＝非ブロック）。設計案（実装系ツール前ゲートで対象repoのactive計画/起票を確認）を出し、過剰摩擦なら見送りを記録。やるならPreToolUse hookで最小の警告から
    場所: plans/04 ／ 依存: 子01
- [ ] 05 入口triageとエージェント格納フロー … 保留（レーンA/B=実装・build検証とも完了commit／レーンB=focusmap local main 0570acff・未push＝本番反映は人間ゲート・工程03まとめ評価が残る）
    役割: 実装
    対象repo: ~/Private（基盤）＋ projects/active/focusmap（表示）
    並列: 可
    人間ゲート: focusmapの本番反映（git push / Cloud Runデプロイ）
    次: 両レーン実装完了（入口2分岐＋計画外ゾーン/plan直結格納/repo表示・npm run build成功）。残=工程03まとめ評価（両レーン独立評価）でPASS確認→子05クローズ。focusmap本番反映は人間承認まで保留
    場所: plans/05 ／ 依存: 子03

## 人間ゲート

- skill削除（子02: plan-triage を skill-delete で閉じる）＋ global-skill-registry catalog 更新
- daily-start 手順書の差し替え（子03: 朝の儀式の変更）
- hook登録（子04: 立案強制hookを実装する場合のみ）
- focusmapの本番反映（子05: git push / Cloud Runデプロイ。ローカルcommit/buildまではゲート外）

## 完了条件

- [ ] new-plan.sh生成の新規計画に「工程」節・評価/分離があり、plan-lintが工程節欠落と実装/評価混在を検出する（対象: plan-ops）
- [ ] plan-registryに「まとめ評価既定」の正文とまとめ評価テンプレがあり、本program自身がまとめ評価で全PASSしている（対象: plan-registry・本program評価/）
- [ ] plan-triageのtriage手続き・テストがplan-registry配下にあり、skills/plan-triageが閉じ、9参照がplan-registryを指す（対象: plan-registry・各参照skill・catalog）
- [ ] 翌朝のdaily-start実走で、テーマ作文・やること作文が発生せず、選択計画の工程がそのままDB登録される（対象: daily-start・翌朝実測）
- [ ] theme-addが意図1行だけで通り、完了条件入力が要求されない（対象: session-board）
- [ ] 立案強制hookの要否が判断され、実装 or 見送りの記録がある（対象: 子04）
- [ ] 入口(UserPromptSubmit)の注入文に「必ず判断→記録だけ／計画作成+commit+反映」の2分岐が明示され、focusmapに「計画外エージェント」ゾーンが出てplan宣言で計画へ格納される（対象: 子05・common.py・focusmap build）

## 関連

- 前身: `2026-07-21-計画工程化と朝会刷新/plan.md`（単発planを本programへ格上げ・scope拡大でtriage統合と立案強制を追加）。
- 対: `plans/done/2026-07-21-ボードUI計画統合`（見る側＝当日ボード4段化・完了）。本programは作る側。

## 終了記録

archive時に必須。実行中は記入しない。
