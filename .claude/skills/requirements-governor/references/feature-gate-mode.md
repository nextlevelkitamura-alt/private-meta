# Feature Gate Mode

Feature Gate Mode decides whether a new feature proposal is ready for implementation.

## Read

- `docs/requirements/product-requirements.md`
- `docs/requirements/requirements-ledger.md`
- `docs/requirements/progress-board.md`
- `docs/requirements/contradictions.md`
- `docs/requirements/non-goals.md`
- Related files under `docs/specs/`
- Relevant implementation files only when needed to check duplication or impact

## Check

- Existing requirement conflicts.
- Similar or duplicate features.
- Scope growth.
- Conflict with `non-goals.md`.
- Affected requirements and surfaces.
- Acceptance criteria.
- Completion evidence expected after implementation.
- Open questions and missing decisions.

## Stop Conditions

Do not proceed to implementation when:

- Acceptance criteria are missing.
- Existing specs or requirements conflict.
- Priority is unclear.
- Non-goals and out-of-scope work are not separated.
- Completion criteria are unclear.
- Required user decisions are missing.

## Output

If ready, create:

```text
docs/specs/<feature-id>/requirements.md
```

If not ready:

- Record the issue in `docs/requirements/contradictions.md`.
- Ask the minimum required confirmation questions.
- Keep the requirement status as `proposed` or `blocked`.
