# heavy-flow — 「詰めて一気に」詳細手順（0+9ステップ）

前提: task-router が「詰めて一気に」と判定済み。既存 `docs/ai` 運用repoまたは明示採用時だけ状態ボードを更新する。この workflow は legacy/compat 運用であり、Personal OS やrepo横断の新しいdocs標準ではない。

## 0. 指示正本チェック

- `AGENTS.md` と `CLAUDE.md` の有無を確認する。
- 共通指示の正本は `AGENTS.md`。Claude Code では `CLAUDE.md` の先頭に `@AGENTS.md` を置く。
- 両者がない、または共通指示が重複・矛盾している場合は、`repo-create` のAGENTS監査で整備してから重い開発に入る。
- 小さな即実装ではこの整備をブロック条件にしない。ただし無い物は状態報告に1行で明記する。

## 1. Run記録開始

- 既存 `docs/ai` 運用repoまたはユーザーが明示採用した場合だけ、`workflows/task-board.md` に従い、`docs/ai/task-board.md` が無ければ作る。
- 同じ条件で、`workflows/telemetry-and-mistakes.md` に従い、`docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` が無ければ作る。
- 既存または作成済みの `docs/ai/task-router-analysis.md` がある場合だけ、最新Summaryと、open/highまたは今回の領域に関係するmistakeを確認する。
- 既存 `docs/ai` 運用repoまたは明示採用repoの非自明な作業は、開始時に `TASK-YYYYMMDD-NNN` を採番して board の Active に追加する。
- 同じ条件で計画が必要なら `docs/ai/plans/active/YYYYMMDD-<slug>.md` を作る。既存の `docs/plans/*` や `docs/requirements/*` を使う場合は、board の Plan 欄からそこへリンクする。
- 同じ条件で `workflows/telemetry-and-mistakes.md` に従い、`docs/ai/task-runs.jsonl` 用の run_id を決める。
- 開始時刻、依頼概要、初期判断を控える。
- 初期判断は `SINGLE_CHAT` / `SEQUENTIAL` / `PARALLEL_WORKTREES` / `PARALLEL_SUBAGENTS_READONLY` / `HYBRID_PLAN_THEN_PARALLEL` / `DO_NOT_PARALLELIZE` のいずれか。
- `docs/ai/` がないrepoでは、ユーザーが旧 task-router 運用を明示採用した場合だけ必要最小限で作る。明示採用がない場合はチャット上で記録案を出し、新しいdocs標準づくりには入らない。
- ユーザーが「実装しない」「編集しない」「記録ファイルも触らない」と指定した場合は board / plan / run log も更新せず、記録案だけチャットに出す。

## 2. 詰める（grill-me）

- 目的 / 客観的で実行可能な受け入れ条件 / スコープ in-out / リスク を確定。
- 曖昧が残るうちは先へ進まない。
- 複数タスクがある場合は、依存関係、同じファイル・同じ機能領域、UI/backend/DB/auth/docs/tests/refactor の分類を先に出す。
- 企画・プランを作ったら board の Plan / Status / Scope / Next を更新する。チャット内の計画だけで進めない。
- 大きいタスクでは、この親チャットは実装に入らず、grill-me / 調査統合 / 計画 / workerプロンプト生成 / 戻りレビューを担当する。
- 多方面の調査が必要な場合は、ユーザーが明示的に並列agentを許可している時だけ、コード調査・公式docs/Web調査・テスト観点・リスク調査をreadonlyに分ける。各調査は要約、根拠、未解決質問、推奨分割だけ返す。
- 調査結果が戻ったら、親チャットで事実・推測・未決事項を分け、実装方針と分割可否を確定してから次へ進む。

## 3. 分解 + Parallelization Gate

- まず触る領域を概算（`rg` / `ls` で対象ファイル群を把握）。
- 層・モジュール境界で割る: 例 API route / DB migration / UI component / tests / 型・契約。
- 時間だけで判断しない。以下を必ず見る。
  - 同じファイルを複数チャット/agentが触りそうか。
  - API contract / DB schema / shared types / generated client / auth / error format が未確定ではないか。
  - 変更範囲がディレクトリ単位・route単位・component単位で分けられるか。
  - 統合時の衝突コストが高すぎないか。
  - 先に設計・契約ファイルを作れば安全に並列化できるか。
  - 調査・レビュー・テスト設計のように、書き込みを伴わない並列化か。
- 各タスク: `ID / Goal / Allowed files(被らない) / 禁止範囲 / 依存 / 受け入れ条件 / 完了報告`。
- 被るならマージして1タスクに、依存があれば後段へ。allowed files が重なる実装チャットは並列化しない。
- 並列化可否は `workflows/parallelization-gate.md` に従って判断し、判断理由を run 記録に残す。

## 4. 契約 / ownership / worktree 判断

UI と backend を並列で進める場合は、いきなり実装に入らない。

