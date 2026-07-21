分類: 横断 ／ 種別: 新規作成 ／ 形態: program
規模: フル
優先: ◎

# ボードUI計画統合

人間確認方針: 最終一括（危険操作は実行前に個別承認）
差し戻し上限: フル=2・ライト=1（超過は人間へエスカレーション。正本は plan-registry/AGENTS.md）

## 目的

focusmapボードを「朝決めたテーマが唯一の軸」の形（モックv2）へ刷新し、計画（program/子計画）の進行をボード上で
「ステップ時系列・✔＋斜線・今ここ・計画が閉じた瞬間に丸ごと終わったことへ」の形で見えるようにする。
あわせてサブエージェントの詳細（runtime・種別・起動方法・渡したプロンプト）をhookで捕捉しタップ展開で見せる。
設計の正本は 2026-07-21 の討論6体（3トピック×提案/批判）の統合裁定（`references/統合裁定.html`）。

## 非対象

- 計画mdの正本移管（md＋gitが唯一の正本のまま。DBは一方向ミラー。オンライン編集UIは作らない）
- 新テーブルの追加（列追加のみ。第2の状態台帳を作らない）
- daily-start の起動経路・morning-routine の手順変更（読み先は反転済み・前program所掌）
- focusmapのSupabase系機能（カレンダー・習慣等）

## 依存（前提ゲート）

program「当日ボードSQL化」の親最終一括が完了していること:
子08（session_subagents）・子09（sessions.todo_id/theme_id）migration の本番適用＋push＋評価。
未消化のまま本programの子を積むと差分が二重化するため、子01着手前に必ず閉じる。

## 正本境界（憲法・討論全員一致）

1. 計画md＋git が唯一の正本。plan_docs は post-commit 一方向ミラー（読み取り専用）。DB→md書き戻し経路は作らない。
2. ライブ進行（今ここ・済み）の正本は todo_steps 一本。md内チェックボックスは文書スナップショット。矛盾時はライブ優先。
3. 進捗%・今ここ・稼働N体は全てSQL導出。主観値・導出値をDBに保存しない。
4. 計画リンクは path でなく slug（バケット移動・改名で切れない）。done/archive の plan_docs 行は削除せず保持する。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01 ボード純UI … 修正02まで実装済み（本番実機の人間確認待ち）
    役割: 実装
    対象repo: /Users/kitamuranaohiro/Private/projects/active/focusmap
    並列: 子03（捕捉側）と可（repo非交差）
    人間ゲート: push・本番デプロイ反映（2026-07-21消化済み）
    次: 本番実機375px目視（人間）→ 評価03で完了判定。経緯=評価02全PASS→本番実機で人間FAIL指摘（見づらい・きみの番不要・詳細常時表示）→修正02（きみの番廃止・テーマ/未分類のデフォルト折りたたみ・1行サマリ化）=focusmap 2dcd7420・push済み・完了条件も改訂済み
    場所: plans/01 ／ 依存: 前提ゲート消化済み
- [ ] 02 計画接続 … 実装完了（テスト603PASS・inbox migration適用済み・push済み・本番実機確認待ち）
    役割: 実装
    対象repo: focusmap ＋ ~/Private（plan-ops・session-board・skills/daily-start）
    並列: 子01完了後（plansync部分のみ子01と並列可）
    人間ゲート: inbox migration適用（todos.plan_slug）=2026-07-21適用・検証済み ／ push=同日消化
    次: 本番で計画チップ・md文書タブの実機確認 → 評価md作成。実装=基盤267ce08＋focusmap 5f520df7（plan_slug列・計画チップ・ライブ進行タブ・plansync3バケット走査・繰越し継承手順）
    場所: plans/02 ／ 依存: 子01
- [ ] 03 サブエージェント詳細化 … 捕捉側統合済み（366テストPASS・hook登録済み）・表示側未着手
    役割: 実装
    対象repo: ~/Private/personal-os/AIエージェント基盤（hooks-registry）＋focusmap（表示側のみ）
    並列: 捕捉側は子01と可（focusmap禁止）／表示側は子01完了後
    人間ゲート: board migration適用（session_subagents 詳細5列）・hook登録変更・push
    次: 捕捉E2E実測→表示側（sub-detail）を修正02後の畳みUI規約に合わせて実装（初回実装エージェントはセッション圧縮で消失・成果物なし＝再実行）。board migration適用済み（詳細5列・2026-07-21）・統合=9a9e204（rebase済み・366PASS）・PreToolUse hook登録済み（settings.json反映済み2026-07-21）・payload結論=プロンプト捕捉可
    場所: plans/03 ／ 依存: 前提ゲート消化済み（表示側は子01）
