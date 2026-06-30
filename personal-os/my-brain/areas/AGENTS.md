# My Brain Areas

このディレクトリは、work、ai運用、money、health などの継続領域を置く場所。
各areaは、考え、判断軸、計画を領域ごとに閉じて管理する。
personal-os の計画はここを単一正本にする。基盤・Skill・repo・loop計画は `ai運用/` が担当し、旧 `../../plans/` は廃止済み。
縦の目標ladder（3年→年間→デイリーの的と履歴）は隣の `../ゴール/`。ここ（areas）は横の領域別。全体の今は `../ダッシュボード.md`（my-brain直下へ昇格）。

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

## 2. 全体俯瞰: ダッシュボード.md

`../ダッシュボード.md`（my-brain直下へ昇格）は全領域の「今」を1枚で見る中央ボード。計画状態と AIジョブ状態を集約する。

1. active な計画だけを載せる。1計画＝1ブロックのリスト形式（表は使わない／生テキストで列がずれるため）。書式: 1行目「優先(◎/○) 計画名 … 領域」、続けて `次:`（次の一手）と `場所:`（plan・programへのパス）。
2. area で育成中の計画と、repoへ卒業して実行中の計画の両方を載せる（`場所:` で区別）。
3. 状態の正本はフォルダ。ダッシュボード.md は索引。計画を active に出し入れする `git mv` と同じコミットで、このブロックも足す/消す。
4. 進行中（area は `active`、基盤は `planning`/`ready`/`active`）だけ載せる。`paused` / `done` / `archive` に入ったら載せない（履歴は各 `plans/` とログが持つ）。

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
2. 必須セクション: `目的` / `現状` / `方針` / `完了条件（レビュー項目）`。
3. `完了条件` は検証可能な**レビュー項目**で書く（下の「レビュー項目と実行ゲート」）。未確定なら「未確定」と明記。`方針` も固まる前は「未確定」と書いて育てる。
4. 「背景: 未記入」のような空欄テンプレは禁止。書けない欄は消すか「未確定」と書く。

### レビュー項目と実行ゲート

計画は「完了条件＝レビュー項目（検証可能なチェック）」を実行前に定義する。これが実行GOと done の判定基準になる。

1. **実行ゲート**: レビュー項目が定義され着手可能になったら実行に出す。area計画は run-card を ai-jobs/ready へ出す（§4.2）。基盤計画は `planning → ready` に上げる（loop が拾う印）。
2. **done ゲート**: 実行後、レビュー項目を全部満たせば done。満たさなければ差し戻す。
3. レビュー項目は「やったか」でなく「**こうなっていれば正しい**」を書く（例: 「テーブル行が残っていない」「リンクが全て解決する」「secret混入なし」）。
4. 各項目は**対象（ファイル/セクション）を明示**する（例: 「3年計画.md の領域別4行すべてにヒントが付く」）。範囲を絞らないと機械チェックが誤判定する。

### プログラム計画（親子層）

複数の子計画を束ねる必要が出たら、単発 plan.md の上に「プログラム（program）」を被せる。

**判定基準**: 派生が単発作業で足りる → 単発計画のまま。**独立に卒業する子計画を2本以上生む → プログラム化**。

```text
plans/active/<YYYY-MM-DD-日本語企画名>/   # programフォルダ（自身の状態はこのareaバケット）
  program.md            # 親＝索引（目的・全体像・子計画マップ・完了条件）
  plans/                # 子計画群（平置きファイル）
    NN-<子計画名>.md     # 子＝plan.md 相当。frontmatter に 親計画: backlink
  references/           # 任意・遅延：参照資料（完成した材料。考え・未確定は方針/identity.md）
```

1. **親はフォルダ、親ドキュメントは直下 `program.md`。** 子は `plans/` に平置き。
2. **子の状態は program.md の子計画マップが持つ**（リスト形式: 「NN 子計画名 … 状態」＋ `次:` ＋ `場所:/依存:`。表は使わない）。子に状態バケットは作らない。
3. `program.md` frontmatter に `形態: program` を書く（単発 plan.md と区別）。
4. 子が並列実行で複数作業に割れる時だけ、その子をフォルダにし、実行は ai-jobs へ（§4.2）。
5. 子が卒業しても program.md は索引として残り、マップの「場所」を更新する（§5）。

### コピペ用テンプレ（案A準拠・表は使わない）

program.md:

```text
分類: <skill/repo/loop> ／ 種別: <新規作成/既存改善/統合整理> ／ 形態: program

# <program名>
## 目的
## 全体像
## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新
NN  <子計画名> … <状態>
    次: <次の一手>
    場所: plans/NN ／ 依存: <NN／―>
## 完了条件（レビュー項目）
- [ ] <検証可能なチェック>
## 関連
```

子計画.md（program の `plans/NN-*.md`）:

```text
親計画: ../program.md ／ 分類: <…> ／ 種別: <…>

# <子計画名>
## 目的
## 現状
## 方針
## 完了条件（レビュー項目）
- [ ] <検証可能なチェック>
```

