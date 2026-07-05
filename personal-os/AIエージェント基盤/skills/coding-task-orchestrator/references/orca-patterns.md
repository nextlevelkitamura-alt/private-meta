# Orca Patterns

Use Orca when coordination overhead is justified by real parallelism or risk separation.

## Good Fit

- Large task with planning, implementation, review, and integration roles
- Multiple independent worktrees
- Multiple browser contexts or terminals
- UI alternative comparison
- Architecture option comparison
- Visible status coordination matters

## Poor Fit

- One typo or copy change
- One narrow file edit
- No need for multiple contexts
- Scope is not confirmed yet
- Worker ownership is unclear

## Recommended Setup

- Supervisor chat owns the confirmed understanding and execution pack.
- Planning AI A/B return plans to supervisor.
- Integrator produces final implementation plan before workers begin.
- Implementation workers receive allowed files, branch/worktree/port, docs, verification, and return report requirements.
- Review worker reports findings first.

## Worktree And Prototype Rules

- Use at most five worktrees. If five or more already exist, report the limit, show the list, propose cleanup candidates, and wait for human approval.
- Do not open the same branch in multiple worktrees.
- Use lowercase ASCII, digits, hyphens, and slashes only for branch/worktree names. Put Japanese explanations in the Orca task name, Issue, PR body, or task doc.
- For UI or implementation comparison, give each option its own branch, worktree, and port, such as `experiment/login-ui-a` / `repo-wt-login-ui-a` / `3001` and `experiment/login-ui-b` / `repo-wt-login-ui-b` / `3002`.
- PR only the winning option. Mark losing options as cleanup candidates; do not merge them.
- Never delete a branch or worktree without human approval.

## Fallback

If Orca is not available:

- Use Codex App Worktree for one isolated branch.
- Use sequential Codex chats for planning/review.
- Keep the same return instructions and human gates.

## Status Board Fields

- branch
- worktree
- port
- role
- status
- blocker
- verification
- next action
- human gate
