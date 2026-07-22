---
name: custom-agent-creator
description: Claude Code の subagent、Codex の custom agent、OpenCode の primary/subagent など、AIコーディング環境のカスタムエージェント定義ファイルを作成・整理・レビューする。permission/sandbox/approval、inline MCP、hooks、model routing、reviewer/quality-gate の設計を扱う。「subagentを作りたい」「custom agentを作りたい」「エージェント定義」「permission設計」「codex-reviewerを作りたい」等で使う。Skillそのものの新規作成・改善は skill-creator-custom / skill-creator-codex を使いこれには使わない。エージェントの運用・指揮は cockpit-supervisor、作業の入口判断は plan-registry（経路解決＝triage決定手続き）を使う。
metadata:
  short-description: カスタムエージェント定義の作成・整理
---

# Custom Agent Creator

Claude Code / Codex / OpenCode 向けのカスタムエージェント定義を、目的・権限・モデル・保存先・呼び出し方に応じて設計・整理・レビューする支援 Skill。このSkill自体はエージェントではなく、定義ファイルを作るための作成支援である。

## 1. 対象

1. Claude Code subagent（`.claude/agents/*.md` / `~/.claude/agents/*.md`）
2. Codex custom agent（`.codex/agents/*.toml` / `~/.codex/agents/*.toml`）
3. OpenCode primary agent / subagent（`.opencode/agents/*.md` / `~/.config/opencode/agents/*.md`）
4. permission / sandbox / approval、inline MCP、hooks、model routing、reviewer / evaluator / quality-gate の設計

## 2. 手順

1. 対象ツールを判定する（Claude Code / Codex / OpenCode / 横断）。
2. 対象ツールの reference だけを読む（§3）。不要なツールの reference は読まない。
3. global 用か project 用かを決め、保存先・権限方針・モデルを設計する。
4. 定義ファイルの内容を書く。
5. `references/checklist.md` で安全確認する。
6. 出力する（§5）。

## 3. 読み分け

1. Claude Code の話 → `references/claude-code.md`
2. Codex の話 → `references/codex.md`
3. OpenCode の話 → `references/opencode.md`
4. reviewer / evaluator / quality-gate を作るとき → `references/quality-gate.md`（対象ツールの reference と併読）
5. 最後に必ず → `references/checklist.md`
6. 複数ツール比較・横断設計のときだけ複数を読む。

## 4. 言語ルール

1. 自然言語の説明・指示・本文は日本語で書く。
2. 次は公式値・英語 ASCII のままにする: ファイル名 / agent 名 / Skill 名 / YAML・TOML・JSON のキー / enum 値 / model ID / tool 名 / command / permission 値。

## 5. 出力ルール

カスタムエージェントを作るときは次を順に出す。

1. 作る目的
2. 対象ツール
3. 保存先パス
4. 設定方針
5. 実際のファイル内容
6. 注意点
7. `checklist.md` の確認結果

## 6. 安全方針

1. 副作用: 定義ファイルの作成・編集のみ。エージェントの実行はしない。
2. reviewer / evaluator / quality-gate は原則 read-only にする（Claude=編集ツールを渡さない、Codex=`sandbox_mode: read-only`、OpenCode=`edit: deny`）。
3. 禁止: secret / token を定義に書く。`bypassPermissions` / `danger-full-access` / `--auto` 前提や destructive command の無条件許可。
4. 保存先の global / project を明示してから書く。
5. model ID・各ツールのキー名はバージョンで変わりうる。断定せず、実装時に公式値を確認する（特に OpenCode Go の model ID）。
