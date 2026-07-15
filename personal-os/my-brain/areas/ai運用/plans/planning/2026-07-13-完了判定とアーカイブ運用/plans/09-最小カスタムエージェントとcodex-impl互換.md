親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 可 ／ レビュー: 都度
人間ゲート: なし（runtime `~/.claude/agents` 等へのsymlink露出が必要になった場合は個別承認）

# 最小カスタムエージェントと/codex-impl互換

## 目的

再利用可能な役割定義を explorer／implementer／reviewer の3つだけに絞って正本化し、既存 `/codex-impl` を共通delegate（08）を呼ぶ互換ラッパーへ置き換える。役割と実行時割当（worktree・Task）の混同を無くす。

## 非対象

- 3役割を超えるエージェントの新設（必要が実証されてから別計画）
- harness本体（08）
- 既存 `codex-consult`・`impl-reviewer` エージェントの削除（impl-reviewerはreviewer役割との関係を整理し、互換を保つ）
- runtimeへの登録・露出の実施（差分提示まで。適用は人間承認後）

## 現状

`agents-registry/` には claude/agents/（codex-consult・impl-reviewer）と claude/commands/codex-impl.md があるのみで、runtime横断の役割定義（roles/）とCodex側agent定義は無い。`/codex-impl` はClaudeメインがcodex execを直接駆動する実装で、委譲ロジックがコマンド本文に埋まっている。`custom-agent-creator` の references には「`.codex/agents/*.toml` は存在しない」という旧記述が残り、現行Codex仕様（project/global custom agent TOML対応）と矛盾する（references/2026-07-15-計画実行基盤/01 §12-13・02 §14）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/agents-registry/AGENTS.md`・`claude/agents/impl-reviewer.md`・`claude/commands/codex-impl.md`
  2. `personal-os/AIエージェント基盤/skills/custom-agent-creator/SKILL.md`・`references/codex.md`・`references/checklist.md`
  3. `../program.md`・この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §14-15
  5. `../references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md` §3-5（役割別追加指示）
- 依存成果: 08のdelegate・manifest・schemas
- 変更可能範囲: `agents-registry/roles/`（新規）、`agents-registry/claude/agents/`・`agents-registry/codex/agents/`（新規）、`agents-registry/claude/commands/codex-impl.md`、`agents-registry/AGENTS.md`、`skills/custom-agent-creator/references/codex.md`・`references/checklist.md` の旧記述箇所
- 変更禁止範囲: `agents-registry/harness/`（08所有）、`~/.claude/agents/`・`~/.codex/` への露出（人間ゲート）、`skills/plan-ops/`・`hooks-registry/`
- 維持する契約: `/codex-impl` の入口（コマンド名・主要な使い方）互換／impl-reviewerの既存呼び出し互換／エージェント定義に 固定worktree・固定branch・Program固有背景・毎回変わるモデルID を入れない
- 検証: 役割定義の禁止事項チェック（grepベースで可）＋codex-impl互換の合成タスク実行
- 停止・エスカレーション条件: 現行Codex CLIのcustom agent仕様がローカルversionで確認できない／codex-impl互換が保てない変更が必要になった
- 完了時に返す情報: 02指示書§24の完了報告形式

## 方針

1. `agents-registry/roles/` に explorer.md・implementer.md・reviewer.md を作る。各定義は 目的・権限・行動原則・出力契約 だけを持ち、性格は各1行まで。explorer=read-only・地図を作る・pathとsymbolを根拠に返す。implementer=workspace-write・一つのTask Packetだけ・最小で安全な変更・result packet必須。reviewer=read-only・完了条件とdiffの照合・自己申告を根拠にしない・PASS/FAIL/対象外と根拠。
2. roles/ を正本とし、claude/agents/・codex/agents/ はruntime形式への薄い写像にする（本文の二重管理を避け、生成または最小差分で保つ）。モデル選定は `AIモデル一覧.md` とハーネスが行い、定義へ固定しない。
3. `/codex-impl` を、共通delegate（08）を呼ぶ互換ラッパーへ置き換える。plan path・runtime=codex・role=implementer・base SHA・worktree policy・result packet・impl-reviewer・planctl apply-evaluation の流れを使う。汎用コマンドを増やす場合も命名は最小限にする。
4. `custom-agent-creator/references/` の旧Codex記述（`.codex/agents/*.toml` は存在しない等）を、現行仕様とローカルversion確認を両立する書き方へ更新する。
5. impl-reviewer は reviewer役割の Claude 実装として位置づけを整理し、既存の呼び出し（/codex-implからの評価）互換を保つ。

## 完了条件（レビュー項目）

- [ ] `roles/` の3定義が存在し、どの定義にも 固定worktree・固定branch・タスク固有path・Program固有背景・モデルID・長い性格設定 が無い（禁止語のgrepで機械確認できる）。
- [ ] claude/agents/・codex/agents/ がroles/と矛盾せず、本文の実質的な二重管理（同文の長文コピー）が無い。
- [ ] `/codex-impl` が共通delegateを経由して従来と同じ入口で使え、合成タスクで 委譲→result packet→レビュー→apply-evaluation の流れが通る。
- [ ] `custom-agent-creator/references/codex.md`・`checklist.md` に「.codex/agents は存在しない」系の旧記述が残っておらず、現行仕様の確認手順が書かれている。
- [ ] runtimeへの露出（symlink等）を実施しておらず、必要な露出差分が一覧で提示されている。
- [ ] `agents-registry/AGENTS.md` が roles／harness／runtime別定義の構成と正本関係を1画面で説明している。
