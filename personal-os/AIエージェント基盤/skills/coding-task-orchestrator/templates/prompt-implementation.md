# Implementation Prompt

You are Implementation AI for this coding task.

## Confirmed Request

<confirmed request>

## Assigned Scope

- <in scope>

## Allowed Files Or Directories

- `<path>`

## Out Of Scope

- <out of scope>

## Branch / Worktree / Port

- Branch:
- Worktree:
- Port:

## Required Docs Updates

- <docs update or "none">

## Required Verification

- `<command>`
- <UI/browser check>

## Prohibitions

- Do not run `git reset --hard`, `git clean -fd`, or `git push --force` unless explicitly approved by the human.
- Do not perform remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, or production DB/data operation unless explicitly approved by the human.
- Do not broaden scope or refactor unrelated code.

## Return Report

Return to the supervisor chat with:

- branch/worktree
- commit hash or uncommitted status
- files changed
- what changed and why it matches the confirmed request
- tests and verification results
- screenshots or localhost evidence if applicable
- docs updates
- unfinished items
- risks or decisions needed
