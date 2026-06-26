# Coding Task Orchestrator Plan

Status: done
Created: 2026-06-26
Scope: Skill specification, implementation plan, and implementation evidence
Implementation: completed on 2026-06-26 at `~/.agents/skills/coding-task-orchestrator/`; review patch, supervisor evaluation patch, live manual prompt tests, and real branch/worktree representative operation evidence completed on 2026-06-26

## Feature Gate Result

The requested work was ready for planning first. Implementation was approved by the user on 2026-06-26 and completed after this plan was reviewed.

- Non-goal conflict: none found. The plan keeps implementation code untouched and does not treat AGENTS.md as a task board.
- Existing overlap: resolved in the implemented Skill. `coding-task-orchestrator` is documented as a stricter confirmation-first intake and supervision Skill, not a replacement for `task-router`.
- Required user gate: satisfied by the implementation request on 2026-06-26.
- Requirements record: REQ-027, status `done`.

## Implementation Result

- Canonical source: `~/.agents/skills/coding-task-orchestrator/`
- Mirrors: `~/.codex/skills/coding-task-orchestrator` and `~/.claude/skills/coding-task-orchestrator` symlink to the canonical source.
- File count: 29 files.
- Hub size: `SKILL.md` is 133 lines.
- Required structure: `SKILL.md`, 9 workflows, 8 references, and 11 templates.
- Validation: required file check passed; trailing whitespace check found no issues; acceptance keyword check passed 17/17. `bash scripts/agent-instructions/check-skill-compatibility.sh` is not formal evidence for this Skill because it verifies `requirements-governor` and rewrites `docs/agent/compatibility-checklist.md`.
- Final REQ-027 evidence: basic six live prompt cases passed, additional six live prompt cases passed, and real branch/worktree representative operation evidence was recorded in `docs/specs/coding-task-orchestrator-skill/real-operation-evidence-2026-06-26.md` with worker-return supervision, closeout judgment, and prohibited-operation non-execution evidence.

## Skill Purpose

`coding-task-orchestrator` is a planning and supervision Skill for development requests.

It takes a user's coding request and prevents premature execution by enforcing this sequence:

1. Confirm the user's intended change in plain language.
2. Ask permission to classify and plan.
3. After confirmation, classify size and execution surface.
4. Produce branch/worktree/port/docs/agent/prompt guidance.
5. Supervise returned reports from other AI chats or worktrees.
6. Require human gates for risky operations and closeout.

The Skill should make Small tasks lightweight while giving Medium and Large tasks enough structure to avoid drift, undocumented branches, and unclear integration ownership.

## Target Users

- Kitamura using Codex App, Codex CLI, Codex Cloud, Orca, or multiple AI chats for development work.
- A planning AI that creates execution packs for implementation/review/integration AIs.
- An implementation AI that receives a tightly scoped prompt and returns a structured completion report.
- A review or integrator AI that checks whether returned work matches the original confirmed request.

## Expected Use Cases

- A user says, "こういう修正をしたい", and the Skill responds with only understanding confirmation.
- A confirmed Medium UI/API task needs branch, worktree, port, task doc, ACTIVE_TASKS row, localhost verification, and review prompt.
- A Large Auth/DB/payment/refactor task needs multiple planning views, clear ownership, ADR consideration, and repeated human confirmation.
- Several worker chats return reports, and the supervisor needs to classify the report type, compare it against the original plan, decide the next owner, and produce the next paste-ready prompt.
- A completed PR needs closeout summary, active task cleanup, and branch/worktree cleanup candidates.

## First Response Design

The first response must not classify the task, propose AI count, create branch/worktree, or write an implementation plan.

Required first response shape:

```md
理解確認：
やりたいことは「<current behavior or object>」を「<desired behavior>」にすることですね。
現時点では <explicit exclusions> は含めず、まず <initial scope> の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

If the request is ambiguous, the Skill should ask only the minimum clarification needed to write the understanding confirmation. It should not use ambiguity as a reason to jump into a full plan.

## Post-Confirmation Output Design

After the user confirms, the Skill emits a complete execution pack:

```md
## Understanding Confirmed

