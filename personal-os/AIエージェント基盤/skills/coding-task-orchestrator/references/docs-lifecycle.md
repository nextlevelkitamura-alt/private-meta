# Docs Lifecycle

## Stable Vs Dynamic

Stable repository rules belong in `AGENTS.md`.

Dynamic task state belongs in:

- `docs/tasks/ACTIVE_TASKS.md`
- `docs/tasks/active/<branch-name>.md`
- `docs/tasks/archive/`
- `docs/tasks/quick-log.md` for short Small-task notes

Never put branch-specific status, port reservations, worker assignments, or task checklists in `AGENTS.md`.

## Repo Minimum Operation Gate

Before normal implementation planning, confirm the target repo has:

- nearest `AGENTS.md` or `CLAUDE.md`
- `docs/agent/active-context.md` or repo-equivalent active context
- `docs/tasks/README.md`
- `docs/tasks/ACTIVE_TASKS.md`
- `docs/tasks/quick-log.md`
- `docs/tasks/active/` convention
- `docs/tasks/archive/` convention
- clear handling for any repo-standard `docs/ai/task-board.md`

If this structure is missing, or if completed work remains in `docs/tasks/active/`, stop normal implementation planning. Report the gap and propose minimal setup. Proceed with setup only when already approved or after human approval.

## Required Documents

### `docs/PROJECT_SPEC.md`

Durable facts:

- Product behavior
- Stack
- Deploy destination
- Local development method
- DB/Auth/external integrations
- Environment variable policy
- Major directory structure

### `docs/DOCS_PROFILE.md`

Docs policy:

- Which docs exist
- When to update each
- What not to duplicate
- ADR location
- Task archive policy
- PR body expectations

### `docs/tasks/ACTIVE_TASKS.md`

Active index. Recommended columns:

```md
| Status | Branch | Worktree | Purpose | Size | Surface | Agents | Port | Task Doc | Last Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

### `docs/tasks/active/<branch-name>.md`

Branch/worktree task state. Use for Large tasks and Medium tasks that need explicit tracking.

Keep progress `Status` separate from `Closeout Classification`. Progress status describes the current phase, such as planned, in progress, review, integration, blocked, or ready for closeout. Closeout classification describes the final outcome: integrated, abandoned, or main_unintegrated.

### `docs/tasks/archive/`

Use only for completed work worth retaining. Delete trivial active task docs after PR summary is sufficient.

### `docs/tasks/quick-log.md`

Use for Small tasks, investigation-only work, and task-doc-below notes. Do not paste raw logs or long transcripts.

### ADRs

Prefer existing repository convention:

- `docs/adr/`
- `docs/decisions/ADR-xxx.md`

Create/update ADRs only for durable decisions.

## Closeout

Before completion:

- PR body summarizes work and verification
- active task doc deleted or archived
- ACTIVE_TASKS row removed
- ROADMAP updated only if sequencing changed
- ADR updated only if durable decision changed
- cleanup candidates listed, not performed without approval
- closeout classification is recorded separately from progress status

## Light Medium Exception

For light Medium tasks, `docs/tasks/active/<branch-name>.md` and `docs/tasks/ACTIVE_TASKS.md` may be recommendations instead of hard requirements.

Still create a task doc and update `ACTIVE_TASKS.md` when any of these apply:

- multiple-file changes
- existing feature impact
- Review AI usage
- Orca usage
- PR-required work
- local repository rules require active task tracking

When the exception is used, the Documentation Plan must say which triggers are absent. Do not let "Medium" automatically become a docs-heavy workflow when the change is narrow, local, and easy to verify.
