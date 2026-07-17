# 検証とplanningからactiveへの昇格

静的検査と、planningからactiveへの一方向の昇格を扱う。レビューの合否、archiveへの移動、削除、卒業先の選択は自動化しない。

## 1. program構造を静的検査する

```bash
scripts/program-lint.sh <program.mdの絶対パス>
```

- 子計画マップと `plans/NN-*.md` の対応、子のbacklink、状態語彙、完了なのに未チェックの完了条件を検査する。
- 違反なしはexit 0、違反ありは `<file>:<行>: <メッセージ>` とexit 1。
- lintが通っても、計画内容・レビュー証跡・人間承認の妥当性は判定しない。該当レビュー手順で別途確認する。

## 2. レビュー項目を節単位で見る

```bash
scripts/check-section.sh <file> <section-heading>
scripts/check-section.sh <file> <section-heading> <grep-pattern>
```

- headingは `#` を付けない前方一致。patternなしは節本文の目視用表示、ありは節内だけの `grep -E` で、exit 0が一致、1が不一致。
- 一致だけでレビュー合格とはしない。対象ファイル・節・期待する内容を評価書に明示し、人または独立したレビュー担当が意味を確認する。

## 3. planningからactiveへ昇格する

最初にdry-runを実行する。計画フォルダは `plans/planning/` の直下で、同じ `plans/active/` だけが遷移先である。

```bash
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active
```

- 既定は表示だけ。activeは原則4件で（2026-07-17人間承認で3→4。旧2026-07-14の一時例外は吸収済み）、上限なら現在一覧を出して拒否する。
- 何をactiveにするか、何をpaused/archiveへ移すかは指揮官と人間の判断。完了・評価済みでない計画をarchiveへ逃がさない。

承認済みの移動だけ、dry-runの同じsource/targetを確認して適用する。

```bash
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active --apply
scripts/bucketctl.sh promote <plans/planning/計画フォルダ> --to active --commit
```

- `--apply` は `git mv` のみ、`--commit` はこの移動だけを定型commitする。いずれも移動なので、人間の明示承認が必要。
- activeからpaused/done/archiveへの移動、削除、卒業とbacklink更新はこのscriptの対象外。正本規約と承認に従って手動で行う。

## 4. 失敗時

- dry-run、lint、section checkの失敗は副作用なしで止まる。表示されたpath・行・上限を確認する。
- 曖昧なpath、上限超過、正本不明、承認未取得を自動回避しない。指揮官または人間へ判断を戻す。
