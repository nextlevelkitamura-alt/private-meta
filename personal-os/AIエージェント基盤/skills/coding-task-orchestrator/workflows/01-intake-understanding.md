# 01 Intake Understanding

Use this workflow for the first response to any fresh coding request.

## Goal

Confirm the user's intended change in plain language and ask whether classification and planning may proceed.

## Must Not Do

- Do not classify the task as Small, Medium, or Large.
- Do not propose Codex App, Orca, Cloud, Terminal, or `codex exec`.
- Do not propose AI count or roles.
- Do not propose branch, worktree, port, task docs, PR, or docs updates.
- Do not create files, branches, worktrees, tickets, docs, or prompts.
- Do not write an implementation plan.

## Intake Steps

1. Identify the object or current behavior the user wants changed.
2. Identify the desired behavior or outcome.
3. Identify obvious exclusions from the user's wording.
4. Name the initial scope conservatively.
5. If any of the first three items are unclear, ask one short clarification and stop.
6. Otherwise output only the required confirmation.

## Required Output

```md
理解確認：
やりたいことは「<current behavior or object>」を「<desired behavior>」にすることですね。
現時点では <explicit exclusions> は含めず、まず <initial scope> の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

## Ambiguous Request Output

If the request cannot be safely restated:

```md
理解確認のために1点だけ確認します。
「<unclear object>」は <option or interpretation> という理解で合っていますか？
```

Do not include any planning content in this ambiguous case.

## Exit Condition

Proceed to workflow `02-classify-task-size.md` only after the user explicitly confirms that the understanding is correct or asks to continue with that understanding.
