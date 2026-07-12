# account-edit-spec — アカウント編集の正本仕様

スプシ「アカウント管理」シートの**正本仕様**。どのフィールドがどのセルに対応し、どう書き込むかを一元管理する。

## なぜこのファイルがあるか

- スプシ・config・実装・MD ドキュメントの 4 箇所で同じ情報が散らばると必ずズレる
- このファイル（と config の `managementSheetSchema`）を **唯一の正本（SSOT）** にする
- スプシ構造を変えたら `npx tsx scripts/sns-post/src/sync-spec.ts` で `<!-- AUTO:* -->` ブロックを再生成する
- 解説文（人が書く部分）は AUTO ブロック外で保持される

## 共通レイアウト（両環境）

両環境（副業・本業）で **同一レイアウト**。アカウントは列単位で並ぶ:

```
A列    | B列          | C列          | D列   | ...
ラベル | アカウント1   | アカウント2   | (空)  |
```

| 環境 | スプシID | 列マッピング |
|---|---|---|
| 副業 | `1PrqLcBiNJLzWPAxGRFGcmlI9Pal4d6t_mrBHZZmVG2A` | B=hiro_ai_dx / C=yuu_workstyle |
| 本業 | `1fKrUBjsj_GdadGgitlquP_azf02G3tiCj1jyCs3QLnA` | B=kurashi_to_hataraku / C=nextlevel__career |

各アカウントの列は config.accounts[].managementColumn で定義。

## 行スキーマ（3ピラー版・行1開始）

<!-- AUTO:schema-table START -->
| 行 | field                | label                | 編集経路 / 連動更新 |
|----|---------------------|---------------------|---|
| 1  | accountName         | アカウント名              | 新規作成時のみ |
| 2  | profileImage        | プロフィール画像            | サブ④コンセプト更新（IMAGE 数式） |
| 3  | purpose             | アカウント目的             | サブ④。変更時は concept/pillar との整合性チェック |
| 4  | selfIntro           | 自己紹介文               | サブ④。変更時は concept との整合性チェック |
| 5  | concept             | アカウントコンセプト          | サブ④。変更時は purpose / pillarMix / pillar*Detail との整合性チェック |
| 6  | pillarMix           | 投稿打ち分け              | サブ②。**pillar1Detail / pillar2Detail / pillar3Detail と atomic 更新** |
| 7  | pillar1Detail       | ①ピラー詳細              | サブ①。**pillarMix の該当箇所と atomic 更新** |
| 8  | pillar2Detail       | ②ピラー詳細              | サブ①。**pillarMix の該当箇所と atomic 更新** |
| 9  | pillar3Detail       | ③ピラー詳細              | サブ①。**pillarMix の該当箇所と atomic 更新** |
| 10 | recommendedLength   | 推奨文字数               | サブ①から自動算出 or 手動 |
| 11 | postAction          | 投稿後アクション            | 共通仕様（変更頻度低） |
| 12 | algorithmPriority   | アルゴリズム優先順位          | 共通仕様（変更頻度低） |
<!-- AUTO:schema-table END -->

> ⚠️ この表は config.managementSheetSchema から自動生成される。手動編集禁止。スキーマ変更は config を編集して `sync-spec.ts` を実行。

## ピラー詳細セルのフォーマット

各 pillar*Detail セルは複数行テキスト。以下の固定キーを含む:

```
【①{ピラー名}】メイン枠 / サブ枠
構成比: {N}% / 週{X}（{曜日帯}）
文字数: {min}〜{max}字
絵文字: {方針}
メディア: {テキスト/画像/動画}
書き方: {スタイル}
NG: {禁止事項}
```

検証時はこのキーがすべて存在するか確認。欠損時は警告。

## pillarMix セルのフォーマット

```
3ピラー / 構成比
① {pillar1Name}: {ratio1}% / {frequency1} / {type}
② {pillar2Name}: {ratio2}% / {frequency2} / {type}
③ {pillar3Name}: {ratio3}% / {frequency3} / {type}
```

`pillar*Detail` の構成比・頻度・名称と完全一致する必要がある（atomic 更新で保証）。

## 連動更新ルール（必須セット）

```
変更フィールド          → 一緒に書き込む必要がある
─────────────────────────────────────
pillarMix              → pillar1Detail / pillar2Detail / pillar3Detail （構成比・頻度の整合）
pillar*Detail (任意1〜3) → pillarMix の該当行
concept 変更           → purpose / selfIntro / pillar*Detail との整合性を LLM で判定し警告
purpose 変更           → concept との整合性を LLM で判定し警告
```