<confirmed request>

## Task Size

Small / Medium / Large

## Reason

<why this classification fits>

## Execution Surface

Codex App Local / Codex App Worktree / Orca / Codex Cloud / Terminal / codex exec

## Agent Setup

<agent count and roles>

## Branch / Worktree / Port

- Branch:
- Worktree:
- Port:
- Naming reason:
- Collision checks:

## Documentation Plan

- Create:
- Update:
- Maybe:
- Do Not Update:
- Closeout:

## Workflow

1. <step>
2. <step>
3. <step>

## Prompt Pack

### Planning Prompt
<only if needed>

### Implementation Prompt
<only if needed>

### Review Prompt
<only if needed>

### Integrator Prompt
<only if needed>

### Progress Return Prompt
<only if needed>

### Closeout Report Prompt
<only if needed>

## Return Instructions

<what worker outputs must be returned to the supervisor chat>

## Human Confirmation

この方針で進めてよいか。
```

## Task Size Rubric

### Small

Examples:

- Text change
- A few CSS lines
- README or docs typo
- Comment-only change
- Light change in 1-2 files
- No DB/Auth/API/production effect

Operation:

- 1AI
- Codex App Local or Codex App Worktree
- Docs update usually unnecessary
- PR optional
- Task doc unnecessary
- Branch recommended if another AI will work on it

### Medium

Examples:

- UI improvement
- New screen
- Light API change
- Multiple files
- Existing feature behavior changes
- Localhost verification needed

Operation:

- Codex App Worktree or Orca
- Orca when several Medium tasks run in parallel
- Implementation AI + Review AI
- Branch + worktree recommended and usually required
- Create `docs/tasks/active/<branch-name>.md`
- Update `docs/tasks/ACTIVE_TASKS.md`
- PR recommended and usually required
- Run localhost verification
- Run `npm run build` or repository equivalent

### Large

Examples:

- Auth
- DB
- Billing
- Migration
- External API integration
- Production data effect
- Major refactor
- Multiple feature areas
- Ambiguous specification
- Need for design comparison
- Need for current/latest information research

Operation:

- Orca recommended
- Planning AI A/B + Integrator AI + Implementation AI + Review AI
- Branch + worktree required
- Task doc required
- ACTIVE_TASKS update required
- Draft PR recommended
- ADR when decisions are durable
- Multiple human approval gates

## Execution Surface Rules

### Codex App Local

Use when:

- Small work
- One local working copy is enough
- Docs update is unnecessary or tiny
- No branch/worktree isolation is needed

### Codex App Worktree

Use when:

- One Medium task needs isolation
- Diff, commit, push, and PR should stay inside the app workflow
- Localhost verification is needed
- The task has clear ownership and a bounded branch

### Orca

Use when:

- Medium tasks are truly parallel
- Large work needs multiple terminals, worktrees, or browser contexts
- Planning, implementation, review, and integration should be separated
- Several UI or architecture alternatives need comparison
- The user needs visible overall coordination

### Codex Cloud

Use when:

- The task is self-contained
- It does not depend on local `.env`, local DB, browser login, or private runtime state
- The task is a light fix, test addition, PR review, or repository-only investigation

### Terminal / `codex exec`

Use when:

- The output is a non-interactive plan, review summary, or file artifact
- The work is deterministic and can run as a command
- The result should be saved to a file

## Agent Setup Rules

### 1AI

Use for Small tasks and simple Medium tasks where implementation and verification can be handled in one context.

### Implementation AI + Review AI

Use for Medium tasks where behavior changes, UI checks, API changes, or multiple files introduce review risk.

### Planning AI A/B + Integrator AI + Implementation AI + Review AI

Use for Large tasks where the plan itself is uncertain or competing designs need comparison.

Responsibilities:

- Planning AI A: propose architecture and risk model.
- Planning AI B: challenge scope, alternatives, and test plan.
- Integrator AI: own contracts, merge order, conflicts, and final verification.
- Implementation AI: implement only the assigned scope and allowed files.
- Review AI: review behavior, tests, security, docs, and acceptance criteria.

## Branch / Worktree / Port Naming

Branch name:

```text
feat/<short-purpose>
fix/<short-purpose>
chore/<short-purpose>
docs/<short-purpose>
```

Worktree name:

```text
../<repo-name>-wt-<short-purpose>
```

Port rule:

- Prefer the repository's documented default port if no parallel work exists.
- For parallel web work, reserve an explicit port per worktree.
- Suggested range: main on `3000`, feature worktrees on `3001-3005`, unless the repository already documents another range.
- Check collisions before assigning: `lsof -i :<port>`.

Naming requirements:

- Use lowercase ASCII letters, digits, hyphens, and branch slashes only.
- Do not use Japanese, spaces, uppercase letters, underscores, or other symbols in branch/worktree names.
- Put Japanese explanations in the Orca task name, Issue, PR body, or task doc.
- Keep the name readable in PR, worktree, and task doc paths.
- Include the task's main noun, not a vague label like `misc` or `updates`.
- Treat five worktrees as the maximum; if five or more exist, list them, propose cleanup candidates, and wait for human approval.
- Do not open the same branch in multiple worktrees.
- Do not create branches or worktrees before human confirmation.

Alternative comparison requirements:

- UI or implementation alternatives must use separate branch/worktree/port assignments.
- Example: `experiment/login-ui-a` / `repo-wt-login-ui-a` / `3001` and `experiment/login-ui-b` / `repo-wt-login-ui-b` / `3002`.
- Only the winning option becomes a PR.
- Losing options must not merge and become cleanup candidates.
- Do not mix multiple alternatives in the same worktree.

## Documentation Plan Rules

### AGENTS.md

Use for stable AI constitution only. Do not write dynamic task information here.

### README.md

Use for human-facing project overview, setup, and durable usage notes.

### ROADMAP.md

Use for Now / Next / Later / Not Now planning when the task changes product direction or release sequencing.

### `docs/PROJECT_SPEC.md`

Use for durable current project facts:

- Current product behavior
- Tech stack
- Deploy destination
- Local development method
- DB/Auth/external integrations
- Environment variable policy
- Major directory structure

### `docs/DOCS_PROFILE.md`

Use to define which docs this repository updates and when.

### `docs/tasks/ACTIVE_TASKS.md`

Use for active branch/worktree index.

Recommended columns:

| Status | Branch | Worktree | Purpose | Size | Surface | Agents | Port | Task Doc | Last Updated |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

### `docs/tasks/active/<branch-name>.md`

Use for branch/worktree-specific task state.

Required sections:

- User Request
- Confirmed Understanding
- Scope
- Out of Scope
- Task Size
- Execution Surface
- Agent Setup
- Branch / Worktree / Port
- Done Criteria
- Verification
- Status
- Notes

### `docs/tasks/archive/`

Use only for past work worth retaining. Do not archive every trivial task.

### ADRs: `docs/adr/` or `docs/decisions/`

Use when a decision should survive the branch:

- Architecture direction
- DB/migration strategy
- Auth/billing/security policy
- External integration contract
- Significant tradeoff or rejected alternative

Path policy:

- Prefer the repository's existing ADR directory.
- In this repository, the existing directory is `docs/adr/`.
- If a repository already uses `docs/decisions/ADR-xxx.md`, respect that.
- If neither exists, propose the path in `docs/DOCS_PROFILE.md` before creating ADRs.

## Docs Update Rules By Size

### Small

- Usually no docs update.
- Commit message or PR body is enough.
- No task doc.

### Medium

- Create active task doc.
- Update ACTIVE_TASKS.
- Summarize in PR body after implementation.
- On closeout, remove or archive active task doc.
- Remove task from ACTIVE_TASKS.

### Large

- Create active task doc.
- Update ACTIVE_TASKS.
- Update ROADMAP if sequencing changes.
- Create ADR if durable decisions are made.
- Summarize in PR body after implementation.
- On closeout, remove or archive active task doc.
- Remove task from ACTIVE_TASKS.

## Prompt Pack Specification

### Planning Prompt

Use when the implementation plan needs another planning pass.

Must include:

- Confirmed understanding
- Constraints and non-goals
- Affected surfaces
- Questions to answer
- Output format: architecture, risks, acceptance criteria, suggested decomposition
- Explicit no-write instruction when planning only

### Implementation Prompt

Use for an implementation worker.

Must include:

- Confirmed request
- Allowed files or directories
- Out-of-scope items
- Branch/worktree/port assignment
- Required docs updates
- Required verification commands
- Commit expectation, if any
- Push/merge/deploy prohibition unless explicitly approved
- Return report format

### Review Prompt

Use for a reviewer.

Must include:

- Original confirmed request
- Diff or files to inspect
- Acceptance criteria
- Known risks
- Required output: findings first, severity, file/line references, missing tests, residual risk
- No broad refactor instruction

### Integrator Prompt

Use when multiple branches or worker results must be merged.

Must include:

- All worker branches and reports
- Shared contracts
- Merge order
- Conflict policy
- Verification matrix
- Final docs cleanup
- Human gates before main merge or deploy

### Progress Return Prompt

Use when worker chats return to the supervisor.

Must include:

- Branch/worktree
- Commit hash, if any
- Files changed
- Tests run and results
- Screenshots or localhost verification, if applicable
- Unfinished items
- Risks or decisions needed
- Cleanup status

### Closeout Report Prompt

Use after implementation and review pass.

Must include:

- PR body summary
- Verification evidence
- Active task doc cleanup choice
- ACTIVE_TASKS cleanup
- ROADMAP/ADR updates if needed
- Branch/worktree cleanup candidates
- Explicit human gate for main merge, deploy, and destructive cleanup

## Return Instructions

Workers must return enough information for the supervisor to decide the next step without re-reading the whole branch:

- What was changed
- Why it matches the confirmed request
- Exact verification commands and outcomes
- Any failed or skipped checks
- Files changed
- Commit hash or uncommitted status
- Open questions
- Whether the active task doc and ACTIVE_TASKS were updated
- Whether the worktree/branch should remain active, be integrated, or be abandoned

## Closeout Specification

Before completion, the Skill should check:

- PR body includes purpose, changes, verification, impact, and unfinished items.
- Active task doc is deleted or archived.
- ACTIVE_TASKS no longer lists completed work.
- ROADMAP is updated only when roadmap meaning changed.
- ADR is updated only when durable decisions changed.
- Branch/worktree cleanup candidates are listed.
- Main merge, deploy, branch deletion, and worktree deletion require explicit human approval.

## Proposed Skill Directory

```text
~/.agents/skills/coding-task-orchestrator/
  SKILL.md
  workflows/
    01-intake-understanding.md
    02-classify-task-size.md
    03-choose-execution-surface.md
    04-plan-agent-setup.md
    05-plan-branch-worktree.md
    06-plan-docs-lifecycle.md
    07-generate-prompt-pack.md
    08-monitor-progress.md
    09-closeout-task.md
  references/
    task-size-rubric.md
    execution-surfaces.md
    agent-role-patterns.md
    docs-lifecycle.md
    project-context-docs.md
    orca-patterns.md
    codex-app-patterns.md
    codex-cloud-patterns.md
  templates/
    active-task-doc.md
    active-tasks-index.md
    project-spec.md
    docs-profile.md
    prompt-planning.md
    prompt-implementation.md
    prompt-review.md
    prompt-integrator.md
    progress-return.md
    closeout-report.md
