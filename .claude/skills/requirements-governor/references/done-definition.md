# Done Definition

An item can be marked `done` only when at least one evidence item is recorded.

## Valid Evidence

- Code path proving the behavior exists.
- Test path and command result.
- Screen verification result.
- Related commit.
- Related PR.
- Explicit user decision.

## Invalid Evidence By Itself

- "It looks done."
- A README claim with no code or user confirmation.
- A vague memory of implementation.
- A generated plan that says the work should be done.

## If Evidence Is Weak

Use `needs_verification`.

Record what must be checked next:

- Test command to run.
- File or screen to inspect.
- User decision needed.
- External dependency that blocks verification.
