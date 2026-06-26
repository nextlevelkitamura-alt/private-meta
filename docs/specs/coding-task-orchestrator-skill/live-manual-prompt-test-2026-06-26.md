# Coding Task Orchestrator Live Manual Prompt Test

Date: 2026-06-26
Tester: Codex
Target Skill: `/Users/kitamuranaohiro/.agents/skills/coding-task-orchestrator/`
Method: Manual live invocation in the current Codex thread after reading `SKILL.md` and the required workflows. No branch, worktree, merge, deploy, deletion, force push, hard reset, clean, secret change, migration, or production data operation was performed.

## Case 1: Small

### Input Prompt

Turn 1:

```text
ボタンの文言を『保存』から『保存する』に変えたいです
```

Turn 2:

```text
はい。この理解で判定してください。
```

### Actual Response

Turn 1:

```md
理解確認：
やりたいことは「ボタンの文言『保存』」を「『保存する』に変更する」ことですね。
現時点では ボタンの挙動変更、保存処理、レイアウト変更、翻訳キー設計、対象画面の追加調査 は含めず、まず 表示文言の単純変更 の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

Turn 2:

```md
## Understanding Confirmed

ボタン表示文言を『保存』から『保存する』に変える単純変更として扱います。

## Task Size

Small

## Reason

文言だけの軽微な変更で、DB/Auth/API/migration/production data/shared contract への影響がないためです。Medium以上に上げる理由は現時点ではありません。

## Execution Surface

Codex App Local

Reason: 1ファイルまたは少数行の変更で足ります。
Fallback: 対象repoに未コミット変更が多い場合だけ Codex App Worktree。

## Agent Setup

- Count: 1AI
- Roles: Implementation and verification
- Why this split: 文言変更なので独立Review AIの効果が薄い
- Why not more: Orcaや複数AIは不要

## Branch / Worktree / Port

- Branch: none by default
- Worktree: none
- Port: none
- Naming reason: branch/worktreeを作るほどの変更ではない
- Collision checks: branch/worktree/portを使わないため不要
- Human gate: branch/worktreeを作る場合は事前承認が必要

## Documentation Plan

- Create: none
- Update: none usually
- Maybe: PRを作る場合のみPR本文またはcommit messageに変更内容を書く
- Do Not Update: `docs/tasks/active/`, `docs/tasks/ACTIVE_TASKS.md`, `ROADMAP.md`, ADR, `AGENTS.md`
- Closeout: 追加のtask doc cleanupなし

## Workflow

1. 対象ボタンの表示箇所を特定する。
2. 表示文言だけを変更する。
3. 画面または該当テストで表示を確認する。
4. 変更ファイルと確認結果を返す。

## Prompt Pack

### Implementation Prompt

対象ボタンの表示文言を『保存』から『保存する』に変更してください。保存処理、レイアウト、バリデーション、翻訳設計は変更しないでください。変更後、該当画面または既存テストで表示を確認し、変更ファイルと確認結果を返してください。

## Return Instructions

Implementation完了報告をこの監督チャットに戻してください。変更ファイル、確認方法、未完了項目、リスクの有無を含めてください。

## Human Confirmation

この方針で進めてよいですか？
承認前に branch/worktree/docs 作成、main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は行いません。
```

### Expected Behavior

- First response only confirms understanding.
- `docs/tasks/active` and `ACTIVE_TASKS` are not required.
- Orca and multiple AI workers are not forced.
- Small is treated lightly.

### Pass / Fail

Pass

### Notes

The actual response keeps task docs optional/unneeded and selects 1AI plus Codex App Local.

## Case 2: Medium

### Input Prompt

Turn 1:

```text
タスク詳細画面のUIを見やすくして、スマホでも崩れないようにしたいです
```

Turn 2:

```text
はい。この理解で判定してください。
```

### Actual Response

Turn 1:

```md
理解確認：
やりたいことは「タスク詳細画面の現在のUI」を「見やすく、スマホでも崩れないレスポンシブUI」にすることですね。
現時点では 新機能追加、DB/API変更、認証変更、タスクデータ構造変更、production deploy は含めず、まず タスク詳細画面のUI改善とレスポンシブ修正 の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

Turn 2:

