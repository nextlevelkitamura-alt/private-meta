# Codex custom agent

Codex 内で spawn する custom agent を作るための reference。`SKILL.md` の読み分けで Codex が対象のとき読む。

注意: Codex の custom agent 機能・キー名・enum 値はバージョンで差異がありうる。キーと値は実装時に Codex 公式ドキュメントで確認する。

## 目次

1. custom agent とは / 2. 保存先 / 3. 基本構造・必須項目 / 4. 主な設定項目 / 5. sandbox_mode / 6. approval_policy / 7. 推奨 agent / 8. テンプレート

## 1. custom agent とは

Codex 内で spawn する専門エージェント。Claude Code subagent と違い、Markdown ではなく TOML で定義する。

向く用途: read-only レビュー / コードベース探索 / テスト失敗調査 / 小さな修正 worker / セキュリティレビュー / 並列調査。

## 2. 保存先

1. 個人共通: `~/.codex/agents/<agent-name>.toml`
2. プロジェクト専用: `.codex/agents/<agent-name>.toml`

## 3. 基本構造・必須項目

```toml
name = "reviewer"
description = "変更差分の正しさ、セキュリティ、回帰、テスト不足を確認するPRレビュー担当。"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
あなたは厳格なコードレビュー担当です。
ファイルは編集しないでください。
"""
```

必須扱い: `name` / `description` / `developer_instructions`。

## 4. 主な設定項目

1. `name`: agent 名。
2. `description`: 何をする agent か。
3. `developer_instructions`: agent への主要指示。
4. `nickname_candidates`: 表示名候補。
5. `model` / `model_reasoning_effort`: 使用モデル / 推論強度。
6. `sandbox_mode`: sandbox 設定（§5）。
7. `approval_policy`: 承認方針（§6）。
8. `mcp_servers`: MCP 設定。
9. `skills.config`: Skill 設定。

## 5. sandbox_mode

1. `read-only`: 調査・レビュー。
2. `workspace-write`: 実装修正。
3. `danger-full-access`: 原則使わない。

方針: reviewer / explorer / security auditor は `read-only`。fix worker は `workspace-write`。global agent で `danger-full-access` は禁止。

## 6. approval_policy

承認方針。値はバージョンで異なるため公式で確認する。reviewer は承認を要さない read-only 構成に寄せる。

## 7. 推奨 agent

1. `reviewer`: 差分レビュー。基本 `read-only`。
2. `pr_explorer`: 実装前の調査。編集しない。
3. `fix_worker`: レビュー後の小さな修正。`workspace-write`。
4. `security_reviewer`: セキュリティ観点のレビュー。基本 `read-only`。

## 8. テンプレート: reviewer

```toml
name = "reviewer"
description = "変更差分の正しさ、セキュリティ、回帰、テスト不足を確認するPRレビュー担当。review、security、regression、missing testsが必要なときに使う。"
model_reasoning_effort = "high"
sandbox_mode = "read-only"
developer_instructions = """
あなたは厳格なコードレビュー担当です。
ファイルは編集しないでください。
現在の差分と関連ファイルを確認してください。
重点的に確認すること:
- 正しさ / 回帰バグ / セキュリティリスク / テスト不足 / 仕様とのズレ
出力形式:
1. Verdict: APPROVED / WARNING / BLOCKED
2. 重要な指摘
3. 必須修正
4. 実行すべきテスト
"""
```
