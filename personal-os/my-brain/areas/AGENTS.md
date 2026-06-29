# My Brain Areas

このディレクトリは、work、ai運用、money、health などの継続領域を置く場所。
各areaは、考え、判断軸、計画を領域ごとに閉じて管理する。
personal-os の計画はここを単一正本にする。基盤・Skill・repo・loop計画は `ai運用/` が担当し、旧 `../../plans/` は廃止済み。

計画は area で育て、成熟したら実行repoへ卒業させる（§5）。my-brain は計画を育てる工房であって、実行の現場ではない。

## 1. Area標準構成

新しいareaは、原則として次の形にする。

```text
areas/<area>/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  identity.md
  plans/
```

1. `AGENTS.md`: そのareaでAIが作業するための入口ルール。
2. `CLAUDE.md`: `AGENTS.md` への相対symlink。本文コピーは禁止。
3. `identity.md`: そのareaの目的、判断基準、置くもの、置かないもの。
4. `plans/`: 実行する計画（バケット管理）。

考え・調査・仮説は独立フォルダにせず、`identity.md`（判断軸）か、育成中の計画の `plans/active/<計画>/plan.md` の `方針`（未確定のまま育てる）に寄せる。`thinking/` は廃止した。

## 2. 全体俯瞰: 現在地.md

`areas/現在地.md` は全領域の「今」を1枚で見る中央ボード。

1. active な計画だけを1行ポインタで載せる。列＝優先 / 領域 / 計画 / 場所 / 次の一手。
2. area で育成中の計画と、repoへ卒業して実行中の計画の両方を載せる（`場所` 列で区別）。
3. 状態の正本はフォルダ。現在地.md は索引。計画を active に出し入れする `git mv` と同じコミットで、この1行も足す/消す。
4. paused / done / archive / 卒業済みは載せない（履歴は各 area の `plans/` とログが持つ）。

## 3. Plan標準構成

計画は `plans/` 直下のライフサイクルバケットに置く。状態はフォルダで持ち、plan.md に状態フィールドは書かない。

```text
plans/
  active/    <YYYY-MM-DD-日本語企画名>/plan.md
  paused/    .gitkeep
  done/      .gitkeep
  archive/   .gitkeep
  移行済み/   YYYY-MM/MM-DD-<計画名>.md   （卒業ログ。初回卒業時に作る）
```

0. 計画フォルダ名は `YYYY-MM-DD-日本語企画名`。日付は作成日。固有名詞（Orca, skill-creator-custom 等）は識別子として残し、企画名は日本語で簡潔に（15〜20字目安）。
1. バケットが計画の状態の正本。意味は次の通り（area 内計画の状態）。
   - `active`: 育成中、または area 内で実行中。
   - `paused`: 一時停止。再開予定あり。
   - `done`: area 内実行が完了・未評価（repo不要の計画のみ。repoへ卒業した計画はここに来ない）。
   - `archive`: 評価して問題なしを確認済み。参照専用。
   - `移行済み/`: repoへ卒業した計画のログ置き場（状態バケットではなく履歴。詳細は §5）。
2. plan.md に `状態:` フィールドは書かない（フォルダが正本）。`分類:`（skill/repo/loop）と `種別:`（新規作成/既存改善/統合整理）は計画の分類なので plan.md 冒頭に書く。
3. 状態が変わったら `git mv` でバケット間を移す。
   - 新規 → `active/`。
   - 一時停止 → `paused/`。
   - area内実行 完了（未評価）→ plan.md に結果を追記し `done/` へ。
   - 評価OK → `archive/`。問題があれば `active/` へ戻す。
   - repoへ卒業 → バケット移動ではなく §5 の卒業手順で repo へ移す。
   - 評価ゲート: `done`=「完了・未評価」、`archive`=「評価済みOK」。完了報告を受けた計画オーナー（または委任された Claude）が done を確認してから archive へ動かす。
4. 空の `paused/` `done/` `archive/` は `.gitkeep` を置く。`移行済み/` は空フォルダを先に作らず、初回卒業時に作る。
5. `plan.md` を計画本文の正本にする。追加ファイルは分離した方が読みやすい時だけ作る。

### plan.md 統一テンプレ

1. 冒頭に `分類:`（skill/repo/loop。横断は最も近い分類）、`種別:`（新規作成/既存改善/統合整理）。
2. 必須セクション: `目的` / `現状` / `方針` / `完了条件`。
3. `完了条件` は未確定でよい（「未確定」と明記）。`方針` も固まる前は「未確定」と書いて育てる。
4. 「背景: 未記入」のような空欄テンプレは禁止。書けない欄は消すか「未確定」と書く。

