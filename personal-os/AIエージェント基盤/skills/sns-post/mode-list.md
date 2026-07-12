# mode-list — 予約状況確認モード

「投稿確認」「何が予約されてる？」「予約一覧」で起動。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。「全部」を選択した場合は全アカウント横断表示。

## フロー

1. **Buffer予約一覧取得**:
   ```bash
   cd {config.scriptPath}
   npx tsx src/publish.ts {--account flag} --list
   # または
   npx tsx src/list.ts
   ```
2. **整形して表示**:
   - 投稿日時（JST）/ アカウント / 本文プレビュー / 画像有無

## 出力フォーマット

```
{accountName} の予約投稿（N件）

| 行 | 日時(JST)       | ピラー | 本文プレビュー       | 画像 |
|----|-----------------|-------|---------------------|------|
| 14 | 2026-05-04 9:04 | ⑤休息 | GW明けの月曜日…    | なし |
| 15 | 2026-05-04 13:06| ①励まし| GW明け、エンジン… | なし |
```

過去日時の予約があれば警告（投稿失敗の可能性）。

## 残枠表示の強化（追加）

各アカウントの予約一覧の冒頭に、enabled スケジューラーの残枠サマリを表示する:

```bash
cd {config.scriptPath}
npx tsx src/quota.ts {accountName}
```

出力例:
```
■ {accountName}
  Buffer: 残 7/10（使用 3）
  API: ∞ (無制限)            ← enabled の場合のみ表示
```

その後で予約一覧の表を出す。

## 次のアクション提案

✅ 予約状況確認完了
- 表示件数: {N}件
- 残枠: Buffer {残}/10

次にどうしますか？

A. 📝 残枠分の投稿を立案する（mode-create-post）
   — 残り枠ぶんの新規投稿を作る
B. ✏️ 既存予約を編集する（mode-edit-post）
   — 予約済みの本文を差し替える
C. 📅 新規 Buffer 予約（mode-publish）
   — スプシの未予約行を Buffer に登録
D. 終了

選択時の動作:
- A → Read mode-create-post.md
- B → Read mode-edit-post.md
- C → Read mode-publish.md
- D → 「お疲れさまでした」で終了
