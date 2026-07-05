# 08 Monitor Progress And Returned Reports

Use this workflow when planning, implementation, review, or integration reports return to the supervisor chat.

The supervisor chat is not a passive relay. It evaluates the returned report against the original plan and requirements, decides the next owner, and emits the next prompt to use.

## Required Inputs From Workers

- Returned report type
- Branch/worktree, if applicable
- Commit hash or uncommitted status, if applicable
- Files changed, if applicable
- What changed and why it matches the confirmed request
- Tests and verification commands with outcomes
- Screenshots or localhost evidence when applicable
- Docs updates completed or skipped
- Active task doc and ACTIVE_TASKS status
- Unfinished items
- Risks, blockers, or human decisions needed

## Returned Report Type

Classify the returned answer as exactly one of:

- Planning Result
- Integrator Result
- Implementation Report
- Review Report
- Error / Blocker Report
- Closeout Report

If the report mixes types, choose the type that should drive the next decision and mention the secondary type under Problems / Gaps.

Do not accept the worker's own `Recommended Next Step` as the supervisor decision. Treat it as one input, then make the supervisor decision from the comparison baseline and evidence.

## Type-Specific Evaluation

Planning Result:

- Check whether the plan answers the confirmed request without implementation.
- Check whether scope, out-of-scope, done criteria, verification, docs, branch/worktree/port, and human gates are explicit.
- Decide `Proceed` only when an implementation or integrator handoff can run from the plan without guessing.
- Decide `Return to Planning` when the plan skips acceptance criteria, expands scope, ignores requirements, or leaves material sequencing unclear.

Integrator Result:

- Check merge order, contract alignment, conflict handling, final verification matrix, docs cleanup, and unresolved worker gaps.
- Decide `Proceed` when the next planned implementation/review step is clear.
- Decide `Send to Review` when integration claims are ready but independent review has not happened.
- Decide `Return to Planning` when integration exposes design or contract drift.

Implementation Report:

- Check changed files, scope fit, verification evidence, screenshots/localhost evidence when needed, docs/task board updates, and remaining risks.
- Decide `Send to Review` only when implementation claims are complete enough for independent review.
- Decide `Return to Implementation` when code, docs, tests, screenshots, or required verification are missing or incorrect.

Review Report:

- Check findings severity, file/line evidence, acceptance criteria coverage, skipped verification, and whether review stayed read-only unless explicitly allowed.
- Decide `Return to Implementation` for blocking or material findings.
- Decide `Closeout Ready` only when review passes, verification is adequate, and no implementation or docs gaps remain.

Error / Blocker Report:

- Separate true blockers from worker uncertainty.
- Decide `Return to Planning` when the blocker changes design or scope.
- Decide `Human Approval Needed` when the next safe step is allowed only after approval.
- Decide `Stop: Safety Risk` when the report asks for, performed, or depends on unapproved forbidden operations.

Closeout Report:

- Check PR body, verification evidence, active task doc removal/archive plan, ACTIVE_TASKS cleanup, ROADMAP/ADR decisions, cleanup candidates, and closeout classification.
- Decide `Closeout Ready` only when closeout evidence is sufficient and cleanup candidates are listed without being executed.
- Decide `Return to Implementation` or `Return to Planning` if closeout reveals unfinished implementation, missing verification, or unresolved scope/design issues.

## Representative Supervision Examples

Error / Blocker Report with possible env or localhost setup issue:

- Returned report says localhost cannot start and suspects missing environment variables.
- The supervisor must not ask the worker to print secret values, inspect `.env` contents, or edit `.env` automatically.
- Decision: `Human Approval Needed`.
- Prompt To Use Next should ask the human to confirm only safe diagnostics such as required variable names, whether local env files exist, which setup doc applies, and whether a non-secret placeholder or documented local value should be added by the human.
- Do not proceed to PR, merge, or deploy while the env blocker is unresolved.

Integrator Result with Phase 2 scope split:

- Returned report says the original request included Auth, DB, and an external API integration, but the final plan moves the external API integration to Phase 2.
- Treat this as a scope change, even when the split may be technically sensible.
- Decision: `Human Approval Needed`.
- Prompt To Use Next should ask whether Phase 1 may exclude the external API integration before implementation starts.
- Recommend updating the task doc, Done Criteria, and Out of Scope to show the approved Phase 1/Phase 2 boundary before any implementation work proceeds.

## Compared Against

Compare the returned report against every available source below:

