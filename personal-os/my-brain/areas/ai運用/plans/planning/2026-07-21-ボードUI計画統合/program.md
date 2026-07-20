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

ファイル担当マップ（相互に触らない契約）:

- 子01: `focusmap/src/`（today系コンポーネント・board page・lib/turso の読みクエリ）。`db/turso/migrations/`・`session-board/`・`plan-ops/` は触らない。
- 子02: `focusmap/db/turso/migrations/`（inbox宛1本）・`focusmap/src/app/dashboard/plans/`・`plan-ops/scripts/plansync.py`・`session-board/board.py`＋`turso/store.py`（todo-add拡張・steps継承）・`skills/daily-start/SKILL.md`（繰越し継承の1節）。子01が作ったtoday系部品はpropsの追加のみ可（構造変更は子01へ差し戻し）。
- 子03: `hooks-registry/events/`（新hook）・`shared/session-board/`（sub-start拡張）・board宛migration。表示側は新規ファイル（sub-detail部品）に閉じ、子01のtask-row部品を書き換えない。
- 子04: コード変更なし（微調整が要れば該当子へ差し戻し）。

## 役割別コンテキスト

- `実装/共通.md`: 実装担当が全子で守ること
- `レビュー/共通.md`: レビュアーの観点
- `評価/`: `NN-〈子名〉-評価RR.md`、programの統合評価は `評価RR.md`

## 人間ゲート一覧

- inbox migration適用（子02: todos.plan_slug／todo_steps.started_at）
- board migration適用（子03: session_subagents 詳細4列）
- hook登録変更（子03: PreToolUse捕捉の settings.json 反映）
- push・本番デプロイ反映（各Wave末）

## 状態

planning（起票 2026-07-21）。activeへの遷移は前提ゲート消化＝「当日ボードSQL化」done移動で席が空いてから bucketctl で行う。
