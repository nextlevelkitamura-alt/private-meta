# Agent Entry File Policy

`CLAUDE.md` and `AGENTS.md` are entry files and routers, not product specifications.

## Line Policy

- Target: 120 to 180 lines.
- Recommended maximum: 200 lines.
- Warning line: more than 250 lines.
- Failure line: more than 300 lines.

If either entry file grows too large, move the detail to one of these locations:

- `docs/requirements/`
- `docs/specs/`
- `docs/adr/`
- `.claude/skills/<skill>/references/`
- `.agents/skills/<skill>/references/`
- `docs/agent/`

## Router Block

The shared router block is stored in `docs/agent/root-agent-router.md`.

In `CLAUDE.md` and `AGENTS.md`, it must be wrapped by:

```md
<!-- AGENT-ROUTER:START -->
...
<!-- AGENT-ROUTER:END -->
```

Use `bash scripts/agent-instructions/sync-agent-router.sh` to synchronize the block.

## What Belongs In Entry Files

- Repository identity and high-priority operating principles.
- The shared agent router block.
- Tool-specific notes for Claude Code or Codex.
- Short pointers to source-of-truth documents.

## What Does Not Belong In Entry Files

- Full product requirements.
- Long feature specs.
- Detailed procedures.
- Long checklists.
- Prompt templates.
- Issue logs, contradiction logs, or progress boards.

## Import Policy

Do not use `@docs/...` imports in `CLAUDE.md` merely to make rules visible. Imports may consume startup context. Prefer plain reference paths, then read the file only when the task requires it.
