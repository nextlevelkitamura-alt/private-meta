# mode-account-tend — アカウント整備モード

「アカウント整備」「ピラー編集」「打ち分け変えたい」「ネタ帳追加」「コンセプト変えたい」「育てる」で起動。

スプシ「アカウント管理」と「ネタ帳」を直接編集する。アカウントの核（投稿打ち分け・ピラー詳細）を継続的に改善する経路。

## 前提

アカウントは SKILL.md の Step 4 で確定済み。`{accountName}` は確定アカウント参照。
**起動時に必ず force refresh** を実行（cache-design.md 参照）。

```ts
const account = await readAccount(accountName, { force: true });
```

## Step 1: サブメニュー選択

```
何を整備しますか？

A. ① ピラー詳細を編集
   — 個別ピラーの構成比・文字数・書き方を見直す（思いつき駆動）
B. ② 投稿打ち分けを見直す
   — 4ピラーの増減・全体比率変更（pillarMix 全体の再設計）
C. ③ ネタ帳に追加
   — アイディア・素材・伸びた型を貯める
D. ④ コンセプト・自己紹介を更新
   — アカウントの立ち位置・ターゲット再定義
```

選択に応じて以下の Step に分岐。

---

## サブ① ピラー詳細を編集

### 1-1: どのピラーか選択

現在のピラーを表示して選ばせる:

```
どのピラーを編集しますか？
A. ① {pillar1Name}（{ratio}%）
B. ② {pillar2Name}（{ratio}%）
C. ③ {pillar3Name}（{ratio}%）
```

### 1-2: 編集内容のヒアリング

選んだピラーの現状（pillar*Detail セル）を表示し、何を変えるか対話:
- 構成比を増やす/減らす
- 文字数の範囲変更
- 絵文字方針変更
- 書き方の変更
- NG項目追加

### 1-3: 連動更新の確定

- ピラー詳細を変更 → pillarMix の該当行も自動更新（atomic）
- 構成比変えた場合、他ピラーの構成比合計が 100% になっているか検証
- 100% にならない場合「他ピラーの構成比も調整しますか？」と提案

### 1-4: dry-run → 承認 → 書き込み

```ts
const result = await updateAccount(accountName, {
  pillarMix: newMixText,
  pillars: [{ id: targetId, detail: newDetailText }],
}, { dryRun: true });
```

diff を表示して承認 → `dryRun: false` で実行。

### 1-5: 変更ログ + 次のアクション提案

`insights/{accountName}.md` に変更ログ追記（フォーマットは account-edit-spec.md 参照）。
末尾の「次のアクション提案」セクションへ。

---

## サブ② 投稿打ち分けを見直す

### 2-1: 全体方針のヒアリング

現状のピラー一覧を表示:

```
現在のピラー構成:
① {name}: {ratio}% / {frequency}
② {name}: {ratio}% / {frequency}
③ {name}: {ratio}% / {frequency}

何を変えますか？
- 構成比のバランス変更
- ピラー名の変更
- 完全な再設計（pillarMix 全体を書き直す）
```

### 2-2: 編集案の作成

LLM が編集後の pillarMix セル全体と、影響を受ける全 pillar*Detail セルを生成。

⚠️ **重要**: pillarMix を変えたら必ず 3つの pillar*Detail も更新する（atomic）。
- 構成比の数字を整合させる
- 頻度を整合させる
- ピラー名を整合させる

### 2-3: 検証

- 構成比合計 = 100%
- ピラー数 = 3
- 各 detail に必須キー含む

違反時はユーザーに確認。

### 2-4: dry-run → 承認 → 書き込み

```ts
await updateAccount(accountName, {
  pillarMix: newMixText,
  pillars: [
    { id: 1, detail: newDetail1 },
    { id: 2, detail: newDetail2 },
    { id: 3, detail: newDetail3 },
  ],
});
```

### 2-5: 変更ログ + 次のアクション提案

