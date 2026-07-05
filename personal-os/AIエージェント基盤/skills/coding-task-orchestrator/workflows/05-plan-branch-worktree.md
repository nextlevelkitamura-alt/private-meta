# 05 Plan Branch Worktree

Use this workflow after the execution surface and agent setup are known.

## Hard Gate

Before human confirmation, propose branch/worktree/port only as a draft. Do not create them and do not speak as if they are final.

Before proposing a new worktree, inspect `git worktree list`. Treat five worktrees as the maximum:

- If the current count is five or more, report `Worktree Limit Reached`.
- Show the current worktree list.
- Propose cleanup candidates, but do not delete anything.
- Wait for human approval before any worktree creation or cleanup.

## Branch Naming

Use kebab-case and a concrete noun:

```text
feat/<short-purpose>
fix/<short-purpose>
chore/<short-purpose>
docs/<short-purpose>
```

Avoid vague names such as `misc`, `updates`, `changes`, or `task`.

Branch and worktree names must use only lowercase ASCII letters, digits, hyphens, and slashes. Do not use Japanese, spaces, uppercase letters, underscores, emoji, or other symbols. Put Japanese explanations in the Orca task name, Issue, PR body, or task doc instead.

## Worktree Naming

Default:

```text
../<repo-name>-wt-<short-purpose>
```

One worktree maps to one branch and one implementation owner. Do not share one branch across multiple implementation worktrees, and do not open the same branch in multiple worktrees.

## Port Rule

- Prefer the repository's documented default port when no parallel web work exists.
- For parallel web work, reserve an explicit port per worktree.
- Suggested default range: main on `3000`, feature worktrees on `3001-3005`, unless the repository documents another range.
- Check collisions before assigning:

```sh
lsof -i :<port>
```

## UI Or Implementation Alternative Comparison

When comparing UI options or implementation prototypes, separate every option:

```text
experiment/login-ui-a / repo-wt-login-ui-a / port 3001
experiment/login-ui-b / repo-wt-login-ui-b / port 3002
```

- Keep each alternative in its own branch, worktree, and port.
- Do not mix multiple alternatives inside the same worktree.
- Only the winning option should be turned into a PR.
- Losing options must not be merged; list them as cleanup candidates.
- Branch/worktree cleanup still requires human approval.

## Collision Checks

Before proposing final names, inspect or ask the worker to inspect:

- `git branch --list`
- `git worktree list`
- `git worktree list --porcelain` to confirm the branch is not already checked out elsewhere
- existing `docs/tasks/active/`
- `lsof -i :<port>` for web tasks

## Output Fragment

```md
## Branch / Worktree / Port

- Branch: <draft branch>
- Worktree: <draft worktree path or none>
- Port: <draft port or existing default>
- Naming reason:
- Collision checks:
- Human gate: create none of these until approved.
```