## 4. Ops標準構成

計画を作ったら、`ops/` に種別5フォルダを作る。状態はフォルダにせず、各作業ファイルの中で持つ。

```text
plans/active/<YYYY-MM-DD-日本語企画名>/
  plan.md
  ops/
    human/        .gitkeep
    ai/           .gitkeep
    repositories/ .gitkeep
    skills/       .gitkeep
    loops/        .gitkeep
```

1. 種別フォルダは空のまま `.gitkeep` を置く。gitは空ディレクトリを保存しないため。
2. 作業は `ops/<種別>/<作業名>.md` に置く。
3. 状態はファイル先頭の `状態:` 行で持つ。フォルダで状態を分けない。

種別は次を使う。

1. `human`: 人間がやること。
2. `ai`: 既存AIに依頼すること。
3. `repositories`: repoの新規作成、既存改善、移動、整理。
4. `skills`: Skillの新規作成、既存改善、統合整理。
5. `loops`: 定期実行、監視、反復処理、自動運用loop。

状態は次を使う。

1. `planning`: 方針検討中、未着手、判断未確定。
2. `ready`: 計画済みで、着手可能。
3. `active`: 実行中。
4. `paused`: 一時停止。
5. `done`: 完了済み。
6. `archive`: 終了、参照専用、または古いもの。

## 5. 計画ライフサイクル: 育成 → 卒業

計画は area で生まれ育て、成熟したら実行先へ「卒業」させる。

1. 育成: `active/` で `plan.md` を育てる。成熟マーカーは持たない（成熟＝即卒業なので状態化しない）。
2. 卒業の引き金: 当面は人間が判断する。評価軸が固まったらAIとのハイブリッドへ。評価軸は実運用の中で固める。
3. 卒業先の判断:
   - 単一repoに属す作業 → そのrepoの `plans/`。
   - personal-os構造・横断・repo無し → 卒業せず area 内で実行（`ops/human`・`ops/ai`）。
   - global skill / 横断infra → 成熟後に「AIエージェント基盤へ卒業 or area留置」を1計画ずつ判断（今は AIエージェント基盤に `plans/` を作らない）。

### 卒業手順（repoへ移す場合）

1. 人間が「卒業」と判断。
2. 移行先を決める（既存repo / 新規repo＝repo-create で先に作成 / AIエージェント基盤＝global skill）。
3. 移行先repoに `plan.md`（＋要れば ops）を作成 → そのrepoで commit。
4. area の元 plan フォルダを削除し、`移行済み/YYYY-MM/MM-DD-<計画名>.md` に移行ログを追記 → ~/Private で commit。
5. `現在地.md` の行を「場所＝<repo>」に更新（active のまま、実行先が変わっただけ）。
6. 確認: secret無し / 移行先パスが現在地と移行ログで一致。
   ※ 卒業は ~/Private と移行先repoの2repoをまたぐ。`git mv` できないので「移行先で作成commit → area側で削除＋ログcommit」の2コミットになる。

### 移行ログの書式

`<area>/plans/移行済み/YYYY-MM/MM-DD-<計画名>.md`、1卒業＝1ファイル（並列書き込み衝突なし・既存 logs 規約と同形）。本体は移行先repoが持つのでここには置かない。

```text
移行日時: YYYY-MM-DD HH:mm JST
元計画: <area側の計画フォルダ名>
移行先: <repo名>
移行先パス: <repo内の plan.md / SKILL.md 等>
要約: <1行>
```

### area内実行のコミット

1. area内実行が生むのはドキュメント・意思決定・human行動の記録のみ → ~/Private にコミットしてよい（local-only・非コード）。
2. コードや成果物ファイルが出る瞬間に卒業対象。~/Private にコードを置かない。
3. 使い捨て実行は scratchpad、コミットしない。

## 6. 配置判断

1. 領域内の実行計画は `plans/active/<計画名>/plan.md` に作り、状態に応じてバケット間を移す。考え・調査は独立させず `identity.md` か plan.md の `方針` に寄せる。
2. その計画から派生する作業は、同じ計画フォルダ内の `ops/<種別>/<作業名>.md` に置き、状態はファイル内の `状態:` 行で持つ。
3. 成熟した計画は §5 の卒業手順で実行repoへ移す。area には現在地ポインタと移行ログが残る。
4. repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
5. Skill正本、registry、logsは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/` を正とする。
6. 計画本文を複数箇所にコピーしない。必要なら相対パスで参照する。