1. Architect / Planner チャットで設計・契約を作る。
2. 必要に応じて `API_CONTRACT.md` / `UI_ACCEPTANCE.md` / `TEST_PLAN.md` / `OWNERSHIP.md` を作る。
3. Frontend / Backend / Integration / Review の責務、編集範囲、禁止範囲を決める。
4. 記録責務を決める。通常は Planner が開始時の board / active plan、Integration が完了時の board / run log / archive を担当し、Frontend / Backend worker は記録ファイルを触らない。
5. commit / staging 方針を決める。`commitしないで` は編集・検証のみ、`実装しないで` / `編集しないで` は no-write として扱う。
6. worktree は例外として扱う。既存の main worktree で順次実装できるなら作らない。
7. worktree を使う場合は、実行ではなく計画として提示する。契約・allowed files・統合担当・終了条件・mainへ取り込む条件・捨てる条件が固まるまでは作らない。

Planner / Architect は原則として実装しない。役割は計画、契約、ownership、実装チャット用プロンプト案、最後に戻ってきた成果物のレビュー観点作成までに留める。

worktree 提案前に確認する。

```bash
git fetch --prune origin
git status --short --branch
git branch --show-current
git rev-parse --show-toplevel
```

提案に含める。

- 既存の main worktree で足りない理由
- worktreeを作る例外条件（明示された並行実装、大型機能、DB migration、本番保留、未コミット差分の保護など）
- current branch / base branch
- uncommitted changes
- branch/worktree 名
- 各 worktree の責務
- 各 worktree で編集してよい範囲 / いけない範囲
- 各 worktree の終了条件、mainへ取り込む条件、捨てる条件
- merge順
- integration 用 worktree を作るか
- worktree側で検証を完結できるか、最後にLocalへHandoff/統合して検証するか
- 終了時に `active` / `integrated` / `abandoned` / `main_unintegrated` のどれで記録するか

コマンド例は「提案」として出す。実行は親またはユーザーが確認してから。

```bash
git worktree add ../<repo>-<topic>-ui -b feat/<topic>-ui main
git worktree add ../<repo>-<topic>-api -b feat/<topic>-api main
git worktree add ../<repo>-<topic>-integration -b feat/<topic>-integration main
```

## 5. 実装チャット用プロンプト生成 / handoff

実装並列は既定にしない。必要な場合だけ、サブエージェントspawnではなく、別Codexチャットまたは承認済みworktreeへプロンプトを渡す。

- Planner / Frontend / Backend / Integration / Review / Docs Tests 用プロンプトは `workflows/worker-prompt-template.md` の型を使う。
- 各プロンプトには、役割、目的、参照docs/files、編集してよい範囲、編集してはいけない範囲、制約、確認コマンド、完了条件、Integrationへの引き継ぎを入れる。
- 実装workerには、明示的に禁止されていない限り「allowed filesだけ編集 → 検証 → commit → 親チャットへ完了報告」を指示する。pushは明示依頼がある時だけ。
- Frontend / Backend / Docs Tests worker には、明示的に任せない限り `docs/ai/task-board.md` / `docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` / `docs/ai/task-archive/**` を編集しないよう指定する。記録は終了報告に残させ、Integration が回収する。
- ユーザー指定の commit / no-write 方針を各プロンプトへ明記する。曖昧な場合は「編集はするがcommitしない」などの推測を置かず、親チャットで決めてから渡す。
- 並列 worktree で実装する場合は、各チャットの最後に必ず以下を報告させる。
  - changed files
  - implemented behavior
  - test commands and results
  - assumptions
  - contract deviations
  - integration notes
  - risks / unresolved items
  - staged / unstaged changes
  - commit hash（commitした場合）

サブエージェントを使う場合は、ユーザーが明示的に並列agent利用を求めており、現在の実行環境で許可されている時だけにする。使う場合も原則 readonly。

- explorer: 影響範囲、既存パターン、過去PR、テスト方法を調べる。
- reviewer: セキュリティ、テスト漏れ、保守性、API契約一致を確認する。
- test-designer: テスト観点と不足ケースを出す。

## 6. 全部を1本に組み上げる（Integration）

- 前提: 各実装チャットが自タスクをコミット済みにする（未コミットを残さない）。
- 親チャットまたは Integration チャットは、各実装チャットの「完了」報告、commit hash、検証結果、未解決リスクを受け取ってから統合する。
- 統合前に、各workerのcommitがallowed filesと目的に収まっているかを確認する。範囲外変更や未報告差分があれば統合前に差し戻す。
- ユーザーが worker に commit 禁止を指定した場合は、各workerの未コミット差分をIntegrationが確認して統合する。commit済み前提に戻さず、未コミット差分の所有者とscopeを先に整理する。
- worker が記録ファイルを編集していた場合は、意図を確認し、最終記録はIntegrationで一本化する。衝突を避けるため、記録ファイルの更新は最後にまとめる。
- 複数worktree / 複数branch を使った場合は、統合ブランチを作り、全 feat を漏れなく集約する。main は人間ゲートまで触らない。単一チャットまたは順次実装で済む場合は、リポジトリのAGENTS.mdに従って main へ小さくコミットしてよい。

