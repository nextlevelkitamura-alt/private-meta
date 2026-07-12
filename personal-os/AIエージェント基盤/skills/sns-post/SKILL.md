---
name: sns-post
description: >-
  SNS（Threads / 将来的にX・Instagram等）の投稿運用を「ループ・単発・予約管理・アカウント整備・競合/トレンド調査」の5機能で統合管理するグローバルスキル。
  本業（kurashi_to_hataraku / nextlevel__career）と副業（hiro_ai_dx / yuu_workstyle）で
  config を分離し、クロスリポでのアカウント誤操作を防ぐ。スプシ「アカウント管理」「ネタ帳」シートが正本。
  「投稿」「コンテンツ」「ネタ」「ポスト」「Buffer」「Threads」「予約」
  「ループ」「ループ回して」「育てたい」「整備」「ピラー編集」「打ち分け」「コンセプト変えたい」「ネタ帳」
  「投稿作って」「Buffer入れて」「予約して」「分析して」「文面変えたい」「画像作って」
  「改善したい」「インサイト」「競合調査」「トレンド調査」「Threads調査」「インフルエンサー調査」
  「スクショしてスプシ」「投稿構造を調べて」「AIコーチングの動向」
  またはアカウント名（kurashi_to_hataraku / nextlevel__career / hiro_ai_dx / yuu_workstyle 等）
  が出てきたら必ず起動する。
---

# /sns-post — SNS投稿管理（グローバル）

## 必読：予約時刻ルール（**恒久・最優先**）

**1日3投稿** の運用基本は 9時／13時／18時 "あたり"（朝・昼・夜）。

- **分は 00 / 15 / 30 / 45 を絶対に使わない**（ボット判定→アルゴリズム不利・実害あり）
- 分は 3〜38 の範囲でバラつかせる（プール例: `[3,7,11,14,17,19,22,24,27,29,31,33,36,38]`）
- 同一スロットでも **日ごとに違う分** にする
- 画像付き（②ピラー）は昼スロット 13 時あたりに揃える慣例
- アカウント config の `postingTimes` よりこのルールを優先する
- 詳細・背景は memory: [feedback_post-times-non-bot.md](file:///Users/kitamuranaohiro/.claude/projects/-Users-kitamuranaohiro-Private---/memory/feedback_post-times-non-bot.md)

予約スクリプト・ループモードの全ルートでこのルールを必ず通す。

## 起動時フロー

### Step 0: 本業 / 副業 選択

発話に短縮形（hiro / yuu / kurashi / nextlevel 等）が含まれる場合は自動推定してスキップ。
明示なしなら AskUserQuestion で確認:

- 本業（キャリア）→ `~/Private/仕事/.claude/sns-config.json`
- 副業（AI/働き方）→ `~/Private/副業/.claude/sns-config.json`

### Step 1: 5枠メニュー（AskUserQuestion）

```
何をしますか？

🔁 A. ループを回す      — 分析→立案→残枠確認→予約→記録 を一気通貫
📝 B. 単発で作る        — 投稿作成 / 画像生成
📅 C. 予約を管理        — 確認（残枠付き）/ 新規予約 / 既存編集
🛠 D. アカウント整備    — ピラー編集 / 打ち分け / ネタ帳 / コンセプト
🧭 E. 調査する          — 競合 / トレンド / 投稿構造 / スクショ台帳
```

意図が明確なら自動分岐（例: 「予約確認」→ C-1、「ループ」→ A）。

### Step 2: サブモード分岐

各枠のサブメニューは AskUserQuestion で:

| 枠 | サブ | 読み込むファイル |
|---|---|---|
| 🔁 A | （単一） | `mode-loop.md` |
| 📝 B | 1. 新規作成 / 2. 画像生成 | `mode-create-post.md` / `mode-generate-image.md` |
| 📅 C | 1. 確認＋残枠 / 2. 新規予約 / 3. 編集 | `mode-list.md` / `mode-publish.md` / `mode-edit-post.md` |
| 🛠 D | 1. ピラー / 2. 打ち分け / 3. ネタ帳 / 4. コンセプト | `mode-account-tend.md`（4サブ統合） |
| 🧭 E | 1. Threads競合調査 / 2. トレンド調査 / 3. スクショ台帳化 / 4. 投稿型抽出 | `mode-research.md` |

C-grade（育てる）は必要に応じて `mode-growth.md`（フローA: インサイト / フローB: 分析→改善）を読み込む。

### Step 3: アカウント確定 → モード実行

選択が確定したら必ずコンテキストに明記してから Read:

```
▶ 枠: {A/B/C/D/E} / モード: {モード名} / アカウント: {accountName}
```

## ソース別サブフロー（mode-create-post / mode-loop の Step 4 内分岐）

| ソース種別 | 読み込むファイル | 主用途 |
|---|---|---|
| ネタ帳 + WebSearch（**メイン**） | `sources/source-stock-research.md` | 全ピラー共通の通常ルート |
| PDF / URL | `sources/source-pdf-url.md` | 求人投稿（nextlevel ①） |
| 定型テンプレ | `sources/source-template.md` | DM 誘導等の任意 CTA |

## Loading Policy（progressive disclosure）

- **常時 in context**: SKILL.md（このファイル）のみ
- **モード選択時**: 対応する `mode-*.md` 1 ファイル
- **アカウント情報**: `account-config.readAccount()` 経由でスプシから取得（cache TTL 3 分）
- **ソース選択時**: `sources/source-*.md` 1 ファイル
- **on-demand**: `references/*.md` は必要時のみ

## 共通ルール

- **データ正本はスプシ**（アカウント管理 + ネタ帳 + 各投稿管理シート）。ローカルキャッシュは TTL 3 分で同期
- **書き込みは必ず atomic**: pillarMix と pillar*Detail はセットで書く（仕様: `references/account-edit-spec.md`）
- **副作用前は dry-run → 確認（対象・内容・影響）→ 実行**
- **全モード末尾で「次のアクション提案」フック必須**（仕様: `references/next-action-hooks.md`）
- **mode-loop 内では next-action フック抑制**（loop が司令塔）
- **予約は scheduler 経由**: `getScheduler('Buffer'|'API')` で抽象化（仕様: `references/scheduler-design.md`）
- 認証情報（BUFFER_TOKEN / THREADS_ACCESS_TOKEN_*）はログ出力禁止
- **スプシへの書き込みは投稿管理シートでは日時降順、アカウント管理シートではセル直接 update**

## 主要参照ファイル

- 正本仕様: `references/account-edit-spec.md`
- キャッシュ: `references/cache-design.md`
- 予約抽象化: `references/scheduler-design.md`
- 次アクション: `references/next-action-hooks.md`
- スプシ全体: `references/spreadsheet-layout.md`
- config: `references/config-schema.md`
- 安全ルール: `references/safety-rules.md`

## 環境マッピング（クイック参照）

| 環境 | スプシ列 | scriptPath |
|---|---|---|
| 副業 B | hiro_ai_dx | `~/Private/副業/scripts/sns-post` |
| 副業 C | yuu_workstyle（設計中） | 同上 |
| 本業 B | kurashi_to_hataraku | `~/Private/仕事/scripts/buffer` |
| 本業 C | nextlevel__career | 同上 |

スプシ「アカウント管理」「ネタ帳」シートのレイアウトは config.managementSheetSchema が SSOT。
変更時は `npx tsx scripts/sns-post/src/sync-spec.ts` で `references/account-edit-spec.md` の AUTO ブロックを再生成。