```

## SKILL.md Design

The hub `SKILL.md` should stay below 200 lines if possible and below 500 lines as a hard cap.

Frontmatter draft:

```yaml
---
name: coding-task-orchestrator
description: Confirms coding task intent before planning, then classifies task size, selects execution surface, plans agents, branch/worktree/port/docs lifecycle, generates worker prompts, supervises returned progress, and guides closeout. Use when a user asks for development work, task decomposition, worktree/Orca/Codex routing, multi-agent prompts, implementation supervision, or cleanup planning.
---
```

Core sections:

- Purpose
- Loading Policy
- Trigger Conditions
- Two-Phase Rule
- Mode Routing
- Safety Policy
- Output Contracts
- Human Gates
- Related Skills

Related Skills:

- `requirements-governor`: requirements, contradictions, non-goals, acceptance criteria, progress truth.
- `skill-creator-custom`: Skill creation and compatibility review.
- `task-router`: existing development routing patterns to compare or migrate from.
- `kaihatsu-kanri`: broader project-management governance when working inside `起業スキル`.

## Workflow File Responsibilities

### `01-intake-understanding.md`

Owns the first response. It must stop at understanding confirmation and permission to proceed.

### `02-classify-task-size.md`

Owns Small / Medium / Large classification and reason generation.

### `03-choose-execution-surface.md`

Owns Codex App Local, Codex App Worktree, Orca, Codex Cloud, Terminal, and `codex exec` selection.

### `04-plan-agent-setup.md`

Owns AI count, role assignment, and when not to split.

### `05-plan-branch-worktree.md`

Owns branch/worktree/port naming, collision checks, and approval gates.

### `06-plan-docs-lifecycle.md`

Owns Create / Update / Maybe / Do Not Update / Closeout docs planning.

### `07-generate-prompt-pack.md`

Owns prompt templates and when each prompt is included.

### `08-monitor-progress.md`

Owns returned-report interpretation, status board, rework decisions, and integration readiness.

### `09-closeout-task.md`

Owns PR body, task doc cleanup, ACTIVE_TASKS cleanup, archive decisions, and human gates.

## Implementation Plan And Result

### Phase 1: Confirm Placement and Overlap

1. Decide whether `coding-task-orchestrator` is the successor to `task-router` or a new stricter Skill.
2. Decide canonical source path:
   - Recommended: `~/.agents/skills/coding-task-orchestrator/` as requested.
   - Alternative: repository source under `起業スキル/skills/` with global symlinks.
3. Confirm whether `docs/tasks/` should be the standard even in repos that already use `docs/ai/task-board.md`.

Resolved on 2026-06-26:

- `coding-task-orchestrator` is a stricter confirmation-first Skill, not a `task-router` replacement.
- Canonical source path is `~/.agents/skills/coding-task-orchestrator/`.
- `docs/tasks/` is the default for new task tracking; repositories already using `docs/ai/task-board.md` must keep or explicitly migrate that convention.
- Human confirmation for Phase 2 was satisfied by the implementation request.

### Phase 2: Create Hub and Split Files

1. Create `SKILL.md` with frontmatter and lightweight routing.
2. Create all `workflows/` files with clear entry and exit conditions.
3. Create `references/` files for rubrics and environment rules.
4. Create `templates/` files for task docs, indexes, prompts, and closeout reports.
5. Keep workflow and template names stable so prompts can reference them directly.

### Phase 3: Add Safety and Governance Gates

1. Ensure the first-response rule forbids classification before user confirmation.
2. Add hard gates for branch/worktree creation, main merge, deploy, destructive cleanup, production DB, secret handling, and force pushes.
3. Add repository-docs fallback behavior:
   - If `docs/PROJECT_SPEC.md` is missing, propose creating it for Medium/Large only.
   - If `docs/DOCS_PROFILE.md` is missing, propose creating it before broad docs changes.
   - If requirements governance exists, route contradictions to it.
4. Add "do not over-document Small tasks" rule.

### Phase 4: Manual Prompt Tests

Run at least these manual tests:

1. Small typo request: verify the first response asks only for understanding confirmation.
2. Confirmed Small request: verify docs/task doc are not over-prescribed.
3. Confirmed Medium UI request: verify branch/worktree/task doc/ACTIVE_TASKS/localhost/build/review are included.
4. Confirmed Large Auth request: verify Orca, Planning A/B, ADR, repeated human gates, and no auto-merge.
5. Worker return report: verify supervisor can decide continue/review/integrate/rework.
6. UI comparison scenario: verify each option gets its own branch/worktree/port.
7. Worker return report: verify supervisor can decide continue/review/integrate/rework.
8. Closeout scenario: verify PR body and docs cleanup instructions.

### Phase 5: Compatibility and Registration

1. Check file list:

   ```sh
   find ~/.agents/skills/coding-task-orchestrator -maxdepth 3 -type f | sort
   ```

2. Check line count:

   ```sh
   wc -l ~/.agents/skills/coding-task-orchestrator/SKILL.md
   ```

3. If mirrored:

   ```sh
   test -e ~/.codex/skills/coding-task-orchestrator/SKILL.md
   test -e ~/.claude/skills/coding-task-orchestrator/SKILL.md
   ```

4. If repository check scripts apply:

   ```sh
   bash scripts/agent-instructions/check-skill-compatibility.sh
   ```

   This script currently verifies `requirements-governor`, not `coding-task-orchestrator`, and rewrites `docs/agent/compatibility-checklist.md`. Do not use it as formal `coding-task-orchestrator` evidence unless it is generalized or replaced by a dedicated check.

## Implementation Prompt

```md
You are implementing the `coding-task-orchestrator` Skill from the plan at `docs/tasks/active/coding-task-orchestrator-plan.md`.

