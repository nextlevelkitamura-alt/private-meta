# Status Rules

Use only these statuses in `docs/requirements/requirements-ledger.md`.

| Status | Meaning |
| --- | --- |
| `proposed` | Proposal stage. Not approved for implementation. |
| `approved` | Approved for implementation. |
| `in_progress` | Implementation or documentation work is underway. |
| `done` | Complete with evidence. |
| `needs_verification` | Appears implemented, but evidence is not strong enough. |
| `blocked` | Stopped by an unresolved decision or dependency. |
| `deferred` | Intentionally postponed. |
| `rejected` | Not accepted. |
| `deprecated` | Previously valid, now retired. |

## Rules

- New feature ideas start as `proposed`.
- A feature becomes `approved` only after Feature Gate Mode clears contradictions and acceptance criteria.
- A feature becomes `done` only with evidence.
- Weak implementation claims become `needs_verification`.
- Out-of-scope ideas should become `rejected` or be moved to `non-goals.md`.
- Old valid requirements should become `deprecated`, not deleted, when history matters.
