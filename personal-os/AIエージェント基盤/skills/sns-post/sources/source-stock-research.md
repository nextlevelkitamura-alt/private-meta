# source-stock-research — ネタ帳 + リサーチからの素材取得

mode-create-post / mode-loop でピラー選択後、**メイン経路**として使う。

旧 source-news.md / source-tips.md / source-cases.md を統合した。
ニュース・Tips・事例の境界はネタ帳一元化により曖昧になったため、優先順位だけで分岐する。

## フロー

```
Step 1: ネタ帳から該当ピラーの未使用素材を取得
  ↓ 件数十分 → Step 4 へ
  ↓ 不足 → Step 2 へ
Step 2: WebSearch / Threads 検索でリサーチ補完
  ↓
Step 3: LLM 生成で穴埋め（最低限）
  ↓
Step 4: 投稿文に整形 → ユーザー確認 → スプシ追記
  ↓
Step 5: 採用した素材を「使用済み」にマーク
```

## Step 1: ネタ帳取得

```ts
import { readStock } from '../scripts/sns-post/src/stock.js';

const stock = await readStock(accountName, {
  pillarId: selectedPillarId,
  status: '未使用',
});
```

優先順位:
1. **ヒット型**（過去の伸びた構造）— スコアが高い保証あり
2. **アイディア**（投稿の種）— 未加工だが方向性は決まっている
3. **素材**（具体的な事実・データ）— ファクトベースで使える

## Step 2: リサーチ補完（必要時のみ）

ネタ帳が空 or 不足の場合に WebSearch:

| ピラータイプ | リサーチ手法 |
|---|---|
| ニュース系（最新AI実装等） | WebSearch で「{業界} 最新 ニュース」 |
| 業界解説・ライフハック | WebSearch + 既存記事ベース |
| 成功事例 | スプシ「管理表」（候補者DB）から属性検索 ※本業のみ |
| 共感系・あるある | アカウントの過去投稿から類似トーン抽出 or LLM |

WebSearch 利用時は **ソース URL を必ず記録**（後で素材ストックにアイディアとして保存できる）。

## Step 3: LLM 生成（穴埋め）

ネタ帳もリサーチも当たらないピラーは LLM の創作で埋めるが、警告を出す:

```
⚠️ ピラー{X} はネタ帳・リサーチで素材を確保できませんでした。
LLM 生成のみで作成します。スコアが伸びにくい可能性があります。
ネタ帳追加（mode-account-tend サブ③）を推奨します。
```

## Step 4: 投稿文に整形

アカウント管理シートから取得した情報を全部踏まえる:
- `concept` / `stance` の方針
- `pillar*Detail` の文字数・絵文字・書き方ルール
- `recommendedLength` の文字数
- `forbiddenTopics` の NG ワード回避

整形後、ユーザーに dry-run 確認:

```
📝 立案 {N}件

1. [ピラー{X}] {本文}
   素材: ネタ帳 行{stockRow} / WebSearch / LLM
2. ...

これでよろしいですか？
```

## Step 5: 採用素材を使用済みマーク

スプシ追記後、ネタ帳の該当行を `使用済み` に更新:

```ts
import { markStockAsUsed } from '../scripts/sns-post/src/stock.js';

if (post.stockRowIndex) {
  await markStockAsUsed(post.stockRowIndex, accountName);
}
```

リサーチで集めた素材は「アイディア」としてネタ帳に追加することを提案（mode-account-tend サブ③）。

## 関連ファイル

- 実装: `scripts/sns-post/src/stock.ts`
- 仕様: `references/account-edit-spec.md`
- 他ソース: `source-pdf-url.md` `source-template.md`
