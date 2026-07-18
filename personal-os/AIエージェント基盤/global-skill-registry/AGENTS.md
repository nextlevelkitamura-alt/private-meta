# Global Skill Registry

このディレクトリは、Global Skillの索引、履歴、runtime露出補助を置く。

Global Skill本文の正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/<skill>/SKILL.md` に置く。このディレクトリにはSkill本文を置かない。

## 1. 役割

1. `catalog/`: Global Skillの現在索引（`meta.md` / `applied.md`）。
2. `logs/`: Global Skillの作成、移行、削除履歴。
3. `scripts/`: Global Skillのruntime露出などの補助script。
   - `link-global-skill.sh`: 正本から既定4窓へのdirect symlinkを作成。
   - `exposure-manifest.tsv`: 既定4窓と異なる露出にしたいskillだけを載せる例外リスト（`<skill>\t<窓キーのカンマ区切り>`）。載らないskillは既定4窓のまま。第2の正本にしない。
   - `check-exposure.sh`: 露出のdrift検出（後述）。
4. `plans/`: 卒業してきた skill 計画（`plans/<状態>/<YYYY-MM-DD-日本語企画名>/plan.md`。状態は6バケット。未生成は初回卒業で生やす）。

- 既定露出窓＝4つ（正本にしない・コピー同期しない。symlinkは各runtimeから正本へ直接。機械露出は `scripts/link-global-skill.sh`）:
  - `~/.agents/skills` … Codex（0.144.1は`~/.agents/skills`をネイティブに読む。実測2026-07-18: `codex debug prompt-input`）＋共通窓。`~/.agents/.skill-lock.json` の `lastSelectedAgents` の配布元でもある。
  - `~/.claude/skills` … Claude Code。**OpenCodeも`~/.agents/skills`ではなくこの窓と`~/.config/opencode`を読む**（実測2026-07-18・OpenCode 1.1.36。OpenCode CLI自体はskillコマンドを持たず `opencode agent` と `~/.config/opencode/agents/` のみ）。したがって `~/.agents/skills` は「全ハーネス共通ハブ」ではなく実質「Codex＋一部ハーネス」向けの窓であり、OpenCodeへは `~/.claude/skills` 経由で届く。
  - `~/.gemini/config/skills` … Gemini CLI。
  - `~/.gemini/antigravity-cli/skills` … Antigravity CLI。
- **`~/.codex/skills` はGlobal Skillの露出先にしない**（Codex 0.144.1は`~/.agents/skills`をネイティブに読むため不要・実測同上）。`~/.codex` はconfig.toml・hooks・rules・custom agents・auth・state専用。Codexは同名Skillを複数窓に置いても統合せず2件別々に注入するため、`.codex`と`.agents`の両ミラーは二重登録になる。
  - 例外: Codexのskill-creator/skill-installerが新規skillを`~/.codex/skills`（=`$CODEX_HOME/skills`）に自動生成することは容認する（Codex専用scratchとして扱う）。正本化したい時は人間が手動で`skills/`へ移送する。`scripts/check-exposure.sh`が`.agents`との同名重複や自動生成物を警告する。
- 選択露出は `scripts/exposure-manifest.tsv` に例外だけ列挙する（既定4窓と異なる露出にしたいskillのみ）。例: kickoff/morning-routine/sns-postは`claude`限定。
- drift-check: `scripts/check-exposure.sh` が「`.codex/skills`への二重登録」「露出欠落」「broken link」「Codex自動生成物」を検出する。
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
