---
name: coding-task-orchestrator
description: Confirms coding task intent before planning, then classifies task size, selects execution surface, plans agents, branch/worktree/port/docs lifecycle, generates worker prompts, supervises returned progress, and guides closeout. Use when a user asks for development work, task decomposition, worktree/Orca/Codex routing, multi-agent prompts, implementation supervision, or cleanup planning.
---

# coding-task-orchestrator

Confirmation-first orchestration for coding work. This Skill prevents premature implementation by confirming the user's intended change before classifying task size, choosing an execution surface, assigning AI roles, proposing branch/worktree/port/docs handling, generating worker prompts, monitoring returns, and closing out.

## Relationship To Existing Skills

- `task-router` is the broader heavy-development router and uses `docs/ai/task-board.md`.
- `coding-task-orchestrator` is a stricter confirmation-first intake and supervision Skill. It does not replace `task-router`; route to `task-router` only when a repository already standardizes on that workflow or the user explicitly asks for it.
- `repo-create` owns first-time repository setup, GitHub remote/upstream connection, baseline folders, and small commit/push closeout. Route there when the target repo is not yet connected or lacks a minimal AI-work structure.
- When coding docs lifecycle, task-state, or intake defaults change, check whether `repo-create` should update its minimal `AGENTS.md` / Context Pack templates.
- `requirements-governor` owns requirements conflicts, non-goals, acceptance criteria, and progress truth.
- `skill-creator-custom` owns Skill creation/review conventions.

## Loading Policy

1. For a fresh user coding request, read only `workflows/01-intake-understanding.md` first.
2. After the user confirms the understanding, run the Repo Minimum Operation Gate, then use workflows `02` through `07` to produce the execution pack.
3. When worker results come back, use `workflows/08-monitor-progress.md`.
4. When the task is ready to finish, use `workflows/09-closeout-task.md`.
5. Read references and templates only when their workflow needs them.

## Repo Minimum Operation Gate

Before planning normal implementation, check the target repository's minimal operation path:

- nearest `AGENTS.md` or `CLAUDE.md`
- `docs/agent/active-context.md` or repo-equivalent active context
- `docs/tasks/README.md`
- `docs/tasks/ACTIVE_TASKS.md`
- `docs/tasks/quick-log.md`
- active task convention under `docs/tasks/active/`
- archive convention under `docs/tasks/archive/`
- any repo-standard `docs/ai/task-board.md` convention

If required context is missing, or if completed work remains in `docs/tasks/active/`, do not continue to normal implementation planning. Report the missing or stale structure and propose the smallest setup. If the user has already approved setup, switch to that setup first.

Small tasks stay lightweight: no active task doc or `ACTIVE_TASKS` row by default, with `quick-log.md` only when a durable note is useful. Medium/Large tasks use `ACTIVE_TASKS` and an active task doc when required by risk, Orca, Review AI, PR-required work, multiple-file changes, or local repo rules.

## Trigger Conditions

Use this Skill for development requests, task decomposition, Codex App vs Orca vs Cloud decisions, branch/worktree/port planning, multi-agent prompt packs, returned-progress supervision, and closeout cleanup.

Do not use it for purely strategic life decisions, sales tactics, legal/regulatory detail, or non-coding workflows unless the user asks to adapt it.

## Two-Phase Rule

### Phase 1: Understanding Only

The first response must only confirm understanding and ask whether planning may proceed. It must not include task size, execution surface, AI count, branch, worktree, port, docs plan, prompt pack, or implementation steps.

Required first response shape:

