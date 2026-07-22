親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
テンプレ: v2
規模: フル
形態判定: Program子 ／ 理由: 入口の判断強制とボードのエージェント格納を1子で束ね、基盤とfocusmapの2レーンを統合する
並列: 可 ／ 差し戻し上限: フル=2
人間ゲート: focusmapの本番反映（git push / Cloud Runデプロイ）

# 子05: 入口triageとエージェント格納フロー

## 目的

作業の「入口」（UserPromptSubmit）で「計画が要るかを必ず判断 → 要らない=記録だけ／要る=規定の場所に計画作成しcommitしてfocusmap反映」を通す。
さらに、動いているエージェント（セッション）を「計画外で動いているエージェント」ゾーンにまず出し、計画が固まって宣言したらその計画の中へ格納して見えるようにする。
「計画はじめでエージェントがどこにいるか分からない」を解消し、判断のタイミングを編集時（遅い）から入口（正しい）へ移す。

## 非対象

- triage判定基準そのものの再定義（規模3条件・route＝plan-registry §6所掌）。plansyncのmd→DBミラー根幹。
- 段階1 hook（guard-plan-gate）の新しい判定ロジック追加（役割整理＝入口の補助へ位置づけるだけ・撤去/登録は人間判断）。
- focusmapのボードUI大改修（子07の4段構造は維持。ゾーン1つの追加に留める）。

## 現状

- 入口: `register-and-guide.py`→`common.register_prompt` が UserPromptSubmit で枠登録＋ガイド注入する。だが「必ず判断→記録だけ/計画作成+commit+反映」の2分岐は明示強制が弱く、AIの規律頼み。
- 格納の配線: `board.py update --plan/--theme/--todo` でセッションの所属を宣言できる（`sessions` に列あり）。
- focusmap表示: `getCurrentSessions`（`src/lib/turso/personal-os-board.ts:260`）は `todo_id`/`theme_id` を読むが `plan` 直結でカードへ入れる経路が無い。plan/theme/todoのどれも無いセッションは `straySessions`（`build.ts:221`）→「未分類(StrayBox)」に混在し、「計画外エージェント」専用ゾーンが無い。

## 実行契約

- 対象repo: 2つ（基盤=`/Users/kitamuranaohiro/Private`、表示=`/Users/kitamuranaohiro/Private/projects/active/focusmap`）
- 実行形: delegated-parallel
- 最初に読む順番:
  1. `../program.md`
  2. `../実装/共通.md`
  3. この計画
  4. レーンA: `hooks-registry/events/prompt-register/register-and-guide.md`・`shared/session-board/common.py`(register_prompt)
  5. レーンB: focusmap `src/components/today/board-v2/build.ts`・`types.ts`・`src/lib/turso/personal-os-board.ts`(getCurrentSessions)・`stray-box.tsx`・`session-row.tsx`
- 依存成果: 子03（朝会の計画選択が入口判断の一部を担う・整合を取る）
- 変更可能範囲: レーン別（下記2レーンのpathのみ・2repoで非交差）
  - レーンA（基盤）: `shared/session-board/common.py`（register_promptの注入文）・`events/prompt-register/register-and-guide.md`・（必要なら）`board.py` の `--plan` 反映
  - レーンB（focusmap）: `src/lib/turso/personal-os-board.ts`（sessions読取に plan 追加）・`src/components/today/board-v2/{build.ts,types.ts}`・新規「計画外エージェント」表示コンポーネント・`src/app/dashboard/board/page.tsx`（差し込み）・API `summary/route.ts` は共有buildで自動追従
