# mode-create-post — 投稿作成モード

`/sns-post` で「投稿作って」「ネタ作って」「コンテンツ作って」と言われた時のフロー。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。以降の `{accountName}` は会話コンテキストの選択を参照。

## フロー全体像

```
Step 1: アカウント専用ファイル accounts/{name}.md を読む
  ↓
Step 2: ピラー選択（accounts ファイル内の「ピラー × ソース対応表」を提示）
  ↓
Step 3: ソース別フロー sources/source-{type}.md を読み込み
  ↓
Step 4: ソースに応じた素材入手 → 投稿文整形
  ↓
Step 5: ユーザー確認 → スプシ追記
  ↓
Step 6: Buffer予約するか確認 → mode-publish.md へ
```

---

## Step 1: アカウント専用ファイルを読む

```
Read ~/.claude/skills/sns-post/accounts/{accountName}.md
```

このファイルから以下を取得：
- アカウントの立ち位置・コンセプト・スタンス
- ピラー一覧（id / 名前 / 頻度 / 標準ソース）
- 投稿スタイル（語尾・絵文字・文字数）
- 週間ローテーション
- 過去の伸びた型・NG表現

**ない場合**: テンプレートから作成提案（`references/account-template.md`）

## Step 2: ピラー選択

accounts ファイルの「ピラー × ソース対応表」を表示し、ユーザーに選ばせる：

```
{accountName} のピラーから選んでください：

① 具体求人紹介（ソース: PDF/URL）
② 業界解説+ライフハック（ソース: AI生成 + 必要に応じてWebSearch）
③ スタッフ・成功事例（ソース: 候補者DB / 実績スプシ）
④ 求職市場ニュース（ソース: WebSearch）
⑤ DM相談誘導（ソース: 定型テンプレ）

▶ どのピラーで投稿しますか？（複数指定可）
```

ユーザー発話に手がかりがあれば自動推奨：
- 「PDFあるんだけど」「この求人」「URL貼った」 → ①
- 「面接の話」「履歴書のTips」 → ②
- 「内定もらった人」「事例」 → ③
- 「最近のニュース」「業界トレンド」 → ④
- 「DM誘導したい」 → ⑤

## Step 3: ソース別フロー読み込み

ピラーが決まったら、対応する sources/source-*.md を読む：

| ピラー指定 | 読み込むファイル |
|---|---|
| 求人系（PDF/URL） | `sources/source-pdf-url.md` |
| ニュース系 | `sources/source-news.md` |
| Tips/ライフハック系 | `sources/source-tips.md` |
| 事例系 | `sources/source-cases.md` |
| DM誘導/テンプレ系 | `sources/source-template.md` |

複数ピラー同時に作る場合、ピラーごとにループ。

## Step 4: 素材入手 → 投稿文整形

各 source ファイルの手順に従う。共通ルール：
- 投稿スタイルは accounts/{name}.md を参照（文字数・語尾・絵文字）
- 1投稿1ピラー
- 画像が必要かどうかは accounts ファイルで指定

## Step 5: ユーザー確認 → スプシ追記

投稿案を提示してOKをもらう。修正があれば反映。OK後にスプシ追記：

```bash
gws sheets +append --spreadsheet {config.spreadsheetId} \
  --range "{accounts.sheetName}!A:G" \
  --values '[["FALSE","","{画像URL}","{投稿内容}","{投稿日時}","{accountName}","{ピラー名}"]]'
```

- A列=FALSE（まだBuffer未投稿）/ B列=空（Buffer登録時に "Buffer" になる）
- 投稿日時は accounts ファイルの postingTimes から決定
  - **分単位は必ずランダム**（基準時刻+0〜9分）／0分・30分ジャストは避ける
  - 例: 19:00 ではなく 19:03 / 13:00 ではなく 13:07
- 画像が必要なピラー → C列は空のまま、後でモード6で生成

## Step 6: Buffer予約確認

「Buffer に予約しますか？」と聞き、Yes なら `mode-publish.md` へ移行。
画像が必要な場合は先に `mode-generate-image.md` を呼ぶ。

---

## エラー処理

- accounts/{name}.md が無い → テンプレ作成提案
- sources/source-*.md が無い → 該当ピラーをスキップ
- スプシ書き込み失敗 → 投稿案をユーザーに表示してリトライ

## データ参照の改修（重要）

旧仕様: `accounts/{name}.md` を Read してアカウント情報を取得
新仕様: **`account-config.readAccount()` 経由でスプシから取得**（cache あり）

```ts
import { readAccount } from './account-config.js';
import { readStock } from './stock.js';

// アカウント管理シートから取得（cache TTL 3分）
const account = await readAccount(accountName);

// ピラー詳細はセル
const pillar1Detail = account.pillar1Detail;
const pillarMix = account.pillarMix;
const concept = account.concept;
// 等

// ネタ帳から未使用素材を取得
const stock = await readStock(accountName, { status: '未使用' });
```

## ネタ帳優先 + リサーチ補完

ピラー選択後、素材源を以下の優先順位で:

1. **ネタ帳から該当ピラーの未使用素材を引く**
2. **不足分は WebSearch でリサーチ補完**（必要な場合のみ）
3. **どちらも無い場合は LLM 生成のみ**

使用したネタ帳行は投稿確定時に `markStockAsUsed()` で使用済みマーク。

## sources/ の使い分け（統合後）

3ファイルに統合済み:

| ピラー / 素材タイプ | 読み込むファイル |
|---|---|
| ネタ帳 + WebSearch | `sources/source-stock-research.md`（メイン経路） |
| PDF / URL（求人投稿等） | `sources/source-pdf-url.md` |
| DM 誘導等の定型 | `sources/source-template.md` |

## 次のアクション提案

✅ 投稿作成完了
- 件数: {N}件
- ピラー: {pillarName}
- スプシに追記済み（A=TRUE, B=空）

次にどうしますか？

A. 📅 Buffer 予約する（mode-publish）
   — 作成した投稿を予約
B. 🎨 画像を生成（mode-generate-image）
   — C列の画像 URL を埋める
C. 📝 別ピラーで追加作成（同モード再起動）
   — 別ピラーの投稿も作る
D. 終了
