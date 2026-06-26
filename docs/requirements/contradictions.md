# Contradictions and Open Issues

Use this file for contradictions, unresolved decisions, stale specs, and requirements conflicts.

| ID | Type | Summary | Status | Evidence | Next Step |
| --- | --- | --- | --- | --- | --- |
| ISSUE-001 | open_issue | Full repository requirements audit has not been performed yet. | needs_verification | Governance setup created before product audit. | Run `requirements-governor` Audit Mode. |
| ISSUE-002 | verification_gap | Claude Code runtime skill detection is unverified. | needs_verification | `command -v claude` found `/Users/kitamuranaohiro/.npm-global/bin/claude`, but `claude --help` exited with "claude native binary not installed." | Fix or reinstall Claude Code CLI, then rerun `bash scripts/agent-instructions/check-skill-compatibility.sh`. |
