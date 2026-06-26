# Audit Mode

Audit Mode inventories an existing repository without changing implementation code.

## Read

- `README*`
- `docs/`
- `CLAUDE.md`
- `AGENTS.md`
- TODO or issue-like notes found with `rg`
- Main package or app manifests
- Major source directories only as needed to identify implemented features

## Do

- Infer the current product or repository purpose.
- Extract implemented features.
- Extract unfinished features.
- Separate blocked, deferred, deprecated, and unclear items.
- Identify requirements with no evidence.
- Identify implementation that has no documented requirement.
- Update `docs/requirements/requirements-ledger.md`.
- Update `docs/requirements/progress-board.md`.
- Update `docs/requirements/contradictions.md`.
- Update `docs/requirements/non-goals.md` when out-of-scope items are explicit.

## Do Not

- Do not modify implementation code.
- Do not mark inferred work as `done` without evidence.
- Do not treat README claims as implementation evidence by themselves.
- Do not approve new feature scope during an audit.

## Output

End with:

- Files updated.
- Requirements marked `done` with evidence.
- Items marked `needs_verification`.
- Contradictions or open questions.
- Recommended next mode.
