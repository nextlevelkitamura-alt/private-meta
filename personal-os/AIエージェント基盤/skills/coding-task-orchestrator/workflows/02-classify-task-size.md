# 02 Classify Task Size

Use this workflow only after the user confirms the understanding.

## Inputs

- Confirmed user request
- Known affected files or surfaces, if available
- Repository rules from `AGENTS.md`
- Requirements and non-goals when the repository has them

## Classification Rule

Choose the smallest size that honestly covers the risk. When uncertain between two sizes, choose the larger size and explain why.

If uncertainty is the only large factor, run a short investigation phase before upgrading the task to Large. The investigation should answer the specific unknowns, avoid broad implementation, and return a recommendation to stay Medium or upgrade to Large.

Short investigation phase:

- Use when the likely work is Medium but the affected surface is unknown.
- Keep it read-only or narrowly diagnostic unless the user explicitly approved a tiny probe.
- Do not create a full Large setup only because the first report lacks information.
- Return: findings, affected files/surfaces, risk classification, whether Medium is still enough, whether Large is needed, and the next prompt.

## Small

Use for:

- Text, copy, typo, README, or comment-only changes
- A few CSS lines
- Light change in one or two files
- No DB, Auth, billing, migration, external API, production data, or shared contract effect

Operation:

- 1AI
- Codex App Local or Codex App Worktree
- Task doc unnecessary
- Docs update usually unnecessary
- PR optional unless repository rules require it
- Branch recommended only if another AI or isolated review will work on it

## Medium

Use for:

- UI improvement or new screen
- Light API change
- Multiple files
- Existing feature behavior change
- Localhost or build verification needed
- Moderate docs or tests needed

Operation:

- Implementation AI + Review AI
- Codex App Worktree or Orca
- Branch and worktree recommended and usually required
- Create `docs/tasks/active/<branch-name>.md` when required by risk
- Update `docs/tasks/ACTIVE_TASKS.md` when required by risk
- PR recommended and usually required
- Run localhost verification where applicable
- Run `npm run build`, test command, or repository equivalent

Light Medium exception:

- For narrow Medium tasks, task docs and `ACTIVE_TASKS.md` may be recommended rather than required.
- Still create a task doc for multiple-file changes, existing feature impact, Review AI usage, Orca usage, PR-required work, or any repository rule that requires task tracking.
- Do not immediately upgrade a light investigation-backed fix to Large unless the investigation finds architecture, production, security, data, or multi-stream risk.
- If the task remains a light Medium after investigation, state which required-task-tracking triggers are absent and keep docs tracking as recommended only.

## Large

Use for:

- Auth, DB, billing, migration, security, production data, or external API integration
- Major refactor or multiple feature areas
- Ambiguous specification or competing architecture options
- Current/latest information research
- Multiple teams, branches, worktrees, or approval gates

Operation:

- Planning AI A/B + Integrator AI + Implementation AI + Review AI
- Add Validation AI when evidence collection is substantial
- Orca recommended
- Branch and worktree required
- Task doc and ACTIVE_TASKS update required
- Draft PR recommended
- ADR when decisions are durable
- Multiple human approval gates

## Output Fragment

```md
## Task Size

Small / Medium / Large

## Reason

<short reason with risk factors and why smaller/larger sizes were rejected>
```