- original user request
- Confirmed Understanding
- task doc
- Scope / Out of Scope
- Done Criteria
- Verification
- previous plan
- previous review
- requirements, if available

If a source is unavailable, say `not available` instead of silently skipping it.

Comparison standards:

- original user request: confirms the work still solves the user's actual ask.
- Confirmed Understanding: confirms the worker did not skip the approved scope or add unapproved scope.
- task doc: checks current status, owner, branch/worktree, port, docs plan, unfinished items, and closeout classification.
- Scope / Out of Scope: catches unrelated refactors, extra features, risky operations, and missing exclusions.
- Done Criteria: checks whether the report proves each completion condition.
- Verification: checks command results, screenshots, localhost evidence, review evidence, and skipped checks with reasons.
- previous plan: checks whether the worker followed the accepted sequence and constraints.
- previous review: checks whether earlier findings were fixed or intentionally deferred with approval.
- requirements, if available: checks status, acceptance criteria, contradictions, non-goals, and evidence rules.

## Decisions

Choose exactly one decision:

- Proceed
- Needs Clarification
- Send to Review
- Return to Implementation
- Return to Planning
- Human Approval Needed
- Stop: Safety Risk
- Closeout Ready

Use `Stop: Safety Risk` when the report asks for, performs, or depends on an unapproved forbidden operation: `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, or production DB/data operation.

The decision must name the next owner: planning, integrator, implementation, review, human, or closeout. Do not end with only "return this to the supervisor" or generic return instructions.

## Supervisor Steps

1. Classify the returned report type.
2. Compare the report to the confirmed understanding, accepted scope, done criteria, verification plan, previous plan/review, task doc, and requirements when present.
3. Check whether the worker stayed within allowed files and out-of-scope boundaries.
4. Check verification evidence, not just claims.
5. Decide whether the next owner is planning, implementation, review, integrator, human, or closeout.
6. Update or instruct updates to `docs/tasks/active/<branch-name>.md` and `docs/tasks/ACTIVE_TASKS.md` when required. For light Medium tasks, these may remain recommended only if no task doc was required by the docs plan.
7. Escalate contradictions or requirements drift to `requirements-governor`.
8. Do not run `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, or production DB/data operation without human approval.
9. Emit a paste-ready `Prompt To Use Next` for the chosen next owner.

## Returned Report Assessment

Prefer concrete evidence:

- command output summary
- screenshot path or URL
- test/build result
- changed-file list
- commit hash
- remaining risk

If evidence is missing, ask for it instead of marking the work complete.

## Decision Guide

- `Proceed`: the returned planning or integration result is sound and the next planned step can run.
- `Needs Clarification`: the report cannot be evaluated because the user request, scope, acceptance criteria, or human preference is unclear.
- `Send to Review`: implementation claims are complete enough for independent review, but review has not happened.
- `Return to Implementation`: implementation, docs, tests, or verification are missing or incorrect.
- `Return to Planning`: the plan is incomplete, contradicts requirements, over-expands scope, or the returned blocker changes the design.
- `Human Approval Needed`: the next step is allowed only after explicit approval.
- `Stop: Safety Risk`: the report crosses a forbidden operation or safety boundary.
- `Closeout Ready`: implementation and review are complete, verification evidence is adequate, and only closeout/reporting remains.

## Prompt To Use Next

Always include a practical next prompt. The prompt must be ready to paste into the next worker or to the human, not just a vague instruction to return something.

Use the decision to choose the prompt target:

- `Return to Implementation`: write a correction prompt for Implementation AI with exact gaps, allowed files, required verification, and the return template.
- `Send to Review`: write a review request with confirmed scope, files/diff to inspect, acceptance criteria, known risks, and findings-first output instructions.
- `Return to Planning`: write a replanning prompt with the failed assumptions, constraints, open questions, and expected planning output.
- `Human Approval Needed`: write the approval question with the exact risky operation, reason, alternatives, and consequences of approval/refusal.
- `Closeout Ready`: write the closeout prompt asking for PR body, verification evidence, task-doc/ACTIVE_TASKS cleanup plan, and cleanup candidates.
- `Proceed`: write the next planned worker prompt or state the next planned supervisor action.
- `Needs Clarification`: write the minimum clarification question needed to evaluate or continue, with the default safe assumption if one exists.
- `Stop: Safety Risk`: write a stop notice and a safe recovery prompt that avoids the forbidden operation.

Prompt requirements:

