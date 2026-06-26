# Coding Task Orchestrator Skill Requirements

Status: done
Created: 2026-06-26
Implemented: 2026-06-26
Review Patch: 2026-06-26
Supervisor Evaluation Patch: 2026-06-26
Real Operation Evidence: 2026-06-26

## Summary

Create a new global Skill, `coding-task-orchestrator`, that handles coding task intake before implementation. The Skill must confirm the user's intended change first, wait for user approval, then classify task size, choose an execution surface, plan agents, propose branch/worktree/port conventions, plan documentation lifecycle, generate worker prompts, supervise returned progress, and guide closeout cleanup.

The user approved implementation on 2026-06-26. The Skill was implemented at `~/.agents/skills/coding-task-orchestrator/`, with `.codex/skills` and `.claude/skills` symlinks pointing to that canonical source.

After review, the supervisor evaluation patch, the six-case live manual prompt test, the additional returned-report prompt test, and the real branch/worktree representative operation evidence, the Skill is formally complete for `REQ-027`. The real operation evidence records worker-return supervision, closeout judgment, and explicit non-execution of prohibited operations.

## Related Requirements

- REQ-027

## Acceptance Criteria

- [x] The first response pattern performs only understanding confirmation and asks whether task-size, agent, execution-surface, branch/worktree, and docs planning may proceed.
- [x] The post-confirmation response emits a complete execution pack with: Understanding Confirmed, Task Size, Reason, Execution Surface, Agent Setup, Branch / Worktree / Port, Documentation Plan, Workflow, Prompt Pack, Return Instructions, and Human Confirmation.
- [x] Small / Medium / Large classification criteria are explicit and conservative.
- [x] Codex App Local, Codex App Worktree, Orca, Codex Cloud, Terminal, and `codex exec` selection rules are explicit.
- [x] AI role patterns cover 1AI, Implementation + Review, and Planning A/B + Integrator + Implementation + Review.
- [x] Branch, worktree, and port naming rules include collision checks and human approval points.
- [x] Documentation rules distinguish AGENTS.md, README.md, ROADMAP.md, `docs/PROJECT_SPEC.md`, `docs/DOCS_PROFILE.md`, `docs/tasks/ACTIVE_TASKS.md`, `docs/tasks/active/<branch-name>.md`, `docs/tasks/archive/`, and ADRs.
- [x] Prompt templates exist for planning, implementation, review, integrator, progress return, and closeout.
- [x] Closeout rules summarize PR content, task doc archival/removal, ACTIVE_TASKS cleanup, ROADMAP/ADR updates, and branch/worktree cleanup candidates.
- [x] The Skill structure uses a lightweight `SKILL.md` hub with details split into `workflows/`, `references/`, and `templates/`.
- [x] The Skill explicitly forbids automatic merge, deploy, destructive git operations, production data changes, and writing dynamic task information into AGENTS.md.
- [x] The implementation includes verification commands for file list, line counts, frontmatter, and global Skill placement.
- [x] Worktree governance aligns with `agents-md-governance`: maximum five worktrees, no duplicate branch checkout across worktrees, lowercase ASCII/digit/hyphen/slash names only, Japanese descriptions outside branch/worktree names, and human approval before cleanup.
- [x] UI or implementation alternative comparison separates each option by branch, worktree, and port; only the winning option becomes a PR and losing options become cleanup candidates.
- [x] Prompt Pack output visibly includes `Progress Return Prompt` and `Closeout Report Prompt`.
- [x] Active task docs separate progress `Status` from `Closeout Classification`.
- [x] Supervisor Mode classifies returned reports as Planning Result, Integrator Result, Implementation Report, Review Report, Error / Blocker Report, Closeout Report.
- [x] Returned reports are compared against original user request, Confirmed Understanding, task doc, Scope / Out of Scope, Done Criteria, Verification, previous plan, previous review, and requirements when available.
- [x] Supervisor decisions include Proceed, Needs Clarification, Send to Review, Return to Implementation, Return to Planning, Human Approval Needed, Stop: Safety Risk, and Closeout Ready.
- [x] Supervisor output includes Returned Report Type, Current Evaluation, Compared Against, What Looks Good, Problems / Gaps, Decision, Next Action, and Prompt To Use Next.
- [x] Prompt To Use Next emits paste-ready prompts for implementation correction, review request, replanning, human approval, safety stop, or closeout.
- [x] Medium handling allows light Medium task docs and ACTIVE_TASKS to remain recommended only, while requiring task docs for multiple-file changes, existing feature impact, Review AI usage, Orca usage, PR-required work, or local rules.
- [x] Uncertainty-only Large upgrades can use a short investigation phase before classifying as Large.
- [x] Live manual prompt transcripts cover Small, Medium, Large, UI comparison, Worker Return, and Closeout cases.
- [x] Real operation evidence records returned-worker supervision and closeout behavior.

## Non-Goals

- Do not implement the Skill during the planning step.
- Do not create branches, worktrees, or ports before the user confirms the execution plan.
- Do not merge, push, deploy, delete worktrees, or run destructive git commands automatically.
- Do not turn AGENTS.md into a dynamic task board.
- Do not replace `requirements-governor`; the new Skill should route requirements/spec/progress contradictions to it.
- Do not require docs updates for trivial Small changes unless the repository's own rules demand it.

## Impacted Surfaces

