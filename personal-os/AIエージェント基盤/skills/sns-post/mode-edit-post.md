# mode-edit-post — 既存予約の本文編集モード

「文面変えたい」「上書きして」「投稿直したい」「N時の投稿変えて」で起動。

**用途**: 予約済み投稿の本文を **時刻維持で書き換え**。
**mode-publish との違い**: publish=新規予約、edit=既存予約の本文上書き。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。以降の `{accountName}` は会話コンテキストの選択を参照。

## フロー

1. **どの予約を変えるか特定**: ユーザーから時刻 or 本文の一部を聞く
2. **スプシで現在の内容と行番号を確認**:
   ```bash
   gws sheets +read --spreadsheet {config.spreadsheetId} \
     --range "{sheetName}!A1:M30"
   ```
3. **Buffer から post ID を取得**（GraphQL で scheduled 投稿一覧）:
   ```graphql
   query Posts($orgId: OrganizationId!) {
     posts(input: { organizationId: $orgId, filter: { status: [scheduled] } }) {
       edges { node { id dueAt text channel { displayName service } } }
     }
   }
   ```
   `dueAt` は UTC、スプシE列は JST。**JST 9:03 = UTC 00:03** で照合。
4. **新本文をユーザーと作成**: トーン・絵文字・CTA を確認してOKをもらう
5. **本文を保存 → Buffer 更新**:
   ```bash
   # 本文を /tmp/post-new.txt に書く
   cd {config.scriptPath}
   npx tsx src/edit-post.ts <postId> /tmp/post-new.txt
   ```
   `edit-post.ts` が元の dueAt を取得して保持したまま本文だけ上書きする。
6. **スプシのD列も同期**:
   ```bash
   gws sheets spreadsheets values update \
     --params '{"spreadsheetId":"{spreadsheetId}","range":"{sheetName}!D<行>","valueInputOption":"RAW"}' \
     --json '{"values":[["<新本文>"]]}'
   ```
   ピラー（G列）が変わるなら同様に G<行> も更新する。
7. **完了報告**: 「Buffer・スプシ両方更新完了。dueAt は維持」

## 注意点

- 複数件まとめて編集する場合は1件ずつ確認する（誤更新の影響が大きい）
- 投稿時刻自体を変える場合はこのモードでは不可（Buffer ダッシュボードで手動 or 別途 dueAt 引数追加）
- 本文の改行は `\n` に、ダブルクォートは `\"` にエスケープ
- スプシ D列の更新は `python3 -c "import json,sys; print(json.dumps(sys.stdin.read().rstrip()))"` でファイルから安全に変換できる

## 次のアクション提案

✅ 既存予約の編集完了
- 編集行: 行{rowIndex}
- 変更内容: {本文 / 画像 / 投稿日時 等}

次にどうしますか？

A. ✏️ 別の予約も編集する（同モード継続）
   — 続けて他の予約を編集
B. 📅 予約一覧を確認する（mode-list）
   — 全体の予約状況を再確認
C. 終了
