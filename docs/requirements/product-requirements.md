# Product Requirements

## Current Scope

This repository-level setup governs requirements, specs, progress, contradictions, and agent entry files for the current workspace.

The initial product or project-specific audit has not been performed yet. Run the First Audit Prompt in `docs/requirements/README.md` before treating this file as a complete product requirements document.

## Governance Requirements

| ID | Requirement | Status | Evidence |
| --- | --- | --- | --- |
| REQ-001 | `CLAUDE.md` and `AGENTS.md` must route to the same requirements governance rules without becoming the source of truth. | done | `bash scripts/agent-instructions/check-agent-instructions.sh` passed on 2026-05-28. |
| REQ-002 | Requirements, specs, progress, contradictions, non-goals, and decisions must live under `docs/requirements/`, `docs/specs/`, and `docs/adr/`. | done | Required paths passed in `bash scripts/agent-instructions/check-agent-instructions.sh` on 2026-05-28. |
| REQ-003 | Claude Code and Codex must both be able to use `requirements-governor`. | done | `bash scripts/agent-instructions/check-skill-compatibility.sh` passed on 2026-06-26, including `claude --help` and `codex --help`. |
| REQ-004 | Entry files must remain short, with warnings above 250 lines and failure above 300 lines. | done | `wc -l CLAUDE.md AGENTS.md` returned 96 lines each on 2026-05-28. |
| REQ-028 | `/Users/kitamuranaohiro/Private` must be a local Git meta-repository for Orca/Codex/Claude governance work without absorbing independent child repositories. | done | Commit `3dc31d3` initialized the repo on `main`; `git ls-files` contains only allowed meta paths; `git status --ignored --short` shows child repos and local settings ignored; no remote is configured. |
