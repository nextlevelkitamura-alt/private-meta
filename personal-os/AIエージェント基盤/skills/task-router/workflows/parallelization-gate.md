# parallelization-gate

単一チャット、順次実行、readonlyサブエージェント、複数Codexチャット、Git worktree をどう使い分けるかを決める判定基準。

## 目的

並列化は速くするための手段であり、目的ではない。タスクが大きいだけでは並列化しない。通常の実装は既存の main worktree で単一チャットまたは順次に進める。編集範囲・責務・契約・統合手順が明確で、並列化による短縮メリットが統合コストを上回り、かつmain作業では安全に進められない場合だけ複数Codexチャット/worktreeを提案する。

重要: task-router では、タスク分解と並列実行を混同しない。分解は常に行ってよいが、並列実行は編集範囲・契約・統合責任が明確な場合だけ選ぶ。サブエージェントは、実行環境とユーザー指示が許す場合に限り、原則 readonly の調査・レビュー・テスト設計に使う。実装並列はサブエージェントspawnではなく、別Codexチャット/worktreeへプロンプトを渡して行うが、worktreeは例外条件を満たす時だけ使う。

## 判定ラベル

| ラベル | 使う場面 |
|---|---|
| `SINGLE_CHAT` | 小さく明確で、1チャット内で実装・検証・コミットまで進める方が速い |
| `SEQUENTIAL` | 複数ステップだが依存が強く、同じチャットで順番に進める方が安全 |
| `PARALLEL_WORKTREES` | write scope が分離でき、mainで順次進めるより明確に安全で、各 worktree を破棄・統合しやすい |
| `PARALLEL_SUBAGENTS_READONLY` | ユーザーが明示的に並列agentを許可し、調査・レビュー・テスト設計など、書き込みなしで観点を分ける |
| `HYBRID_PLAN_THEN_PARALLEL` | 先に設計・契約・ownership を固めれば、後続を安全に分けられる |
| `DO_NOT_PARALLELIZE` | 危険操作・仕様曖昧・衝突高リスクなど、並列化しない方がよい |

## 判断材料

時間や作業量だけで判断しない。必ず次を見る。

- 同じファイルを複数チャット/agentが触りそうか。
- UI と backend のように責務が分けやすいか。
- API contract、型、DB schema、認証、エラー形式などの共通契約が未確定ではないか。
- 変更範囲がディレクトリ単位・route単位・component単位で分けられるか。
- 統合時の衝突コストが高すぎないか。
- 先に設計・契約ファイルを作れば安全に並列化できるか。
- 調査・レビュー・テスト設計のように、書き込みを伴わない並列化か。
- 既存の main worktree で小さく順次コミットすれば足りる作業ではないか。
- worktreeを作ることで一時branchが増えるコストを上回る隔離メリットがあるか。
- 失敗した場合に片方の worktree だけ破棄する必要があるか。
- generated files / lockfile / migration files を複数チャットが触らないか。
- Integration 専用チャットで回収できる粒度か。
- task-board / run log / archive などの記録ファイルを誰が更新するか決まっているか。
- commit禁止・編集禁止・worktree使用の方針が各workerへ明示できるか。
- worktree / branch の終了条件、mainへ取り込む条件、捨てる条件が決まっているか。
- サブエージェント利用が、ユーザーの明示依頼・実行環境・現行のtool policyに反していないか。

## 実行形態の原則

- 分解: 常に可。依存、ownership、順序、検証条件を明確にするだけなら安全。
- 直列実装: 既定。契約が曖昧、同じファイルに触る、統合コストが読めない場合や、小さくmainへコミットできる場合は `SINGLE_CHAT` または `SEQUENTIAL`。
- readonly並列: ユーザーが明示的に並列agentを求め、調査・レビュー・ログ分析・テスト観点出しのように書き込み不要な場合に使う。
- 実装並列: 例外。別Codexチャット/worktreeで行う場合は、先に契約、allowed files、禁止範囲、完了報告、Integration担当を決める。
- worktree: 明示された並行実装、大型機能、DB migration、本番保留、未コミット差分の保護、または独立ブランチ単位で破棄・統合したい時だけ使う。小さい修正、通常のUI調整、docs変更、順次実装では使わない。作る場合は `active` / `integrated` / `abandoned` の lifecycle と片付け条件まで決める。単一のdev serverや普段のIDEで確認したい場合はHandoff/Local統合を前提にする。

