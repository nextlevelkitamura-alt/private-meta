# mode-growth — 育てる・改善モード（インサイト収集→分析→改善 一本化）

「分析して」「インサイス取得」「どの投稿が伸びた？」「改善したい」「育てたい」で起動。

Threads インサイトの収集からパターン分析・改善提案・ファイル反映まで一本のフローで実行する。

---

## 前提

アカウントは SKILL.md の Step 4 で確定済み（または本モード内 Step 1 で選択）。
以降の `{accountName}` は選択済みアカウントを参照。

---

## Step 1: アカウント選択

config.accounts[] から AskUserQuestion で選ぶ。Step 0 で既に確定している場合はスキップ。

---

## Step 2: フロー選択（AskUserQuestion）

```
どちらですか？

A. インサイトだけ更新（クイック）
   — 数値（閲覧数・いいね・返信数）をスプシに書き込むだけ
B. 分析→改善（フルフロー）
   — インサイト確認 → パターン分析 → 改善提案 → ファイル反映
```

---

## フロー A: インサイトだけ更新（クイック）

### A-1: 取得実行

```bash
cd {config.scriptPath}
npx tsx src/insights.ts --sync
```

- `--sync`: Threads API から threads_id を自動マッチング（初回または投稿追加後）
- `--all`: 既存値があっても上書きして最新値取得
- `--test`: 最初の1件のみテスト

### A-2: 結果確認

スプシ I〜L 列が更新されたことを報告して終了:
- I = 閲覧数（views）
- J = いいね（likes）
- K = 返信数（replies）
- L = スコア = views×1 + likes×10 + replies×15

---

## フロー B: 分析→改善（フルフロー）

### B-1: インサイト鮮度確認

```bash
gws sheets get --spreadsheet-id {config.spreadsheetId} \
  --range "{sheetName}!A1:L100"
```

- I列が空の行が多い（50%以上）→ 「先にインサイトを収集しますか？」と提案
  - Yes → フロー A を実行後 B-2 へ
  - No → 手元のデータで分析続行
- I列に値あり → 即 B-2 へ

### B-2: パターン分析

取得したデータから以下を算出してユーザーに提示:

```
{accountName} 分析結果（投稿N件 / 期間: YYYY-MM-DD〜YYYY-MM-DD）

■ ピラー別スコア（平均）
  ① {ピラー名}: {平均スコア}（{件数}件）
  ② {ピラー名}: {平均スコア}（{件数}件）★最高
  ...

■ 時間帯別スコア
  09:00台: {平均スコア}
  13:00台: {平均スコア} ★高い
  18:00台: {平均スコア}

■ 画像あり vs なし
  あり: {平均スコア}（{件数}件） vs なし: {平均スコア}（{件数}件）

■ 気づき（上位5投稿の共通パターン）
  - {パターン1}
  - {パターン2}
```

### B-3: 改善提案

分析結果を踏まえて具体的な改善案を提示:

```
■ ピラー調整案
  - 「{ピラー名}」を週{N}回 → 週{M}回に増やす（スコア高いため）
  - 「{ピラー名}」を週{N}回 → 週{M}回に減らす（スコア低いため）

■ 投稿時間最適化案
  - {時間帯}台が最も効果的 → この帯を優先

■ コンセプト・スタンス強化ポイント
  - {伸びた投稿に共通する特徴}を活かす
  - {スコアが低い型}は内容を見直す

■ 次の1週間の推奨アクション
  1. {具体的なアクション}
  2. {具体的なアクション}
```

### B-4: insights/{accountName}.md への追記

```bash
# ~/.claude/skills/sns-post/insights/{accountName}.md に追記
```

形式:
```
## {YYYY-MM-DD} 分析

- 分析期間: {期間}
- データ件数: {N}件
- 伸びた型: {パターン}
- 次の戦略: {戦略}
```

### B-5: 承認後のファイル反映（オプション）

「以下の変更を適用しますか？」と確認を取ってから:

**変更する場合:**
- `accounts/{accountName}.md` の pillars 頻度・postingTimes・stance を Edit
- `{config の accounts[]}.pillars` を sns-config.json で Edit

**必ず差分を提示してから実行する。ユーザー承認なしに書き込まない。**

---

## エラー処理

| 状況 | 対応 |
|------|------|
| データ0件 | 「投稿実績が溜まってから再実行してください」と通知して終了 |
| H列（threads_id）が空 | `--sync` を提案 |
| スプシ読み込み失敗 | エラーメッセージを表示して停止 |
| Threads API エラー | `.env.local` の `THREADS_ACCESS_TOKEN_{accountName}` を確認するよう案内 |

## スプシ直接 update への改修（B-5 改修）

旧仕様: `accounts/{name}.md` を Edit する
新仕様: **スプシ「アカウント管理」を `account-config.updateAccount()` 経由で更新**

```ts
import { updateAccount } from './account-config.js';

// 分析提案に応じてピラー詳細を改善
const result = await updateAccount(accountName, {
  pillarMix: newMixText,
  pillars: [
    { id: 1, detail: improvedDetail1 },
    { id: 2, detail: improvedDetail2 },
    // 必要なピラーだけ
  ],
}, { dryRun: true });

// diff を表示してユーザー承認を取る
console.log(result.diff);
console.log(result.warnings);

// 承認後
await updateAccount(accountName, {...}, { dryRun: false });
```

`accounts/{name}.md` は廃止。すべてスプシ正本で運用する。

## ネタ帳への自動投入（追加）

分析で「次回試したい型」を発見したら、ネタ帳にアイディアとして追加することを提案:

```ts
import { addStock } from './stock.js';

await addStock({
  account: accountName,
  pillarId: 2,
  type: 'ヒット型',
  content: '〜という構造で書くとスコア高い傾向（直近 N 件で実証）',
  source: '分析: YYYY-MM-DD',
});
```

## 次のアクション提案（フローA: インサイト同期完了時）

✅ インサイト同期完了
- 同期件数: {N}件
- 最新スコア: {X}

次にどうしますか？

A. 📊 詳細分析（フローB）
   — パターン分析・改善案を出す
B. 📝 改善案で投稿立案（mode-create-post）
   — 直近の傾向を反映した新規投稿
C. 終了

## 次のアクション提案（フローB: 分析→改善完了時）

✅ 分析・改善提案完了
- 分析期間: {期間}
- 反映フィールド: {pillar*Detail / pillarMix}

次にどうしますか？

A. 🛠 ピラー詳細を改善する（mode-account-tend サブ①）
   — 提案を踏まえてさらに調整
B. 📝 改善案で投稿立案（mode-create-post）
   — 改善後の方針で実投稿
C. 🛠 ネタ帳に伸びた型を追加（mode-account-tend サブ③）
   — 次回ループ用に貯める
D. 終了
