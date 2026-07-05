# 06 Plan Docs Lifecycle

Use this workflow after branch/worktree planning.

## Source Rules

Read repository docs before proposing broad documentation changes:

- nearest `AGENTS.md` or `CLAUDE.md`
- `docs/agent/active-context.md` or repo-equivalent active context
- `docs/tasks/README.md`
- `docs/tasks/ACTIVE_TASKS.md`
- `docs/tasks/quick-log.md`
- `docs/PROJECT_SPEC.md` for durable project facts
- `docs/DOCS_PROFILE.md` for documentation policy
- Requirements or contradiction docs when present

If `docs/PROJECT_SPEC.md` or `docs/DOCS_PROFILE.md` is missing, propose creation for Medium/Large tasks instead of silently inventing policy.

## Repo Minimum Operation Gate

Before planning normal implementation docs, check whether the repo has `active-context`, `docs/tasks` convention files, active/archive handling, and any existing `docs/ai/task-board.md` convention. If missing, or if completed tasks remain under `docs/tasks/active/`, stop normal planning and report the minimal structure needed.

When the user has already approved setup, create only the smallest repo-local structure. Do not migrate `docs/ai` repos to `docs/tasks` without explicit approval.

## Document Roles

- `AGENTS.md`: stable AI constitution only. Do not write dynamic task info here.
- `docs/agent/active-context.md`: current orientation only, not a log or evidence archive.
- `ROADMAP.md`: Now / Next / Later / Not Now sequencing when product direction changes.
- `docs/PROJECT_SPEC.md`: current product behavior, stack, deploy target, local dev, DB/Auth/external integrations, env policy, major directories.
- `docs/DOCS_PROFILE.md`: which docs exist, when to update each, archive policy, PR body expectations.
- `docs/tasks/README.md`: local task lifecycle rules.
- `docs/tasks/ACTIVE_TASKS.md`: active branch/worktree index.
- `docs/tasks/active/<branch-name>.md`: branch/worktree-specific task state.
- `docs/tasks/archive/`: completed work worth retaining; do not archive every trivial task.
- `docs/tasks/quick-log.md`: Small tasks and investigation notes below task-doc level.
- `docs/adr/` or `docs/decisions/ADR-xxx.md`: durable architecture decisions.
- PR body: purpose, changes, verification, impact, unfinished items.

## By Size

Small:

- Usually no docs update.
- No task doc.
- `quick-log.md` only when a durable short note is useful.
- Commit message or PR body is enough when a PR exists.

Medium:

- Create active task doc when required by risk.
- Update ACTIVE_TASKS when required by risk.
- For light Medium work, active task doc and ACTIVE_TASKS may be recommended only.
- When keeping them recommended only, explicitly state why required triggers are absent.
- PR body summary after implementation.
- Closeout removes or archives task doc and removes ACTIVE_TASKS row.

Medium task tracking is required when the task has multiple-file changes, existing feature impact, Review AI usage, Orca usage, PR-required work, or repository-specific task tracking rules.

Large:

- Medium rules plus ROADMAP and ADR consideration.
- Requirements conflicts route to `requirements-governor`.
- Multiple human gates and durable decision records.

## Output Fragment

```md
## Documentation Plan

- Create:
- Update:
- Maybe:
- Do Not Update:
- Closeout:
```
