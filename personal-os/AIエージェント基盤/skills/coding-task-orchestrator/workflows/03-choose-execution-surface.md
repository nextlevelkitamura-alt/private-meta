# 03 Choose Execution Surface

Use this workflow after task size is known.

## Decision Inputs

- Task size and risk
- Need for isolation
- Need for local browser/login/runtime state
- Need for multiple terminals, worktrees, or visible coordination
- Whether the task can run without local secrets or private environment
- User preference, if stated

## Codex App Local

Use when:

- Small work
- One local working copy is enough
- No branch/worktree isolation is needed
- Docs update is unnecessary or tiny

Avoid when unrelated local changes make isolation risky.

## Codex App Worktree

Use when:

- One Medium task needs isolation
- Diff, commit, push, and PR should stay inside app workflow
- Localhost verification is needed
- Ownership is bounded to one branch

Require human confirmation before creating the branch/worktree.

## Orca

Use when:

- Medium tasks are truly parallel
- Large work needs multiple terminals, browser contexts, or worktrees
- Planning, implementation, review, and integration should be separated
- UI or architecture alternatives need comparison
- The user wants visible coordination across workers

If Orca is unavailable, fall back to Codex App Worktree or sequential Codex chats and state the fallback.

## Codex Cloud

Use when:

- The task is self-contained and repository-only
- It does not depend on local `.env`, local DB, browser login, private runtime state, or local desktop apps
- The task is a light fix, test addition, PR review, or repository-only investigation

Avoid for tasks needing local secrets, authenticated browser sessions, private databases, or visual localhost checks.

## Terminal

Use when:

- The result is a command output, deterministic artifact, generated report, or local verification run
- Human will review the output before changes are applied

Do not use Terminal as a shortcut around human gates.

## `codex exec`

Use when:

- The desired output is a non-interactive plan, review summary, file artifact, or batch check
- The command can run with explicit inputs and produce a bounded result

Avoid for interactive clarification-heavy work.

## Output Fragment

```md
## Execution Surface

<selected surface>

Reason: <why this surface fits>
Fallback: <fallback if unavailable>
```
