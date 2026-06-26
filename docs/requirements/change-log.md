# Requirements Change Log

| Date | Change | Evidence |
| --- | --- | --- |
| 2026-05-28 | Added requirements governance base, shared agent router, and `requirements-governor` skill structure. | User request and files under `docs/`, `.claude/`, `.agents/`, and `scripts/agent-instructions/`. |
| 2026-05-28 | Verified router synchronization, entry-file line counts, skill frontmatter, reference files, and safe CLI availability checks. | `wc -l CLAUDE.md AGENTS.md`, `bash scripts/agent-instructions/check-agent-instructions.sh`, and `bash scripts/agent-instructions/check-skill-compatibility.sh`. |
| 2026-06-26 | Initialized `Private/` as a local Git meta-repository for Orca/Codex/Claude governance work while keeping child repositories ignored. | Commit `3dc31d3`; `git ls-files` allowlist check; `git status --ignored --short`; `git remote -v` returned no configured remote. |
