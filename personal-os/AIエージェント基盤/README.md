# AIエージェント基盤

Codex、Claude Code、AGENTS.md対応CLI、Antigravityなどをまたいで使うAI Skillと運用ルールの正本repo。
Global Skill正本、Global Skill registry、repo registry、runtime露出を分けて管理する。計画書は `personal-os/my-brain/areas/ai運用/plans/` に置く。

このREADMEは人間向けの概要。エージェント向けの運用ルールは `AGENTS.md` を正本にする。

## 最小構成

```text
AIエージェント基盤/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  README.md
  skills/
  global-skill-registry/
    AGENTS.md
    CLAUDE.md -> AGENTS.md
    catalog/
      AGENTS.md
      CLAUDE.md -> AGENTS.md
      meta.md
      applied.md
    logs/
      AGENTS.md
      CLAUDE.md -> AGENTS.md
      created/YYYY-MM/<skill>.md
      migrated/YYYY-MM/<skill>.md
      deleted/YYYY-MM/<skill>.md
    scripts/
  repo-registry/
    AGENTS.md
    CLAUDE.md -> AGENTS.md
    logs/

personal-os/
  my-brain/
    areas/
      AGENTS.md
      ai運用/
        AGENTS.md
        plans/active/<YYYY-MM-short-name>/plan.md   # 状態はバケット(active/paused/done/archive)
```

## 考え方

```text
正本:
  AIエージェント基盤/skills/<skill>

露出先:
  ~/.agents/skills/<skill>
  ~/.codex/skills/<skill>
  ~/.claude/skills/<skill>
  ~/.gemini/config/skills/<skill>
  ~/.gemini/antigravity-cli/skills/<skill>
```

グローバルSkillはこのrepoで管理し、各AI runtimeにはsymlinkで展開する。仕事repoなど特定repoに密結合したSkillは、そのrepo内に残す。
`global-skill-registry/catalog/` はGlobal Skillの索引で、正本ではない。
中〜大規模なGlobal Skill作成・改善、repo改善、loop作成・改善の新規計画は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/<YYYY-MM-short-name>/plan.md` に置く。
repo-local Skillの現在導線は所有repo側に置く。`repo-registry/` には履歴だけを置き、各repo固有の詳細計画は所有repo内の `plans/` を優先する。

## どこを見るか

- 現在の正本: `skills/`
- Global Skill索引: `global-skill-registry/catalog/`
- 計画書: `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/<YYYY-MM-short-name>/plan.md`
- Global Skill作成・移行履歴: `global-skill-registry/logs/`
- repo / repo-local Skill履歴: `repo-registry/logs/`
- AI向け運用ルール: `AGENTS.md`
- runtime露出: `global-skill-registry/scripts/link-global-skill.sh` と `readlink`

`CLAUDE.md` は `AGENTS.md` へのsymlinkなので、エージェント向けルールは自動で同期される。
下位registryの `CLAUDE.md` も同階層 `AGENTS.md` へのsymlink。repo-local Skillの本体と現在導線は各repoに残し、`repo-registry/` には履歴だけ残す。

## scripts

```sh
global-skill-registry/scripts/link-global-skill.sh <skill-name>
```

`skills/<skill-name>` を正本として、Codex / Claude Code / agents / Antigravity系のglobal Skill入口へdirect symlinkを作る。
既存の実ディレクトリは置き換えない。

詳細な禁止事項や停止条件は `AGENTS.md` に集約する。