**実装ルール**: `account-config.ts` の書き込み関数は連動セット単位で受け取り、内部で atomic に実行する。片方だけ書く関数は提供しない。

## 検証ルール（書き込み前に必ず実行）

| ルール | 違反時の挙動 |
|---|---|
| 全ピラー構成比合計 = 100% | 警告 + 「正規化しますか？」提案（自動 100% 化） |
| ピラー数 = 3 | 不一致なら停止しユーザー確認 |
| 各 pillar*Detail に必須キー（構成比・文字数・絵文字・メディア・書き方・NG）が含まれる | 警告（既存セル形式の保持を促す） |
| concept ↔ pillar*Detail の意味的整合 | LLM で判定。乖離大なら警告 |

## 書き込みフロー（全サブモード共通）

```
Step A: 編集案をユーザーに対話で固める
Step B: 連動セットを決定（spec の連動更新ルール参照）
Step C: 検証ルール実行（違反時は中断 or 警告）
Step D: dry-run 表示（diff 形式で書き込みセル一覧を提示）
Step E: ユーザー承認（明示的 yes / no）
Step F: スプシ atomic 書き込み（gws CLI 経由）
Step G: cache 即時 refresh（cache-design.md 参照）
Step H: insights/{accountName}.md に変更ログ追記
Step I: 「次のアクション提案」フック（next-action-hooks.md 参照）
```

## 変更ログのフォーマット（Step H）

`insights/{accountName}.md` に追記:

```markdown
## YYYY-MM-DD HH:MM 変更
- 変更フィールド: pillar2Detail
- 変更経路: mode-account-tend サブ① / mode-growth フローB-5 / mode-loop Step 4
- before: 構成比 30% / 文字数 150〜300字 / ...
- after:  構成比 25% / 文字数 100〜200字 / ...
- 連動更新: pillarMix の ② 行も同期
- 理由: {ユーザー入力 or 分析提案の要約}
```

## 関数 API（account-config.ts）

```ts
// 連動セット単位の atomic 更新
export async function updateAccount(
  accountName: string,
  edits: AccountEditSet,
  opts: { dryRun?: boolean; skipValidation?: boolean }
): Promise<{
  diff: CellDiff[];
  warnings: string[];
  applied: boolean;
}>;

export interface AccountEditSet {
  // 単独編集可（連動なし）
  purpose?: string;
  selfIntro?: string;
  concept?: string;
  recommendedLength?: string;
  postAction?: string;
  algorithmPriority?: string;
  // 連動編集（pillarMix と pillar*Detail を一緒に渡す）
  pillarMix?: string;
  pillars?: Array<{
    id: 1 | 2 | 3;
    detail: string; // pillar*Detail セル全体
  }>;
}
```

**禁止インターフェース**:

```ts
// ❌ 単独でピラー詳細だけ書く関数を作らない（連動が壊れる）
updatePillarDetailOnly(...)
// ❌ 単独で pillarMix だけ書く関数を作らない
updatePillarMixOnly(...)
```

## サブモード別の使い分け

| サブモード | 主に編集するフィールド | 連動更新 |
|---|---|---|
| サブ① ピラー詳細編集 | pillar*Detail（任意1〜3） | pillarMix も同期 |
| サブ② 投稿打ち分け編集 | pillarMix | pillar*Detail も同期（構成比・頻度） |
| サブ④ コンセプト更新 | purpose / selfIntro / concept | 整合性チェック→必要なら pillar*Detail も提案 |
| mode-growth フロー B-5 | 分析提案に応じて pillar*Detail | pillarMix も同期 |

## シート存在確認（起動時）

両環境で起動時に `アカウント管理` シートの存在を確認:
- ない → 警告 + `setup-management-sheet.ts` 提案
- ある → スキーマと一致するか軽量チェック（行数・必須ラベル）

## 関連ファイル

- 設定: 各リポの `.claude/sns-config.json` の `managementSheetSchema`
- 実装: `scripts/sns-post/src/account-config.ts`
- 同期: `scripts/sns-post/src/sync-spec.ts`
- キャッシュ: `references/cache-design.md`
- スプシ全体: `references/spreadsheet-layout.md`
