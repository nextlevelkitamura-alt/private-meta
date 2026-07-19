# agents-registry

Claude / Codex のカスタムエージェント、役割定義、委譲harness、Claudeコマンドの正本を置く場所。runtime側は露出先（symlinkまたはruntimeの登録）であり、正本にしない（GLOBAL_AGENTS の露出原則に従う。2026-07-11新設）。

## 構成

- `roles/` … runtime共通の役割本文の正本（explorer / implementer / evaluator）。固定作業場所・branch・モデル・Program背景を置かない
- `claude/commands/` … Claudeコマンド正本（`/名前` で発動する手順書。本文はメインの文脈に注入される）
- `claude/agents/` … Claude形式の薄い役割写像と互換エージェント（frontmatterのdescriptionで発動判断される別文脈のサブエージェント）
- `codex/agents/` … Codex形式の薄い役割写像（runtime露出時は `.codex/agents/*.toml` として登録する）
- `harness/` … runtime中立のdelegate・program-run・manifest・worktree・adapter・schema。実行時stateはgit管理しない

露出は `~/.claude/commands/<名前>.md` / `~/.claude/agents/<名前>.md` からの symlink。本文コピーは禁止。

## 登録一覧

- `roles/{explorer,implementer,evaluator}.md` … 3役割の本文正本。Claude/Codexの写像はここを参照し、本文を複製しない。2026-07-19。
- `claude/agents/{explorer,implementer,evaluator}.md` … Claude形式の役割写像。2026-07-19。
- `codex/agents/{explorer,implementer,evaluator}.toml` … Codex形式の役割写像。2026-07-19。
- `claude/commands/codex-impl.md` … Codex実装委任の旧互換入口。新規計画の実行導線では使わない。
- `claude/agents/impl-opus.md` … implementer役割のClaude実装（Opus固定・計画駆動・人間ゲートは準備止まり。指揮官の実装委任の既定エージェント）。2026-07-19。
- `claude/agents/impl-evaluator.md` … Claude用の評価担当。`/codex-impl` の実装後評価でも使う。2026-07-19。
- `claude/agents/codex-consult.md` … Codex相談役（exec直接駆動・read-only固定）。2026-07-10。
- `harness/` … Task Packetを起点にruntime・role・plan path・base SHAを受ける共通delegate。2026-07-15。

## 追加・変更の手順

1. 正本をここに作成・編集する（設計知見は `../skills/custom-agent-creator/references/` を参照）。
2. runtimeへの露出は承認後に行う。Claudeは `~/.claude/{commands|agents}/`、Codexは `~/.codex/agents/*.toml` またはproject `.codex/agents/*.toml` の現行仕様に従う。本文コピーは禁止。
3. この AGENTS.md の登録一覧に1行追記する。
4. 削除は skill-delete と同様に人間承認＋一覧から除去＋symlink撤去をセットで行う。

## 置かないもの

- 他ツール由来の野良コマンド（`~/.claude/commands/` に残る旧実体ファイル群は legacy。移す時は1件ずつ人間確認）。
- Skill本文（`../skills/` が正本）・hook（`../hooks-registry/`）・secret。
