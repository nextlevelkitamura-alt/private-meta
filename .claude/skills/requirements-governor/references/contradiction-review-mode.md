# Contradiction Review Mode

Contradiction Review Mode finds conflicts between requirements, specs, docs, implementation, and entry-file rules.

## Check Targets

- Requirement-to-requirement conflicts.
- Requirement-to-implementation mismatch.
- README-to-implementation mismatch.
- Old specs versus new specs.
- Duplicate implementations for the same feature.
- Requirements without acceptance criteria.
- Feature proposals that conflict with `non-goals.md`.
- Stale rules in `CLAUDE.md` or `AGENTS.md`.
- Docs that no longer match code.

## Output File

Write findings to:

```text
docs/requirements/contradictions.md
```

## Finding Format

Each finding should include:

- ID, using `ISSUE-001` style.
- Type.
- Summary.
- Status.
- Evidence.
- Impact.
- Proposed next step.

## Discipline

- Steelman the apparent conflict before recording it.
- Distinguish true contradiction from priority difference, timeline difference, or compatible separation of scope.
- If evidence is thin, record it as `needs_verification`.
