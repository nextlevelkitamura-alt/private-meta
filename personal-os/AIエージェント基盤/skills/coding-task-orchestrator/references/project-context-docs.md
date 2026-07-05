# Project Context Docs

Use this reference when a repository does not already have clear durable project docs.

## Read First

- `AGENTS.md`
- `README.md`
- `ROADMAP.md`
- `docs/PROJECT_SPEC.md`
- `docs/DOCS_PROFILE.md`
- package or build config
- existing docs index

## Missing `docs/PROJECT_SPEC.md`

For Small tasks, usually do nothing.

For Medium/Large tasks, propose creating it before broad implementation if durable facts are unclear.

Minimum content:

- Product purpose
- Current behavior
- Stack
- Local dev command
- Test/build command
- Deploy destination
- DB/Auth/external integrations
- Environment variable handling
- Main directories

## Missing `docs/DOCS_PROFILE.md`

For Small tasks, usually do nothing.

For Medium/Large tasks, propose creating it before adding docs that might conflict with local convention.

Minimum content:

- Source-of-truth docs
- Task docs location
- ADR location
- When to update README, ROADMAP, PROJECT_SPEC, task docs, ADRs, and PR body
- Archive/delete policy

## Existing `docs/ai/task-board.md`

If a repository already uses `docs/ai/task-board.md`, do not silently replace it. State the coexistence decision:

- use existing `docs/ai` because repository convention wins, or
- propose migration to `docs/tasks` and ask for approval.

Default for new repositories:

- `docs/tasks/ACTIVE_TASKS.md`
- `docs/tasks/active/`
- `docs/tasks/archive/`
