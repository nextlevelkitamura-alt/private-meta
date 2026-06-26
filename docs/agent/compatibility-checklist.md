# Compatibility Checklist

This file records whether the repository requirements governance setup works for both Claude Code and Codex.

## Skill Placement

- Claude Code skill path: `.claude/skills/requirements-governor/`
- Codex skill path: `.agents/skills/requirements-governor/`
- Current method: symlink
- Symlink target: `.agents/skills/requirements-governor -> ../../.claude/skills/requirements-governor`
- Reason: the current environment is macOS and symlinks are supported. A symlink keeps the two skill copies from drifting. If a future Windows or team environment cannot resolve the symlink, switch to copy sync and verify with `bash scripts/agent-instructions/check-skill-compatibility.sh`.

## Script Scope And Side Effects

`bash scripts/agent-instructions/check-skill-compatibility.sh` currently verifies `requirements-governor` placement, frontmatter, reference files, and Claude/Codex CLI availability. It does not verify `coding-task-orchestrator` behavior or prompt quality.

The script is not read-only: it rewrites the `Last Compatibility Test Result` block in this file (`docs/agent/compatibility-checklist.md`). Do not use its result as formal evidence for `coding-task-orchestrator` unless the script is generalized or a dedicated `coding-task-orchestrator` check is added.

## Manual Compatibility Checklist

- `CLAUDE.md` exists.
- `AGENTS.md` exists.
- Both entry files contain an identical `AGENT-ROUTER` block.
- Both entry files are below the 250-line warning threshold.
- `.claude/skills/requirements-governor/SKILL.md` exists.
- `.agents/skills/requirements-governor/SKILL.md` resolves.
- `SKILL.md` has `name: requirements-governor`.
- `SKILL.md` has a short `description`.
- Required reference files exist.
- `docs/requirements/`, `docs/specs/`, and `docs/adr/` exist.

## Safe Read-Only Test Commands

```sh
wc -l CLAUDE.md AGENTS.md
bash scripts/agent-instructions/check-agent-instructions.sh
find .claude/skills/requirements-governor -maxdepth 3 -type f -print
find -L .agents/skills/requirements-governor -maxdepth 3 -type f -print
command -v claude || true
command -v codex || true
```

## Compatibility Result Update Command

```sh
bash scripts/agent-instructions/check-skill-compatibility.sh
```

This command updates `docs/agent/compatibility-checklist.md` as part of its normal behavior.

If `claude` or `codex` exists, inspect `--help` first and run only safe read-only checks. Do not assume unsupported detection commands.

## First Audit Prompt

```text
requirements-governor を使って、このリポジトリの現在の要件・実装済み機能・未完了機能・矛盾点・今後の論点を棚卸ししてください。
実装コードはいじらず、まずは docs/requirements/ と docs/specs/ と docs/adr/ に現状整理だけを作成・更新してください。
特に以下を重視してください。
- 完了済みと未完了を分ける
- 根拠がない完了扱いを避ける
- 実装済みに見えるが確認不足のものは needs_verification にする
- 新機能追加によるスコープ肥大を検出する
- 要件と実装のズレを contradictions.md に出す
- 今やらないことを non-goals.md に整理する
- CLAUDE.md / AGENTS.md は短い入口として保つ
- 詳細手順はSkillまたはdocsへ逃がす
```

## Last Compatibility Test Result

<!-- COMPATIBILITY-TEST:START -->
Last run: 2026-06-26 13:38:15 JST

- OK: Claude skill directory exists
- OK: Codex skill directory is symlink -> ../../.claude/skills/requirements-governor
- OK: Codex symlink target resolves
- OK: Claude skill file resolves at .claude/skills/requirements-governor/SKILL.md
- OK: Claude frontmatter name
- OK: Claude frontmatter description
- OK: Codex skill file resolves at .agents/skills/requirements-governor/SKILL.md
- OK: Codex frontmatter name
- OK: Codex frontmatter description
- OK: reference exists audit-mode.md
- OK: reference exists feature-gate-mode.md
- OK: reference exists progress-sync-mode.md
- OK: reference exists contradiction-review-mode.md
- OK: reference exists templates.md
- OK: reference exists status-rules.md
- OK: reference exists done-definition.md
- OK: claude CLI found at /Users/kitamuranaohiro/.npm-global/bin/claude
- OK: claude --help completed
- OK: codex CLI found at /Users/kitamuranaohiro/.npm-global/bin/codex
- OK: codex --help completed
<!-- COMPATIBILITY-TEST:END -->