- Include the confirmed request, current decision, exact gaps or acceptance criteria, allowed files/surfaces, required verification, docs/task-board expectation, and return format.
- For review prompts, require findings first with severity and file/line references when possible.
- For implementation correction prompts, list only the changes needed to close the gaps; do not invite broad refactors.
- For human approval prompts, name the exact operation, why it is requested, safer alternatives, and what happens if approval is refused.
- For closeout prompts, ask for PR body, verification evidence, task-doc/ACTIVE_TASKS cleanup plan, ROADMAP/ADR decisions, cleanup candidates, and Closeout Classification.

## Prompt To Use Next Patterns

Use these as compact starting points and fill the placeholders with the evaluated facts.

Return to Implementation:

```md
You are Implementation AI continuing the same task.

Confirmed request:
<confirmed request>

Supervisor decision: Return to Implementation.

Fix only these gaps:
- <gap with evidence>

Allowed files/surfaces:
- <path or surface>

Do not broaden scope. Do not run `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, or production DB/data operation without explicit human approval.

Required verification:
- <command/check>

Return an updated Implementation Report using `templates/progress-return.md`, including changed files, verification results, docs/task-board updates, unfinished items, and risks.
```

Send to Review:

```md
You are Review AI. Review only; do not implement fixes unless separately approved.

Confirmed request:
<confirmed request>

Inspect:
- <diff/files/branch/worktree>

Acceptance criteria:
- <criterion>

Known risks or skipped checks:
- <risk or none>

Return findings first, ordered by severity, with file/line references where possible. Then include missing tests, skipped verification, residual risk, open questions, and a brief pass/fail summary.
```

Return to Planning:

```md
You are Planning AI. This is replanning only; do not edit files.

Confirmed request:
<confirmed request>

Why replanning is needed:
- <failed assumption, contradiction, blocker, or scope change>

Constraints and non-goals:
- <constraint>

Answer:
- revised scope
- owner/agent setup
- branch/worktree/port impact
- docs/task-board impact
- verification plan
- human gates
- open questions
```

Proceed:

```md
Proceed with the next planned step.

Confirmed request:
<confirmed request>

Accepted baseline:
- Scope: <scope>
- Done Criteria: <criteria>
- Verification: <checks>

Next owner:
<planning / integrator / implementation / review / closeout>

Use this prompt:
<paste the next worker prompt or supervisor action>
```

Needs Clarification:

```md
Clarification needed before continuing:

I cannot safely evaluate or continue because:
- <missing request/scope/acceptance/human preference>

Please answer:
1. <specific question>

Until answered, do not broaden scope, create branches/worktrees, merge, deploy, apply migrations, change secrets, or operate on production data.
```

Human Approval Needed:

```md
Approval needed before continuing:

Requested operation:
<exact operation>

Reason:
<why it is being requested>

Risk:
<what could go wrong>

Safer alternatives:
- <alternative>

Approve or decline this operation. If declined, the next safe path is:
<fallback>
```

Closeout Ready:

```md
Prepare closeout for the completed task.

Confirmed request:
<confirmed request>

Include:
- PR body summary
- verification evidence
- impact
- unfinished items or none
- active task doc delete/archive plan
- ACTIVE_TASKS cleanup
- ROADMAP/ADR update decision
- cleanup candidates only, with human approval required for branch/worktree deletion
- Closeout Classification: integrated / abandoned / main_unintegrated
```

Stop: Safety Risk:

```md
Stop. The returned report requests or depends on an unapproved forbidden operation:
<operation>

Do not perform it. Provide a safe recovery plan that avoids `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, and production DB/data operation unless the human explicitly approves.

Return the safest non-destructive next steps and any information needed from the human.
```

## Output Format

````md
## Returned Report Type
<Planning Result / Integrator Result / Implementation Report / Review Report / Error / Blocker Report / Closeout Report>

## Current Evaluation
- Summary:
- Evidence quality:
- Scope fit:
- Verification status:
- Risk status:

## Compared Against
- original user request:
- Confirmed Understanding:
- task doc:
- Scope / Out of Scope:
- Done Criteria:
- Verification:
- previous plan:
- previous review:
- requirements, if available:

## What Looks Good
- <point or none>

## Problems / Gaps
- <gap or none>

## Decision
<Proceed / Needs Clarification / Send to Review / Return to Implementation / Return to Planning / Human Approval Needed / Stop: Safety Risk / Closeout Ready>

## Next Action
<who gets the next action and why>

## Prompt To Use Next
```md
<paste-ready prompt for the next worker or human approval>
```
````
