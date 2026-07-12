# /sns-post 改修プロジェクト 進捗管理

最終更新: 2026-05-04（Phase 1-4 完了 / Phase 5 残り作業はユーザー実行）

## ゴール

`/sns-post` グローバルスキルを「ループ運用」可能な統合ハブに進化させる。

### 主要変更

1. **トップメニュー4枠化**: 🔁ループ / 📝単発 / 📅予約管理 / 🛠アカウント整備
2. **データ正本をスプシに**: アカウント管理 + ネタ帳（TTL3分のローカルキャッシュ層）
3. **ピラー数3に統一**: 全アカウント
4. **予約バックエンド抽象化**: Buffer + API（ダミー、enabled:false で当面非表示）
5. **全モード末尾に「次のアクション提案」フック必須**
6. **mode-loop / mode-account-tend を新設**

## Phase 進捗

### Phase 1: 仕様確定 ✅ 完了

- [x] references/account-edit-spec.md（スプシ正本仕様・セルマップ・連動更新ルール）
- [x] references/cache-design.md
- [x] references/scheduler-design.md
- [x] references/next-action-hooks.md
- [x] 副業/本業 両 config 拡張（managementSheetSchema・schedulers・managementColumn・3ピラー）

### Phase 2: scripts 実装 ✅ 完了

実装は **副業 `~/Private/副業/scripts/sns-post/src/` をマスター**として書き、`sync-scripts.sh` で 本業 `~/Private/仕事/scripts/buffer/src/` にコピー済み。

- [x] types.ts
- [x] sns-config.ts
- [x] cache.ts
- [x] scheduler/{interface,buffer,ownapi,index}.ts
- [x] account-config.ts
- [x] stock.ts
- [x] quota.ts
- [x] sync-spec.ts（schema → spec.md AUTO ブロック反映）
- [x] setup-stock-sheet.ts（ネタ帳シート初期化スクリプト）
- [x] setup-management-sheet.ts（アカウント管理シート整備スクリプト）
- [x] sync-scripts.sh（副業→本業コピー、実行済み）

### Phase 3: モード改修 ✅ 完了

- [x] mode-loop.md 新規作成（一気通貫: 分析→立案→残枠確認→予約→記録）
- [x] mode-account-tend.md 新規作成（4サブ: ピラー編集/打ち分け/ネタ帳追加/コンセプト更新）
- [x] mode-list.md 改修（残枠表示 + 次のアクション）
- [x] mode-publish.md 改修（scheduler 経由化 + 次のアクション）
- [x] mode-edit-post.md 改修（次のアクション）
- [x] mode-generate-image.md 改修（次のアクション）
- [x] mode-growth.md 改修（B-5 でスプシ直接 update + 次のアクション）
- [x] mode-create-post.md 改修（cache + ネタ帳経由化 + 次のアクション）

### Phase 4: スキル本体仕上げ ✅ 完了

- [x] sources/ 5→3 統合（source-stock-research.md / source-pdf-url.md / source-template.md）
- [x] SKILL.md を 109 行に削り込み（4枠メニュー化）
- [x] 旧ファイル整理（accounts/ 廃止 / REFACTOR-menu.md 削除 / handoff/ → references/handoffs/ 移動）
- [x] evals/evals.json 初版作成

### Phase 5: 実環境セットアップ（ユーザー実行が必要） ⏸ 残り

以下は **ユーザーが手動でスクリプトを走らせる必要がある作業**。スプシを書き換える破壊的操作を含むため、dry-run で確認後に本実行する。

- [ ] **副業スプシに「ネタ帳」シート作成**:
  ```bash
  cd ~/Private/副業/scripts/sns-post
  npx tsx src/setup-stock-sheet.ts
  ```
- [ ] **本業スプシに「ネタ帳」シート作成**:
  ```bash
  cd ~/Private/仕事/scripts/buffer
  npx tsx src/setup-stock-sheet.ts
  ```
- [ ] **副業スプシ「アカウント管理」を3ピラー版に整備**（dry-run → 確認 → 本実行）:
  ```bash
  cd ~/Private/副業/scripts/sns-post
  npx tsx src/setup-management-sheet.ts --dry-run
  npx tsx src/setup-management-sheet.ts            # 既存内容を保持して整備
  # または
  npx tsx src/setup-management-sheet.ts --force-overwrite  # config 値で初期化
  ```
