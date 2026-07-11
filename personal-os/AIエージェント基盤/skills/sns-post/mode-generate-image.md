# mode-generate-image — 画像生成モード

「画像作って」「サムネ作って」「Geminiで生成」で起動。

Gemini（gemini.google.com）をブラウザ自動操作で画像生成。OpenAI API 不要。
`~/.playwright-auth` に Google ログイン済みプロファイルが必要。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。以降の `{accountName}` は会話コンテキストの選択を参照。

## 画像生成エンジン連携

生成方式は `images-generate/SKILL.md`（`image_gen`＋`exec resume`）に従う。

- 投稿予約に使う本番画像は、原則 ChatGPT ブラウザ生成を推奨する
- ChatGPT ブラウザ生成は Playwright の専用 Chrome プロファイルを使う
- Codex Image Gen2 は、ラフ案・その場の試作で使う
- カルーセル画像は、ユーザーが明示しない限り1枚ずつ個別生成する
- 例: 5枚カルーセルなら `Slide 1` → 生成、`Slide 2` → 生成、... の順で進める
- 画像生成後のスプシ書き込み・Drive URL化・Buffer予約は、この `sns-post` 側の手順で扱う

## フロー

1. **対象行特定**:
   - C列（画像URL）が空 / D列（投稿内容）に内容ありの行を自動対象
   - `--row N` 指定で特定行のみ
2. **プロンプト自動生成**:
   - スプシD列の投稿内容 → 英語・シネマティック・人物顔なしのプロンプトに変換
   - アカウントの投稿テイストに合わせる（accounts/{name}.md 参照）
3. **生成実行**:
   ```bash
   cd {config.scriptPath}
   npx tsx src/generate-images.ts {--account flag if needed}
   ```
   オプション:
   - `--row N` : 特定行のみ
   - `--dry-run` : プロンプトだけ確認
   - `--show-browser` : 認証切れ対応
4. **後処理**:
   - 生成画像をダウンロード → Google Drive アップロード → 公開URL取得
   - スプシ C列に URL を自動書き込み

## 認証切れ時

```bash
npx tsx src/generate-images.ts --show-browser
```
ブラウザが開くので Google にログイン → 以降は headless で動く。

## 注意

- 顔出しNG（プロンプトで `no faces, no people in frame` を必ず指定）
- アカウントごとのテイスト：
  - kurashi系 → やわらかい・植物・温かみ
  - nextlevel系 → ビジネス・実用・現場感
  - hiro_ai_dx系 → テック・ドラマティック・劇的
- 既に C列にURLがある行は上書きしない（誤生成防止）

## 次のアクション提案

✅ 画像生成完了
- 生成枚数: {N}枚
- スプシ C 列に URL を書き込み済み

次にどうしますか？

A. 📝 投稿作成に戻る（mode-create-post）
   — 画像を使った投稿を仕上げる
B. 📅 Buffer 予約を確認（mode-list）
   — 予約状況をチェック
C. 終了
