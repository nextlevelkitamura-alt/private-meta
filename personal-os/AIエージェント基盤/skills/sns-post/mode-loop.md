# mode-loop — 一気通貫ループ

「ループ回して」「運用回したい」「いつものやつ」「育てたい」で起動。

SNS 運用ループ（インサイト同期 → 簡易分析 → 残枠確認 → 立案 → 予約 → 記録）を一発で回すモード。
途中で離脱可能。各ステップは個別モードを内部で呼ばずに直接実行する（loop が司令塔）。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。以降の `{accountName}` は確定アカウント参照。

## フロー全体像

```
Step 1: インサイト同期 ─ 数値が古ければ最新化
Step 2: 簡易分析 ─ 直近の伸びた型を3行サマリで提示
Step 3: 残枠確認 ─ 全 enabled スケジューラーの残枠を集計
Step 4: 残枠ぶんの新規投稿を立案 ─ アカウント管理 + ネタ帳 + リサーチで生成
Step 5: スプシ追記 ─ 投稿管理シートに dry-run → 承認 → 確定
Step 6: 予約バックエンド選択 ─ Buffer / API / 両方
Step 7: 予約実行 ─ scheduler 経由で予約 + B列に予約元記録 + ネタ帳の使用済み更新
Step 8: 完了報告 ─ 次回ループ推奨日を通知して終了
```

各 Step 完了時に「ここで止める」を選べる（離脱口を提供）。

## Step 1: インサイト同期

```bash
cd {config.scriptPath}
npx tsx src/insights.ts --sync
```

- threads_id がスプシ H 列にあるか確認、無ければ Threads API から自動マッチング
- I-L 列を最新化

完了時に「現在の最大スコア投稿」を 1 つだけ表示してユーザーに認識させる。

## Step 2: 簡易分析（3行サマリ）

cache 経由で直近 N 件のインサイトを取得し、以下の形式でユーザーに提示:

```
📊 直近 {N}件の傾向
- 最高スコア: ピラー{X} の「{タイトル断片}」（views {V} / 返信 {R}）
- 平均が高いピラー: {ピラー名}（{平均スコア}）
- 落ち込み傾向: {ピラー名}（前月比 -{N}%）
```

ここでユーザーに確認:

```
詳細分析しますか？
A. 続行（残枠確認へ）
B. 詳細分析（mode-growth フローB へ脱出）
```

B が選ばれたら mode-growth.md を読み込んで脱出。A はそのまま Step 3。

## Step 3: 残枠確認

```bash
npx tsx src/quota.ts {accountName}
```

または cache 経由で account-config を取得後に programmatic に呼ぶ。出力例:

```
■ {accountName}
  Buffer: 残 7/10（使用 3）
  API: 残 ∞ (無制限)（使用 0）  ← enabled の場合のみ表示
```

- 残枠 0 → 「予約済みのキャンセル/編集が必要です。mode-edit-post に進みますか？」
- 残枠 1+ → 続行

## Step 4: 投稿立案

cache 経由でアカウント管理データとネタ帳を取得:

```ts
const account = await readAccount(accountName);
const stock = await readStock(accountName, { status: '未使用' });
```

立案の入力:
1. **アカウント管理シート**から `pillarMix` `pillar1Detail` `pillar2Detail` `pillar3Detail` `concept` `stance` を取得
2. **ネタ帳**から `status: 未使用` の素材を取得（ピラー別に並べる）
3. **リサーチ**: ネタ帳が不足するピラーは WebSearch で素材補完（必要な場合のみ）

立案ルール:
- 残枠ぶんの本数を生成
- ピラー比率は pillarMix の構成比に従う
- 投稿時刻はアカウントの postingTimes に従う（直近の空き枠から埋める）
- 各投稿に `pillarId` を紐付ける

ユーザーに dry-run で提示:

```
📝 立案 {N}件

1. [{投稿日時}] [ピラー{X}] {本文プレビュー}
   素材: ネタ帳 行{stockRow} / WebSearch / オリジナル
2. ...

これでよろしいですか？
A. 全部 OK で進む
B. 個別に調整したい（番号で指定）
C. やり直し
```

## Step 5: スプシ追記

承認後、{accountName}投稿管理シートに新規行を追加:
- A 列: TRUE（予約待ち）
- B 列: 空（未予約）
- C 列: 画像 URL（なければ空）
- D 列: 本文
- E 列: 投稿日時
- F 列: アカウント名
- G 列: ピラー名

cache を refresh しない（投稿管理シートは別 cache キーになるため）。

## Step 6: 予約バックエンド選択

```ts
const enabled = listEnabledSchedulers();
```

- enabled が 1 つ → 自動選択（Buffer のみのケース）
- enabled が 2 つ以上 → AskUserQuestion で選ばせる

```
予約先を選んでください:
A. Buffer（残 N枠）
B. API（無制限）
C. 両方
```

## Step 7: 予約実行

選択された scheduler で予約:

```ts
import { getScheduler, markAsScheduled } from './scheduler/index.js';

const scheduler = getScheduler(source);
for (const post of newPosts) {
  const scheduled = await scheduler.schedule({
    channelId: account.channelId,
    text: post.text,
    scheduledAt: post.scheduledAt,
    imageUrl: post.imageUrl,
  });
  // ⚠️ A=TRUE / B=予約元 を atomic 更新（必須・忘れると二重予約事故）
  markAsScheduled(spreadsheetId, sheetName, post.row, scheduled.source);
  // 使用したネタ帳行を「使用済み」にマーク
  if (post.stockRowIndex) {
    await markStockAsUsed(post.stockRowIndex, accountName);
  }
}
```

エラー時は個別行ごとに表示し、成功した分だけ進める。

## Step 8: 完了報告

```
✅ ループ完了

実行内容:
- インサイト同期: {更新件数}件
- 立案 → 予約: {予約件数}件
- 予約先: {Buffer / API / 両方}
- ネタ帳使用: {使用件数}件

次回ループ推奨: {YYYY-MM-DD}
（Buffer 残枠が空く時期 / 投稿頻度から算出）

お疲れさまでした。
```

mode-loop は **next-action フック抑制** が原則。完了時はそのまま終了する（特例）。

## 離脱時の挙動

各 Step 開始時にユーザーが「やめる」「終了」「中止」と発話したら:
1. その時点までの実行結果を報告
2. 「途中までの予約は保持されます。再開する時は /sns-post → ループから再起動してください」
3. 終了

## エラー処理

| 状況 | 対応 |
|---|---|
| インサイト API エラー | Step 1 をスキップして Step 2 から続行（古いデータで分析） |
| 残枠ゼロ | mode-edit-post に脱出提案 |
| ネタ帳が空 | WebSearch + LLM 生成のみで立案（警告表示） |
| Buffer API エラー | 失敗した行を残し、次行へ進む |
| API 未実装 | エラーを表示して Buffer に切り替え提案 |

## 関連ファイル

- 仕様: `references/cache-design.md` / `references/scheduler-design.md` / `references/account-edit-spec.md`
- 実装: `scripts/sns-post/src/{cache,account-config,stock,quota,scheduler/}.ts`
- 脱出先: `mode-growth.md` `mode-edit-post.md` `mode-account-tend.md`
