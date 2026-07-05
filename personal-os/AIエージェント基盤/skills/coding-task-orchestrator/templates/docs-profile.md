# Docs Profile

Last Updated: <YYYY-MM-DD>

## Source Of Truth

- Product/spec:
- Requirements:
- Active tasks:
- ADRs:
- Roadmap:

## Update Rules

| Document | Update When | Do Not Use For |
| --- | --- | --- |
| `AGENTS.md` | stable AI rules change | dynamic task state |
| `README.md` | setup or human-facing usage changes | branch-specific progress |
| `ROADMAP.md` | sequencing or product direction changes | implementation notes |
| `docs/PROJECT_SPEC.md` | durable project facts change | temporary task details |
| `docs/tasks/ACTIVE_TASKS.md` | Medium/Large task starts or status changes | completed history |
| `docs/tasks/active/<branch>.md` | branch/worktree task changes | stable project spec |
| `docs/tasks/archive/` | completed task worth retaining | trivial completed tasks |
| `docs/adr/` or `docs/decisions/` | durable decision is made | routine implementation details |
| PR body | final implementation summary | long-lived specs |

## Archive Policy

<when to archive vs delete active task docs>

## PR Body Expectations

- purpose
- changes
- verification
- impact
- unfinished items
