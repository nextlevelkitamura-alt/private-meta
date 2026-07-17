# 雛形作成と子計画マップ更新

`plan-triage` などが、対象repo・計画箱・規模を解決済みであることを前提にする。ここでは内容を判断せず、雛形生成と**既存ブロック**の機械更新だけを行う。

## 1. plan / program の雛形を作る

```bash
scripts/new-plan.sh --out <生成する.mdの絶対パス> [--program] [--class <分類>] [--kind <種別>]
```

- `--program` なしは単発plan、ありは子計画マップ付きprogramの雛形を生成する。program生成では同じフォルダに `実装/共通.md`・`レビュー/共通.md`・`評価/`（役割別コンテキストと評価置き場・2026-07-17標準）も生成する。
- 親ディレクトリは自動作成するが、既存ファイルは上書きしない。
- 本文テンプレの正本は `templates/plan.md` と `templates/program.md`。生成後に目的・対象・完了条件を人が埋める。
- 置き場が曖昧、既存planと競合、または人間ゲートを含む場合は生成を止めて `plan-triage` / 指揮官へ戻す。

## 2. program の子計画を作る

```bash
scripts/new-child.sh --out <生成する子計画.mdの絶対パス> --program <親program.mdの絶対パス> [--class <分類>] [--kind <種別>]
```

- 親programの実在を確認し、生成した子から親への相対backlinkを自動で入れる。
- 既存ファイルは上書きしない。子の目的・完了条件・レビュー対象は生成後に記入する。
- **子計画マップに新しいNNブロックを追加する作業は手動**。`progctl.sh` は既存NNの更新専用で、新規ブロックは作らない。

## 3. 既存の子計画マップを更新する

まず差分だけを確認する。

```bash
scripts/progctl.sh set <program.mdのパス> <NN> --state "<状態文言>"
scripts/progctl.sh set <program.mdのパス> <NN> --next "<次の一手>"
scripts/progctl.sh set <program.mdのパス> <NN> --ref "<repo>@<hash>"
```

- `NN` は2桁の既存ブロック。`--state` / `--next` / `--ref` のうち少なくとも1つを指定する。
- 既定はdry-runでunified diffのみ。対象NN以外とマップ外は変更しない。同内容なら「変更なし」で終了する。
- 実ファイルへの適用と定型commitを一体で許可された時だけ、確認済みの同じコマンドに `--commit` を付ける。任意の手編集と `--commit` を混ぜない。

```bash
scripts/progctl.sh set <program.mdのパス> <NN> --state "<状態文言>" --next "<次の一手>" --commit
```

## 4. 生成・更新後の確認

programを扱ったら、次を実行する。

```bash
scripts/program-lint.sh <program.mdの絶対パス>
```

失敗時は出力の `<file>:<行>` を直す。状態語彙や完了条件の意味を推測して書き換えず、計画の所有者へ戻して判断を得る。
