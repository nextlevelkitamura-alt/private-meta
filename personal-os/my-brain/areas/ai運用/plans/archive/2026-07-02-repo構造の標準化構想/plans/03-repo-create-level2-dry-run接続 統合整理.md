親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
規模: フル
形態判定: Program子 ／ 理由: repo-create既存改善programと同じSkillへ非重複で接続するため
並列: 不可 ／ 差し戻し上限: フル=2
人間ゲート: 実repoへのapply、GitHub作成、registry実データ更新は個別承認

# repo-create Level 2 dry-run接続

## 目的

repo-createが新規repoでLevel 1又はLevel 2を選べるようにし、Level 2ではarea、area内plans、plan所有outputsの差分をdry-runで示せるようにする。

## 非対象

- repo-createを別Skillへ分割しない。
- 既存repoへのapply、GitHub作成、登録、commit、pushを行わない。
- 既存のrepo-create移植キットの監査、fixture、scaffold実装を重複して作らない。

## 現状

activeの全repoへのAI運用標準移植programの子08が、audit-repo、inventory-legacy-plans、scaffold-repoのdry-run既定と安全契約を所有している。今回の子は成果物・areaの規約をその契約へ接続する役割だけを持つ。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private
- 実行形: integration
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. active/2026-07-13-全repoへのAI運用標準移植/plans/08-repo-create移植キット.md
  5. この子計画
- 依存成果: 01の正本規約、02の雛形規約、子08のdry-run契約
- 変更可能範囲: personal-os/AIエージェント基盤/skills/repo-create の既存workflow、references、scripts、testsのうち子08で許可された範囲
- 変更禁止範囲: repo-create外の新Skill、実repo、registryの実データ、runtime、hook、launchd、GitHub
- ファイル担当マップ: 子08の許可path manifestを最優先し、重複pathは子08の担当と統合担当が確認する
- worktree方針: task-scoped
- 維持する契約: dry-run既定、既存ファイル上書き0、移動0、削除0、commit0、push0、登録0
- 検証: 既存fixtureと新しいLevel 2 fixtureで、差分がarea入口、area内plans、plan所有outputsの規約を示し、applyなしで終了することを確認する
- 停止・エスカレーション条件: 子08と同じpathの同時変更が必要な場合、又はapplyが安全契約を破る場合
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. Level 1とLevel 2の選択は、repoの目的、継続性、areaの有無で明示する。PrivateはLevel 3のメタworkspaceであり、通常repo雛形として扱わない。
2. Level 2のdry-runはrootを入口、areaを判断単位、area内plansを計画正本とする。root plansとarea内plansを併存させない。
3. plan outputsは空フォルダとしてscaffoldせず、成果物が生まれた時に日付-用途名で作る規約だけを出力する。
4. 既存repoはdry-runとread-only診断で差分を示すだけにし、applyは対象repoごとの人間承認後に別sessionで行う。

## 完了条件

- [ ] Level 2のdry-runがarea、area内plans、outputs直下の日付付き命名の規約を明示し、空のoutputsを作らない。
- [ ] 子08のdry-run既定と危険操作0の契約を破らず、重複実装を作らない。

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