---

## サブ③ ネタ帳に追加

### 3-1: 種別選択

```
何を追加しますか？
A. アイディア（投稿の種・まだ素材化していないもの）
B. 素材（具体的な事実・データ・本文の元）
C. ヒット型（過去の伸びた投稿の構造・パターン）
```

### 3-2: ピラー紐付け

```
どのピラー向けですか？
A. ① {pillar1Name}
B. ② {pillar2Name}
C. ③ {pillar3Name}
D. 全ピラー共通
```

### 3-3: 内容入力

ユーザーから内容・ソース（URL/書籍/自分の体験 等）を聞く。

### 3-4: 書き込み

```ts
await addStock({
  account: accountName,
  pillarId: selectedPillarId,
  type: '<アイディア / 素材 / ヒット型>',
  content: userText,
  source: sourceUrl ?? '',
});
```

書き込み後、cache が自動 refresh される。

### 3-5: 連続追加？

「もう1件追加しますか？」と聞いて、Yes なら 3-1 に戻る。No なら次のアクション提案へ。

---

## サブ④ コンセプト・自己紹介を更新

### 4-1: 何を更新するか

```
何を更新しますか？（複数可）
A. アカウント目的（purpose）
B. 自己紹介文（selfIntro）
C. アカウントコンセプト（concept）
D. プロフィール画像（profileImage）
```

### 4-2: 編集内容のヒアリング

選んだフィールドの現状を表示し、変更案を対話で固める。

### 4-3: 整合性チェック（重要）

concept や purpose が変わったらピラーへの影響をチェック:
- ピラー名・構成・トーンが新しい concept と整合しているか LLM で判定
- 乖離が大きければユーザーに警告

```
⚠️ コンセプトを変更すると以下のピラーも見直しが必要かもしれません:
  ② {pillar2Name}: 新コンセプト「{newConcept}」と方向性が異なる可能性

サブ① ピラー詳細編集 / サブ② 投稿打ち分けに進みますか？
```

### 4-4: dry-run → 承認 → 書き込み

```ts
await updateAccount(accountName, {
  concept: newConcept,
  purpose: newPurpose,
  selfIntro: newSelfIntro,
});
```

### 4-5: 変更ログ + 次のアクション提案

---

## 共通ルール

### キャッシュ強制 refresh

各サブモード開始時:
```ts
await readAccount(accountName, { force: true });
```

これにより iPhone 等の手動編集を取りこぼさない。

### atomic 書き込み

`updateAccount()` は連動セット単位で書き込む。
- pillarMix と pillar*Detail は必ずセットで渡す
- account-config.ts 内で 1 セルずつ sheetsUpdate する（現状）が、**呼び出し側からは atomic に見える**

### 検証ルール

書き込み前に必ず実行:
- 構成比合計 = 100%
- 必須キー存在
- 整合性チェック（LLM）

違反時は中断 or 警告（dryRun の diff に含める）。

## 次のアクション提案

完了後、AskUserQuestion で:

```
✅ アカウント整備完了
- 編集フィールド: {field一覧}
- 変更ログ: insights/{accountName}.md に記録

次にどうしますか？

A. 📝 投稿作成に進む（mode-create-post）
   — 整備した内容を反映した投稿を作る
B. 📈 インサイト同期（mode-growth フローA）
   — 直近の数値を確認して効果を見る
C. 🔁 ループを回す（mode-loop）
   — 一気通貫で予約まで進める
D. 終了
```

選択時の動作:
- A → Read mode-create-post.md
- B → Read mode-growth.md（フローA）
- C → Read mode-loop.md
- D → 「お疲れさまでした」で終了

## 関連ファイル

- 仕様: `references/account-edit-spec.md`
- キャッシュ: `references/cache-design.md`
- 実装: `scripts/sns-post/src/account-config.ts` / `stock.ts`
- 次提案: `references/next-action-hooks.md`