## 大きいタスクの標準フロー

大きいタスクでは、親チャットを実装担当にしない。親チャットは計画・分解・プロンプト生成・戻りレビュー・統合判断に集中する。

1. grill-meで目的、受け入れ条件、スコープ外、リスクを詰める。
2. 必要ならreadonly調査を分ける。例: コード影響範囲、公式docs/Web調査、テスト観点、セキュリティ/保守性。
3. 親チャットで調査結果を統合し、事実・推測・未決事項を分ける。
4. タスクを `Planner / Frontend / Backend / Tests / Docs / Integration / Review` に分類する。
5. 実装タスクごとに allowed files、禁止範囲、検証コマンド、完了報告、commit方針を決める。
6. 実装worker用プロンプトを作る。実装workerは原則、検証後に自分の変更だけcommitし、pushせず、親チャットへ「完了」とcommit hashを報告する。
7. 親チャットまたはIntegrationが、戻ってきたcommit/報告をレビューし、契約一致・範囲外変更・未解決リスクを確認する。
8. Integrationで統合・全体検証・最終記録を行う。

## 並列化に向いているタスク

- UI 実装と backend 実装が分離できる機能追加。
- 画面A / 画面B のように、route や component が独立している UI 作業。
- API endpoint A / endpoint B のように、責務が分かれている backend 作業。
- 調査、設計、レビュー、テスト追加、ドキュメント整理。
- Figma / スクショ再現など、UI単体で検証できる作業。
- 既存コード調査を複数領域に分ける作業。
- セキュリティレビュー、テスト漏れレビュー、保守性レビューのような観点別レビュー。
- frontend / backend / integration のように明確なフェーズ分離ができる作業。
- main作業を止めずに背景で試作したいが、失敗時にworktreeごと捨てる必要が明確な作業。

## 並列化に向いていないタスク

以下は原則として `SINGLE_CHAT`、`SEQUENTIAL`、または `DO_NOT_PARALLELIZE` を推奨する。

- 同じファイルを複数チャット/agentが編集する可能性が高い作業。
- DB schema / migration / API contract がまだ決まっていない状態の実装。
- 認証・権限・課金・本番データ・secret/token・GCP/GCS削除など危険操作を含む作業。
- 大規模リファクタで影響範囲が広すぎる作業。
- 仕様が曖昧で、各チャットが勝手に解釈しそうな作業。
- 1つの小さいバグ修正、UI調整、docs変更など、mainで小さくコミットすれば足りる作業。
- generated files / lockfile / migration files など衝突しやすいファイルを複数チャットが触る可能性がある作業。
- 1つのdev server、1つの外部アプリ状態、1つの手元ログだけでしか正しく検証できない作業。
- 進行中のLocal未コミット差分を前提にし、worktreeへ安全に再現できない作業。

## UI / Backend 並列の標準フロー

UI と backend を並列で進める場合は、いきなり実装に入らず以下を提案する。

1. Architect / Planner チャットで設計・契約を作る。
2. 必要に応じて `API_CONTRACT.md` / `UI_ACCEPTANCE.md` / `TEST_PLAN.md` / `OWNERSHIP.md` を作る。
3. 記録責務を決める。通常は Planner が開始記録と改善ログファイルの存在確認、Integration が完了記録を担当し、Frontend / Backend worker は `docs/ai/task-board.md` / `docs/ai/task-runs.jsonl` / `docs/ai/mistakes.md` / `docs/ai/task-router-analysis.md` / `docs/ai/task-archive/**` を触らない。
4. commit / no-write 方針を決める。`commitしないで` は編集・検証のみ、`実装しないで` / `編集しないで` はファイル編集なし。
5. Frontend 用Codexチャットのプロンプトを出す。
6. Backend 用Codexチャットのプロンプトを出す。
7. mainで順次進められない理由が明確な場合だけ、それぞれ Git worktree を分ける。
8. 最後に Integration 用Codexチャットのプロンプトを出す。
9. ユーザーが明示的に並列agentを許可している場合だけ、統合後に Review サブエージェントで観点別レビューを行う。許可がない場合は同じチャットで `/review` 相当のレビュー観点を実施する。

## 複数タスクがある場合

