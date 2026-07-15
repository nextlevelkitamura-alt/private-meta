出所評価: 04-PromptSubmitとhookガード-評価01.md ／ ラウンド: 01 ／ 宛先: 子04実装担当（codex・task/pf04）

# 修正01: Prompt Submitとhookガード

※ 修正はすべてworktree（task/pf04）内で行い、パス指定でcommitする。runtime登録・注入文の有効化は引き続き禁止。

## 前提（計画側で解決済み・実装変更不要の項目）

評価01のFAIL「初回・ミラー注入の更新」「plan-management案内」は、実行契約（未有効化）と完了条件の矛盾が原因。指揮官が完了条件を「**候補文＋テスト＋登録差分までが完走ライン**（有効化は人間承認後の適用ラウンド）」へ明確化した。あなたの対応は、既存の候補文テストがこの文言（責務分離・容量・レビュー方式・bucketctl check誘導・plan-management案内・hook非所有）を網羅しているかの確認と、不足分のテスト追記だけでよい。

## 修正項目

### 1. PreToolガードの回避可能性

- 対象: `hooks-registry/events/pre-tool-use/guard-plan-bucket-move.py` とfixture
- 今の状態: `git -C /tmp mv plans/active/a plans/done/a`（オプション付きgit）と `echo bucketctl; mv plans/active/a plans/done/a`（"bucketctl"文字列を含む連結コマンド）がdenyされず通る。
- 期待する状態: 計画バケット（planning/active/paused/done/archive）への生 `mv`／`git mv` を、グローバルオプション付きgit（`-C`・`-c` 等）やシェル連結（`;`・`&&`・`|`）を含めてdenyし、`bucketctl` 自身の実行と計画バケット外の通常コマンドは通す。
- 修正方法: 「bucketctlという文字列を含むか」ではなく、コマンドを保守的に解析する判定へ改める（連結の各セグメントを個別判定・gitのグローバルオプションをスキップしてサブコマンドを特定）。評価01の2つの実測ケースをClaude/Codex両方のstdin fixtureへ追加する。
- やらないこと: runtime登録・settings変更・symlink変更。過剰な万能パーサ化（保守的=疑わしきはdeny側で構わないが、bucketctl実行と無関係コマンドの誤denyはfixtureで防ぐ）。

### 2. manifest読取のschema整合（fail-open）

- 対象: `hooks-registry/shared/plan-closeout/common.py` の manifest検証
- 今の状態: schema違反（不正な `task_id` pattern・`program_path` が数値・`child_id` が配列）のmanifestを受理し、`review_passed` ならStopをblockし得る。
- 期待する状態: `agents-registry/harness/schemas/run-manifest.schema.json` に反する型・pattern・enum・追加属性のmanifestは**すべてfail-open**（何も出力せず通す）。
- 修正方法: schemaに忠実な検証（最低限: 必須キー・型・task_id pattern・phase enum・追加属性拒否）を実装し、不正task_id／program_path型違反／child_id型違反／追加属性の4 fixtureを追加する。
- やらないこと: manifest・result・計画本文の自動修正。schema自体の変更（03所有）。

### 3. Subagent検査とfail-openの契約テスト不足

- 対象: `hooks-registry/events/subagent/verify-plan-worker.py`・`shared/plan-closeout/` のテスト
- 今の状態: 割当ずれfixtureが非Git一時ディレクトリで、worktree_path・base_commitの警告しか実証していない。branch不一致の検証が無い。不変性確認がplan/resultのみ。壊れたJSON・内部例外時のfail-open契約テストが無い。
- 期待する状態: 一時Git repo＋worktreeを使うfixtureで worktree_path／branch／base_commit の各不一致を個別に検証。ガード実行前後で manifest・計画本文・チェックボックス・バケット・worktree が不変であることを比較テスト。壊れたJSON・schema不正・内部例外がstdoutなしで通る（fail-open）契約fixtureをClaude/Codex両stdinで追加。
- 修正方法: fixture整備とテスト追加が主。実装は必要最小限の修正のみ。
- やらないこと: SubagentStartをblockする実装への変更（照合warn-onlyのまま）。worktreeの作成・削除・merge。

### 4. （軽微）pre-tool-use/AGENTS.md の説明と実体の不一致

- 対象: `hooks-registry/events/pre-tool-use/AGENTS.md`
- 今の状態: 「判定は `shared/plan-closeout/` に置く」とあるが、PreTool判定は `guard-plan-bucket-move.py` 内にある。
- 期待する状態: 説明が実体と一致している（判定の置き場を実装どおりに記述）。
- やらないこと: 実装側の移動（現配置を正とする）。

## 完了時

- 全テスト再実行（plan-closeout・session-board 4本＋今回追加fixture）で全緑を確認し、論理単位でcommit（パス指定・日本語メッセージ）。
- 最終メッセージに「## 実装結果」（状態／最終commit／変更ファイル／テスト結果／登録未適用の確認）を返す。
