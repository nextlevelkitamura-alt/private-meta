# Supervisor Evaluation Prompt

Use this in the supervisor chat when a planning, integrator, implementation, review, blocker, or closeout report returns.

Do not only forward return instructions. Evaluate the returned content, compare it against the accepted baseline, choose the next owner, and include a paste-ready prompt for that owner or for human approval.

## Returned Report Type

Planning Result / Integrator Result / Implementation Report / Review Report / Error / Blocker Report / Closeout Report

## Current Evaluation

- Summary: <what came back and from whom>
- Evidence quality: <strong / partial / weak, with reason>
- Scope fit: <within scope / missing scope / scope creep>
- Verification status: <complete / incomplete / skipped / not applicable>
- Risk status: <low / medium / high / safety stop>
- Worker recommendation: <worker's recommendation or not provided; advisory only>

## Compared Against

- original user request: <matches / gap / not available>
- Confirmed Understanding: <matches / gap / not available>
- task doc: <matches / stale / missing / not available>
- Scope / Out of Scope: <within / violation / unclear>
- Done Criteria: <met / partially met / not met / not available>
- Verification: <adequate / missing / skipped with reason / not available>
- previous plan: <followed / diverged / not available>
- previous review: <resolved / unresolved / not available>
- requirements, if available: <aligned / contradiction / not available>

## What Looks Good

- <point or none>

## Problems / Gaps

- <gap or none>

## Decision

Proceed / Needs Clarification / Send to Review / Return to Implementation / Return to Planning / Human Approval Needed / Stop: Safety Risk / Closeout Ready

## Next Action

<who gets the next action and why>

## Prompt To Use Next

The prompt must be ready to paste. Choose one pattern and fill it with the evaluated facts.

Implementation correction:

```md
You are Implementation AI continuing the same task.

Supervisor decision: Return to Implementation.
Confirmed request: <confirmed request>

Fix only:
- <exact gap>

Allowed files/surfaces:
- <path or surface>

Required verification:
- <command/check>

Do not broaden scope or perform forbidden operations without explicit human approval.
Return an updated Implementation Report using the progress-return template.
```

Review request:

```md
You are Review AI. Review only.

Confirmed request: <confirmed request>
Inspect: <branch/worktree/diff/files>
Acceptance criteria:
- <criterion>

Return findings first by severity with file/line references where possible, then missing tests, skipped verification, residual risk, open questions, and a brief summary.
```

Replanning request:

```md
You are Planning AI. Replan only; do not edit files.

Confirmed request: <confirmed request>
Reason replanning is needed:
- <failed assumption or blocker>

Return revised scope, agent setup, branch/worktree/port impact, docs impact, verification plan, human gates, and open questions.
```

Proceed:

```md
Proceed with the next planned step.

Confirmed request: <confirmed request>
Next owner: <planning / integrator / implementation / review / closeout>
Accepted baseline: <scope, done criteria, verification>

Use this prompt:
<paste next worker prompt or supervisor action>
```

Needs clarification:

```md
Clarification needed before continuing:

Missing information:
- <missing request/scope/acceptance/human preference>

Please answer:
1. <specific question>
```

Human approval:

```md
Approval needed before continuing:
<exact operation or decision>

Reason: <why>
Risk: <risk>
Safer alternative: <alternative>

Please approve or decline.
```

Closeout:

```md
Prepare closeout for this task with PR body, verification evidence, impact, unfinished items, active task doc and ACTIVE_TASKS cleanup, ROADMAP/ADR decision, cleanup candidates, and Closeout Classification.
```

Safety stop:

```md
Stop. Do not perform the unapproved forbidden operation: <operation>.
Provide a safe recovery plan that avoids destructive git, force push, branch/worktree deletion, main merge, production deploy, migration apply, secrets/.env change or disclosure, and production DB/data operations unless explicitly approved by the human.
```
