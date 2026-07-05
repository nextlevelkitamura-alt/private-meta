# Codex App Patterns

## Codex App Local

Use for Small tasks when the existing worktree is acceptable.

Preflight:

- `git status --short`
- check repository instructions
- identify verification command

Do not let unrelated dirty changes become part of the task.

## Codex App Worktree

Use for Medium tasks needing isolation.

Preflight:

- confirm branch/worktree names with human
- `git branch --list`
- `git worktree list`
- port collision check for web apps
- create/update task docs only after approval

Worker prompt must include:

- branch
- worktree
- port
- allowed files
- docs update plan
- verification commands
- push/merge/deploy prohibition
- return report format

## Localhost Verification

For UI work:

- run the documented dev server
- use the assigned port
- verify core screen loads
- capture screenshot or describe concrete visual evidence
- note console/API errors

## Closeout

- PR body summary
- active task doc cleanup
- ACTIVE_TASKS cleanup
- closeout classification for branch/worktree candidates
- human approval before deletion