- [ ] 05 計画直結ボード … 計画（2026-07-21人間の方向転換=カード軸をテーマから計画へ・シェルtodo畳み・active計画の常時表示）
    役割: 実装
    対象repo: focusmap
    並列: 子03表示側と直列（同一ファイル群）
    人間ゲート: push・本番反映
    次: 実装（シェルtodo畳み→計画カード化）→実機確認。表示軸の改訂であり正本境界（憲法）は不変更（DB構造・一方向ミラー維持）
    場所: plans/05 ／ 依存: 子01修正02・子02
- [ ] 06 理想形モック駆動の仕上げ … モック提示済み（人間承認待ち）。ミラー掃除は実施済み（孤児31行削除・active6本一致検証済み）
    役割: 実装
    対象repo: focusmap（表示差分のみ）
    並列: 子03表示側と同一レーン（承認後に一括実装・まとめ評価1本）
    人間ゲート: モック承認・push・本番反映
    次: モック承認 → 差分実装＋子03表示側 → 評価/まとめ評価01.md（修正02+子05+子03+子06一括）
    場所: plans/06 ／ 依存: 子05
- [ ] 04 完了移動の運用実測 … 計画（前提ゲート待ち）
    役割: 評価
    対象repo: なし（観測と記録）
    並列: 不可（子01〜03完了後）
    人間ゲート: なし
    次: 子01〜03完了後に2日間の実測
    場所: plans/04 ／ 依存: 子01・02・03

## 全体像・実行Wave（並列マップ）

```text
Wave 0: 前提ゲート（当日ボードSQL化の親最終一括）……人間ゲート: migration適用・push
Wave 1（並列・repo非交差）:
  ├ 子01 ボード純UI          … focusmap/src のみ（migration禁止・board.py禁止）
  └ 子03 サブ詳細化(捕捉側)   … hooks-registry ＋ board migration準備（focusmap禁止）
Wave 2: 子02 計画接続        … focusmap migration＋plans画面・plan-ops plansync・session-board CLI・daily-start継承
        子03(表示側)         … 子01の部品規約に従いsub展開UIを追加（子01完了後）
Wave 3: 子04 完了移動の運用実測（2日）→ program最終評価
```

ファイル担当マップ（衝突させない契約。同一ファイルは関数単位に分離し追記のみ・Waveで直列化）:

- 子01: `focusmap/src/`（today系コンポーネント・board page・PCカレンダー画面サイドバー・lib/turso の読みクエリ）。`db/turso/migrations/`・`session-board/`・`plan-ops/` は触らない。子01内部は30分スプリントの3レーン並列（担当ファイル分離は子01「実行体制」節が正本）。
- 子02: `focusmap/db/turso/migrations/`（inbox宛1本=todos.plan_slugのみ）・`focusmap/src/app/dashboard/plans/`・`plan-ops/scripts/plansync.py`・`session-board/board.py`＋`turso/store.py`（todo-add拡張・step-doing打刻・steps継承）・`skills/daily-start/SKILL.md`（繰越し継承＋全工程一括登録の節）。子01が作ったtoday系部品はpropsの追加のみ可（構造変更は子01へ差し戻し）。
- 子03: `hooks-registry/events/`（新hook）・`shared/session-board/`（sub-start拡張）・board宛migration。表示側は新規ファイル（sub-detail部品）に閉じ、子01のtask-row部品を書き換えない。
- 子04: コード変更なし（微調整が要れば該当子へ差し戻し）。
- 共有ファイルの注意: `board.py`・`turso/store.py` は子02（todo-add/step系）と子03（sub-start系）が**別関数を追記のみ**で触る。Wave上は子03捕捉（Wave1）→子02（Wave2）の直列となるため物理衝突しないが、後発側は先発の変更をrebaseして重ねる。`lib/turso` の読みクエリは子01が骨格を定義し、子02/03は新規クエリファイル追加のみ可。

## 役割別コンテキスト

- `実装/共通.md`: 実装担当が全子で守ること＋評価者の観点（レビュー/フォルダはlint規則7により作らない）
- `評価/`: `NN-〈子名〉-評価RR.md`、programの統合評価は `評価RR.md`

## 人間ゲート一覧

- inbox migration適用（子02: todos.plan_slug。※ todo_steps.started_at は前program子09のmigrationに含まれ、前提ゲートで適用済みとなる）
- board migration適用（子03: session_subagents 詳細5列）
- hook登録変更（子03: PreToolUse捕捉の settings.json 反映）
- push・本番デプロイ反映（各Wave末）

## 完了条件

- [ ] 全子（01〜04）の完了条件がPASSし、各子の評価mdが `評価/` に揃っている
- [ ] programの統合評価 `評価/評価01.md` が全PASS（憲法4条の違反ゼロを含む）
- [ ] スマホ実機で「テーマ軸ボード＋ステップ縦タイムライン＋計画チップ＋サブ詳細展開」が実データで動いている

※ 状態の正本はフォルダ（現在 planning/）。activeへの遷移は前提ゲート消化＝「当日ボードSQL化」done移動で席が空いてから bucketctl で行う（起票 2026-07-21）。
