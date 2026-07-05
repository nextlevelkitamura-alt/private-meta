---
name: task-router
description: 既存 docs/ai 運用repo向けのlegacy互換ルーター。開発依頼を即実装/詰めて一気に/単一チャット/順次/readonlyサブエージェント/複数Codexチャット/worktreeに振り分ける。契約・ownership・実装/Integration/Review用プロンプト、docs/ai/task-board.md、task-runs/mistakes/task-router-analysisの既存運用を扱う。Use when 既にdocs/aiを採用しているrepoの開発依頼、並列判断、複数チャット分割、worktree判断、task分解、既存task-router分析。
---

# task-router

既存 `docs/ai` 運用repoの開発依頼の交通整理、進捗ボード管理、複数Codexチャットへ安全に渡すプロンプト生成をする。**詰めてから一気に作る**のを既定にする。

## 現状の位置づけ

- この Skill は、既に `docs/ai/task-board.md` 運用を持つrepo、またはユーザーが明示的に旧 task-router 運用を採用したrepo向けの legacy/compat ルーター。
- Personal OS や各repo共通の新しいdocs標準を設計する役割ではない。新標準が決まるまでは、この Skill から明示採用なしに新規repoへ `docs/ai` を増やさない。
- 旧参照の `kaihatsu-kanri` / `task-splitter` は使わない。AGENTS/CLAUDE整備は `repo-create`、要件・進捗・矛盾・実装整合は `requirements-governor`、分解と並列化判断はこの Skill 内の `workflows/parallelization-gate.md` で扱う。

## 哲学（最重要）
- **場当たり修正を避ける。** 「これ直して」を都度こなすと、直した側で別が壊れ全体が崩れる。
- **詰めてから一気に。** 深く設計を詰め、全体を見て分解し、通常は単一チャットまたは順次実装で進める。複数Codexチャット/worktreeは例外条件を満たす時だけ使う。
- **サブエージェントは主にreadonly。** 並列化したい時も、調査・レビュー・テスト設計はサブエージェントに寄せる。実装を分離したCodexチャット/worktreeへ渡すのは、編集範囲と統合責任が明確な時だけ。
- **分解は並列実行の許可ではない。** task-router はまず依存・契約・ownership を明確にする。並列化は、その後に安全性と統合コストで選ぶ。
- **大きいタスクの親チャットは実装しすぎない。** 親チャットは grill-me/調査/計画/分解/workerプロンプト生成/戻りレビュー/統合判断を担当し、実装分離は必要性を確認してから行う。
- **worktreeは常用しない。** worktreeを作る判断は一時branchを増やす判断でもある。小さい作業や通常の順次実装では既存のmain worktreeで小さくコミットする。
- **worktreeは閉じるまでが作業。** worktree / 一時branch を作ったら、終了時に `active`（継続）/ `integrated`（local mainへ取り込み済み）/ `abandoned`（捨てる判断済み）のどれかに分類する。分類できないものは完了扱いにしない。
- **時間だけで並列化しない。** 同じファイルを触る可能性、API契約、DB schema、shared types、generated files、統合コスト、失敗時にworktree単位で捨てる必要が本当にあるかを見る。
- **進捗をチャットに閉じない。** 既存 `docs/ai` 運用repoでは `docs/ai/task-board.md` を現在地の正本にし、計画・完了・月別アーカイブを更新する。
- 自明な小修正は最短で。価値ある案件は徹底的に詰める。迷ったら「詰めて一気に」へ。
- **計測して改善する。** 並列化した理由、agent数、所要時間、失敗、次回判断を記録し、勘ではなく実績でルーティングを改善する。
- **改善ログを必ず用意する。** 既存 `docs/ai` 運用repoの非自明runでは `docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` の存在を確認し、無ければ最小テンプレートで作る。

