# 09 Closeout Task

Use this workflow after implementation and review pass, or when the user asks to finish, archive, or clean up a task.

## Closeout Checks

Confirm:

- PR body includes purpose, changes, verification, impact, and unfinished items.
- Active task doc is deleted or archived.
- `docs/tasks/ACTIVE_TASKS.md` no longer lists completed work.
- `ROADMAP.md` is updated only when roadmap meaning changed.
- ADR is created or updated only when durable decisions changed.
- Requirements/progress status is updated only with evidence.
- Branch/worktree cleanup candidates are listed with Closeout Classification:
  - integrated
  - abandoned
  - main_unintegrated
- `Status` remains the progress state. `Closeout Classification` is the ending classification.

## Human Approval Required

Never perform these without explicit human approval:

- `git reset --hard`
- `git clean -fd`
- `git push --force`
- remote branch deletion
- branch deletion
- worktree deletion
- main merge
- production deploy
- migration apply
- secrets / `.env` change or disclosure
- production DB/data operation

## Archive Policy

- Delete active task docs for trivial completed Medium tasks when the PR body contains enough context.
- Archive active task docs under `docs/tasks/archive/` when the work contains useful decisions, incident context, or future follow-up.
- Do not archive every Small task.

## Output Shape

```md
## Closeout

- PR body summary:
- Verification evidence:
- Active task doc:
- ACTIVE_TASKS cleanup:
- ROADMAP:
- ADR:
- Requirements/progress:
- Cleanup candidates:
- Closeout classification:
- Human confirmation required:
```
