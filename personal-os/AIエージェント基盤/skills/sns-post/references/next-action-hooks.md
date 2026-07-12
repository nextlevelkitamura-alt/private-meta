# next-action-hooks — 「次のアクション提案」フック共通仕様

各モード末尾でユーザーに次の行動を提案する仕組み。SNS 運用ループを自然に回すための仕掛け。

## なぜこのフックが必要か

- スキルは 1 つずつしか起動しない設計
- 個別モードを呼ぶたびに「次は何やるんだっけ」と都度考えるのは面倒
- 完了後に「今ならこれを次にやるのが自然」を提示すれば、ユーザーは流れに乗るだけで運用が回る
- 完了感を区切る「終了」を必ず用意して、降りたい時は降りられるようにする

## 共通フォーマット（必須）

各 `mode-*.md` の末尾に以下のセクションを必ず置く:

```markdown
## 次のアクション提案

### 完了報告

✅ {モード名} 完了
- {実行内容のサマリー（件数・対象等）}
- {副作用の有無}

### 次の選択肢（AskUserQuestion）

A. {次の候補1の見出し}
   — {何が起きるか・なぜ推奨か（1行）}

B. {次の候補2の見出し}
   — {同上}

C. {次の候補3の見出し}（任意・最大 4）
   — {同上}

D. 終了

### 選択時の動作

| 選択 | 動作 |
|---|---|
| A | Read mode-{xxx}.md → 該当モードを起動 |
| B | Read mode-{yyy}.md → 該当モードを起動 |
| C | Read mode-{zzz}.md → 該当モードを起動 |
| D | 「お疲れさまでした」とだけ返して終了 |
```

## モード別の標準提案（推奨マップ）

実装時はモードの内容に応じて柔軟に。以下はデフォルト指針:

| 終了モード | 推奨される次の候補 |
|---|---|
| mode-create-post | A: Buffer予約する（mode-publish）／B: 別ピラーで追加作成（同モード再起動）／C: 画像生成（mode-generate-image）／D: 終了 |
| mode-publish | A: インサイト同期（mode-growth フローA）／B: ネタ帳追加（mode-account-tend サブ③）／C: 別アカ投稿（mode-create-post）／D: 終了 |
| mode-list | A: 残枠分の投稿を立案（mode-create-post）／B: 既存予約を編集（mode-edit-post）／C: Buffer予約（mode-publish）／D: 終了 |
| mode-edit-post | A: 別の予約も編集（同モード継続）／B: Buffer予約（mode-publish）／C: 終了 |
| mode-generate-image | A: 投稿作成に戻る（mode-create-post）／B: Buffer予約（mode-publish）／C: 終了 |
| mode-growth (フローA) | A: 詳細分析（フローB）／B: 改善案で投稿立案（mode-create-post）／C: 終了 |
| mode-growth (フローB) | A: ピラー詳細を改善（mode-account-tend サブ①）／B: 改善案で投稿立案（mode-create-post）／C: ネタ帳に伸びた型を追加（サブ③）／D: 終了 |
| mode-account-tend | A: 投稿作成に進む（mode-create-post）／B: インサイト同期（mode-growth フローA）／C: 終了 |
| mode-research | A: ネタ帳に追加（mode-account-tend サブ③）／B: 投稿案を作る（mode-create-post）／C: アカウント設計を見直す（mode-account-tend）／D: 終了 |
| mode-loop | （特例: 内部 step 完了で next-action 抑制）終了時は「次回ループ推奨日: YYYY-MM-DD」と通知して終了 |

## mode-loop 内では抑制する

mode-loop は司令塔。各 step（インサイト同期 / 立案 / 残枠確認 / 予約 / 記録）の完了で next-action を出すと**ループの流れが切れる**。loop 中は内部的に step を進め、loop 全体が終了したときだけ通知する:

```
✅ ループ完了
- 予約 5 件（Buffer 残枠 3）
- 次回ループ推奨日: 2026-05-11（Buffer 枠が空く想定）

終了します。
```

ユーザーが loop 内で離脱した場合（途中で「終了」選択）は、その時点までの結果を報告して終了。

## 実装ガイド

### 各 mode-*.md 内での書き方

```markdown
## Step N: 完了処理

実行結果を {変数} に保存し、ユーザーに報告。
その後、`次のアクション提案` セクションに進む。

## 次のアクション提案

（前述のフォーマット）
```

### 起動時の挙動

選択肢 A〜C のいずれかが選ばれたら:

1. SKILL.md の Step 4 のロード表に従って該当 `mode-*.md` を Read
2. 「アカウント未確定なら確認、確定済みならそのまま継続」のルールに従う
3. mode 内のフローを実行

選択肢 D（終了）の場合:

1. 完了サマリーを再度短く提示
2. 会話を区切る挨拶（「お疲れさまでした」等）
3. 次の発話を待つ

## 抑制が必要な特殊ケース

以下は next-action フックを出さない:

- mode-loop 内部の step 終了時
- エラー停止時（ユーザーが対処すべき問題があるとき）
- ユーザーが「終了」「ありがとう」「以上で」など明示的に区切った後

## 関連ファイル

- 各モード: `mode-*.md`（末尾セクション）
- ループ: `mode-loop.md`
- SKILL.md: 共通ルールセクションに「全 mode に next-action 必須」を明記
