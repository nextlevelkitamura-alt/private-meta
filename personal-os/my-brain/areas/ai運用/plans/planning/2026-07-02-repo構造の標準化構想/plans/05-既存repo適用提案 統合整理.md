親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
規模: フル
形態判定: Program子 ／ 理由: dry-runと診断をrepo別の人間判断可能な提案へ統合するため
並列: 不可 ／ 差し戻し上限: フル=2
人間ゲート: 物理移動、改名、削除、symlink変更、既存成果物のreference昇格は実行前に個別承認

# 既存repoへの適用提案

## 目的

03のrepo-create dry-runと04のread-only診断を統合し、仕事とfocusmapへ安全に標準を導入するためのrepo別提案を作る。

## 非対象

- 実repoの構成変更、ファイル移動、改名、削除、symlink変更を行わない。
- 既存成果物をarea referenceへ移動しない。
- commit、push、GitHub操作、registry実データ更新を行わない。

## 現状

標準は新規repoと既存repoに同じ粒度で適用できない。既存repoにはlegacy、実運用中の成果物、外部KPI正本、作業ツリーの事情があるため、対象ごとの差分と順序が必要である。

## 実行契約

- 対象repo: repo無し
- 実行形: integration
- 最初に読む順番:
  1. ../program.md
  2. ../実装/共通.md
  3. 03のrepo-create dry-run結果
  4. 04の仕事とfocusmap診断結果
  5. この子計画
- 依存成果: 03と04のresult packet
- 変更可能範囲: この子planの評価、提案Markdown、人間向けHTML、必要時のreferences
- 変更禁止範囲: 仕事、focusmap、repo-create、registry、runtime、外部サービス
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 提案と実行済み変更を混同せず、物理変更は対象repoをrootとする別sessionと個別承認後に限る
- 検証: 各repoに対象、現在の正本、提案差分、実行順、危険操作、人間ゲート、rollbackが一対一で示されていることを評価する
- 停止・エスカレーション条件: 実体配置とregistryが矛盾する場合、又は提案のためにread-onlyを越える調査が必要な場合
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. 提案はrepoごとに分け、標準の一括適用案を出さない。
2. 先にAGENTSの導線、次に計画正本、次に必要時だけのexplainとreferences、最後にlegacyを触るかどうかの人間判断を置く。
3. 既存の知識と成果物は原則そのままにし、reference昇格候補だけを一覧化する。実際の移動は対象・理由・移動先を示して人間承認を得る。
4. repo-createを使う場合もdry-runを先に提示し、applyは対象repoで開始する別sessionへ引き継ぐ。

## 完了条件

- [ ] 仕事とfocusmapそれぞれに、非破壊な適用順、提案差分、保留事項、人間ゲート、rollbackが示されている。
- [ ] 提案には実行済み変更が混ざらず、move、rename、delete、symlink変更、reference昇格が承認対象として明確に分離されている。

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