Scope:
- Create the Skill files only after confirming canonical placement.
- Use a lightweight `SKILL.md` hub and split details into workflows, references, and templates.
- Preserve the mandatory two-phase behavior: first response is understanding confirmation only; post-confirmation emits the execution pack.
- Do not create branches, worktrees, PRs, or task docs as part of the Skill implementation except the Skill's own files and any explicitly approved registration docs.

Required files:
- `SKILL.md`
- workflows `01` through `09`
- references listed in the plan
- templates listed in the plan

Hard rules:
- No auto merge, push, deploy, destructive git cleanup, production DB operation, or secret exposure.
- Do not put dynamic task information in AGENTS.md.
- Do not replace `requirements-governor`; route requirements conflicts to it.
- Keep `SKILL.md` below 200 lines if possible and below 500 lines absolutely.

Verification:
- `find <skill-path> -maxdepth 3 -type f | sort`
- `wc -l <skill-path>/SKILL.md`
- frontmatter review
- manual prompt tests for first response, Small, Medium, Large, worker return, and closeout

Return:
- Files created
- Line counts
- Verification results
- Any skipped checks and why
- Open questions
```

## Review Prompt

```md
Review the implemented `coding-task-orchestrator` Skill against `docs/tasks/active/coding-task-orchestrator-plan.md` and `docs/specs/coding-task-orchestrator-skill/requirements.md`.

