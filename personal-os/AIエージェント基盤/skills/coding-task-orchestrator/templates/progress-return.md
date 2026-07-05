# Progress Return Prompt

Return this report to the supervisor chat.

The supervisor owns the final evaluation and next decision. Your recommended next step is advisory; include evidence so the supervisor can compare this report against the original request, confirmed understanding, plan, review, requirements, and done criteria.

## Returned Report Type

Planning Result / Integrator Result / Implementation Report / Review Report / Error / Blocker Report / Closeout Report

## Report Source

- Role: Planning AI / Integrator AI / Implementation AI / Review AI / Validation AI / Human / Other
- Source chat or tool:
- Report type rationale:

## Compared Against

- Original user request:
- Confirmed Understanding:
- Task doc:
- Scope / Out of Scope:
- Done Criteria:
- Verification plan:
- Previous plan:
- Previous review:
- Requirements:

## Branch / Worktree

Use `not applicable` when the report returns before branch/worktree creation.

- Branch:
- Worktree:
- Port:

## Commit

- Commit hash:
- Uncommitted changes:

## Files Changed

- `<path>`: <summary>

## What Changed

<short summary>

## Match To Confirmed Request

<why this matches the confirmed scope>

## Verification

| Command / Check | Result | Notes |
| --- | --- | --- |
| `<command>` | pass/fail/skipped | <notes> |

## Verification Gaps

- <skipped or missing check and why>

## Screenshots / Localhost

- <path or URL>

## Docs / Task Board

- Active task doc:
- ACTIVE_TASKS:
- PR body:

## Unfinished Items

- <item or none>

## Risks / Decisions Needed

- <risk or none>

## Forbidden Operation Check

State whether this report requests, performed, or depends on any of the following without explicit human approval: `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, production DB/data operation.

- Result: none / approval needed / safety risk
- Details:

## Recommended Next Step

Proceed / Needs Clarification / Send to Review / Return to Implementation / Return to Planning / Human Approval Needed / Stop: Safety Risk / Closeout Ready

## Suggested Prompt To Use Next

Optional. If you recommend a next worker, include a draft prompt. The supervisor may revise or replace it.

```md
<paste-ready draft prompt or "none">
```

## Progress Status

planned / in_progress / review / integration / blocked / ready_for_closeout

## Closeout Classification

unset / integrated / abandoned / main_unintegrated
