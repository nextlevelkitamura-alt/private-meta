# UI Quality Rubric

Score existing or proposed settings UI on 100 points. Use the score to guide the next workflow, not as decoration.

## Scorecard

| Area | Points | Checks |
|---|---:|---|
| Information architecture | 20 | categories match user mental model; no duplicated/misplaced settings; search/deep links where needed |
| Task completion | 15 | users can find, edit, save, cancel, undo, and recover from errors |
| State clarity | 15 | connected, syncing, failed, disabled, unsaved, saving, saved, limited, permission-required states are visible |
| Visual hierarchy | 15 | density, spacing, typography, icons, tokens, and layout support scanning |
| Accessibility and input | 15 | keyboard/touch, labels, focus, contrast, target size, reduced motion, screen-reader semantics |
| Risk controls | 10 | billing/security/destructive/automation settings are isolated and confirmed |
| Implementation readiness | 10 | components, data contracts, ownership, responsive behavior, and tests are clear |

## Severity

- `P0`: user cannot complete a critical task, data/security/billing risk, destructive ambiguity, inaccessible content.
- `P1`: likely confusion, wrong category, missing status, poor mobile behavior, unreliable save/error feedback.
- `P2`: polish, density, naming, minor consistency, low-risk visual issue.

## Score Interpretation

- `90-100`: production-ready with small polish.
- `75-89`: usable; fix P1 issues before broader rollout.
- `60-74`: understandable but fragile; redesign key structure before visual polish.
- `<60`: do not implement further features on top without IA/UX cleanup.

## Next Workflow Mapping

- Many IA issues: `ui-architecture.md`.
- Many visual hierarchy issues: `improvement-roadmap.md` then `mock-generation.md`.
- Many state/interaction issues: `improvement-roadmap.md` then implementation split focused on components and data states.
- Many implementation-readiness gaps: `implementation-splitting.md` only after contracts are written.
- P0 findings: stop implementation and resolve risk controls first.

## Evaluation Report Minimum

Include:

- overall score
- top 3 findings
- P0/P1/P2 list
- what already works
- recommended next workflow
- if implementation is requested: parallelization readiness