単発 plan.md も同じ本文（`目的/現状/方針/完了条件（レビュー項目）`）。`形態: program` と子計画マップだけ持たない。

## 4. 計画状態語彙 と タスク実行（ai-jobs）

### 4.1 計画状態語彙（バケットの正本）

計画 / program のライフサイクル状態。バケット（フォルダ）で持つ。area・基盤で使う語彙の正本はここ。

1. `planning`: 方針検討中、未着手、判断未確定。（基盤plansのみ。areaは active で育てる）
2. `ready`: 計画済みで着手可能。（基盤plansで loop が拾う印）
3. `active`: 実行中／area育成中。
4. `paused`: 一時停止。
5. `done`: 完了・未評価。
6. `archive`: 評価済みOK・参照専用。

area の plan バケットは `active/paused/done/archive`（§3）、基盤の plan バケットは6語フル（基盤 `AGENTS.md` §1.1）。

### 4.2 タスク実行は ai-jobs キューへ

計画から派生する「実行する作業」は、area 内にフォルダを作らず、基盤の **ai-jobs キュー**に run-card として出す。

1. 置き場・運用の正本は `AIエージェント基盤/loops-registry/ai-jobs/`。run-state＝フォルダ位置 `ready/running/review/done/archive`（中身に `状態:` を書かない）。
2. run-card 1枚＝1実行依頼（`担当`/`出所`/`依頼`/`許可`/`戻し方`/`差し戻し上限`）。`出所` は計画への絶対パス backlink。
3. **human 作業は ai-jobs に入れない。** 人間のやることは program.md マップの「次の一手」か 子.md に書く。
4. 完了したら plan-ops が出所の計画（program.md マップ／子.md）を更新する（ジョブ→計画へ集約。コピーしない）。
5. 旧 `ops/` 5フォルダ構成は廃止。既存計画に残る `ops/` は legacy（新規には作らない・破壊しない）。

## 5. 計画ライフサイクル: 育成 → 卒業

計画は area で生まれ育て、成熟したら実行先へ「卒業」させる。

1. 育成: `active/` で `plan.md` を育てる。成熟マーカーは持たない（成熟＝即卒業なので状態化しない）。
2. 卒業の引き金: 当面は人間が判断する。評価軸が固まったらAIとのハイブリッドへ。評価軸は実運用の中で固める。
3. 卒業先の判断:
   - 単一repoに属す作業 → そのrepoの `plans/`。
   - personal-os構造・横断・repo無し → 卒業せず area 内で実行（human作業は program.md マップ／子.md、AI実行は ai-jobs。§4.2）。
   - global skill / loop → 基盤の卒業先（skill＝`AIエージェント基盤/global-skill-registry/plans/`、loop＝`AIエージェント基盤/loops-registry/plans/loop/`）へ卒業。状態は §4 の6語彙をフルでバケット化する（`planning`/`ready`/`active`/`paused`/`done`/`archive`）。構成の正本は基盤 `AGENTS.md` §1.1。

### 卒業手順（repoへ移す場合）

1. 人間が「卒業」と判断。
2. 移行先を決める（既存repo / 新規repo＝repo-create で先に作成 / AIエージェント基盤＝global skill は `global-skill-registry/plans/`、loop は `loops-registry/plans/loop/`）。
3. 移行先repoに `plan.md`（＋要れば子計画）を作成 → そのrepoで commit。
4. area の元 plan フォルダを削除し、`移行済み/YYYY-MM/MM-DD-<計画名>.md` に移行ログを追記 → ~/Private で commit。
5. `../ダッシュボード.md` の行を「場所＝<repo>」に更新（active のまま、実行先が変わっただけ）。
6. 確認: secret無し / 移行先パスがダッシュボードと移行ログで一致。
   ※ 卒業は ~/Private と移行先repoの2repoをまたぐ。`git mv` できないので「移行先で作成commit → area側で削除＋ログcommit」の2コミットになる。

### プログラムの子計画の卒業

プログラム配下の子は、個別に卒業する。親 program.md は索引として area に残る。

1. 子の本体を卒業先へ（上の通常手順）。子 frontmatter の `親計画:` backlink は、卒業後は**絶対パス**にする（cross-repo になるため）。
2. program.md の子計画マップの「場所」列を卒業先に更新（状態は active のまま、実行先が変わっただけ）。
3. 親 program.md は動かさない（全体の地図として工房に残る）。

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
2. その計画から派生する実行作業は、area内にフォルダを作らず基盤の ai-jobs キューに run-card で出す（§4.2）。独立に卒業する子計画を2本以上生むなら program 化する（§3）。
3. 成熟した計画は §5 の卒業手順で実行repoへ移す。area にはダッシュボードのポインタと移行ログが残る。
4. repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
5. Skill正本、registry、logsは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/` を正とする。
6. 計画本文を複数箇所にコピーしない。必要なら相対パスで参照する。