```md
## Understanding Confirmed

タスク詳細画面のUI可読性とスマホ表示崩れを改善する範囲で扱います。データ構造、API、認証、deployは含めません。

## Task Size

Medium

## Reason

UI改善とレスポンシブ対応は複数コンポーネント/CSS/テストまたはスクリーンショット確認が必要になりやすく、既存画面のユーザー体験に影響します。DB/Auth/API/migrationがないためLargeではありません。

## Execution Surface

Codex App Worktree or Orca

Reason: 1つの画面改善なら Codex App Worktree、複数案比較や並列実装をするなら Orca が合います。
Fallback: Orcaが使えない場合は Codex App Worktree で Implementation AI 後に Review AI。

## Agent Setup

- Count: 2AI
- Roles: Implementation AI, Review AI
- Why this split: UI崩れは実装者の見落としが出やすいため、独立Reviewで差分、レスポンシブ、確認証跡を見る
- Why not more: 仕様が明確なので Planning AI A/B は不要

## Branch / Worktree / Port

- Branch: `feat/task-detail-responsive-ui`
- Worktree: `../repo-wt-task-detail-responsive-ui`
- Port: `3001` if parallel localhost verification is needed; otherwise repository default
- Naming reason: task detail screen and responsive UI scopeが分かるlowercase ASCII名
- Collision checks: target repo未指定のため未実行。作成前に `git branch --list`, `git worktree list`, `git worktree list --porcelain`, `find docs/tasks/active -maxdepth 1 -type f`, `lsof -i :3001` を確認する
- Human gate: create none of these until approved

## Documentation Plan

- Create: `docs/tasks/active/feat-task-detail-responsive-ui.md` if worktree/Review AI/PRを使うなら作成
- Update: `docs/tasks/ACTIVE_TASKS.md` if active task docを作るなら追加
- Maybe: `docs/PROJECT_SPEC.md` or `docs/DOCS_PROFILE.md` が存在せず、UI/verification方針が不明なら作成提案
- Do Not Update: `AGENTS.md`, ADR unless durable UI architecture decisionが発生
- Closeout: PR本文にsummary/verification/impactを記載し、active task docは削除または必要ならarchive、ACTIVE_TASKS行を削除

## Workflow

1. 対象画面と既存レイアウト制約を確認する。
2. desktop/mobileのdone criteriaを決める。
3. Implementation AIがUI修正と必要な確認を行う。
4. Review AIが差分、viewport崩れ、テキストはみ出し、テスト/スクリーンショット証跡を確認する。
5. 合格後にcloseoutへ進む。

## Prompt Pack

### Implementation Prompt

タスク詳細画面のUI可読性とスマホ表示崩れを改善してください。Scopeはタスク詳細画面の表示/スタイル/必要な小コンポーネントに限定し、DB/API/Auth/deployは触らないでください。desktopとmobile viewportで確認し、変更ファイル、確認コマンド、スクリーンショットまたはlocalhost確認結果、docs/task更新の有無をImplementation Reportとして返してください。

### Review Prompt

Review AIとして、実装差分が確認済み理解とscopeに合っているかを findings first で確認してください。mobile/desktopの崩れ、テキストはみ出し、不要な挙動変更、テスト/ビルド/スクリーンショット証跡、docs/task更新漏れを確認し、file/line参照つきで返してください。

### Progress Return Prompt

Implementation完了報告は、branch/worktree、変更ファイル、何を変えたか、verification結果、スクリーンショット/localhost evidence、docs更新、未完了、リスク、推奨next stepを含めてこの監督チャットに戻してください。

## Return Instructions

Implementation Reportを戻した後、監督チャットがReview AIへ送るか、実装差し戻しかを判断します。

## Human Confirmation

この方針で進めてよいですか？
承認前に branch/worktree/docs 作成、main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は行いません。
```

### Expected Behavior

- First response only confirms understanding.
- After OK, Medium is selected.
- Codex App Worktree or Orca is proposed.
- Implementation AI + Review AI is proposed.
- Branch/worktree/port/docs plan appears.
- Task doc and ACTIVE_TASKS are proposed based on risk.

### Pass / Fail

Pass

### Notes

The response requires task tracking only because Review AI/worktree/PR-style Medium triggers apply. It does not make task docs unconditional for every Medium.

## Case 3: Large

### Input Prompt

Turn 1:

```text
ログイン認証を入れて、DB設計もして、外部API連携までできるようにしたいです
```

Turn 2:

```text
はい。この理解で判定してください。
```

### Actual Response

Turn 1:

```md
理解確認：
やりたいことは「認証なし/DB設計なし/外部API連携なしの現状」を「ログイン認証、DB設計、外部API連携まで備えた状態」にすることですね。
現時点では production deploy、migration apply、secrets変更、production DB/data操作、課金/請求機能 は含めず、まず 認証・DB・外部API連携の設計と実装計画 の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

Turn 2:

```md
## Understanding Confirmed

ログイン認証、DB設計、外部API連携を入れる大きな機能追加として扱います。deploy、migration apply、secrets変更、production DB/data操作は人間承認なしでは含めません。

## Task Size

Large

## Reason

Auth、DB、外部APIはセキュリティ、データモデル、永続化、外部契約、環境変数、migrationを含む高リスク領域です。複数の設計選択と承認ゲートが必要なためMediumでは足りません。

## Execution Surface

Orca

Reason: Planning A/B、Integrator、Implementation、Reviewを分け、設計選択とリスクを並列に検討する必要があります。
Fallback: Orca不可なら Codex App Worktree + sequential Codex chats。ただしPlanning/Review/Integratorの役割は分離します。

## Agent Setup

- Count: 5AI minimum
- Roles: Planning AI A, Planning AI B, Integrator AI, Implementation AI, Review AI
- Why this split: Auth/DB/APIの設計妥当性、scope、migration/secrets/production riskを分離して検証するため
- Why not more: 性能/負荷/データ検証が重い場合だけValidation AIを追加

## Branch / Worktree / Port

- Branch: `feat/auth-db-api-integration`
- Worktree: `../repo-wt-auth-db-api-integration`
- Port: `3001` for local web verification if needed
- Naming reason: auth, db, api integration scopeを含むlowercase ASCII名
- Collision checks: target repo未指定のため未実行。作成前に `git branch --list`, `git worktree list`, `git worktree list --porcelain`, `find docs/tasks/active -maxdepth 1 -type f`, `lsof -i :3001` を確認する
- Human gate: create none of these until approved

## Documentation Plan

- Create: `docs/tasks/active/feat-auth-db-api-integration.md`, ACTIVE_TASKS row
- Update: requirements/spec if accepted scope exists; PR body after implementation
- Maybe: ADR for auth provider/session strategy, DB schema/migration approach, external API contract; ROADMAP if sequencing/product direction changes; `docs/PROJECT_SPEC.md` / `docs/DOCS_PROFILE.md` if missing
- Do Not Update: `AGENTS.md` with dynamic task state
- Closeout: task doc delete/archive decision, ACTIVE_TASKS cleanup, ROADMAP/ADR requirement status only with evidence

## Workflow

1. Planning AI A/Bが別々に設計案、risks、acceptance criteria、verification、human gatesを出す。
2. Integrator AIが設計差分を統合し、実装順、contracts、migration/secrets扱いを確定する。
3. Humanが計画、branch/worktree/docs作成、migration作成範囲を承認する。
4. Implementation AIが承認済みscopeだけ実装する。
5. Review AIがsecurity/data/API/tests/docsを確認する。
6. migration apply、production deploy、secrets変更、production DB/data操作は別途人間承認があるまで行わない。

## Prompt Pack

### Planning Prompt

Auth/DB/external API integrationの計画だけを作ってください。実装はしないでください。Scope/out of scope、DB schema案、auth/session案、external API contract、migration/secrets/production data risks、done criteria、verification、docs/ADR、human gatesを出してください。

### Integrator Prompt

Planning AI A/Bの案を統合し、採用案、却下理由、実装順、contracts、branch/worktree/docs、migration/secrets/deploy gate、verification matrixを返してください。

### Implementation Prompt

承認済みIntegrator planだけに従って実装してください。未承認のmigration apply、production deploy、secrets変更、production DB/data操作は禁止です。変更ファイル、verification、docs更新、未完了、リスクをImplementation Reportで返してください。

### Review Prompt

Review AIとして、auth/security、DB schema/migration safety、external API error handling、tests、docs、human gate違反の有無を findings first で確認してください。

### Progress Return Prompt

