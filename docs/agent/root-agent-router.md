## Agent Router
This repository keeps long-lived product requirements, feature specs, progress status, and contradiction records outside this entry file.

### Source of truth
- Product requirements: `docs/requirements/product-requirements.md`
- Requirements ledger: `docs/requirements/requirements-ledger.md`
- Progress board: `docs/requirements/progress-board.md`
- Contradictions and open issues: `docs/requirements/contradictions.md`
- Non-goals: `docs/requirements/non-goals.md`
- Feature specs: `docs/specs/`
- Architecture decisions: `docs/adr/`

### Required workflow
Before adding a new feature or changing existing behavior, use the `requirements-governor` skill to check scope, contradictions, affected requirements, and acceptance criteria.
After implementation, update the requirements ledger and progress board. Do not mark items as `done` without evidence.

### Entry file size policy
Keep this file short. Target under 200 lines. If it grows beyond 250 lines, move procedures, templates, or detailed references into docs or skills. Do not exceed 300 lines without explicitly justifying why.

### Do not
- Do not treat this file as the full product spec.
- Do not add long procedures here.
- Do not mark requirements as done without evidence.
- Do not implement new features before checking `non-goals.md` and `contradictions.md`.