## 起動
- **自動**: 既に `docs/ai` と task-router 起動条件を持つrepoの非自明な開発依頼。
- **明示**: `/task-router`。新規repoへ導入する場合は、旧互換運用を暫定採用する判断を先に確認する。
- 他リポへ自動化を広げる時は、新しい共通docs標準が未決であることを明記し、暫定的な旧互換採用として扱う。
- AGENTS.md / CLAUDE.md が無い、または矛盾しているリポでは、実装を急がず `repo-create` のAGENTS監査で入口指示を整備してから重い開発に入る。

## AGENTS.md との関係
- `task-router` は開発依頼の入口と実装進行の司令塔。正本ファイルではない。
- リポジトリの共通指示は `AGENTS.md` を正本にする。Claude Code は `CLAUDE.md` から `@AGENTS.md` を import する形を既定にする。
- `AGENTS.md` には task-router の詳細手順を貼らない。起動条件、ゲート、関連 skill だけを短く書く。
- 旧 `docs/ai` 運用での進捗ボード名は `docs/ai/task-board.md`。task-router が新規に作る計画は `docs/ai/plans/active/`、完了タスクは `docs/ai/task-archive/YYYY/MM.md`、完了計画は `docs/ai/plans/archive/YYYY/MM/` に置く。
- `AGENTS.md` には、旧 `docs/ai` 運用を採用している場合だけ `docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` への短い案内を置く。本文や長い反省は入れない。
- task-router の旧 `docs/ai` 起動条件、task-board、Context Pack / Task State を変えた時は、既存テンプレートが旧互換を前提にしていないか確認する。
- 要件、進捗、矛盾、PR順、デプロイ順、実装整合は `requirements-governor`、AGENTS/CLAUDE同期は `repo-create` に任せる。

## 2モード
| モード | 対象 | 進め方 |
|---|---|---|
| 即実装 | タイポ/文言/自明な1ファイル修正 | 詰めない。git status確認 → 直す → 検証 → 報告 |
| 詰めて一気に（既定） | 機能・設計判断・複数ファイル・不確実 | 下の0+9ステップ。必要なら複数Codexチャット用プロンプトを生成 |

## 大きいタスクの責務分離
- 親チャット: grill-meで要件を詰める、多方面の調査を束ねる、計画を作る、タスクを分解する、各実装チャット用プロンプトを作る、戻ってきたcommit/報告をレビューする。
- 調査サブエージェント: 明示許可がある場合だけ、コード調査・Web/公式docs調査・テスト観点・リスク調査をreadonlyで行い、要約だけ返す。
- 実装チャット（必要時のみworktree）: 指定されたallowed filesだけを編集し、検証し、原則commitして、最後に親チャットへ完了報告する。pushは明示依頼がない限りしない。
- Integration: 各実装commitを集め、契約一致・衝突・テスト・実画面を確認し、必要な最小修正と最終記録を行う。

## 並列化の使い分け（イメージ）
```
オーケストレーター(親=指揮) 1体
 ├ readonly explorer → 影響範囲/既存パターン/リスク調査
 ├ readonly reviewer → セキュリティ/テスト漏れ/保守性レビュー
 ├ Planner chat      → API_CONTRACT / UI_ACCEPTANCE / TEST_PLAN / OWNERSHIP
 ├ Frontend Codex    → 原則は単独/順次。必要時だけUI用worktreeで実装
 ├ Backend Codex     → 原則は単独/順次。必要時だけAPI/DB用worktreeで実装
 └ Integration Codex → 全成果を統合し、実環境検証へつなぐ
```
- **実装サブエージェント並列は既定にしない。** 実装は単一チャットまたは順次を既定にする。別Codexチャット/worktreeへ渡す場合は、役割・参照docs・allowed files・禁止範囲・確認コマンド・完了報告・統合担当を先に明記する。
- **サブエージェントは原則readonlyかつ明示依頼時のみ。** explorer / reviewer / test-designer / security-reviewer のように、調査・レビュー・テスト設計を並列化する。ユーザーや実行環境のルールがサブエージェント明示依頼を要求する場合、暗黙にspawnしない。
- **1実装チャット = 1責務 = 1編集範囲**。worktreeを使うなら原則 `1 Codex chat = 1 worktree = 1 branch` とし、allowed files を重ねない。同じ `main` branch を複数worktreeで実装共有しない。
- **worker branch を放置しない。** 実装workerのcommitは中間成果物。Integrationが `local main` へ取り込むか、理由付きで `abandoned` にするまで、その作業は完了ではない。
- 並列化してよいかは `workflows/parallelization-gate.md` で判定する。迷う場合は `SINGLE_CHAT` または `SEQUENTIAL` に倒し、許可済みなら `PARALLEL_SUBAGENTS_READONLY` に留め、実装チャット分割はしない。