```md
理解確認：
やりたいことは「<current behavior or object>」を「<desired behavior>」にすることですね。
現時点では <explicit exclusions> は含めず、まず <initial scope> の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

If the request is too ambiguous to fill this shape, ask the minimum clarification needed and stop.

### Phase 2: Execution Pack After Confirmation

After the user confirms, output exactly these sections:

- Understanding Confirmed
- Task Size
- Reason
- Execution Surface
- Agent Setup
- Branch / Worktree / Port
- Documentation Plan
- Workflow
- Prompt Pack
- Return Instructions
- Human Confirmation

## Size And Surface Summary

- Small: 1AI, usually Codex App Local or Worktree, no task doc, docs update usually unnecessary, PR optional.
- Medium: Implementation AI + Review AI by default, Codex App Worktree or Orca, branch/worktree/task doc/ACTIVE_TASKS recommended, PR and local verification usually required. Light Medium tasks may keep task docs and ACTIVE_TASKS recommended only when the work is narrow and the docs plan says they are not required.
- Large: Planning AI A/B + Integrator + Implementation + Review, Orca recommended, branch/worktree/task doc/ACTIVE_TASKS required, ADR and repeated human gates when durable decisions or production risk exist.

Execution surfaces:

- Codex App Local
- Codex App Worktree
- Orca
- Codex Cloud
- Terminal
- `codex exec`

## Documentation Rules

- `AGENTS.md`: stable AI constitution only. Never write dynamic task state here.
- `docs/agent/active-context.md`: short current orientation only. Do not use it as a log.
- `ROADMAP.md`: update only when sequencing or product direction changes.
- `docs/PROJECT_SPEC.md`: read for durable project facts; propose creation for Medium/Large when missing.
- `docs/DOCS_PROFILE.md`: read for docs policy; propose creation before broad docs changes when missing.
- `docs/tasks/README.md`: local task lifecycle convention.
- `docs/tasks/ACTIVE_TASKS.md`: active branch/worktree index.
- `docs/tasks/active/<branch-name>.md`: branch/worktree-specific task state.
- `docs/tasks/archive/`: retain only completed work worth keeping.
- `docs/tasks/quick-log.md`: Small tasks, investigations, and task-doc-below work.
- ADRs: prefer the repository's existing `docs/adr/`; use `docs/decisions/ADR-xxx.md` when that is the local convention.
- PR body: final summary, verification, impact, and unfinished items.

## Branch And Worktree Governance

- Treat five worktrees as the maximum. If there are five or more, report `Worktree Limit Reached`, list current worktrees, propose cleanup candidates, and wait for human approval before creating or deleting anything.
- Do not open the same branch in multiple worktrees.
- Branch and worktree names must use lowercase ASCII letters, digits, hyphens, and slashes only. Do not use Japanese, spaces, uppercase letters, underscores, or other symbols.
- Put Japanese descriptions in the Orca task name, Issue, PR body, or task doc, not in branch or worktree names.
- Branch/worktree cleanup requires explicit human approval.
- When comparing UI or implementation alternatives, separate each option into its own branch, worktree, and port. Only the winning option should become a PR; losing options become cleanup candidates and must not be mixed into the same worktree.

## Human Gates

Human confirmation is required before:

- creating branches, worktrees, task docs, or docs indexes when not already approved;
- merging to main;
- cleaning up branches or worktrees;
- pushing, broad refactors, or other operations outside the confirmed scope;
- `git reset --hard`;
- `git clean -fd`;
- `git push --force`;
- remote branch deletion;
- branch deletion;
- worktree deletion;
- main merge;
- production deploy;
- migration apply;
- secrets / `.env` change or disclosure;
- production DB/data operation;
- marking requirements or tasks done without evidence.

## Supervisor Mode

When planning, implementation, review, integration, blocker, or closeout reports return, the supervisor chat must evaluate the content instead of only forwarding it. Use `workflows/08-monitor-progress.md` and, when useful, `templates/supervisor-evaluation.md` to classify the report type, compare it against the original request and accepted plan, choose the next decision, and emit a paste-ready `Prompt To Use Next`.

Worker recommendations are advisory only. The supervisor owns the final Returned Report Type, comparison, Decision, Next Action, and Prompt To Use Next.

## Output Contracts

- First response: use `workflows/01-intake-understanding.md`.
- Post-confirmation execution pack: combine workflows `02` through `07`.
- Returned worker supervision: use `workflows/08-monitor-progress.md`.
- Closeout: use `workflows/09-closeout-task.md`.

Templates live in `templates/`. Rubrics and environment details live in `references/`.