各workerはこの監督チャットに戻してください。branch/worktree、変更ファイル、verification、docs/task状態、unfinished、risks、human decisions neededを含めてください。

### Closeout Report Prompt

PR body、verification evidence、task doc/ACTIVE_TASKS cleanup、ROADMAP/ADR判断、cleanup candidates、Closeout Classificationを返してください。

## Return Instructions

Planning AI A/B の回答をこの監督チャットに戻してください。Integrator final plan、Implementation Report、Review Reportも同じ監督チャットに戻します。

## Human Confirmation

この方針で進めてよいですか？
承認前に branch/worktree/docs 作成、main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は行いません。
```

### Expected Behavior

- First response only confirms understanding.
- After OK, Large is selected.
- Orca is recommended.
- Planning AI A/B + Integrator + Implementation + Review is proposed.
- Task doc, ACTIVE_TASKS, ADR/ROADMAP where needed are proposed.
- Production deploy and migration apply require human approval.

### Pass / Fail

Pass

### Notes

The response explicitly separates planning from implementation and names migration, secrets, deploy, and production data gates.

## Case 4: UI Comparison

### Input Prompt

Turn 1:

```text
ログイン画面をA案、B案、C案で比較して、一番良いものを採用したいです
```

Turn 2:

```text
はい。この理解で判定してください。
```

### Actual Response

Turn 1:

```md
理解確認：
やりたいことは「ログイン画面」を「A案、B案、C案で別々に比較し、一番良い案だけ採用する」ことですね。
現時点では 認証ロジック変更、DB変更、外部API変更、main merge、負け案のmerge は含めず、まず ログイン画面UIの3案比較と勝ち案選定 の範囲として理解しています。

この理解で、タスク規模・AI人数・Orca/Codex・branch/worktree・docs更新計画を判定していいですか？
```

Turn 2:

```md
## Understanding Confirmed

ログイン画面UIをA/B/Cの3案で分離して作り、比較後に勝ち案だけ採用する範囲で扱います。認証ロジックやDB/API変更は含めません。

## Task Size

Medium

## Reason

対象は1画面のUI比較ですが、3案を同時に扱うためbranch/worktree/port分離とReview/Comparisonが必要です。Auth/DB/API/security変更がない前提なのでLargeにはしません。比較中に認証フローや設計変更が出た場合はLargeへ上げます。

## Execution Surface

Orca

Reason: A/B/C案を同時に別worktree/portで見比べる必要があります。
Fallback: Orca不可なら Codex App Worktreeを3本順番に作り、同じ監督チャットで比較します。

## Agent Setup

- Count: 4AI
- Roles: Implementation AI A, Implementation AI B, Implementation AI C, Review/Comparison AI
- Why this split: 各案を混ぜずに作り、最後に同一基準で比較するため
- Why not more: ログイン機能そのものを変えないならPlanning A/BやIntegratorは不要

## Branch / Worktree / Port

- Branch A: `experiment/login-ui-a`
- Worktree A: `../repo-wt-login-ui-a`
- Port A: `3001`
- Branch B: `experiment/login-ui-b`
- Worktree B: `../repo-wt-login-ui-b`
- Port B: `3002`
- Branch C: `experiment/login-ui-c`
- Worktree C: `../repo-wt-login-ui-c`
- Port C: `3003`
- Naming reason: 案ごとにbranch/worktree/portを完全分離するため
- Collision checks: target repo未指定のため未実行。作成前に `git branch --list`, `git worktree list`, `git worktree list --porcelain`, `find docs/tasks/active -maxdepth 1 -type f`, `lsof -i :3001`, `lsof -i :3002`, `lsof -i :3003` を確認する
- Human gate: create none of these until approved. 勝ち案だけPR化し、負け案はmergeせずcleanup candidatesにする。branch/worktree削除も人間承認が必要

## Documentation Plan

- Create: 比較用active task doc or 案別active task docs if 3 worktreesを実際に作る
- Update: ACTIVE_TASKSにA/B/Cのworktree/portを明記 if task docsを作る
- Maybe: PR body only for winning option
- Do Not Update: 負け案のPR、AGENTS.md、ADR unless durable design decisionが発生
- Closeout: 勝ち案PRに比較結果を書く。負け案branch/worktreeはcleanup candidatesとして列挙し、削除は承認待ち

## Workflow