- Proposed global Skill path: `~/.agents/skills/coding-task-orchestrator/`
- Optional global mirrors or symlinks: `~/.codex/skills/coding-task-orchestrator/`, `~/.claude/skills/coding-task-orchestrator/`
- Planning artifact: `docs/tasks/active/coding-task-orchestrator-plan.md`
- Requirements artifact: `docs/specs/coding-task-orchestrator-skill/requirements.md`
- Requirements ledger and progress board entries for REQ-027
- Related existing Skill to compare against: `task-router`
- Related governance Skill: `requirements-governor`

## Resolved Decisions

- `coding-task-orchestrator` remains a stricter confirmation-first alternative focused on intake and supervision; it does not replace `task-router`.
- The canonical Skill source is `~/.agents/skills/coding-task-orchestrator/`.
- `.codex/skills/coding-task-orchestrator` and `.claude/skills/coding-task-orchestrator` are symlinks to the canonical source.
- Default new-task tracking uses `docs/tasks/`, but repositories that already use `docs/ai/task-board.md` must keep or explicitly migrate their local convention.
- Orca handoff is documented as a pattern with fallback to Codex App Worktree or sequential Codex chats when Orca is unavailable.
- Default parallel web ports are main on `3000` and feature worktrees on `3001-3005` unless the repository documents another range.

## Canonical Source Risk

Current canonical source is `~/.agents/skills/coding-task-orchestrator/`, and `.codex/skills/coding-task-orchestrator` plus `.claude/skills/coding-task-orchestrator` are symlinks to it. This is operationally simple, but `.agents` is outside the git-managed repository sources, so the canonical Skill can drift or be lost without a normal repo diff.

Recommended future state:

- Move the canonical source to a git-managed path such as `skills/coding-task-orchestrator/`.
- Point `.agents`, `.codex`, and `.claude` skill paths to that git-managed source by symlink.
- Do not move it as part of this review patch without separate human approval.

## Completion Evidence Expected

- `find ~/.agents/skills/coding-task-orchestrator -maxdepth 3 -type f | sort`
- `wc -l ~/.agents/skills/coding-task-orchestrator/SKILL.md`
- Frontmatter inspection confirms `name: coding-task-orchestrator` and a third-person `description`.
- Manual prompt tests confirm the first response does not classify before user confirmation.
- Manual prompt tests cover Small, Medium, Large, closeout, and returned-worker-report scenarios.
- Manual prompt test evidence is tracked in `docs/specs/coding-task-orchestrator-skill/manual-prompt-tests.md`.
- Symlink or copy checks confirm intended availability from Codex, Claude Code, and agents paths.

## Completion Evidence

- `find ~/.agents/skills/coding-task-orchestrator -maxdepth 3 -type f | sort` returned 29 files after `templates/supervisor-evaluation.md` was added.
- `wc -l ~/.agents/skills/coding-task-orchestrator/SKILL.md` returned 133 lines after the returned-report evaluation patch.
- Frontmatter includes `name: coding-task-orchestrator` and a third-person `description`.
- `.codex/skills/coding-task-orchestrator` and `.claude/skills/coding-task-orchestrator` symlink to `~/.agents/skills/coding-task-orchestrator`.
- Required-file check passed.
- Trailing whitespace check returned no matches.
- Previous acceptance keyword check passed 17/17 before the supervisor evaluation patch; current static taxonomy checks passed for returned-report and forbidden-operation keywords.
- `bash scripts/agent-instructions/check-skill-compatibility.sh` passed for its current `requirements-governor` scope, but it is not accepted as formal `coding-task-orchestrator` verification evidence.
- 2026-06-26 review patch added worktree governance, UI comparison separation, Prompt Pack headings, closeout classification separation, and static manual prompt test expectations.
- 2026-06-26 supervisor evaluation patches added Returned Report Type classification, Compared Against checklist, Decision taxonomy, type-specific returned-report evaluation, worker recommendation as advisory only, paste-ready Prompt To Use Next patterns, light Medium docs exception, short investigation phase, and explicit forbidden operation names.
- 2026-06-26 live manual prompt test recorded Small, Medium, Large, UI Comparison, Worker Return, and Closeout transcripts in `docs/specs/coding-task-orchestrator-skill/live-manual-prompt-test-2026-06-26.md`; all six requested cases passed.
- 2026-06-26 additional live manual prompt test recorded Short Investigation, Planning Return, Integrator Return, Review Return, Error / Blocker, and Realistic Worker Return + Closeout transcripts in `docs/specs/coding-task-orchestrator-skill/live-manual-prompt-test-additional-2026-06-26.md`; all six requested additional cases passed.
- 2026-06-26 real operation evidence recorded a Focusmap branch/worktree operation in `docs/specs/coding-task-orchestrator-skill/real-operation-evidence-2026-06-26.md`: branch `chore/cto-real-op-evidence-20260626`, worktree `/Users/kitamuranaohiro/Private/focusmap-wt-cto-real-op-evidence-20260626`, local commit `e938272e14ea93092455ab752fa8e4d6bfe27b9c`, implementation-worker return report, supervisor evaluation, `Prompt To Use Next`, closeout judgment, and prohibited-operation non-execution record.

## Verification Gaps

- No blocking `REQ-027` verification gaps remain.
- Strict destructive-operation Error / Blocker live coverage remains optional future hardening because the Skill docs and prompt tests already cover safety-stop behavior, and the requested real branch/worktree supervision plus closeout evidence is recorded.
- `check-skill-compatibility.sh` is fixed to `requirements-governor` and rewrites `docs/agent/compatibility-checklist.md`; it does not verify `coding-task-orchestrator` and is not used as formal evidence.
