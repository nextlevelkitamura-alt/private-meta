# Agent Role Patterns

## Supervisor Chat

Use for intake, planning approval, returned-report evaluation, next-owner decisions, and closeout guidance.

Required responsibilities:

- Keep the original user request, Confirmed Understanding, scope, done criteria, and verification plan as the comparison baseline.
- Classify returned reports as Planning Result, Integrator Result, Implementation Report, Review Report, Error / Blocker Report, or Closeout Report.
- Evaluate returned content against the baseline; do not simply forward Return Instructions or accept the worker's recommended next step.
- Decide Proceed, Needs Clarification, Send to Review, Return to Implementation, Return to Planning, Human Approval Needed, Stop: Safety Risk, or Closeout Ready.
- Produce a paste-ready Prompt To Use Next for the next worker or human approval.
- Stop on unapproved forbidden operations instead of forwarding the report.

## 1AI

Use for Small tasks and simple Medium tasks when one context can implement and verify safely.

Required responsibilities:

- Restate confirmed scope
- Implement
- Verify
- Report changed files, checks, and residual risk

## Implementation AI + Review AI

Use for Medium work with behavior, UI, API, or multi-file risk.

Implementation AI:

- Works only on assigned branch/worktree and allowed scope
- Updates required docs
- Runs verification
- Does not push, merge, deploy, or clean up without approval
- Returns the progress report

Review AI:

- Reviews findings first
- Uses severity and file/line references when possible
- Checks acceptance criteria, tests, docs, security, and UX/API risk
- Avoids broad refactors

## Planning A/B + Integrator + Implementation + Review

Use for Large work.

Planning AI A:

- Main architecture
- Risk model
- Suggested decomposition

Planning AI B:

- Challenge assumptions
- Alternatives
- Acceptance criteria
- Test strategy

Integrator AI:

- Owns contracts
- Tracks merge order
- Resolves conflicts
- Owns final verification matrix and docs cleanup

Implementation AI:

- Implements only assigned files and scope
- Returns evidence

Review AI:

- Independent review
- Findings first
- Missing tests and residual risk

Validation AI:

- Optional evidence collection for UI, performance, data, or external integration verification

## Anti-Patterns

- Splitting one file across multiple implementation AIs
- Adding more AIs because the task feels important but ownership is unclear
- Letting worker chats choose their own scope
- Treating implementation worker commits as complete before integration