## 「詰めて一気に」0+9ステップ（詳細: workflows/heavy-flow.md）
0. **指示正本チェック**: `AGENTS.md` / `CLAUDE.md` の有無と矛盾を確認。未整備なら `repo-create` のAGENTS監査で正本化する。
1. **Board/Run記録開始**: 既存 `docs/ai` 運用repoまたは明示採用時だけ、`workflows/task-board.md` に従い `docs/ai/task-board.md` を作成/更新し、`workflows/telemetry-and-mistakes.md` に従い改善ログ3点を作成/確認し、run_id、開始時刻、並列化仮説を記録する。
2. **詰める**（grill-me）: 目的・客観的な受け入れ条件・スコープを確定。曖昧なら先へ進まない。
3. **分解と並列化Gate**: `workflows/parallelization-gate.md` に従い、編集範囲・共通契約・統合コストまで見て判断する。
4. **契約/ownership/worktree判断**: 必要なら Planner チャットで API_CONTRACT / UI_ACCEPTANCE / TEST_PLAN / OWNERSHIP を作る。worktreeは例外条件を満たす時だけ状態確認後に提案する。実装分割は契約とallowed filesが固まってから。
5. **実装チャット用プロンプト生成**: Frontend / Backend / Tests / Docs / Integration / Review など、各Codexチャットへ渡すプロンプトを `workflows/worker-prompt-template.md` で作る。実装workerには「検証後commit、完了報告、push禁止」を明記する。readonly調査・レビューだけサブエージェントを使う。
6. **全部を1本に**: 複数branch/worktreeを使った場合は、各Codexチャットのコミット/報告を受け、**全 feat を漏れなく**統合ブランチへ集約。単一チャット/順次実装ならリポジトリのAGENTS.mdに従ってmainへ小さくコミットする。**部分リリース禁止**。
7. **全体を検証**: 複数branch/worktreeの場合は統合ブランチ＝全機能が合体した状態で実環境チェック。単一チャット/順次実装の場合も全体の不整合はここで修正。
8. **人間ゲート → main へ一括 merge → 後片付け**。デプロイは別ゲート（main push後・明示承認）。
9. **Board/Run記録終了**: 既存 `docs/ai` 運用repoまたは明示採用時は、完了前に各worktree/branchを `active` / `integrated` / `abandoned` / `main_unintegrated` に分類し、`docs/ai/task-board.md` と月別アーカイブを更新する。所要時間、agent数、衝突、検証、mistakes、次回の並列化判断を記録する。5 runごと、または重要な失敗後は分析を更新し、恒久ルールだけこのSkillやworkflowへ昇格する。

## 検証（Phase 2a・実環境）
- アプリ種別を判定して適切な環境で開く: web/localhost=デスクトップ実画面、スマホ=モバイル幅(例375px)、API=ステータス確認。
- **ログイン必須の画面は kimi-webbridge**（あなたの実ブラウザ＝Arc 等の保存ログインで操作）。playwright-scout も可。
- **客観指標で合否判定**: 画面ロード / console 無エラー / 主要 API 200 / スクショ。**自分の実装を自分でOKにしない**。
- ※ 検証NG→自動修正の「ループ」は **Phase 3**。今は検証→報告まで（直しは人間判断 or 明示指示）。

