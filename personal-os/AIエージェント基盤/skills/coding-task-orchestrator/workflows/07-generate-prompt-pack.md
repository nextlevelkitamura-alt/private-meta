# 07 Generate Prompt Pack

Use this workflow to assemble worker prompts after size, surface, agents, branch/worktree/port, and docs lifecycle are known.

## Inclusion Rules

- Small: usually Implementation prompt only, often inline in the same chat.
- Medium: Implementation prompt + Review prompt + Progress return prompt.
- Large: Planning prompts A/B, Integrator prompt, Implementation prompt, Review prompt, Progress return prompt, Closeout report prompt.
- Include only prompts that will actually be used.

## Prompt Sources

- Planning: `templates/prompt-planning.md`
- Implementation: `templates/prompt-implementation.md`
- Review: `templates/prompt-review.md`
- Integrator: `templates/prompt-integrator.md`
- Progress return: `templates/progress-return.md`
- Supervisor evaluation: `templates/supervisor-evaluation.md`
- Closeout report: `templates/closeout-report.md`

## Required Return Instructions

Always tell workers where to return results. Examples:

- Planning AI A/B の回答をこの監督チャットに戻してください。
- Integratorのfinal planをこの監督チャットに貼ってください。
- Implementation完了報告をこの監督チャットに戻してください。
- Review結果をこの監督チャットに戻してください。

## Output Fragment

```md
## Prompt Pack

### Planning Prompt
<include only if needed>

### Implementation Prompt
<include only if needed>

### Review Prompt
<include only if needed>

### Integrator Prompt
<include only if needed>

### Progress Return Prompt
<include only if needed>

### Closeout Report Prompt
<include only if needed>

## Return Instructions

<worker return route and required report fields>
```

## Human Confirmation Fragment

```md
## Human Confirmation

この方針で進めてよいですか？
承認前に branch/worktree/docs 作成、main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は行いません。
```
