# AIエージェント基盤

AI が動くための「グローバル/基盤レイヤの正本」を置く場所。
global に使うもの（Skill・loop・hook）は、実体をここに登録し正本を管理する。
特定 repo 専用のものは `projects/<repo>/`（repo-local）に置く。

## 配下すべてが守ること
- 絶対ルール（危険操作=人間承認／secret禁止／単一正本・二重管理禁止／push は明示依頼時）は personal-os の `AGENTS.md`（`../AGENTS.md`）に従う。
- フォルダ固有の機能・構成は、そのフォルダの `AGENTS.md` に書く。この入口には書かない。
- Global か repo-local か：複数 repo/runtime で使うメタ的なもの（planning・review・orchestration・Skill運用・loop・hook）→ ここに登録。特定 repo 依存 → `projects/<repo>/`、ここには履歴だけ。迷ったら repo-local。

## 新しく足すときの手順
- フォルダ/内容を足したら：
  1. 下の「フォルダ」一覧に1行足す
  2. そのフォルダに `AGENTS.md`（＋`CLAUDE.md`→`AGENTS.md` の相対symlink）を置き、固有の構成・機能はそこに書く

## 正本ファイル
- `GLOBAL_AGENTS.md` … Claude / Codex / OpenCode など、各runtimeが毎回読むグローバル指示の正本。runtime側のファイルは正本にせず、このファイルへの symlink として露出する。
  - `~/.claude/CLAUDE.md`
  - `~/.codex/AGENTS.md`
  - `~/.config/opencode/AGENTS.md`
- `AIモデル一覧.md` … 契約サブスクと用途別モデル使い分けの正本（2026-07-08新設・決定ログ#11のレーン規約を集約）。各計画・Skill・フローは本文をコピーせずここを参照する。

## git（`~/Private` 単一repoに統合済み）
- この基盤は 2026-07-05 に `~/Private`（`private-meta`・remote `nextlevelkitamura-alt/private-meta`・branch `main`）へ**統合済み**。もう別repoではない（旧 `ai-agent-foundation` はGitHub archiveに履歴が残る・参照専用）。
- commit前に確認: `main`直か作業branchか、`git add -A`を避けパス指定、secret混入、push可否（pushは明示依頼時のみ）。
- git構成（1repo・`.gitignore`方針・push先・スマホ閲覧）の一望正本は `git-registry/git-overview.md`。

## フォルダ（どこに何があるか。詳細は各 AGENTS.md）
- `skills/` … Global Skill 本体
- `global-skill-registry/` … Skill の索引・履歴・runtime露出・skill計画
- `loops-registry/` … loop 運用の一式（実行レーン・loop本体・共通参照・loop計画）
- `repo-registry/` … repo と repo-local Skill の履歴
- `hooks-registry/` … runtime フック本体（機構共有 `hooks/`＋runtime受け口 `claude/`・`codex/`）
- `agents-registry/` … Claude カスタムエージェント・コマンドの正本（runtime `~/.claude/agents|commands/` へ symlink 露出。2026-07-11新設）
- `git-registry/` … 全体git構成（2repo・追跡範囲・push・スマホ閲覧）の一望正本
