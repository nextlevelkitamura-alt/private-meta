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

## git（この基盤は別repo）
- ここだけ独立した git repo（remote `nextlevelkitamura-alt/ai-agent-foundation`・branch `main`）。`~/Private` 本体（`private-meta`）とは別repo。
- 本体の `.gitignore` が `/personal-os/*` を無視するため、この基盤は本体からは**非追跡**（二重commitされない）。2repoの全体構成・追跡範囲・スマホ閲覧の一望正本は `git-registry/git-overview.md`。
- 1つの変更が2repoにまたがることがある。各repoで別々にcommitし、本文で相手repoの変更に触れて束ねる。
- commit前に確認: `main`直か作業branchか、`git add -A`を避けパス指定、secret混入、push可否（pushは明示依頼時のみ）。

## フォルダ（どこに何があるか。詳細は各 AGENTS.md）
- `skills/` … Global Skill 本体
- `global-skill-registry/` … Skill の索引・履歴・runtime露出・skill計画
- `loops-registry/` … loop 運用の一式（実行レーン・loop本体・共通参照・loop計画）
- `repo-registry/` … repo と repo-local Skill の履歴
- `hooks/` … runtime フック本体
- `git-registry/` … 全体git構成（2repo・追跡範囲・push・スマホ閲覧）の一望正本
