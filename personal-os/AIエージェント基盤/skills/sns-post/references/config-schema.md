# config-schema — sns-config.json スキーマ

各リポの `.claude/sns-config.json` の構造定義。

## トップレベル

```json
{
  "spreadsheetId": "string (必須) — Google Sheets ID",
  "bufferOrgId": "string (必須) — Buffer Organization ID",
  "scriptPath": "string (必須) — Bufferスクリプトのパス（~ 展開可）",
  "envFile": "string (必須) — .env.localファイルのパス",
  "accounts": [...]
}
```

## accounts[] エントリ

```json
{
  "name": "string (必須) — アカウント名（@なしのプロフィール名）",
  "channelId": "string | null — Buffer チャンネルID（未接続なら null）",
  "sheetName": "string (必須) — スプシのシート名",
  "service": "threads | x | instagram (必須)",
  "concept": "string (必須) — アカウントの位置づけ・1行で",
  "stance": "string (推奨) — 投稿スタンス・トーン",
  "targetAudience": "string (必須) — ターゲット層",
  "useWhen": ["string"] (必須) — このアカウントを使う場面のキーワード,
  "doNotUseWhen": ["string"] (必須) — 使わない場面のキーワード（→ 他アカウント案内付き）,
  "postingTimes": ["HH:MM" or "HH:MM-HH:MM"] — 投稿時間帯,
  "postLength": "string — 文字数の目安",
  "pillars": [
    {
      "id": "number",
      "name": "string — ピラー名",
      "frequency": "string — 頻度（例: 週3）",
      "emoji": "string — 推奨絵文字（任意）",
      "ctaStrength": "なし | ソフト | ハード (任意・主に副業系)",
      "note": "string — 補足"
    }
  ],
  "weeklyRotation": "string — 週間ローテーション（任意）"
}
```

## 必須フィールドの最小構成

```json
{
  "name": "...",
  "sheetName": "...",
  "service": "threads",
  "concept": "...",
  "targetAudience": "...",
  "useWhen": ["..."],
  "doNotUseWhen": ["..."]
}
```

これだけあればアカウント選択ロジックが動く。

## アカウント別詳細フロー（accounts/*.md）との関係

- **config 側に持つもの**: メタデータ・選択判定材料（concept / useWhen 等）
- **accounts/*.md に持つもの**: 詳細なピラー説明・スタイルガイド・伸びた型・テンプレ例

config の `pillars[]` には基本情報だけ書き、詳細フロー（どのソース使うか等）は accounts/{name}.md の表で管理。

## バリデーション例

スキル起動時のチェック:
- `spreadsheetId` が空 → エラー
- `accounts[]` が空 → エラー
- 各 account の必須フィールド不足 → 警告（その account はスキップ）
- `sheetName` 重複（複数アカウントが同じシート使うのは副業スプシのケース）→ 許容
