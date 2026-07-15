親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
並列: 不可 ／ レビュー: 一括（Wave 4完了時に02・03・04の3子をまとめてレビュー。schema・Task Packet等の共通契約を変える修正が必要になった場合だけ即差し戻し）
人間ゲート: なし（worktree削除は明示cleanupのみ。runtime `~/.claude/agents` 等への露出が必要なら承認セットへ記録）

# harness・エージェント・ゴールコマンド（Wave 3）

## 目的

委譲実行の土台を1子で作る。(a) Claude→Codex・Codex→Claudeを同じTask Packetで動かすharness（delegate・manifest・task-scoped worktree）、(b) 役割定義 explorer／implementer／reviewer の3つと `/codex-impl` 互換化、(c) **ゴールコマンド `program-run`** — program.mdを読み、Wave順に 委譲→レビュー→planctl同期 を人間なしで完走し、危険操作は実行せず承認セットへ積み、最後に1回だけ人間確認へ上げるオーケストレータ。

## 非対象

- planctl本体（02。program-runは02のplanctl・bucketctlを呼ぶ側）
- hookガード（04）
- 3役割を超えるエージェント新設・Orca経路の改修
- runtime設定変更・trust・symlink露出の実施（差分の用意と承認セットへの記録まで）

## 現状

実働の委譲は `/codex-impl`（Claudeメイン→codex exec直接駆動）のみで、Codex→Claudeの逆方向・worktreeの一元管理・program全体を回すランナーは存在しない。実装が1子終わるごとに人間がチャットで次を指示しており、「program+子計画を作ったら完走する」経路が無い。`agents-registry/` にはclaude/agents（codex-consult・impl-reviewer）とclaude/commands/codex-impl.mdのみで、runtime横断のroles/・harness/は無い。`custom-agent-creator` referencesには「`.codex/agents/*.toml` は存在しない」という現行Codex仕様と矛盾する旧記述が残る。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/agents-registry/AGENTS.md`・`claude/commands/codex-impl.md`（codex exec・resume知見）・`claude/agents/impl-reviewer.md`
  2. `skills/custom-agent-creator/references/codex.md`・`references/checklist.md`
  3. `../program.md`（レビュー運用と完走スキーム＝program-runの要求仕様）・この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §13-15
  5. `../references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md`（Task Packetの形・親エージェントの回収手順＝program-runのループ仕様）
- 依存成果: 01の実行指示.md・実行結果.jsonテンプレ、02のplanctl（prepare/apply-evaluation/sync-check/close）・bucketctl・run manifest契約
- 変更可能範囲: `agents-registry/harness/`（新規）、`agents-registry/roles/`（新規）、`agents-registry/claude/agents/`・`codex/agents/`、`agents-registry/claude/commands/codex-impl.md`、`agents-registry/AGENTS.md`、`skills/custom-agent-creator/references/` の旧記述箇所
- 変更禁止範囲: `skills/plan-ops/`（02所有）、`hooks-registry/`（04所有）、`~/.claude/`・`~/.codex/` のruntime設定、既存 `codex-consult`
- 維持する契約: push・merge・deployをしない／conflict時は停止／secret非表示／worktree・branchはTask IDで命名し `~/Private` 直下に作らない／`/codex-impl` の入口互換／エージェント定義に固定worktree・branch・Program固有背景・モデルIDを入れない
- 検証: `harness/tests/`（worktree分離・schema検証・conflict停止・secret非表示・並列分離・program-runのWave進行/停止/承認セット蓄積を合成programで）
- 停止・エスカレーション条件: Claude CLIの安全なnon-interactive呼び出しが確認できない（→Claude adapterはfeature-disabledで返す）／codex execのwire formatがローカルversionと不一致／差し戻し上限（フル=2）超過
- 完了時に返す情報: result packet＋Claude adapter状況＋program-runの合成実行ログ要約

## 方針

### A. harness（1 taskの委譲）

1. `delegate.py`: runtime=`codex|claude`・role=`explorer|implementer|reviewer`・plan path必須・write taskは明示base SHA必須。Task Packet（01の実行指示.mdへ具体値充填）を生成してadapterを起動。テンプレ全文の丸渡しをしない。
2. worktreeはTask-scoped: write workerの並列・dirty checkout・別repo handoffではtask専用worktreeを明示baseから作り、read-only taskは省略可。task_idから決定的に命名。自動削除しない。
3. `runtimes/codex.py` は `/codex-impl` のcodex exec `--json`・resume知見を再利用。`runtimes/claude.py` は実機 `claude --help` と公式non-interactive仕様を確認してフラグをテストで固定し、未確認機能はfeature-disabled。`schemas/` にrun-manifest・result-packetを置き02と契約を共有する。

### B. roles（役割定義）と /codex-impl 互換

4. `roles/` に explorer（read-only・地図・pathとsymbolを根拠）／implementer（workspace-write・1 Task Packetのみ・最小変更・result packet必須）／reviewer（read-only・完了条件とdiff照合・自己申告を根拠にしない・PASS/FAIL/対象外＋根拠）。性格は各1行まで。claude/codex両形式へは薄い写像で、本文を二重管理しない。impl-reviewerはreviewer役割のClaude実装として位置づけ、既存呼び出し互換を保つ。
5. `/codex-impl` を共通delegateを呼ぶ互換ラッパーへ置き換える（入口・使い方は不変）。`custom-agent-creator` referencesの旧Codex記述を現行仕様＋ローカルversion確認の書き方へ更新。

### C. program-run（ゴールコマンド＝完走オーケストレータ）

6. `program-run` を新設する: program.mdの子マップを読み、**Wave順に自動進行**する。各子について (1) `planctl prepare` でTask Packet生成 → (2) delegateで実装worker起動（同時write最大2・並列可否はマップに従う）→ (3) result packet回収・検証 → (4) 子の `レビュー:` 宣言に従い、**都度なら即reviewer起動、一括なら束ねて後で**（束ね先マップ注記に従う。既定は3子程度）→ (5) 全PASSで `planctl apply-evaluation` → 次へ。FAILは修正MD→同一threadへresume（差し戻し上限=2、超過は停止して人間へ）。
7. **人間に聞くのは2種類だけ**: (a) 完走後の最終一括確認（統合評価＋承認セット）、(b) 途中で危険操作の**即時実行が避けられない**場合（原則発生しない設計。hook登録・移動・削除・trust等は実行せず `承認セット.md` へ差分・根拠を追記して先へ進む）。それ以外の確認・待ち・軽微な判断はprogram-runと指揮官が解消する。
8. 停止条件: blocked result・差し戻し上限超過・共通契約（schema/テンプレ/CLI引数）を変える修正が必要・対象path衝突。停止時はrun状態（どの子まで完了・レビュー待ちキュー・承認セット）を出力し、再開可能にする。

## 完了条件（レビュー項目）

- [ ] `delegate.py` が明示引数（runtime・role・plan path・base SHA）で動き、write taskのbase未指定を拒否し、task-scoped worktreeの分離・read-only省略・conflict停止・secret非表示・並列2taskの非交差がテストで確認できる。
- [ ] 生成Task Packetに読む順番・変更可能/禁止範囲・result packet要求が含まれ、run-manifest・result-packetのschema検証が不正データを拒否する。
- [ ] `roles/` の3定義に固定worktree・branch・タスク固有path・Program固有背景・モデルID・長い性格が無い（grepで機械確認可）。claude/codex両形式がroles/と矛盾しない。
- [ ] `/codex-impl` が共通delegate経由で従来と同じ入口で使え、合成タスクで 委譲→result→レビュー→apply-evaluation が通る。custom-agent-creatorの旧記述が現行仕様へ更新済み。
- [ ] `program-run` が合成programで、Wave順の自動進行・並列上限2・レビュー宣言（都度/一括）どおりのreviewer起動・全PASS時のみの同期・FAIL時のresume差し戻し・上限超過での停止を再現できる。
- [ ] `program-run` が危険操作を実行せず `承認セット.md` へ蓄積して完走し、完走後の出力に統合評価と承認セットが揃う。blocked・契約変更が必要な場合に再開可能な状態で停止する。
- [ ] Claude adapterは実機確認済みフラグのみ使用、または明示的feature-disabled。runtime設定・trust・symlinkに変更が無い。