- [ ] **本業スプシ「アカウント管理」を3ピラー版・行1開始に整備**（同上）:
  ```bash
  cd ~/Private/仕事/scripts/buffer
  npx tsx src/setup-management-sheet.ts --dry-run
  npx tsx src/setup-management-sheet.ts
  ```
  - 本業は行1=空・行2=アカウント名 だった旧レイアウトから 行1開始へ自動マイグレーションされる
  - 行 13 以降に旧ピラー詳細が残っていたら手動で削除
- [ ] **副業/仕事の config.json を git commit & push**（managementSheetSchema 等の追加）

### Phase 6: description 最適化（任意） ⏸

- [ ] skill-creator-custom の trigger eval で description を最適化

```bash
# 副業/本業どちらかの環境で
cd ~/.claude/skills/skill-creator-custom
# evals/evals.json の trigger_eval_seed をベースに最適化（手順は skill-creator-custom 参照）
```

## 重要な決定事項

### 共通レイアウト（行1開始・3ピラー版・config.managementSheetSchema が SSOT）

| 行 | field | label |
|---|---|---|
| 1 | accountName | アカウント名 |
| 2 | profileImage | プロフィール画像 |
| 3 | purpose | アカウント目的 |
| 4 | selfIntro | 自己紹介文 |
| 5 | concept | アカウントコンセプト |
| 6 | pillarMix | 投稿打ち分け |
| 7 | pillar1Detail | ①ピラー詳細 |
| 8 | pillar2Detail | ②ピラー詳細 |
| 9 | pillar3Detail | ③ピラー詳細 |
| 10 | recommendedLength | 推奨文字数 |
| 11 | postAction | 投稿後アクション |
| 12 | algorithmPriority | アルゴリズム優先順位 |

### アカウント別の列マッピング

| 環境 | B列 | C列 |
|---|---|---|
| 副業 | hiro_ai_dx | yuu_workstyle |
| 本業 | kurashi_to_hataraku | nextlevel__career |

### ピラー削減確定内容（config 反映済み）

- **hiro_ai_dx (4→3)**: ④DM誘導削除（任意CTAに）/ ②③で構成比+5%/+10%
- **kurashi_to_hataraku (5→3)**: ④内定 → ①へ吸収 / ⑤休息 → ③に統合
- **nextlevel__career (5→3)**: ④市場ニュース → ②に統合 / ⑤DM誘導削除（任意CTAに）
- **yuu_workstyle**: 設計セッション後に 3ピラーで作成（pillars: []）

## 残タスクチェックリスト（ユーザー実行用）

```
[ ] 1. 副業 setup-stock-sheet.ts 実行
[ ] 2. 本業 setup-stock-sheet.ts 実行
[ ] 3. 副業 setup-management-sheet.ts --dry-run 確認
[ ] 4. 副業 setup-management-sheet.ts 本実行
[ ] 5. 本業 setup-management-sheet.ts --dry-run 確認
[ ] 6. 本業 setup-management-sheet.ts 本実行
[ ] 7. 副業/仕事 リポで config.json を git commit & push
[ ] 8. /sns-post を起動して4枠メニューが表示されるか動作確認
[ ] 9. 1アカウント分の updateAccount() が動くか実地確認
[ ] 10. （任意）description trigger eval 最適化
```

## 関連ファイル一覧

### スキル本体
- `~/.claude/skills/sns-post/`
  - SKILL.md（109行）
  - mode-{loop,create-post,publish,list,edit-post,generate-image,growth,account-tend}.md
  - sources/{source-stock-research,source-pdf-url,source-template}.md
  - references/{account-edit-spec,cache-design,scheduler-design,next-action-hooks,spreadsheet-layout,config-schema,safety-rules,account-selection}.md
  - references/handoffs/（旧 handoff/handoff-concept-review.md 移動先）
  - evals/evals.json
  - cache/（gitignore）

### config（git 管理）
- `~/Private/副業/.claude/sns-config.json`
- `~/Private/仕事/.claude/sns-config.json`

### scripts マスター
- `~/Private/副業/scripts/sns-post/src/`
  - 既存: config.ts / publish.ts / insights.ts / generate-images.ts / append-posts.ts / edit-post.ts / check-schema.ts
  - 新規: types.ts / sns-config.ts / cache.ts / account-config.ts / stock.ts / quota.ts / sync-spec.ts / setup-stock-sheet.ts / setup-management-sheet.ts / scheduler/

### scripts コピー先（副業から sync-scripts.sh で同期済み）
- `~/Private/仕事/scripts/buffer/src/`

### 同期スクリプト
- `~/Private/副業/scripts/sns-post/sync-scripts.sh`
