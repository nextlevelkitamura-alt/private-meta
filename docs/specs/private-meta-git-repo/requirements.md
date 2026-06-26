# Private Meta Git Repository

## Status

approved

## Problem

`/Users/kitamuranaohiro/Private` contains workspace-level governance files and global skill bridges, but the directory itself is not a Git repository. Orca therefore cannot provide branch and worktree workflows for meta work such as AGENTS/CLAUDE routing, requirements governance, and global skill placement.

Running that meta work from unrelated project repositories creates scope drift: histories, branch names, agent instructions, and worktrees inherit the wrong project context.

## Requirement

`/Users/kitamuranaohiro/Private` must be initialized as a local Git repository for meta-governance work only.

The repository must track workspace-level files and ignore independent child repositories, existing worktrees, archives, local settings, and generated artifacts.

## In Scope

- Track `AGENTS.md`, `CLAUDE.md`, `docs/`, `.agents/`, `.claude/skills/`, `scripts/`, `schemas/`, `tests/`, and `.gitignore`.
- Keep independent repositories such as `人生管理/`, `起業スキル/`, `仕事/`, `focusmap/`, `playnote/`, `side-business/`, `副業/`, `転職/`, and `投資/` outside the parent repo.
- Keep worktree-like directories such as `focusmap-*` outside the parent repo.
- Keep local settings such as `.claude/settings.local.json` outside the parent repo.
- Use local Git first; do not add a remote until a separate secret/review gate passes.

## Out of Scope

- Converting `Private/` into a monorepo for all child projects.
- Submodule management for child repositories.
- GitHub remote creation or push.
- Moving existing global skill source directories during this setup.
- Rewriting existing child repository histories.

## Acceptance Criteria

- `git -C /Users/kitamuranaohiro/Private rev-parse --show-toplevel` returns `/Users/kitamuranaohiro/Private`.
- `git -C /Users/kitamuranaohiro/Private branch --show-current` returns `main`.
- `git -C /Users/kitamuranaohiro/Private ls-files` contains only the allowed meta-governance paths.
- `git -C /Users/kitamuranaohiro/Private status --ignored --short` shows independent child repositories and local artifacts as ignored, not staged.
- No remote is configured unless a later explicit GitHub/private-remote task approves it.
