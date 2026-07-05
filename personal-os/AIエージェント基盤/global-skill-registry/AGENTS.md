# Global Skill Registry

このディレクトリは、Global Skillの索引、履歴、runtime露出補助を置く。

Global Skill本文の正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/<skill>/SKILL.md` に置く。このディレクトリにはSkill本文を置かない。

## 1. 役割

1. `catalog/`: Global Skillの現在索引（`meta.md` / `applied.md`）。
2. `logs/`: Global Skillの作成、移行、削除履歴。
3. `scripts/`: Global Skillのruntime露出などの補助script（各runtimeの `skills/` へ正本から direct symlink）。
4. `plans/`: 卒業してきた skill 計画（`plans/<状態>/<YYYY-MM-DD-日本語企画名>/plan.md`。状態は6バケット。未生成は初回卒業で生やす）。

- runtime露出先: `~/.agents/skills`・`~/.codex/skills`・`~/.claude/skills`・`~/.gemini/config/skills`・`~/.gemini/antigravity-cli/skills`。露出先は正本にしない・コピー同期しない（symlinkは各runtimeから正本へ直接）。
- Global Skillの新規作成・既存改善・統合整理の計画（育成中）は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/` を見る。

## 2. 境界

1. repo-local Skill本文は各repo内を正本にする。
2. repo-local Skillの導線と履歴は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/` を見る。
3. 計画書は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/` を見る。
4. Global Skill本文、catalog、logs、plansに同じ情報を重複して書かない。
5. runtime露出先は正本ではない。

## 3. 作業前ルーティング

1. `catalog/` を触る前に `catalog/AGENTS.md` を読む。
2. `logs/` を触る前に `logs/AGENTS.md` を読む。
3. 計画書を触る前に `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/AGENTS.md` と `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/AGENTS.md` を読む。
4. `scripts/` を触る場合は、対象scriptの内容を読んでから実行する。

## 4. 完了条件

1. Global Skill本文正本は `skills/` にある。
2. catalog、logs、Personal OS plansの更新要否を説明できる。
3. repo-local Skill情報をこのregistryに混ぜていない。
4. `CLAUDE.md -> AGENTS.md` のsymlinkが維持されている。
