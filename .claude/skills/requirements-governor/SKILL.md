---
name: requirements-governor
description: Use this skill to audit, create, update, validate, and govern repository requirements, feature specs, progress status, contradictions, non-goals, and implementation alignment. Use before adding features, after implementation, when requirements are scattered, or when CLAUDE.md/AGENTS.md are becoming too large.
---

# requirements-governor

Use this skill to govern requirements and implementation alignment. This skill does not exist to write polished requirements in isolation; it exists to prevent scope drift, contradictions, unclear progress, and oversized agent entry files.

## Core Rule

Implementation code is not changed unless the user explicitly asks for implementation work. In governance modes, update only docs, specs, ledgers, contradictions, non-goals, ADRs, skill references, and agent instruction files.

## Source of Truth

- Product requirements: `docs/requirements/product-requirements.md`
- Requirements ledger: `docs/requirements/requirements-ledger.md`
- Progress board: `docs/requirements/progress-board.md`
- Contradictions and open issues: `docs/requirements/contradictions.md`
- Non-goals: `docs/requirements/non-goals.md`
- Feature specs: `docs/specs/`
- Architecture decisions: `docs/adr/`
- Entry-file policy: `docs/agent/agent-file-policy.md`

## Modes

Use the narrowest mode that fits the request:

- Audit Mode: inventory existing requirements, docs, TODOs, specs, and implementation state. See `references/audit-mode.md`.
- Feature Gate Mode: check a new feature before implementation. See `references/feature-gate-mode.md`.
- Progress Sync Mode: sync implementation state with the requirements ledger. See `references/progress-sync-mode.md`.
- Contradiction Review Mode: detect conflicts and stale requirements. See `references/contradiction-review-mode.md`.
- Entry File Maintenance Mode: keep `CLAUDE.md` and `AGENTS.md` short and synchronized. See `docs/agent/agent-file-policy.md`.
- Compatibility Test Mode: verify Claude Code and Codex compatibility. See `docs/agent/compatibility-checklist.md`.

## Required Statuses

Use only the statuses in `references/status-rules.md`.

Do not mark anything `done` without evidence. Use `references/done-definition.md`.

## Default Workflow

1. Identify the mode from the user request.
2. Read only the files required for that mode.
3. Check `non-goals.md` and `contradictions.md` before accepting new scope.
4. Update the smallest source-of-truth file needed.
5. Record evidence or mark weak claims as `needs_verification`.
6. If changing entry files or skill placement, run the check scripts.

## Required Checks

For entry-file and compatibility work, run:

```sh
bash scripts/agent-instructions/check-agent-instructions.sh
bash scripts/agent-instructions/check-skill-compatibility.sh
```

For router synchronization, run:

```sh
bash scripts/agent-instructions/sync-agent-router.sh
```

## Templates

Use `references/templates.md` for requirement rows, feature specs, contradictions, and progress updates.
