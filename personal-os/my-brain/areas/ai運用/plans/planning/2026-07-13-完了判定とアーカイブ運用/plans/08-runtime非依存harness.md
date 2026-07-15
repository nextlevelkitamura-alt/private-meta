親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
並列: 不可 ／ レビュー: 都度
人間ゲート: なし（worktree削除は明示cleanupのみ・自動削除を作らない）

# runtime非依存harness

## 目的

Claude→Codex・Codex→Claudeのどちらでも、同じTask Packetとrun manifestで委譲実行できるharnessを `agents-registry/harness/` に作る。worktreeはagentではなくTaskに所属させ、親ハーネスが明示base SHAから作る。

## 非対象

- カスタムエージェント定義・`/codex-impl` 互換ラッパー（09）
- planctl本体（07。harnessは07のmanifest契約を消費する）
- Orca経路の改修（任意アダプターのまま）
- runtime設定変更・trust変更（人間ゲート。本子はコードとテストまで）

## 現状

現行の委譲は `/codex-impl`（Claudeメイン→codex exec直接駆動）が実働で、Codex→Claudeの逆方向は同じ粒度で正本化されていない。worktreeの扱いは計画・エージェント側に固定されがちで、「正確なbase SHA・branch命名の一元管理・runtime入れ替え」を親が制御する仕組みが無い（references/2026-07-15-計画実行基盤/01 §11・§13）。Claudeのagent定義 `isolation: worktree` は既定branchから分岐し親HEADとは限らないため、明示baseの要求を満たさない。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/agents-registry/AGENTS.md`
  2. `agents-registry/claude/commands/codex-impl.md`（既存のcodex exec・resume知見）
  3. `../program.md`・この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §13（必須機能）
  5. `../references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md`（生成するTask Packetの形）
- 依存成果: 05の実行指示.md・実行結果.jsonテンプレ、07のrun manifest契約（schema・phase語彙）
- 変更可能範囲: `agents-registry/harness/`（新規: delegate.py・manifest.py・worktree.py・runtimes/codex.py・runtimes/claude.py・schemas/・tests/）、`agents-registry/AGENTS.md` の構成節
- 変更禁止範囲: `skills/plan-ops/`、`hooks-registry/`、`agents-registry/claude/commands/codex-impl.md`（09所有）、`~/.claude/`・`~/.codex/` のruntime設定
- 維持する契約: push・merge・deployをしない／conflict時は停止／secret非表示／worktree・branchはTask IDで命名し `~/Private` 直下に作らない
- 検証: harness/tests/（worktree分離・schema検証・conflict停止・secret非表示・parallel task分離）
- 停止・エスカレーション条件: 現在のClaude CLIで安全なnon-interactive呼び出しが確認できない（→ Claude adapterはfeature-disabledで返し、その旨を報告）／Codex execのwire formatがローカルversionと一致しない
- 完了時に返す情報: 02指示書§24の完了報告形式（Claude adapter状況を必須で含む）

## 方針

1. `delegate.py` は runtime=`codex|claude`、role=`explorer|implementer|reviewer`、plan path必須、write taskは明示base SHA必須で受け、Task Packet（実行指示.mdへ具体値充填）を生成してruntime adapterを起動する。
2. worktreeはTask-scopedにする。write workerの並列・dirty checkout・別repo handoffの場合はtask専用worktreeを明示baseから作り、read-only task（explorer/reviewer）はworktree省略可とする。worktree・branchはtask_idから決定的に命名し、agent定義からworktreeを決めない。worktree削除は明示cleanupまたは人間ゲートで、自動削除しない。
3. 生成するTask Packetには、最寄りAGENTS.mdを読むこと、plan・親Program・referencesの読む順番、変更可能/禁止範囲、完了時のresult packetを必ず含める（03資料の共通プロンプト構成）。
4. `runtimes/codex.py` は既存 `/codex-impl` の `codex exec --json`・resume知見を再利用する。`runtimes/claude.py` は実装時点のローカル `claude --help` と公式non-interactive仕様を確認し、使用可能なフラグをテストで固定する。未確認・未対応の機能は明示的にfeature-disabledで返し、決め打ちしない。
5. `schemas/` に run-manifest.schema.json・result-packet.schema.json を置き、07のplanctl・10のguardと同じ契約を共有する（複製せず参照可能な形にする）。process outputはstate（gitignore配下）へ保存し、secretを表示・記録しない。

## 完了条件（レビュー項目）

- [ ] `delegate.py` が runtime・role・plan path・base SHA を明示引数で受け、write taskでbase SHA未指定なら拒否する。
- [ ] task-scoped worktreeが明示baseから作られ、branch・worktree名がtask_idから決まり、parallel 2taskの分離（相互のファイル非交差）をテストで確認できる。read-only taskはworktreeを作らない。
- [ ] 生成Task Packetに 読む順番・変更可能/禁止範囲・result packet要求 が含まれ、テンプレ全文の丸渡しをしていない。
- [ ] run-manifest・result-packetのschema検証があり、不正データを拒否するテストがある。
- [ ] conflict発生時に停止し、push・merge・自動worktree削除の経路が無い。process outputにsecretが出ない。
- [ ] Codex adapterが `codex exec` を駆動できる（合成タスクで確認）。Claude adapterは実機CLI確認済みのフラグだけを使うか、未確認ならfeature-disabledを返す。
- [ ] harness/tests/ が全緑で、既存 `/codex-impl` の動作を変えていない。
