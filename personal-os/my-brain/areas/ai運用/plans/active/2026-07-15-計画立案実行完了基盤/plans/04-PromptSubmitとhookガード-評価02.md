対象計画: 04-PromptSubmitとhookガード.md ／ ラウンド: 02  
diff範囲: e9a6e16..81772b2 ／ 評価者: read-only reviewer

# 評価02: Prompt Submitとhookガード

## 修正01の項目別対応確認

- [PASS] PreToolガード回避  
  `shlex`で連結コマンドを分割し、`git`のグローバルオプションを飛ばして`mv`を判定する実装へ修正済み。Claude/Codex fixtureに追加されている。実測でも `git -C /tmp mv plans/active/a plans/done/a` と `echo bucketctl; mv plans/active/a plans/done/a` はともにdenyされた。

- [PASS] manifest schema違反のfail-open  
  run-manifest schemaに合わせ、必須キー・型・`task_id` pattern・phase/role/runtime enum・追加属性・`allowed_paths`を検証する。実測で不正`task_id`、数値`program_path`、配列`child_id`、追加属性はいずれも終了コード0・stdout空だった。

- [PASS] Subagent検査・fail-openテスト  
  一時Git repo＋worktreeで、`worktree_path`／branch／`base_commit`の不一致を個別検証している。manifest・計画・バケットを含むworktree内容とGit statusの不変性も確認している。壊れたJSON、schema違反、内部例外はClaude/Codexでfail-open fixtureがある。

- [PASS] PreToolUse説明の整合  
  `events/pre-tool-use/AGENTS.md`を修正し、判定の実体が`guard-plan-bucket-move.py`であることと一致した。

## 完了条件の再採点

- [PASS] 初回・ミラー注入候補  
  `common.py`の候補文に状態遷移、容量、`bucketctl check`、一括/都度レビュー、archiveの人間承認を含む。明確化後の完走ラインどおり、候補文は未有効化であり、テストと登録差分が揃う。

- [PASS] plan-management最小ゲートとhook非所有境界  
  候補文は「全YESでない、または不明なら plan-management」とし、repo・計画箱・レビュー合否・バケット遷移をhookが決めないことを明示。候補文テストもある。

- [PASS] PreToolガード  
  生の`mv`／`git mv`による計画バケット移動をdenyし、`bucketctl`とバケット外移動は通す。要求されたオプション付きgit・連結コマンドの2ケースも実測deny済み。

- [PASS] Stopガード  
  manifest不在、running、implemented、review_passed未同期、synced、blockedをテスト。継続要求はreview_passed未同期だけで、implementedの一括レビュー待ちは通す。

- [PASS] SubagentStart/Stopと不変性  
  implementerの割当不一致をwarn-onlyで検知し、read-only roleは照合を省略する。implementerのresult欠落・reviewerの評価欠落はblockし、Claude/Codex stdin fixture、不変性テストがある。

- [PASS] 無限ループ防止・fail-open・既存Stop共存  
  `stop_hook_active`で再blockしない。壊れたmanifest JSON・schema違反・内部例外はfail-open。既存`mark-wait.py`との共存テストがあり、旧`hooks-registry/hooks/`構造も存在しない。

- [PASS] `finish`≠archive承認・session-board境界  
  `common.py`候補文、session-start/session-end説明、`mark-wait.md`、session-board終了手順で一貫している。README/milestoneの対象実体はなく、session-boardの状態所有も変更していない。

- [PASS] runtime未適用と承認セット  
  `codex/hooks.json`は差分なし。settings、symlink、trust、候補文の`register_prompt()`への接続はいずれも未適用。`registration-diff-04-plan-closeout.md`にClaude/Codex登録案、既存イベントE2E、Codex再trustを含む適用手順がある。

## テスト再実行

- `test_plan_closeout.py`: PASS=62 / FAIL=0
- `test_common.py`: PASS=13 / FAIL=0
- `test_events.py`: PASS=43 / FAIL=0
- `test_builders.py`: PASS=14 / FAIL=0

合計: PASS=132 / FAIL=0。`git diff --check e9a6e16..81772b2`も成功。

## 総合判定

**全PASS**