## 状態の可視化（必須）
「詰めて一気に」の最中は、更新のたび**状態ボード**を出す:
```
[router 状態] 目的:<一言>   詰め:✅  分解:4タスク
 #1 feat/api-intake   Backend Codex  実装中 ▓▓▓░░
 #2 feat/db-migrate   Planner        ✅→Integration待ち
 #3 feat/ui-form      Frontend Codex 実装中 ▓▓░░░
 #4 feat/tests        待機(依存#1)
検証:未   mainマージ:未(人間ゲート)   デプロイ:未
```

## 安全方針（自動化の歯止め）
- 副作用レベル: **L2**。実装チャット分割・worktree作成・統合の前に、既存main worktreeで足りない理由、終了条件、mainへ取り込む条件、捨てる条件を含めて要点を提示。
- **人間ゲート必須**: **main への merge とデプロイの直前**は、状態ボードを見せて明示承認を取る（既定）。信頼できたら緩める相談可。
- 自動補修は**上限3回**で停止→人間へ。無限ループ禁止。自己採点での合格判定 禁止。暗黙の merge/push/deploy 禁止。
- 禁止 git: `reset --hard` / `clean -fd(x)` / `restore .` / `checkout .` / `rebase` / `push --force` / branch・worktree 削除（承認なし）。
- 禁止操作: 本番DB操作 / secret・tokenの表示編集 / GCP・GCS等の削除停止 / ユーザー承認なしの大規模削除 / 意図しないlockfile更新 / unrelated refactor。
- 並列実装の絶対条件: **allowed files が重ならない**。重なるなら直列化、または先に契約/ownershipを作る。

## 既存資産の扱い
`AGENTS.md` / `docs/ai` / `scripts` / `package.json` / テストは**有れば使う**。旧 `docs/ai` 運用を明示採用していないrepoでは、無い物を前提にせず素の git だけで進め、無い物は1行明記する。着手前は preflight が有れば実行、無ければ `git status` で dirty 確認。

## 記録と改善
- 既存 `docs/ai` 運用repoの非自明な task-router run は `docs/ai/task-runs.jsonl` に1行で実績を残す。
- 既存 `docs/ai` 運用repoの非自明な task-router run は `docs/ai/task-board.md` に現在地を残す。完了後は `docs/ai/task-archive/YYYY/MM.md` と `docs/ai/plans/archive/YYYY/MM/` へ月別格納する。
- 既存 `docs/ai` 運用repoで再発しそうな失敗は `docs/ai/mistakes.md` に記録する。`AGENTS.md` には mistakes の本文を入れず、「失敗・学習ログは `docs/ai/mistakes.md`」という見出しとリンクだけ置く。
- `docs/ai/task-router-analysis.md` は毎回全文を読まない。開始時は最新Summary、open/highのmistake、今回の領域に関係するFindingだけ確認する。
- 既存 `docs/ai` 運用repoでは5 run ごと、または大きな失敗後に `docs/ai/task-router-analysis.md` を更新し、「単一チャットがよかった / readonly並列がよかった / 複数Codexチャットがよかった / worktreeが必要だった / 並列化が危険だった」の判断基準を見直す。
- 重要度が高く、今後も毎回守るべき改善は `task-router` の `SKILL.md` または該当workflowへ昇格する。状況依存・観察中の知見は `task-router-analysis.md` に留める。
- 詳細は `workflows/task-board.md` / `workflows/telemetry-and-mistakes.md`。

## 関連
- 詰める=**grill-me** / 分解と並列化判断=この Skill の `workflows/parallelization-gate.md` / 要件・進捗・矛盾=**requirements-governor** / AGENTS整備=**repo-create** / 実環境検証=**kimi-webbridge**・**playwright-scout**
- 詳細手順: `workflows/heavy-flow.md`
