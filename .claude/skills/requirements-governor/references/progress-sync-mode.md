# Progress Sync Mode

Progress Sync Mode compares implementation reality with `docs/requirements/requirements-ledger.md`.

## Read

- Requirements ledger.
- Progress board.
- Related specs.
- Tests.
- README or user docs.
- Configuration files.
- Relevant implementation paths.

## Classify

Use these statuses:

- `done`
- `in_progress`
- `needs_verification`
- `blocked`
- `deferred`
- `deprecated`

## Done Rule

Only mark `done` when at least one evidence item exists:

- Code path.
- Test path or command result.
- Screen verification.
- Related commit or PR.
- Explicit user decision.

If evidence is weak, use `needs_verification`.

## Update

- `docs/requirements/requirements-ledger.md`
- `docs/requirements/progress-board.md`
- `docs/requirements/contradictions.md` if implementation and docs disagree
- Related `docs/specs/<feature-id>/requirements.md` if completion criteria changed

## Output

Report:

- Items changed to `done`.
- Items changed to `needs_verification`.
- Items blocked or deferred.
- Evidence recorded.
- Tests or verification not run.