- 変更禁止範囲: triage基準（plan-registry §6）・plansync・子07の4段構造・sessions/session_* スキーマ・段階1 hookの判定ロジック
- ファイル担当マップ: レーンA=基盤repoの上記のみ／レーンB=focusmap repoの上記のみ（2repoで物理的に非交差）
- worktree方針: 不要（別repoで作業＝交差しない。各repoのworking treeで実装しcommit）
- 維持する契約: register_promptの非ブロッキング・毎ターンコスト規律（初回ガイドと毎ターンミラーの分離）・board.py既存サブコマンド互換・focusmap buildの契約型後方互換
- 検証: レーンA=common.pyの注入文にサクッと3条件と2分岐が入り、既存session-boardテスト全PASS。レーンB=`getCurrentSessions`がplanを読み、planを持つセッションが計画カードに入り、持たないセッションが「計画外エージェント」ゾーンに出る（`npm run build`成功＋ローカルpreviewで確認）
- 停止・エスカレーション条件: focusmapのsessions.plan照合が既存grouping（todo/theme）を壊す場合は分離設計へ戻す。本番反映（push/deploy）は人間承認まで実行しない
- 完了時に返す情報: result packet（status / changed_paths(2repo別) / tests / 本番反映=保留の明示 / remaining_risks）

## 方針

### レーンA（基盤・~/Private）: 入口で判断を必須化
1. `common.register_prompt` の初回ガイド注入文に「**必ず①計画要否を判断** → ②サクッと(3条件全YES)=記録だけ(--plan なし・log) → ③1つでもNO=規定の場所に計画作成しcommit→focusmap反映、その計画をupdate --planで宣言」を明示の手順として入れる（既存の三段ルート/3判定の文言と整合・重複させない）。
2. register-and-guide.md（説明書）を上記に追従。
3. 段階1 hook（guard-plan-gate）は「入口ガイドの補助（編集時の弱いリマインド）」と位置づけを明記（撤去/登録は子04の人間判断のまま）。

### レーンB（focusmap）: 計画外エージェントゾーンと計画への格納
1. `getCurrentSessions` の SELECT/型に `plan`（既存列）を確実に読ませ、`CurrentSession` に含める。
2. `build.ts` のセッション振り分けに「plan宣言済み → その計画カード（planSlugBase一致）へ」を追加。todo/theme経路は維持。
3. plan/theme/todoのいずれも無いセッションを、strayでなく新配列「計画外エージェント」へ。`types.ts` `BoardV2Data` に `unplannedSessions` を追加。
4. 新ゾーンの表示コンポーネントを追加し、`page.tsx` の themeGroups と StrayBox の間へ差し込む。空なら非表示。
5. 「移動して見える」＝plan宣言したセッションが次ポーリングで計画カード内 `cardSessions` へ移る（既存描画を流用）。

## 工程

- [ ] 01 実装: レーンA 入口ガイド強化（common.py注入文＋register-and-guide.md＋段階1位置づけ）  評価: まとめ
- [ ] 02 実装: レーンB focusmap 計画外エージェントゾーン＋plan直結格納（getCurrentSessions/build/types/新コンポーネント/page差し込み）  評価: まとめ
- [ ] 03 レビュー: 両レーンを独立評価（入口2分岐の明示・focusmap groupingの後方互換・build成功・格納の移動）  評価: まとめ

## 完了条件

- [ ] 入口(UserPromptSubmit)の注入文に「必ず判断→記録だけ／計画作成+commit+反映」の2分岐が明示される（対象: common.py register_prompt・register-and-guide.md）
- [ ] session-board既存テストが全PASS（入口文変更で挙動を壊さない）（対象: shared/session-board/tests）
- [ ] focusmapで plan を宣言したセッションがその計画カード内に表示される（対象: build.ts・getCurrentSessions・ローカル確認）
- [ ] plan/theme/todoの無いセッションが「計画外エージェント」ゾーンに出る（strayと分離）（対象: build.ts・types.ts・新コンポーネント・page.tsx）
- [ ] focusmap `npm run build` が成功し、契約型が後方互換（対象: focusmap build）
- [ ] 本番反映（push/deploy）は人間承認を得るまで保留にしてある（対象: 本子・人間ゲート）

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