Focus on bugs and operational risks:
- Does the first-response rule truly prevent premature task classification?
- Are Medium/Large docs requirements strong enough without overburdening Small tasks?
- Are human gates explicit for branch/worktree creation, main merge, deploy, and cleanup?
- Does it avoid dynamic task state in AGENTS.md?
- Does it distinguish Codex App Local, Worktree, Orca, Codex Cloud, Terminal, and `codex exec`?
- Does it overlap with `task-router` in a confusing way?
- Are prompt templates specific enough for worker chats?
- Is `SKILL.md` lightweight and progressively disclosed?

Output findings first with severity and file references, then open questions, then a brief summary.
```

## Integrator Prompt

```md
Integrate the `coding-task-orchestrator` Skill implementation after implementation and review reports are returned.

Inputs:
- Implementation report
- Review report
- Skill file list
- Manual prompt test results
- Any global placement or symlink decisions

Tasks:
- Confirm all required files exist.
- Resolve review findings or mark them as explicit follow-up.
- Confirm the canonical source and any symlinks/copies.
- Update requirements ledger/progress board only with evidence.
- Prepare final closeout summary.
- Do not merge, push, deploy, or delete branches/worktrees without human approval.

Return:
- Integrated status
- Remaining findings
- Verification evidence
- Recommended cleanup actions
```

## Review Checklist

- The first response cannot include task size, execution surface, agent count, branch, worktree, port, or implementation steps.
- The post-confirmation pack contains all required headings.
- Small tasks stay lightweight.
- Medium/Large tasks create enough traceability.
- Branch/worktree/port creation is proposed, not performed, before approval.
- Docs lifecycle is explicit and avoids AGENTS.md bloat.
- Closeout includes PR summary and active task cleanup.
- Risky operations are gated.
- `task-router` overlap is addressed in docs.
- `requirements-governor` is referenced for requirements conflicts.

## Risks and Countermeasures

| Risk | Countermeasure |
| --- | --- |
| The new Skill duplicates `task-router`. | Implemented as a stricter confirmation-first alternative and documented that it does not replace `task-router`. |
| The Skill becomes too heavy for Small tasks. | Hard-code Small as lightweight: no task doc, docs update usually unnecessary, one AI. |
| The Skill overuses worktrees. | Require explicit reason, collision checks, five-worktree maximum, and closeout classification before creating worktrees. |
| The `.agents` canonical source is outside git. | Future recommendation: move canonical source to git-managed `skills/coding-task-orchestrator/` and symlink `.agents`, `.codex`, and `.claude` to it. Do not move it in this patch without human approval. |
| Dynamic task state leaks into AGENTS.md. | Put active task state only under `docs/tasks/`; AGENTS.md receives only stable routing rules if ever needed. |
| Worker prompts are too vague. | Templates must include scope, allowed files, verification, return format, and prohibitions. |
| Closeout is forgotten. | Make closeout a required workflow and include ACTIVE_TASKS/task-doc cleanup in every Medium/Large plan. |
| Orca availability is assumed. | Add fallback to Codex App Worktree or sequential Codex when Orca is not available. |
| Requirements docs drift. | Route feature/spec/progress conflicts to `requirements-governor` and avoid marking done without evidence. |

## Resolved Decisions

- Canonical source path: `~/.agents/skills/coding-task-orchestrator/`.
- Symlink strategy: `.codex/skills/coding-task-orchestrator` and `.claude/skills/coding-task-orchestrator` point to the canonical source.
- Relationship to `task-router`: stricter confirmation-first alternative, not a replacement.
- `docs/tasks/` default: use it for new task tracking; preserve `docs/ai/task-board.md` where a repository already standardizes on it unless migration is explicitly approved.
- Default port range: main on `3000`, feature worktrees on `3001-3005`, unless a repository documents another range.
- Orca handoff syntax: document role/return patterns and provide fallback to Codex App Worktree or sequential Codex chats when Orca is unavailable.

## Human Confirmation Result

Implementation was approved by the user's request on 2026-06-26 and completed, with the review patch and returned-report supervisor evaluation patches applied on 2026-06-26. `REQ-027` is `done` after the basic six live prompt cases, additional six live prompt cases, and real branch/worktree closeout/worker-return evidence were recorded. Risky operations remain gated by the implemented Skill: `git reset --hard`, `git clean -fd`, `git push --force`, remote branch deletion, branch deletion, worktree deletion, main merge, production deploy, migration apply, secrets / `.env` change or disclosure, and production DB/data operation require explicit human approval.
