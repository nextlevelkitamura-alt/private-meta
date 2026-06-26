# Feature Specs

Feature-level specs live in this directory.

Create one directory per feature:

```text
docs/specs/<feature-id>/
  requirements.md
  acceptance.md
  implementation-notes.md
```

Before creating a feature spec, run `requirements-governor` Feature Gate Mode.

Minimum content for `requirements.md`:

- Feature summary.
- Related requirement IDs.
- Acceptance criteria.
- Non-goals.
- Impacted files or surfaces.
- Open questions.
- Completion evidence expected after implementation.

Do not implement the feature until contradictions and blocking questions are resolved.
