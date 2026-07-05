# Codex Cloud Patterns

Use Codex Cloud for self-contained repository work that does not need local private state.

## Good Fit

- Light bug fix
- Test addition
- Static repository investigation
- PR review
- Docs-only change
- Refactor with clear tests and no local services

## Avoid

- Local `.env`
- Local database
- Browser login
- Private desktop state
- Authenticated localhost UI
- Production credentials
- Large ambiguous product decisions

## Prompt Requirements

Cloud worker prompts must include:

- confirmed request
- repository context
- allowed files or directories
- out-of-scope items
- verification commands
- no secret exposure
- no merge/deploy/delete instructions
- return report format

## Return Evidence

Require:

- changed files
- tests run
- failures or skipped checks
- commit or PR reference if created by the platform
- open questions
