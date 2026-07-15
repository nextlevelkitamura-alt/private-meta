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

1. 作成・露出の直前に `codex --version` と公式「Subagents」を確認したか。個人用は `~/.codex/agents/*.toml`、project用は `.codex/agents/*.toml` であることを対象versionで確認する。
2. custom agent TOMLには `name`、`description`、`developer_instructions` があり、nameとファイル名の対応が明確か。プロンプトを作る場合はfrontmatter `description` と `$ARGUMENTS` があるか。プロファイルのキーはconfig.tomlと同じ公式キーか。
3. sandboxは適切か（reviewer / explorerは `read-only`。implementerはTask Packetとworktree分離がある時だけ `workspace-write`。execのread-only委任は `-s read-only`）。
4. `danger-full-access` と固定モデルIDを新たに指定していないか。
5. Claudeからの委任は共通delegateを経由し、Task Packet・run manifest・result packetを使うか。delegate未導入の互換経路だけ `codex exec --json`＋`exec resume` を使い、inline MCPを長時間委任に使っていないか。
6. Codexに渡す評価基準・制約はTask Packetまたは依頼文で自己完結しているか（Claude側と文脈非共有のため）。

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
