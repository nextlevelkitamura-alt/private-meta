# Requirements Governance

This directory is the source of truth for repository requirements, progress, contradictions, non-goals, and change history.

`CLAUDE.md` and `AGENTS.md` are only entry routers. Do not put full requirements or long procedures there.

## Files

- `product-requirements.md`: product or repository-level purpose and boundaries.
- `requirements-ledger.md`: canonical requirement table and status.
- `progress-board.md`: current progress grouped by status.
- `contradictions.md`: contradictions, open issues, and requirements conflicts.
- `non-goals.md`: explicit out-of-scope items.
- `change-log.md`: requirements governance changes.
- `glossary.md`: shared terms.
- `docs/specs/`: feature-level specs.
- `docs/adr/`: architecture or governance decisions.

## Status Rules

Use only these statuses in `requirements-ledger.md`:

- `proposed`: proposal stage.
- `approved`: approved for implementation.
- `in_progress`: implementation or documentation work is underway.
- `done`: complete with evidence.
- `needs_verification`: appears implemented, but evidence is not strong enough.
- `blocked`: stopped by an unresolved decision or dependency.
- `deferred`: intentionally postponed.
- `rejected`: not accepted.
- `deprecated`: previously valid, now retired.

Do not mark an item as `done` without at least one evidence item.

Evidence can be:

- Code path.
- Test path or command result.
- Screen verification.
- Related commit or PR.
- Explicit user decision.

## ID Rules

- `REQ-001`: repository or whole-product requirement.
- `FEAT-001`: feature requirement.
- `NFR-001`: non-functional requirement.
- `ISSUE-001`: contradiction, open issue, or unresolved decision.
- `ADR-001`: architecture or governance decision.

## Required Modes

Use the `requirements-governor` skill in these modes:

- Audit Mode: inventory current requirements and implementation state.
- Feature Gate Mode: check a new feature before implementation.
- Progress Sync Mode: synchronize implementation state with the ledger.
- Contradiction Review Mode: detect conflicts and stale specs.
- Entry File Maintenance Mode: keep `CLAUDE.md` and `AGENTS.md` short and synchronized.
- Compatibility Test Mode: verify Claude Code and Codex skill compatibility.

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

## Feature Gate Prompt

```text
requirements-governor の Feature Gate Mode を使って、以下の新機能案を実装してよいか確認してください。
実装はまだしないでください。
確認してほしいこと:
- 既存要件との矛盾
- 類似機能・重複機能
- non-goals との衝突
- スコープ肥大
- 影響範囲
- 受け入れ条件
- 未決定事項
- 実装後に更新すべき要件ID
問題がなければ docs/specs/<feature-id>/requirements.md を作成してください。
問題がある場合は contradictions.md に記録し、先に確認質問を出してください。
新機能案:
<ここに新機能案を書く>
```

## Progress Sync Prompt

```text
requirements-governor の Progress Sync Mode を使って、現在の実装状況と docs/requirements/requirements-ledger.md を同期してください。
実装コードは変更しないでください。
確認してほしいこと:
- 実装済み機能
- 未完了機能
- done にできる根拠
- needs_verification にすべき項目
- blocked / deferred / deprecated にすべき項目
- progress-board.md の更新
- contradictions.md の更新
```
