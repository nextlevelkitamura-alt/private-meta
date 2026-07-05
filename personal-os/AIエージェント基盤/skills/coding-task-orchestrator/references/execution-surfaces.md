# Execution Surfaces

Use this reference with `workflows/03-choose-execution-surface.md`.

## Codex App Local

Best for:

- Small local edits
- One working copy
- No parallel work
- Quick verification

Risk:

- Existing dirty changes may make ownership unclear.

## Codex App Worktree

Best for:

- One Medium task needing isolation
- Localhost verification
- Clear branch ownership
- App-native diff, commit, push, and PR flow

Risk:

- Worktree cleanup can be forgotten; closeout must classify it.

## Orca

Best for:

- Large orchestration
- Multiple terminals, browser contexts, worktrees, or worker roles
- Parallel Medium tasks that are truly independent
- Visible supervision

Fallback:

- Codex App Worktree for one branch
- Sequential Codex chats when parallel tooling is unavailable

## Codex Cloud

Best for:

- Repository-only work
- Self-contained fixes or tests
- PR review or static investigation

Avoid when:

- Local `.env`, DB, browser login, private desktop state, or localhost UI is required

## Terminal

Best for:

- Deterministic command output
- Verification commands
- File-list, line-count, or format checks
- Generating a bounded artifact after approval

## `codex exec`

Best for:

- Non-interactive plan/review/report generation
- Batch analysis with explicit inputs
- Saving a bounded result to a file

Avoid when:

- The task needs conversational clarification or live UI interaction

## Selection Output

Always include:

- selected surface
- reason
- fallback
- unavailable assumptions
- human gates before side effects