1. A/B/Cの評価基準を先に決める。
2. 各案を別branch/worktree/portで実装する。
3. 各案のスクリーンショット/localhost evidenceを集める。
4. Review/Comparison AIが同一基準で比較する。
5. Humanが勝ち案を承認する。
6. 勝ち案だけPR化する。負け案はmergeしない。

## Prompt Pack

### Implementation Prompt

各案のImplementation AIは自分のbranch/worktree/portだけを使ってログイン画面UI案を作ってください。他案のworktreeやbranchを変更しないでください。認証ロジック、DB、APIは変更しないでください。スクリーンショット、変更ファイル、verification、未完了、リスクを返してください。

### Review Prompt

Review/Comparison AIはA/B/Cの各案を同一基準で比較してください。可読性、スマホ表示、入力導線、エラー表示余地、既存デザインとの整合、実装リスク、不要な認証ロジック変更の有無を findings first で返し、勝ち案候補と理由、負け案cleanup候補を出してください。

### Progress Return Prompt

各Implementation ReportとComparison Reportをこの監督チャットに戻してください。

## Return Instructions

各案の完了報告を戻した後、監督チャットが比較Reviewへ送ります。勝ち案のPR化はhuman承認後です。

## Human Confirmation

この方針で進めてよいですか？
承認前に branch/worktree/docs 作成、main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は行いません。
```

### Expected Behavior

- Each option has its own branch/worktree/port.
- Only the winning option becomes a PR.
- Losing options are not merged and become cleanup candidates.
- Multiple options are not mixed in one worktree.

### Pass / Fail

Pass

### Notes

The response chooses Medium because the stated scope is one UI screen only. The Skill could benefit from an explicit note that bounded UI comparison may be Medium+Orca, while architecture-heavy comparison should become Large.

## Case 5: Worker Return

### Input Prompt

```text
実装担当からこの報告が返ってきました。変更ファイルはA/B/C、buildは通っていますが、レビューはまだです。次にどう進めますか？
```

### Actual Response

~~~~md
## Returned Report Type

Implementation Report

## Current Evaluation

- Summary: 実装担当はファイルA/B/Cを変更し、buildが通ったと報告しています。Reviewは未実施です。
- Evidence quality: 部分的です。build結果はありますが、元計画、Done Criteria、テスト、スクリーンショット、docs/task状態、未完了項目、リスクが不足しています。
- Scope fit: original requestとConfirmed Understandingが提示されていないため判断不能です。
- Verification status: build passのみ確認。必要なtest、localhost/screenshot、docs更新確認は不明です。
- Risk status: 未レビューのため残リスクあり。

## Compared Against

- original user request: not available
- Confirmed Understanding: not available
- task doc: not available
- Scope / Out of Scope: not available
- Done Criteria: not available
- Verification: build passのみavailable。test/screenshot/local verificationはnot available
- previous plan: not available
- previous review: not available; review not yet run
- requirements, if available: not available

## What Looks Good

- buildが通っているため、Reviewへ送れる可能性はあります。
- 変更ファイル一覧が存在します。

## Problems / Gaps

- 元計画、Done Criteria、scope/out of scopeがないため、変更A/B/Cが妥当か判断できません。
- build以外のverificationが不明です。
- docs/task doc/ACTIVE_TASKSの状態が不明です。
- Review未実施です。

## Decision

Needs Clarification

## Next Action

human/supervisor が元計画とDone Criteriaを補足してください。それが揃えばReview AIへ送ります。

## Prompt To Use Next

```md
Clarification needed before continuing:

I cannot safely decide whether to send this to Review because:
- original user request is missing
- Confirmed Understanding is missing
- Scope / Out of Scope is missing
- Done Criteria is missing
- verification plan is missing
- previous review is not available

Please provide:
1. accepted plan or task doc
2. Done Criteria
3. required verification beyond build
4. whether files A/B/C are the expected changed files

Until answered, do not broaden scope, create branches/worktrees, merge, deploy, apply migrations, change secrets, delete branches/worktrees, or operate on production data.

If those items confirm the implementation is complete enough, the next prompt will be:

You are Review AI. Review only; do not implement fixes unless separately approved.

Confirmed request:
<paste confirmed request>

Inspect:
- Files A/B/C

Acceptance criteria:
- <paste Done Criteria>

