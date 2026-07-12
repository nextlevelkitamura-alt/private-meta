# 引き継ぎプロンプト: SNSアカウントコンセプト精緻化セッション

以下をそのまま新しいチャットに貼り付けて開始してください。

---

## セッション開始プロンプト（ここからコピー）

```
SNS運用の4アカウントについて、アカウントコンセプトを精緻化したい。

## 背景・現状

以下4アカウントを運用中（または準備中）。
それぞれスプレッドシートとaccounts/*.mdで管理している。

### 副業アカウント（~/Private/副業/.claude/sns-config.json）
スプレッドシートID: 1PrqLcBiNJLzWPAxGRFGcmlI9Pal4d6t_mrBHZZmVG2A

**hiro_ai_dx**（Threads表示名: sora_ai_dx）
- 現コンセプト: AI業務自動化コンサル（定型業務のAI化で人件費削減）
- アカウント目的: AI導入を検討する中小企業経営者・士業へDM診断→有償コンサルへの集客
- 状態: 運用中（ピラー設計済み）
- ファイル: ~/.claude/skills/sns-post/accounts/hiro_ai_dx.md

**yuu_workstyle**
- 現コンセプト: ユウ｜働き方の気づき（働き方・キャリアの気づきを発信）
- アカウント目的: 働き方に迷う社会人との共感形成（戦略確定後に更新）
- 状態: ⚠️ 戦略未確定 — ピラー・投稿スタイル・時間帯すべて未設計
- ファイル: ~/.claude/skills/sns-post/accounts/yuu_workstyle.md

### 本業アカウント（~/Private/仕事/.claude/sns-config.json）
スプレッドシートID: 1fKrUBjsj_GdadGgitlquP_azf02G3tiCj1jyCs3QLnA

**kurashi_to_hataraku**
- 現コンセプト: 就活・転職活動で頑張る20〜30代の"心の伴走者"
- アカウント目的: 就活・転職中20〜30代との感情的繋がりを築きNextLevel認知を拡大
- 状態: 運用中（ピラー設計済み・伸びた投稿実績あり）
- ファイル: ~/.claude/skills/sns-post/accounts/kurashi_to_hataraku.md

**nextlevel__career**
- 現コンセプト: e-nextlevel キャリア事業部公式 集客アカウント
- アカウント目的: 20〜30代にDM経由で派遣就業を促進する集客アカウント
- 状態: 運用中（ピラー設計済み）
- ファイル: ~/.claude/skills/sns-post/accounts/nextlevel__career.md

## このセッションでやりたいこと

1. **各アカウントのコンセプトを精緻化する**
   - 「目的がぶれないシンプルなコンセプト」に整理する
   - 1〜2行で読んで「なるほど」とわかるものにしたい
   - スプレッドシートの「アカウント目的」行に書いたものの精度を上げる

2. **yuu_workstyle のコンセプト・ピラーを0から設計する**
   - hiro_ai_dx（AI/自動化）、kurashi（感情共感）との棲み分けを明確にする
   - ターゲット・ピラー・投稿スタイル・時間帯まで設計する

3. **4アカウントの棲み分けマップを整理する**
   - 4つが競合せず補完し合う構造になっているか確認
   - 各アカウントの役割の境界線を言語化する

## ゴール・制約

- シンプルさを優先。コンセプトは長くなりすぎない（1〜3行）
- 目的（何のためのアカウントか）は絶対に言語化する
- 決まった内容は以下に反映する:
  - accounts/{name}.md の内容を更新
  - スプレッドシートの「アカウント目的」行を更新（gws CLIで書き込み）

## 参照してほしいファイル

まず以下を読んでから提案してください:
- ~/.claude/skills/sns-post/accounts/hiro_ai_dx.md
- ~/.claude/skills/sns-post/accounts/yuu_workstyle.md
- ~/.claude/skills/sns-post/accounts/kurashi_to_hataraku.md
- ~/.claude/skills/sns-post/accounts/nextlevel__career.md
```

---

## セッション終了後にやること

セッションで確定した内容を以下に反映する:

1. `accounts/{name}.md` の更新（コンセプト・ピラー・投稿スタイル等）
2. スプレッドシートの「アカウント目的」行を更新:
   - 副業: `gws sheets spreadsheets values update --params '{"spreadsheetId":"1PrqLcBiNJLzWPAxGRFGcmlI9Pal4d6t_mrBHZZmVG2A","range":"アカウント管理!B3:C3","valueInputOption":"USER_ENTERED"}'`
   - 本業: `gws sheets spreadsheets values update --params '{"spreadsheetId":"1fKrUBjsj_GdadGgitlquP_azf02G3tiCj1jyCs3QLnA","range":"アカウント管理!B4:C4","valueInputOption":"USER_ENTERED"}'`
3. yuu_workstyle のピラー設計が完了したら sns-config.json の pillars[] を更新
