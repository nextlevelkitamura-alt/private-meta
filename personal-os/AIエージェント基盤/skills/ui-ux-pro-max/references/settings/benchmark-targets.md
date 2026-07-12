# Benchmark Targets

Use this when mature-app comparison is useful. If current behavior or exact screenshots matter, verify with live web/app research or user-provided screenshots instead of relying on memory.

## Apps To Consider

Pick only relevant benchmarks:

- Apple System Settings: platform-native hierarchy, search, sidebar/list-detail, device-level preferences.
- Google Workspace/Admin/Account: account, security, privacy, billing, and organization management.
- Notion: workspace/account/preferences, integration surfaces, simple language, progressive disclosure.
- Slack: workspace administration, notification preferences, integrations, permission-sensitive settings.
- GitHub: developer settings, security, SSH/GPG/API tokens, organization roles, billing separation.
- Linear: modern SaaS settings, workspace/member/project preferences, compact UI.
- Stripe: high-risk billing/developer/security settings, state-heavy admin surfaces.
- Codex or developer tools: environment, permissions, worktrees, hooks, connectors, usage, coding preferences.

## What To Extract

Do not copy visual style blindly. Extract principles:

- category names and ordering
- personal vs workspace/org separation
- search and deep link behavior
- list-detail vs tab vs sidebar structure
- status labels and error recovery
- integration connection states
- dangerous operation isolation
- billing/security/developer density
- responsive/mobile behavior
- permission/plan gating language

## Benchmark Summary Format

```md
## Benchmark Summary

Relevant products:
- ...

Reusable patterns:
- ...

Anti-patterns:
- ...

Recommended for this app:
- ...

Not recommended:
- ...

Unknowns requiring live verification:
- ...
```
