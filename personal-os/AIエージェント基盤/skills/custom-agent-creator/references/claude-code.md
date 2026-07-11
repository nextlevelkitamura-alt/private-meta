# Claude Code subagent

Claude Code の subagent（専門エージェント）を作るための reference。`SKILL.md` の読み分けで Claude Code が対象のとき読む。frontmatter 仕様は Claude Code v2.1.200+ 公式ドキュメント準拠。

## 目次

1. subagent とは / 2. 保存先 / 3. 基本構造 / 4. frontmatter の主な項目 / 5. permissionMode / 6. model / 7. inline MCP / 8. hooks / 9. Plugin 配布時の制限 / 10. 推奨 agent / 11. テンプレート

## 1. subagent とは

Claude Code 内で使う専門エージェント。Markdown ファイルの先頭に YAML frontmatter を書き、その下に自然言語の指示を書く。

Skill との違い: Skill は「手順・知識・判断基準」をコンテキストへ載せる。subagent は「独立した文脈・権限・モデルで動く実行主体」。

向く用途: 設計 / 調査 / レビュー / quality gate / hooks 連携 / inline MCP 連携 / Codex への外部レビュー依頼 / 実装前後の安全確認。

## 2. 保存先

1. 個人共通: `~/.claude/agents/<agent-name>.md`
2. プロジェクト専用: `.claude/agents/<agent-name>.md`

global に置くもの: 汎用 reviewer / quality-gate / codex-reviewer / codex-consult / hook-designer。
project に置くもの: repo 固有の DB ルール / テストコマンド / デプロイ手順 / ディレクトリ構成 / 禁止操作。

## 3. 基本構造

```markdown
---
name: quality-gate
description: 変更差分をレビューし、要件・品質基準を満たしているか判定する。
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: plan
---
あなたは品質ゲート担当です。
ファイルは編集しないでください。
```

## 4. frontmatter の主な項目

公式サポート項目（Claude Code v2.1.200+ で確認）。

1. `name`（必須）: agent 名。英語 ASCII 推奨。
2. `description`（必須）: 何をする agent か。日本語可。
3. `tools`: 使用可能ツール（カンマ区切り）。省略時は全ツール継承。
4. `disallowedTools`: 使用禁止ツール。
5. `model`: 使用モデル（§6）。
6. `permissionMode`: 権限モード（§5）。
7. `maxTurns`: 最大ターン数。
8. `skills`: 起動時にプリロードする Skill。
9. `mcpServers`: inline MCP（§7）。
10. `hooks`: agent 内 hooks（§8）。
11. `background`: background 実行（true/false）。
12. `isolation`: worktree 隔離など。
13. `memory` / `effort` / `initialPrompt` / `color`: メモリ / 推論強度 / 初期プロンプト / 表示色。

## 5. permissionMode

指定できる値: `default` / `plan` / `acceptEdits` / `dontAsk` / `auto` / `bypassPermissions`。

1. `plan`: 読み取り専用の探索。調査・設計・レビュー向き。
2. `default`: 標準の権限チェック＋プロンプト。
3. `acceptEdits`: 編集を自動承認。実装 agent 向き。
4. `dontAsk`: プロンプトを自動拒否（明示的に許可したツールのみ動く）。厳格な reviewer 向き。
5. `bypassPermissions`: プロンプトをスキップ（危険・原則使わない）。

方針: reviewer / evaluator / quality-gate は `plan`。実装 agent は `acceptEdits` も候補。global agent で `bypassPermissions` は使わない。

## 6. model

エイリアス: `sonnet` / `opus` / `haiku` / `fable` / `inherit`（親と同じ）/ `opusplan` など。フル model ID（例 `claude-opus-4-8`）も指定可。
方針: 最強モデルを常用しない。reviewer は用途に足りる範囲で選ぶ。値は変わりうるので最新は公式で確認する。

## 7. inline MCP

subagent が起動している間だけ MCP を接続する仕組み。`mcpServers` に list で書く。

```yaml
mcpServers:
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
  - github   # 既存サーバー名だけ書くと親セッションの接続を再利用
```

型: `stdio` / `http` / `sse` / `ws`。短い応答の外部ツールを subagent 起動中だけ使う用途に向く。
注意: 長時間作業に使わない。1回のMCPツール呼び出しはClaude Code側の実質10分タイムアウト（progress通知での延長仕様なし）に支配され、深い調査・実装ほど途中で切れる。`codex mcp-server` の threadId はサーバープロセス内のみ有効で、subagent終了とともに消える（2026-07-10実機確認）。**Codexへの委任（実装・相談とも）は Bash 経由の `codex exec --json`＋`codex exec resume`（文脈ディスク永続）を使う**（詳細は `codex.md` §7）。Codex 側と Claude 側は文脈を自動共有しないので、差分・基準・結果はファイル化して渡す。

## 8. hooks

subagent 定義の frontmatter に hooks を書ける。

```yaml
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/validate-readonly-query.sh"
```

対応イベント: `PreToolUse` / `PostToolUse` / `Stop`（自動的に `SubagentStop` に変換）。

## 9. Plugin 配布時の制限

subagent を plugin として配布すると、`hooks` / `mcpServers` / `permissionMode` は無視される。これらが必要なら `.claude/agents/` または `~/.claude/agents/` に置いて独立させる。

## 10. 推奨 agent

1. `quality-gate`: reviewer と evaluator を統合。普段は分けない（分けると時間が伸びやすい）。
2. Codexへの実装委任は **agentにしない**（旧 `codex-implementer` は2026-07-11廃止）。既定はメインエージェントが `/codex-impl`（`~/.claude/commands/codex-impl.md`）の手順で直接 `codex exec --json` を駆動し、thread_id捕捉→`exec resume`で継続、git diffを自分で検証する。agentで包むのは独立2本以上の並列時だけ（general-purposeに手順ごと委任）。詳細は `codex.md` §7。
3. `codex-reviewer`: `codex exec -s read-only` を Bash 経由で呼び、Codex のレビュー結果をファイルに保存。
4. `codex-consult`: `codex exec --json -s read-only`＋`exec resume` で Codex に継続相談（旧 inline MCP 方式は10分タイムアウトとスレッド非永続のため2026-07-10に廃止）。実例 `~/.claude/agents/codex-consult.md`。
5. `hook-designer`: Stop / SubagentStop / Notification / PreToolUse hooks を設計。

## 11. テンプレート: quality-gate

```markdown
---
name: quality-gate
description: 変更差分をレビューし、要件・品質基準・Definition of Doneを満たしているか判定する。review、evaluator、quality gateが必要なときに使う。
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: plan
---
あなたはreviewerとevaluatorを統合した品質ゲート担当です。
ファイルは編集しないでください。
確認すること:
- 正しさ / 回帰バグ / セキュリティ / テスト不足 / 要件適合 / Definition of Doneへの適合
出力形式:
1. Verdict: APPROVED / WARNING / BLOCKED
2. 重要な指摘
3. 必須修正
4. 実行すべきテスト
5. 外部レビューが必要か
```
