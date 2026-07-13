---
name: plan-ops
description: 計画ライフサイクルの機械手続き（program.md子計画マップの機械書換、計画テンプレからの雛形生成、program.mdの静的整合チェック、レビュー項目の範囲付き判定）を固定パスのscriptで安全に実行する窓口。Use when program.mdの子計画マップを更新する（状態/次の一手/参照repo@hash）, 単発plan.md/program.md/子計画.mdの雛形を作る, program.mdの整合（実ファイル有無・backlink・状態語彙・完了条件チェック漏れ）を機械チェックする。中身の判断（何をやるか・どう直すか）は判断系skillへ委譲し、ここは手続きだけを担う。
---

# plan-ops

計画ライフサイクルの「機械手続き」を、固定パスのscriptで安全に回す窓口skill。
**判断（中身の決定）はしない。** 何をやるか・どう直すかは既存の判断系skill（`mokuteki-jisso` / `plan-triage` / `grill-me` 等）へ委譲する。ここは手だけ。

規約の正本（コピーしない・ここから参照する）:
- 状態の持ち方・作業パイプライン段階語彙・人間ゲート: `~/Private/personal-os/説明書/運用契約.md` §1-2。
- 計画テンプレ／レビュー項目と実行ゲート／バケット状態語彙: `~/Private/personal-os/my-brain/areas/AGENTS.md` §3-4。

規模・段階・状態の語彙はこのSKILL.mdでは独自定義しない（上記正本への前方一致参照のみ。program-lintの状態語彙チェックも運用契約§2を参照する実装）。

## 0. 状態の持ち方（テキスト状態）

- **既定はテキスト状態**（単一指揮官）。program.md の子計画マップ／plan.md がそのままテキストで状態を持つ。`progctl.sh` はこの状態（子計画マップ）の書換を機械化する。

## 1. これで自動化していること（実地テストの痛点）

1. **子計画マップの機械書換（マップ手動更新が最大の痛点・実測）** → `scripts/progctl.sh`
   「NNブロックの状態変更 → 手でEdit+コミット」が当日コミットの過半を占めた実測を受け、該当NNブロックだけを冪等に書き換える（マップ外・他ブロックはバイト不変）。何を書くか（状態文言・次の一手・参照repo@hash）は指揮官の判断のまま。
2. **計画テンプレのscaffold（テンプレ正本の二重管理防止）** → `scripts/new-plan.sh` / `scripts/new-child.sh`
   テンプレ本文の正本を `skills/plan-ops/templates/` の1箇所に集約し、そこから単発plan.md・program.md・子計画.mdを生成する。中身（目的/現状/方針等）は書かない＝雛形のみ。実装後のレビューサイクル用に `templates/評価.md`・`templates/修正.md` もここが正本（生成scriptは無し・手でコピーして使う。運用規約は areas/AGENTS.md §3「評価・修正文書」）。
3. **program.mdの静的整合チェック** → `scripts/program-lint.sh`
   「子計画マップを0件検出している」「マップにあるのに実ファイルが無い」「子のbacklinkが解決しない」「状態語彙が崩れている」「完了なのに完了条件未チェック」を機械検出する。ライブなレーン状態（cockpit/watch.sh）は見ない・見るのは静的ファイルのみ。
4. **レビュー項目の範囲付き機械判定** → `scripts/check-section.sh`
   ファイル全体 grep が例示・別節を誤検出する痛点を、対象セクションに範囲を絞って潰す。
5. **WIP上限付きの昇格** → `scripts/bucketctl.sh`
   planning に起案済みの計画を active へ昇格する時だけ使う。既定dry-runで、active が3件以上なら一覧を示して拒否する。追い出し・削除・卒業は自動化しない。

## 2. 使い方

### 2.1 子計画マップを更新する（progctl）

該当NN（2桁）のブロックだけを冪等に書き換える。既定はdry-run（unified diffのみ表示）。

```
scripts/progctl.sh set <program.mdのパス> <NN> --state "<状態文言>"
scripts/progctl.sh set <program.mdのパス> <NN> --next "<次の一手>"
scripts/progctl.sh set <program.mdのパス> <NN> --ref "<repo>@<hash>"   # 2repo束ね（基盤マージ↔マップ更新）の相手hashを記録
scripts/progctl.sh set <program.mdのパス> <NN> --state "..." --next "..." --ref "..." --commit   # 書換+定型コミット
```

