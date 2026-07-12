# Settings Taxonomy

Use this as the default classification system. Adapt it to the product instead of forcing every category to appear.

## Core Categories

| Category | Typical Items | Placement Rules |
|---|---|---|
| Account | profile, email, password, sessions, personal identity | Personal, user-scoped, not workspace-wide. |
| Workspace / Organization | team, roles, members, workspace name, ownership | Shared scope. Show role/permission limits clearly. |
| Preferences | language, theme, density, editor, shortcuts, defaults | Low risk. Put high-frequency preferences near top. |
| Notifications | channels, quiet hours, event subscriptions | Group by channel or event type, not random toggles. |
| Integrations | connected services, OAuth, sync status, external accounts | Show status, last sync, error, reconnect, disconnect. |
| AI / Automation | agents, approvals, execution permissions, model/provider, budgets, schedules | Show what can act automatically and where approval is required. |
| Data | import, export, backup, retention, history | Clarify scope and format. Avoid destructive ambiguity. |
| Security | 2FA, SSO, sessions, audit log, permissions, API access | Keep near account/org depending on scope. Avoid hiding critical state. |
| Billing / Usage | plan, invoices, usage, limits, seats | Separate plan management from usage visibility. |
| Developer | API keys, webhooks, env, logs, repos, CLI | Use dense tables and copy/reveal controls. Protect secrets. |
| Advanced | experimental flags, diagnostics, reset, destructive actions | Separate visually. Include confirmation and recovery language. |

## Placement Rules

- If a setting affects only the current user, keep it under Account or Preferences.
- If a setting affects teammates, billing, shared data, or automation, keep it under Workspace/Organization, Security, Billing, or AI/Automation.
- If a setting touches an external service, show connection state and failure recovery near the setting.
- If a setting can delete, reset, revoke, spend money, expose secrets, or change permissions, isolate it from ordinary preferences.
- Avoid categories with fewer than two useful items unless the category is security-critical.
- Prefer searchable labels over clever labels.

## Common Misplacements

- Putting workspace-wide automation under personal preferences.
- Hiding billing limits inside account profile.
- Mixing integrations and developer API keys without state labels.
- Mixing dangerous reset/delete actions with ordinary toggles.
- Creating separate pages for every small preference instead of grouping by user job.

## Category Ordering

Default order for productivity/SaaS apps:

1. General or Preferences
2. Account/Profile
3. Workspace/Organization
4. AI/Automation, if central to the product
5. Integrations
6. Notifications
7. Security
8. Billing/Usage
9. Developer
10. Advanced/Danger Zone

Change the order when the product has a stronger primary job. Developer tools may put Developer and Git/Environment before Billing. Consumer apps may put Account, Preferences, Notifications first.
