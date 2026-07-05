# 04 Plan Agent Setup

Use this workflow after size and execution surface are known.

## Principle

Use the fewest AIs that provide meaningful risk reduction. More AIs are coordination cost, not progress by default.

## Small

Default:

- 1AI

Responsibilities:

- Implement
- Verify
- Report

Do not add Review AI unless the repository or user explicitly requires it.

## Medium

Default:

- Implementation AI
- Review AI

Planning can be done by the same supervising AI unless the specification is unclear.

Responsibilities:

- Implementation AI: implement assigned scope, update required docs, run verification, return progress report.
- Review AI: findings first, check diff against confirmed request, tests, docs, UX/API risks, and residual risk.

## Large

Default:

- Planning AI A
- Planning AI B
- Integrator AI
- Implementation AI
- Review AI

Optional:

- Validation AI for screenshots, data checks, performance evidence, or complex test matrices.

Responsibilities:

- Planning AI A: architecture and risk model.
- Planning AI B: challenge scope, alternatives, acceptance criteria, and test plan.
- Integrator AI: contracts, merge order, conflicts, final verification, and docs cleanup.
- Implementation AI: implement only assigned files and scope.
- Review AI: behavior, security, tests, docs, acceptance criteria.
- Validation AI: collect independent verification evidence.

## Output Fragment

```md
## Agent Setup

- Count:
- Roles:
- Why this split:
- Why not more:
```
