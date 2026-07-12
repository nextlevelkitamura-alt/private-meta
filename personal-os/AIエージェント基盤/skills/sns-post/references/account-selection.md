# account-selection — アカウント選択ロジック

アカウント選択は **SKILL.md の Step 2〜3** で一元管理される。
このファイルは選択フローの詳細リファレンス。

## 選択フロー（SKILL.md Step 2〜3 の詳細）

### Step 2: 即時判定（スキップ条件）

ユーザー発話から以下が両方特定できる場合 → メニュー表示をスキップして直接 mode-*.md をロード:

| 条件 | 即時判定の例 |
|---|---|
| モード + アカウントの両方が明示 | 「hiro_ai_dx で投稿作って」 |
| アカウント短縮形が含まれる | 「hiro で投稿、ニュース系」 |

アカウント短縮形の対応（config.accounts[] の name から自動生成）:
- `hiro_ai_dx` → 「hiro」「hiro_ai」「ai_dx」
- `yuu_workstyle` → 「yuu」「workstyle」
- `kurashi_to_hataraku` → 「kurashi」「hataraku」
- `nextlevel__career` → 「nextlevel」「career」

### Step 3: 明示選択（AskUserQuestion）

メニュー画面でユーザーが入力する形式:

| 入力例 | 解釈 |
|---|---|
| `1A` | モード1（投稿作成）+ Aのアカウント |
| `3B` | モード3（Buffer予約）+ Bのアカウント |
| `2` | モード2（予約確認）→ アカウントは後続で聞く |
| `1 hiro` | モード1 + hiro_ai_dx（短縮形） |
| `2 全部` | モード2 + 全アカウント横断 |

**アカウントが1つのみの場合**: メニューのアカウント欄を省略し「{name} のみ設定されています。続けますか？」と確認。

## config.accounts[] の列挙方法

`.claude/sns-config.json` を読んで accounts[] から以下を取得:
- `name`: 内部識別子（ファイル名と一致）
- `concept`: 一行説明（メニューに表示）

メニュー表示例（2アカウントの場合）:
```
【アカウント】
  A. hiro_ai_dx（AI業務自動化コンサル）
  B. yuu_workstyle（働き方・キャリア）
```

## 選択後の処理

1. アカウントが確定したら会話コンテキストに明記:
   ```
   ▶ モード: {N}（{モード名}）/ アカウント: {accountName}
   ```
2. 対応する mode-*.md を Read して実行フローへ
3. mode-*.md 内で accounts/{accountName}.md を必要に応じて Read

## エラー処理

- config が見つからない → エラー停止「このリポジトリには sns-config.json がありません」
- accounts[] が空 → エラー「config にアカウントが定義されていません」
- 該当 accounts/{name}.md が無い → 「アカウント別フロー文書が無いため、テンプレから作成提案」
