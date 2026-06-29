分類: repo
種別: 既存改善

# 計画ライフサイクル設計（incubate → graduate）

日付: 2026-06-29 17:20 JST

## 目的

計画を「area で育て、成熟したら実行repoへ卒業させる」流れを構造化し、人間もAIも全体を俯瞰しやすくする。

## 現状

1. バケットは active/paused/done/archive の「実行ステータス」軸だけ。計画の成熟度や「repoへ卒業」の概念がない。
2. 全領域の「今」を1枚で見る場所がない（横断の優先順位・現在地に住所がない）。
3. thinking/ が空稼働（考え→そのまま plan 化するため使われない）。
4. plan.md の品質がばらつく（超詳細〜未記入テンプレ）。

## 方針（この会話で確定した設計）

### 中核モデル
1. 計画は area の `active/` で生まれ育てる。すぐ repo に持っていかない。
2. 成熟したら実行先へ「卒業」する。成熟マーカーは持たない（成熟＝即卒業なので状態化しない）。
3. 卒業の引き金は当面は人間。評価軸が固まったらAIとのハイブリッドへ。評価軸は実運用の中で固める（今は定義しない）。

### 計画の置き場
1. 単一repoに属す作業 → そのrepoの `plans/`（repo自己完結）。area には現在地ポインタのみ。
2. personal-os構造・横断・repo無し → area の `plans/`（area完結、ops/human・ai で実行）。
3. global skill / 横断infra → area で育て、成熟後に「AIエージェント基盤へ卒業 or area留置」を1計画ずつ判断。今は AIエージェント基盤に `plans/` を作らない（先送り）。

### バケットの意味（area内計画）
1. active: 育成中 or area内実行中。
2. paused: 停止。
3. done: area内実行 完了・未評価（repo不要の計画のみ）。
4. archive: 評価済み・参照。
5. 卒業した計画はここに居ない（repo＋移行ログへ移る）。

### 俯瞰と履歴
1. `areas/現在地.md`（中央1枚・今）: 全領域の active を1行ポインタ。列＝優先 / 領域 / 計画 / 場所 / 次の一手。area育成中と repo実行中の両方を載せる。フォルダ出し入れと同じコミットで1行更新。状態の正本はフォルダ。
2. `<area>/plans/移行済み/YYYY-MM/MM-DD-<計画名>.md`（領域ごと・履歴）: 卒業の記録。1卒業=1ファイル（並列書き込み衝突なし・高volumeで壊れない・既存 logs 規約と同形）。本体は repo 側にあるので置かない（二重管理しない）。空の月フォルダは先に作らず、初回卒業時に作る。

### 移行ログのファイル内容
```
移行日時: YYYY-MM-DD HH:mm JST
元計画: <area側の計画フォルダ名>
移行先: <repo名>
移行先パス: <repo内の plan.md / SKILL.md 等>
要約: <1行>
```

### 卒業手順（areas/AGENTS.md を唯一の正本にする）
1. 人間が「卒業」と判断。
2. 移行先を決める（既存repo / 新規repo=repo-create で先に作成 / AIエージェント基盤=global skill）。
3. 移行先repoに plan.md（＋要れば ops）を作成 → そのrepoで commit。
4. area の元 plan フォルダを削除し、移行ログを追記 → ~/Private で commit。
5. 現在地.md の行を「場所＝<repo>」に更新（active のまま、実行先が変わっただけ）。
6. 確認: secret無し / 2repo・2コミット / 移行先パスが現在地と移行ログで一致。
   ※ 卒業は ~/Private と移行先repoの2repoをまたぐ。`git mv` できないので「移行先で作成commit → area側で削除＋ログcommit」の2コミットになる。

### area内実行のコミット
1. area内実行が生むのはドキュメント・意思決定・human行動の記録のみ → ~/Private にコミットしてよい（local-only・非コード）。
2. コードや成果物ファイルが出る瞬間に卒業対象。~/Private にコードを置かない。
3. 使い捨て実行は scratchpad、コミットしない。

### plan.md 統一テンプレ
1. 冒頭に `分類:`（skill/repo/loop。横断は最も近い分類）、`種別:`（新規作成/既存改善/統合整理）。
2. 必須セクション: 目的 / 現状 / 方針 / 完了条件。完了条件は未確定可（「未確定」と明記）。
3. 「背景: 未記入」のような空欄テンプレは禁止。書けない欄は消すか「未確定」と書く。

### 概念の記録先（重複させない）
1. `my-brain/AGENTS.md`: 概念（my-brain＝計画の工房、育て→卒業）。数行。
2. `areas/AGENTS.md`: 機構（バケット・卒業手順・移行ログ形式・現在地.md）。唯一の正本。
3. `personal-os/AGENTS.md`: 1行ポインタ。
4. 各 `area/AGENTS.md`: `areas/AGENTS.md` を参照、複製しない。

## ステップ（実装＝すべて ~/Private のドキュメント作業）

- [ ] `areas/現在地.md` 新設（現 active: OrcaCLI複数エージェント運用 / キャリア転換 を記載）。
- [ ] `areas/AGENTS.md` 更新: 卒業フロー・卒業手順・移行ログ形式・現在地.md・area内実行のコード線引き・plan.md統一テンプレ。
- [ ] `my-brain/AGENTS.md` 更新: 工房→卒業の概念を数行。
- [ ] `personal-os/AGENTS.md` 更新: 1行ポインタ追加＋「公開GitHub remote」→「非公開(private)」訂正（CLAUDE.md は symlink なので実体は AGENTS.md を直す）。
- [ ] thinking/ 廃止: 各 area の thinking/ 削除、`plans-lifecycle.md` をこの plan に畳む（内容を失わない）。
- [ ] 触らない: AIエージェント基盤（plans/作らない）／既存 active・done・archive 計画（移動しない、OrcaCLI・キャリア転換もそのまま）／projects 配下の各repo。

## 完了条件

1. `現在地.md` と `移行済み/` 規約が存在し、AGENTS.md 群と整合している。
2. 卒業手順・移行ログ形式・area内実行の線引きが `areas/AGENTS.md` に1か所だけ書かれている。
3. 概念が `my-brain/AGENTS.md`、機構が `areas/AGENTS.md` にあり、重複していない。
4. thinking/ が無く、`plans-lifecycle.md` の内容が失われていない。
5. `personal-os/AGENTS.md` の remote 記述が事実（private）と一致。

## 関連

1. 先行: `done/2026-06-29-計画バケット化`（バケット導入）、`done/2026-06-29-運用整理`（命名規約・2repo構造）。
2. 旧設計メモ `../../thinking/plans-lifecycle.md` は本 plan に畳む（thinking/ 廃止に伴い移設）。
