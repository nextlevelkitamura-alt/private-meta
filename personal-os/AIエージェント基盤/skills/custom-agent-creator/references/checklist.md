# チェックリスト

カスタムエージェント定義を作ったら、最後にこのリストで安全確認する。対象ツールの節と共通・最終出力を確認する。

## 共通

1. 対象ツールは明確か。
2. global 用か project 用か明確か。
3. 保存先パスは正しいか。
4. agent 名は英語 ASCII か。
5. description は具体的か。
6. 自然言語部分は日本語で書かれているか。
7. 設定キー・enum・model ID は公式値のままか。
8. secret / token を書いていないか。
9. destructive command を無条件許可していないか。
10. reviewer に編集権限を持たせていないか。

## Claude Code

1. `.claude/agents/` または `~/.claude/agents/` 向けか。
2. `name` と `description` があるか。
3. `permissionMode` は適切か（reviewer は `plan`）。
4. `bypassPermissions` を安易に使っていないか。
5. inline MCP が必要な理由は明確か。
6. hooks を入れる場合、発火タイミングは明確か。
7. plugin 配布なら `hooks` / `mcpServers` / `permissionMode` が無視される点を確認したか。

## Codex

1. TOML 形式か。
2. `name` / `description` / `developer_instructions` があるか。
3. `sandbox_mode` は適切か（reviewer は `read-only`）。
4. `danger-full-access` を使っていないか。
5. Codex に渡す評価基準は曖昧でないか。

## OpenCode

1. Markdown agent または JSON 設定として正しいか。
2. `mode` は `primary` / `subagent` のどちらか明確か。
3. OpenCode Go を使う場合、`model` が明示されているか（model ID は実装時に確認したか）。
4. `permission` は `allow` / `ask` / `deny` で書かれているか。
5. reviewer は `edit: deny` か。
6. 危険な bash command を deny しているか。

## 最終出力

1. 目的が説明されているか。
2. 保存先パスが提示されているか。
3. 実際のファイル内容が出ているか。
4. 注意点が書かれているか。
5. チェックリスト結果が出ているか。