`--state` は見出し行の状態部分を丸ごと置換（注記の括弧書きを付けるかは呼び出し元の判断）。`--next`/`--ref` は該当行が無ければ「場所:」行の直前に新設する。同じ内容で再実行すると「変更なし（冪等）」で終わり、空コミットは作らない。

### 2.2 計画テンプレから雛形を作る（new-plan / new-child）

```
scripts/new-plan.sh --out <生成する.mdの絶対パス> [--program] [--class <分類>] [--kind <種別>]
scripts/new-child.sh --out <生成する子計画.mdの絶対パス> --program <親program.mdの絶対パス> [--class <分類>] [--kind <種別>]
```

`new-plan.sh` は単発plan.md（既定）またはprogram.md（`--program`）を生成する。`new-child.sh` は既存programの子計画.mdを生成し、frontmatterの「親計画:」backlinkを `--out` から `--program` への相対パスで自動算出する。**生成した子を program.md の子計画マップへ追記するのは引き続き手動**（`progctl.sh` は既存ブロックの更新専用で、新規行の追加はスコープ外）。

### 2.3 program.mdの整合を機械チェックする（program-lint）

```
scripts/program-lint.sh <program.mdの絶対パス>
```

違反0件なら「違反なし」でexit 0。違反があれば `<file>:<行>: <メッセージ>` を列挙してexit 1。

### 2.4 完了条件を機械チェックする（check-section / done ゲート）

`areas/AGENTS.md` §3 の「レビュー項目は対象（ファイル/セクション）を明示する」を前提に、その対象セクションだけを見る。

```
scripts/check-section.sh <file> <section-heading>             # セクション本文を表示（目視判定）
scripts/check-section.sh <file> <section-heading> <pattern>   # その節内だけ grep（exit 0=一致 / 1=無し）
```

見出しは前方一致なので、`## 子計画マップ   ※ …` は `子計画マップ` だけで指定してよい。

### 2.5 planning から active へ昇格する（bucketctl）

指揮官が「今動かす」と判断した計画だけを昇格する。ライト以上の起案先は planning であり、`bucketctl` 以外で active へ直接置かない。既定はdry-runで、`--commit` を付けた時だけ `git mv` と対象計画だけの定型コミットを行う。

```
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active --apply
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active --commit
```

active が3件以上なら昇格を拒否して一覧を表示する。何を paused/archive に移すかは人間／指揮官が判断し、完了・評価済み以外を archive へ退避させない。

## 3. まだ自動化していない（当面は手動）

- **子計画マップへの新規行追加**（program化・子の新設時に「NN 子計画名 … 状態」行そのものを追記する操作）: `progctl.sh` は既存ブロックの更新（`set`）専用。追加は手で書く。
- **active 以外へのバケット遷移**（active→paused/done/archive）: 計画フォルダは git 追跡対象。`git mv` で手動。planning→active だけは `bucketctl.sh` を使う。
- **卒業＋backlink**（repo/基盤へ移す）: `areas/AGENTS.md` §5 の手順。**削除を伴うので人間承認必須。**
- **親子集約**（ジョブ完了→ program.md マップ / 子.md を更新）: 当面手動（コピーせず集約）。`progctl.sh --ref` で2repo束ねの相手hashは機械記録できるが、何を書くかの判断自体は人間/指揮官のまま。

## 4. 規律

1. secret / token / 認証値をログ・出力に書かない。
2. 計画に `状態:` フィールドを書かない（バケット／子計画マップが正本）。
3. 判断系skillの役割を奪わない（中身の決定は委譲）。
4. `progctl.sh` はマップ外・対象NN以外のブロックをバイト不変で保つ（テストで担保）。

## 5. script 早見

- `scripts/progctl.sh set <program.mdのパス> <NN> [--state --next --ref] [--commit]`
- `scripts/new-plan.sh --out <path> [--program] [--class --kind]`
- `scripts/new-child.sh --out <path> --program <親program.mdのパス> [--class --kind]`
- `scripts/program-lint.sh <program.mdの絶対パス>`
- `scripts/check-section.sh <file> <section-heading> [grep-pattern]`
- `scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active [--apply|--commit]`