ユーザーが複数の実装案・修正案・タスク一覧を出した場合は、すぐ実装せず先に整理する。

1. タスクを一覧化する。
2. 依存関係を確認する。
3. 同じファイル・同じ機能領域を触るものをまとめる。
4. UI系 / backend系 / DB系 / auth系 / docs系 / tests系 / refactor系 に分類する。
5. 単一チャット向き、順次実行向き、parallel worktree 向き、readonly サブエージェント向きを分類する。
6. 並列化する場合は、各チャットの目的・編集範囲・禁止範囲・完了条件を出す。分類結果が複数でも、依存や編集範囲が重なるなら直列化する。
7. 各workerが記録ファイルを触る必要があるか確認する。不要なら禁止範囲に入れ、終了報告でIntegrationへ渡す。
8. 最後に Integration チャットへ渡すプロンプトも出す。

数で機械的に分けない。「3つタスクがあるから3チャット」ではなく、依存関係・編集範囲・統合しやすさで分ける。

## worktree 判定

worktree を使う場合でも、いきなり作成しない。まず統括側が確認・提案する。

- 既存の main worktree で足りない理由
- worktreeを作る例外条件（明示された並行実装、大型機能、DB migration、本番保留、未コミット差分の保護など）
- current branch
- git status
- uncommitted changes
- base branch
- 作業ごとの branch/worktree 名
- 各 worktree の責務
- 各 worktree で編集してよい範囲
- 各 worktree の終了条件、mainへ取り込む条件、捨てる条件
- merge順
- integration 用 worktree を作るか
- board / run log / archive をどのworktreeで最後に更新するか
- 同じbranchをLocalとworktreeで同時にcheckoutしない運用になっているか
- 同じ `main` branch を複数worktreeにcheckoutしようとしていないか
- worktree側で完結して検証できるか、最後にLocalへHandoff/統合して検証するか
- 終了時に `active` / `integrated` / `abandoned` / `main_unintegrated` のどれで記録するか

既存の未コミット変更がある場合は、勝手に混ぜない。今回作業と関係ない差分は触らず、必要ならユーザーに整理を依頼する。

## 必須出力形式

計画・分解だけを返す場合は、この順で出す。

```markdown
## 1. 親チャットの役割

今回は <計画のみ / 計画+レビュー / 単一チャット実装 / worker実装+Integration> のどれか。

## 2. 並列化判断

<SINGLE_CHAT | SEQUENTIAL | PARALLEL_WORKTREES | PARALLEL_SUBAGENTS_READONLY | HYBRID_PLAN_THEN_PARALLEL | DO_NOT_PARALLELIZE>

理由:
- ...

代替案:
- ...

## 3. タスク分解

- Architect / Planner: ...
- Frontend: ...
- Backend: ...
- Integration: ...
- Review: ...
- Docs / Tests: ...
- Other: ...

## 4. worktree計画

必要な場合だけ、base / branch / worktree / ownership / merge order を出す。
記録ファイルの更新担当、commit禁止・編集禁止の扱い、終了条件、mainへ取り込む条件、捨てる条件もここで明記する。

## 5. 各チャット用プロンプト

Planner / UI / Backend / Integration / Review / Docs Tests 用プロンプトを必要数だけ出す。
実装workerには「allowed filesだけ編集、検証後commit、push禁止、完了報告、commit hash報告」を必ず入れる。

## 6. 統合条件

- typecheck
- lint
- unit test
- E2E
- manual check
- API contract一致
- UI状態確認
- docs更新
- PR summary

## 7. 注意点

- ...
```

不要なロールは省略してよいが、見出し `## 1` から `## 7` は維持する。

## Run記録用 JSON

run 記録には次を残す。

```json
{
  "parallel_decision": "SINGLE_CHAT | SEQUENTIAL | PARALLEL_WORKTREES | PARALLEL_SUBAGENTS_READONLY | HYBRID_PLAN_THEN_PARALLEL | DO_NOT_PARALLELIZE",
  "decision_reason": "短い理由",
  "implementation_channel": "same_chat | codex_chat | codex_chat_worktree | none",
  "readonly_subagents": ["explorer", "reviewer"],
  "disjoint_write_scopes": true,
  "contract_first": true,
  "serial_estimate_minutes": 0,
  "parallel_risk": "low | medium | high"
}
```
