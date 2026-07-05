# Task Size Rubric

Choose the smallest honest size. If the task might affect data, auth, billing, security, external integrations, or production behavior, do not classify it as Small.

## Small

Signals:

- One clear change
- One or two files
- Copy, CSS, README, comments, or narrow bug fix
- No shared contracts
- No database, auth, billing, migration, production data, or external API
- Verification is simple and local

Default handling:

- 1AI
- No task doc
- No ACTIVE_TASKS row
- Docs usually unnecessary
- PR optional

Upgrade to Medium when the change touches user-visible behavior in multiple places or needs browser/build verification.

Do not use Small for UI or implementation A/B comparison.

## Medium

Signals:

- UI improvement, new screen, or behavior change
- Light API change
- Multiple files
- Tests, build, or localhost verification needed
- Review risk exists but architecture is clear
- UI or implementation comparison with a small number of alternatives and clear acceptance criteria

Default handling:

- Implementation AI + Review AI
- Branch/worktree recommended
- `docs/tasks/active/<branch-name>.md` recommended by default
- `docs/tasks/ACTIVE_TASKS.md` recommended by default
- PR recommended
- For alternative comparison, use one branch, worktree, and port per option; PR only the winning option and mark losing options as cleanup candidates.

Required task tracking:

- Create a task doc and update `ACTIVE_TASKS.md` for multiple-file changes, existing feature impact, Review AI usage, Orca usage, PR-required work, or any local repository rule that requires task tracking.
- For light Medium tasks without those factors, task docs and `ACTIVE_TASKS.md` may remain recommendations rather than hard requirements.

Upgrade to Large when the plan is uncertain, durable architecture is involved, or production/security/data risk exists.

If uncertainty is the only large factor, run a short investigation phase before upgrading the task to Large.

Short investigation phase:

- Use it to answer concrete unknowns such as affected files, existing behavior, ownership boundaries, or whether a bug is local or systemic.
- Keep it read-only or narrowly diagnostic.
- Return a recommendation: stay Medium, upgrade to Large, or ask the human for scope clarification.
- If the task stays Medium, re-check whether task docs and `ACTIVE_TASKS.md` are required or only recommended.

## Large

Signals:

- Auth, DB, billing, security, migration, external API, or production data
- Major refactor or multiple feature areas
- Ambiguous requirements or competing designs
- Requires latest/current research
- Multiple branches, worktrees, or approval gates

Default handling:

- Planning AI A/B
- Integrator AI
- Implementation AI
- Review AI
- Optional Validation AI
- Branch/worktree/task docs required
- ADR and ROADMAP considered
- Repeated human gates
- Enforce the five-worktree limit and do not reuse the same branch in multiple worktrees.

## Tie Breakers

- More uncertainty -> larger size.
- More irreversible impact -> larger size.
- More independent work streams -> larger size.
- More documentation burden alone does not make a task Large.
- Small must remain light; do not add task docs just because a template exists.
- Light investigation may resolve uncertainty before choosing Medium vs Large.