Known risks or skipped checks:
- Review has not yet run. Build passed. Other checks: <paste status>.

Return findings first, ordered by severity, with file/line references where possible. Then include missing tests, skipped verification, residual risk, open questions, and a brief pass/fail summary.
```
~~~~

### Expected Behavior

- Returned Report Type is Implementation Report.
- It compares against original plan, Done Criteria, previous review, and other sources.
- Decision is Send to Review or Needs Clarification.
- Prompt To Use Next is emitted.

### Pass / Fail

Pass

### Notes

The response chooses Needs Clarification because the prompt lacks the baseline needed to safely send to Review. This is within the expected decision set.

## Case 6: Closeout

### Input Prompt

```text
レビュー合格、mainへのmerge前です。作業を閉じるには何を確認すべきですか？
```

### Actual Response

```md
## Closeout

- PR body summary: purpose、変更内容、verification、impact、unfinished items がPR本文に揃っているか確認してください。未完了がない場合も `none` と明記します。
- Verification evidence: build/test/localhost/screenshotなど、Done Criteriaを満たす証跡があるか確認してください。レビュー合格だけではverificationの代替にしません。
- Active task doc: `docs/tasks/active/<branch-name>.md` がある場合、trivialなら削除、判断やincident/follow-upが有用なら `docs/tasks/archive/` へarchiveする計画を確認してください。
- ACTIVE_TASKS cleanup: `docs/tasks/ACTIVE_TASKS.md` から完了branch/worktreeの行を削除する計画を確認してください。
- ROADMAP: product directionやsequencingが変わった場合だけ更新します。変わっていなければ更新不要と記録します。
- ADR: durable architecture decisionが増えた場合だけ作成/更新します。なければ不要と記録します。
- Requirements/progress: 要件やprogress statusをdoneにする場合は evidence を添えます。証拠が弱ければ `needs_verification` のままにします。
- Cleanup candidates: merge後のbranch、remote branch、worktreeはcleanup candidatesとして列挙するだけにします。削除は人間承認が必要です。
- Closeout classification: `main_unintegrated`。まだmain merge前なので `integrated` にはしません。
- Human confirmation required: main merge、production deploy、migration apply、`git push --force`、`git reset --hard`、`git clean -fd`、branch/worktree/remote branch deletion、secrets / `.env` change or disclosure、production DB/data operation は明示承認が必要です。
```

### Expected Behavior

- Treated as Closeout Report or Human Approval Needed.
- PR body, active task doc, ACTIVE_TASKS, ROADMAP/ADR, cleanup candidates are checked.
- Main merge, deploy, branch deletion, worktree deletion require human approval.

### Pass / Fail

Pass

### Notes

The response correctly keeps the task as `main_unintegrated` before main merge and does not authorize cleanup or merge.

## Overall Verdict

pass

## Issues Found

- No behavioral failure was found in the six requested prompt cases.
- REQ-027 still has a completion evidence gap outside these six cases: the existing spec/progress board also asks for real operation evidence, and the manual prompt test plan still lists additional live returned-report scenarios such as Planning Result, Integrator Result, Review Report, and Error / Blocker Report.
- Case 4 exposes a small ambiguity: bounded UI comparison can reasonably be Medium+Orca, while the size rubric also lists multiple branches/worktrees as a Large signal.

## Suggested Fixes

- Add one explicit sentence to the Skill rubric: bounded same-screen UI comparison may stay Medium+Orca when it has no Auth/DB/API/security/data impact; architecture-heavy or cross-feature comparisons should be Large.
- Run and record the remaining returned-report scenarios if the existing `manual-prompt-tests.md` checklist remains the acceptance source.
- Record at least one real operation closeout or representative PR/task closeout before marking REQ-027 done.

## Can REQ-027 Move To Done?

no

Reason: the six requested prompt cases pass, but the repository's own completion criteria still require real operation evidence and additional live returned-report coverage before `REQ-027` can safely move from `needs_verification` to `done`.

## Final Update

On 2026-06-26, the missing additional returned-report prompt cases were recorded in `live-manual-prompt-test-additional-2026-06-26.md`, and real branch/worktree representative operation evidence was recorded in `real-operation-evidence-2026-06-26.md`. This historical `no` verdict is superseded by the final REQ-027 `done` decision in the requirements ledger.
