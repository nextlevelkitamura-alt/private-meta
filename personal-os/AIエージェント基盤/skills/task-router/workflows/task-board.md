# task-board workflow

既存 `docs/ai` 運用repo、またはユーザーが明示的に旧 task-router 運用を採用したrepoで進捗を管理するための legacy/compat 標準。

## 標準ファイル名

task-router は、既存 `docs/ai` 運用repoまたは明示採用repoに以下を使う。条件に該当する場合だけ、無ければ必要最小限で作る。

| Path | 用途 |
|---|---|
| `docs/ai/task-board.md` | 現在のタスクボード。企画中・実装中・確認待ち・ブロック中を一覧する正本 |
| `docs/ai/plans/active/` | task-router が新規に作る現行計画の置き場 |
| `docs/ai/plans/archive/YYYY/MM/` | 完了した task-router 計画の月別置き場 |
| `docs/ai/task-archive/YYYY/MM.md` | 完了タスクの月別サマリー |
| `docs/ai/task-runs.jsonl` | runごとの定量ログ |
| `docs/ai/mistakes.md` | 再発防止が必要な失敗ログ |
| `docs/ai/task-router-analysis.md` | 5 runごとの判断改善 |

既に `docs/plans/*` や `docs/requirements/*` などの計画体系がある場合は、移行しない。`docs/ai/task-board.md` の `Plan` 欄から既存計画へリンクする。新規に task-router が作る計画だけ `docs/ai/plans/active/` を既定にする。

## AGENTS.md 入口

既存 `docs/ai` 運用repoまたは明示採用repoの `AGENTS.md` / `CLAUDE.md` には、詳細を貼らず入口だけ置く。

```md
## Task Router Board

- 現在のタスクボードは `docs/ai/task-board.md` を正とする。
- task-router が新規に作る計画は `docs/ai/plans/active/` に置く。
- 完了タスクは `docs/ai/task-archive/YYYY/MM.md`、完了計画は `docs/ai/plans/archive/YYYY/MM/` に月別で移す。
- 非自明な作業を始める時・計画を立てた時・完了前には task-router がこのボードを更新する。
- 作業実績は `docs/ai/task-runs.jsonl`、再発防止メモは `docs/ai/mistakes.md`、並列化判断の分析は `docs/ai/task-router-analysis.md` に置く。
```

AGENTS.md を肥大化させない。運用詳細はこの workflow に残す。

## task-board.md テンプレート

```md
# Task Board

Last updated: YYYY-MM-DD

task-router の現在地を示す軽量ボード。詳細は各 Plan を正とし、このファイルは見出し・状態・リンク・次アクションを一覧する。

## Active

| ID | Status | Task | Plan | Scope | Owner/Chat | Branch | Next | Updated |
|---|---|---|---|---|---|---|---|---|
| TASK-YYYYMMDD-001 | planned | <task> | [plan](plans/active/<file>.md) | <files/area> | task-router | `main` | <next action> | YYYY-MM-DD |

## Waiting / Blocked

| ID | Status | Task | Plan | Blocker | Needed Decision | Updated |
|---|---|---|---|---|---|---|

## Recently Completed

直近の完了だけ最大5件。月別の正本は `docs/ai/task-archive/YYYY/MM.md`。

| ID | Completed | Task | Plan | Result |
|---|---|---|---|---|
```

## ステータス

- `planned`: 企画・計画が作られたが実装前。
- `in_progress`: 実装または調査中。
- `review`: 実装後の確認・レビュー中。
- `blocked`: ユーザー判断、外部状態、危険操作承認などが必要。
- `waiting_integration`: 別チャット/worktreeの成果待ち。
- `done_pending_archive`: 完了したが月別アーカイブ未反映。

完了後は Active から消す。`Recently Completed` は短期の見出しだけ残し、詳細は月別アーカイブへ移す。

## ライフサイクル

### 1. 非自明な作業を始める時

1. 既存 `docs/ai` 運用repoまたは明示採用repoか確認する。該当しない場合はこの workflow で `docs/ai` を作らない。
2. 該当する場合だけ、`docs/ai/task-board.md` があるか確認し、無ければ作る。
3. 同じ条件で、`docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` があるか確認し、無ければ `workflows/telemetry-and-mistakes.md` のテンプレートで作る。
4. 同じ条件で、`TASK-YYYYMMDD-NNN` を採番する。同日に既存IDがあれば次番号にする。
5. 同じ条件で、Active に1行追加する。
6. 同じ条件で、計画が必要なら `docs/ai/plans/active/YYYYMMDD-<slug>.md` を作る。既存計画を使う場合はそこへリンクする。

### 2. 企画・プランを立てた時

- Plan 欄に計画ファイルのリンクを入れる。
- Status を `planned` または `in_progress` にする。
- Scope / Owner/Chat / Branch / Next を更新する。
- 並列化判断、worktree計画、Integration条件は plan 本文に書き、board には要約だけ置く。

### 3. 作業中

- 大きな状態変化があったら board を更新する。
- 複数Codexチャット/worktreeへ分ける場合は Owner/Chat に `Frontend Codex` / `Backend Codex` / `Integration Codex` などを書く。
- ブロックしたら Active から Waiting / Blocked へ移すか、Status を `blocked` にする。

### 4. 完了前

完了報告の前に必ず行う。

1. 検証結果、commit、未解決リスクを plan に追記する。
2. Active から該当行を消す。
3. `docs/ai/task-archive/YYYY/MM.md` に完了行を追加する。
4. task-router が作った active plan は `docs/ai/plans/archive/YYYY/MM/` へ移す。
5. `Recently Completed` に最大5件の見出しだけ残す。
6. コード変更・設定変更・docs変更をした場合は、対象差分だけ commit する。

## 月別アーカイブテンプレート

```md
# Task Archive YYYY/MM

## Completed

| ID | Completed | Task | Plan | Commits | Verification | Notes |
|---|---|---|---|---|---|---|
| TASK-YYYYMMDD-001 | YYYY-MM-DD | <task> | [plan](../../plans/archive/YYYY/MM/<file>.md) | `<hash>` | <checks> | <short note> |
```

## 計画ファイルテンプレート

```md
# <Task Title>

- Task ID: TASK-YYYYMMDD-001
- Status: planned | in_progress | review | blocked | completed
- Created: YYYY-MM-DD
- Completed:
- Board: `docs/ai/task-board.md`

## Goal

## Scope

## Non-goals

## Plan

## Parallelization

## Verification

## Result

## Links
```

## 既存リポジトリへの導入

- 旧 task-router 運用を明示採用する場合だけ導入する。
- 旧 task-router 運用の導入条件に合う場合だけ、`docs/ai/task-board.md` が無ければ作る。
- 同じ条件で、`docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` が無ければ作る。
- 既存の `docs/plans/*` / `docs/requirements/*` はそのまま残す。
- 既存の活発な計画がある場合、board に代表行だけ追加して Plan 欄からリンクする。
- 過去分の完全な棚卸しは必須にしない。次の作業から運用を始め、必要なら直近月だけバックフィルする。