```bash
git switch -c "integrate/<topic>" main
for b in feat/<id1> feat/<id2> feat/<id3>; do git merge --no-ff "$b"; done
```

- コンフリクト/ビルド/テスト失敗は、両側の意図を踏まえて最小修正する。自動補修は上限3回。
- 全タスクが入るまで integration は未完。失敗タスクが残るなら直すか、明示的にスコープ外にする。黙って部分リリースしない。
- UI mock、temporary flag、contract deviations、generated files / lockfile の意図しない更新を確認する。
- `local main` に取り込めた worker branch は `integrated` として記録する。取り込まない判断をしたものは理由付きで `abandoned`、継続するものは次の判断タイミング付きで `active`、判断不能なものは `main_unintegrated` として残す。

## 7. 組み上がった全体を検証（実環境）

- 検証は integration ブランチ＝全機能が合体した状態で行う。
- 種別判定: web(localhost) / mobile / API / lib。
- web は dev 起動 → kimi-webbridge（ログイン済みブラウザ）または playwright → viewport(PC / 375px) → 主要フロー → スクショ → console/network 確認。
- 客観指標で合否判定する。画面ロード / console 無エラー / 主要 API 200 / UI状態 / API contract一致。
- 全体で見つかった不整合は integration 上で修正する。自己採点で合格扱いしない。

## 8. 人間ゲート → main へ一括 → デプロイ

- 状態ボード（全タスク / 検証結果 / 差分要約 / 未解決リスク）を提示し、「全部入りました。main に入れていいですか?」と明示確認する。
- 承認後、integration を main に一度の merge で入れる。

```bash
git switch main && git merge --no-ff "integrate/<topic>"
```

- worktree 片付けは `integrated` または `abandoned` に分類した後、明示承認を得てから行う。`git worktree remove --force` で未コミットのフォルダを捨てない。
- デプロイは別ゲート。main push 後・明示承認でデプロイする。

## 9. Run記録終了

- 完了報告の前に `workflows/task-board.md` に従い、board と月別アーカイブを更新する。
- Active から完了タスクを外し、`docs/ai/task-archive/YYYY/MM.md` に完了行を追加する。
- task-router が作った active plan は `docs/ai/plans/archive/YYYY/MM/` へ移す。
- `docs/ai/task-board.md` の Recently Completed には直近の見出しだけ残す。
- `docs/ai/task-runs.jsonl` に実績を追記する。
- worktree / branch を使った場合は、各 worktree / branch の lifecycle 状態（`active` / `integrated` / `abandoned` / `main_unintegrated`）を記録する。
- ユーザーが commit 禁止を指定している場合は、上記の記録更新も未コミット差分として残すか、ユーザーが記録ファイル編集も禁止している場合は追記案だけ最終報告に出す。
- `parallel_value` に、単一チャットがよかった / readonly並列がよかった / 複数Codexチャットがよかった / worktreeが必要だった / 並列化が危険だった、の評価を残す。
- 再発防止が必要な失敗は `docs/ai/mistakes.md` に記録する。
- 5 run ごと、または大きな失敗後に `docs/ai/task-router-analysis.md` で判断基準を見直す。
- 分析で毎回守るべき恒久ルールが見えたら、`docs/ai/task-router-analysis.md` に留めず `task-router` の `SKILL.md` または該当workflowへ昇格する。状況依存・観察中の知見はanalysisに残す。

## マージ安全（worktree）

- worktree は常用しない。小さい作業、通常のUI調整、docs変更、順次実装は既存の main worktree で進める。
- worktree を使う場合、通常は対応する一時branchも増える。branchを増やしたくない目的なら、そもそもworktreeを使わない判断を優先する。
- 同じ `main` branch を複数worktreeにcheckoutして並行実装する運用はしない。
- マージ前に各 worktree でコミットしておく（未コミットを残さない）。merge は履歴を足すだけで非破壊。
- 片付け前に、対象が `integrated` または `abandoned` であること、未コミット差分と未追跡ファイルがないこと、DB migration / 外部設定 / 生成物の扱いが決まっていることを確認する。
- コンフリクトを片側一括破棄で解決しない: `git checkout --theirs/--ours .` / `git merge -X ours|theirs` / `git reset --hard` は禁止。
- 片付けは `git worktree remove`。`--force` で未コミットのフォルダを捨てない。

## 禁止

- 人間ゲート無しの main merge / push / deploy。
- 実装サブエージェントの無計画な並列spawn。
- 自動補修の無限ループ。
- 被る allowed files での並列実装。
- force push / `git reset --hard` / `git clean -fd(x)` / `git restore .` / `git checkout .`。
- 本番DB操作 / secret・token表示編集 / GCP・GCS削除停止 / 未承認の大規模削除 / 意図しないlockfile更新 / unrelated refactor。
