# mode-publish — Buffer予約実行モード

「Buffer入れて」「予約して」「投稿予約して」で起動。

スプシのA列=TRUE な未予約行（B列=空）を Buffer に新規登録する。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。以降の `{accountName}` は会話コンテキストの選択を参照。

## フロー

1. **dry-run で確認**:
   ```bash
   cd {config.scriptPath}
   npx tsx src/publish.ts {--account flag} --dry-run
   ```
   投稿対象の一覧を表示してユーザーに確認
2. **OK後に実行**:
   ```bash
   npx tsx src/publish.ts {--account flag} --post --yes
   ```
3. **実行後の状態**:
   - A列 → FALSE（処理済み）
   - B列 → "Buffer"（予約元）
4. **完了報告**: 予約件数・スケジュール時刻を提示

## アカウント特定

config.scriptPath/src/publish.ts は `--account` フラグでシート切り替えに対応：
- 仕事リポ: `--account kurashi` / `--account nextlevel`
- 副業リポ: フラグ不要（単一スプシシート）か、副業側もアカウント別シートになっていればフラグ必要

config の `accounts` から該当アカウントの sheetName を確認して指定。

## エラー処理

- スケジュール時刻が過去 → スキップ（スプシ更新が必要と通知）
- Buffer API エラー → 個別行ごとにエラー表示し、成功した分だけ進める
- 予約済み（B列=Buffer）の行 → 自動スキップ

## ⚠️ Step 0: 予約バックエンド選択（必須）

予約実行前に **必ずユーザーに選ばせる**:

```ts
import { getEnabledSchedulers } from './sns-config.js';
const enabled = getEnabledSchedulers();
```

AskUserQuestion で提示:

```
どこで予約しますか？

A. Buffer で予約          — 残 {N枠}/10。安定稼働中
B. API で予約             — 自社開発の予約 API（Post AI）。無制限
C. 両方                   — Buffer と API の両方に同じ内容を入れる
```

意図がはっきりしてれば自動分岐:
- 「Buffer で」「Buffer に予約」 → A
- 「API で」「API に予約」「Post AI で」 → B
- 配分指示なら都度確認

**enabled が 1 つしかない場合は自動選択**（質問せず進む）。

## scheduler 経由化（重要・改修）

旧 publish.ts は Buffer 直接呼び出しだったが、新方式では `scheduler/` 経由で予約する:

```ts
import { getScheduler, listEnabledSchedulers, markAsScheduled } from './scheduler/index.js';

// アカウントの defaultScheduler に基づいて取得
const scheduler = getScheduler(account.defaultScheduler);

// 予約実行
const result = await scheduler.schedule({
  channelId: account.channelId,
  text: post.text,
  scheduledAt: post.scheduledAt,
  imageUrl: post.imageUrl,
  videoUrl: post.videoUrl,
});

// ⚠️ 必ず markAsScheduled() で A=TRUE / B=予約元 を atomic 更新
// 直接 sheetsUpdate で B 列だけ書くのは禁止（A=FALSE 残し→二重予約事故の元）
markAsScheduled(spreadsheetId, sheetName, row, result.source);
```

`result.source` は `"Buffer"` / `"API"` のいずれか。
**A 列のチェックボックスを必ず `TRUE` にすること**（運用上の予約済みフラグ）。

## 残枠チェック（必須）

予約実行前に必ず残枠を確認:

```ts
const quota = await scheduler.quota(account.channelId);
if (quota.remaining < posts.length) {
  // ユーザーに分割提案
  console.warn(`残枠不足: ${quota.remaining}枠 / 投稿予定 ${posts.length}件`);
}
```

残枠が 0 → mode-edit-post に脱出提案。

## 次のアクション提案

✅ 予約完了
- 予約件数: {N}件
- 予約元: Buffer / API
- 残枠: Buffer {残}/10

次にどうしますか？

A. 📈 インサイト同期して最新数値を反映（mode-growth フローA）
   — 過去投稿の views/likes/replies を取得
B. 🛠 今回のテーマでネタ帳を増やす（mode-account-tend サブ③）
   — 次回ループ用の素材を貯める
C. 📝 別アカウントの投稿も作る（mode-create-post）
   — Step 0 から再開（アカウント選び直し）
D. 終了
