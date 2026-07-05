# Closeout Report Prompt

Use this when implementation and review are complete.

## PR Body Summary

```md
## Summary
- <change>

## Verification
- <command or UI check>

## Impact
- <user/system impact>

## Unfinished Items
- <item or none>
```

## Verification Evidence

- <command/result>
- <screenshot/path>

## Active Task Doc

- Delete or archive:
- Archive path, if any:
- Reason:

## ACTIVE_TASKS Cleanup

- Row removed:
- Remaining active related work:

## ROADMAP

- Update needed: yes/no
- Reason:

## ADR

- Update needed: yes/no
- Path:
- Reason:

## Cleanup Candidates

| Item | State | Recommended Action | Requires Human Approval |
| --- | --- | --- | --- |
| branch `<name>` | integrated/abandoned/main_unintegrated | keep/delete later | yes |
| worktree `<path>` | integrated/abandoned/main_unintegrated | keep/delete later | yes |

## Closeout Classification

integrated / abandoned / main_unintegrated

## Human Gates

Explicit approval is required before:

- `git reset --hard`
- `git clean -fd`
- `git push --force`
- remote branch deletion
- branch deletion
- worktree deletion
- main merge
- production deploy
- migration apply
- secrets / `.env` change or disclosure
- production DB/data operation
