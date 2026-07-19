分類: skill ／ 種別: 統合整理
規模: フル
並列: 可（Wave 1は2 write lane） ／ レビュー: full・都度 ／ 差し戻し上限: 2

# 計画とカスタムエージェント導線の整理

計画合意: 2026-07-19 人間確認済み。`plan-registry/execution` の新設案は不採用とし、plan-registryとagents-registryを直接つなぐ中間構成で実装する。

## 目的

計画運用を `plan-registry` に集約しつつ、同registryを独自execution基盤へ肥大化させない。計画の作成・合流・レビュー・終了はplan-registry、custom agentの定義・索引・runtime露出はagents-registryを正本とし、計画実行時はagents-registryのcustom agentをruntime nativeに直接起動する。

Global Skillは `plan-create-review` 1本だけを10行以内の参照窓として残す。`plan-triage` と `plan-ops` の内容はplan-registryへ吸収し、Skill露出は撤廃する。現在の独自harness・互換command・重複reviewerは別の場所へ移さず廃止する。

## 非対象

- repo-localの計画箱・過去計画本文の一括移動や書式変換
- Orca、cockpit-supervisor、Codex組み込みのsubagent機構の再実装
- 新しいmanifest、runner、キュー、状態台帳、execution registryの作成
- main以外のbranchへのpush、外部公開、本番データ変更
- 今回の対象外であるregistry外legacy Claude command・`fixer.md` の整理

## 現状

- `plan-registry` は規約中心で、作成・route・機械処理が `plan-create-review` / `plan-triage` / `plan-ops` の3 Skillへ分散している。
- `agents-registry` には共通role、Claude/Codex adapter、harness、互換commandが同居するが、runtimeへ露出中なのは `codex-consult`、`impl-reviewer`、`/codex-impl` だけである。
- harnessはcustom agent定義を使わず汎用CLIを直接起動し、共通role本文も読まない。`program_run.py` はtests以外の外部callerが無い。
- plan-opsは209件PASS、role写像チェックはPASS、harnessは26件中5件が契約driftでFAILしている。harnessを移設・温存せず、決定的plan scriptのテストだけ残す。
- 既存planning計画 `2026-07-18-実装指揮の入口スキル化` はharness存続を前提としていたため、本計画へ大幅更新・改名して合流した。

## 実行契約

- 対象repo: `/Users/kitamuranaohiro/Private`
- 実行形: Wave 1=`delegated-parallel`（Terra 2 lane）、Wave 2=`integration`
- 最初に読む順番:
  1. `/Users/kitamuranaohiro/Private/AGENTS.md`
  2. `personal-os/AIエージェント基盤/AGENTS.md`
  3. 本計画
  4. `plan-registry/AGENTS.md` と `agents-registry/AGENTS.md`
  5. 担当laneが変更するSkill・registryの最寄り `AGENTS.md` / `SKILL.md`
- 依存成果: 2026-07-19の構造監査と人間合意。説明HTMLは同計画 `explain/plan.html` を最新とする。
- 変更可能範囲: 下記Lane A / Lane B / Integrationの列挙pathだけ
  - Lane A: `AIエージェント基盤/plan-registry/**`、`skills/plan-create-review/**`、`skills/plan-triage/**`、`skills/plan-ops/**`
  - Lane B: `AIエージェント基盤/agents-registry/**`、`skills/custom-agent-creator/**`
  - Integration: `AIエージェント基盤/GLOBAL_AGENTS.md`、`AIエージェント基盤/AGENTS.md`、`hooks-registry/**`、`global-skill-registry/**`、runtime symlink、同計画と説明HTML
- 変更禁止範囲: 既存の未コミット変更、他計画、loops-registry、当日ボード実装、secret・credential、push
- ファイル担当マップ:
  - Lane A（Terra）: plan-registryと計画系3 Skillだけ。agents-registry・hooks・runtime露出を触らない。
  - Lane B（Terra）: agents-registryとcustom-agent-creatorだけ。plan-registry・計画系Skill・hooks・runtime露出を触らない。
  - Integration（指揮官、必要ならTerra reviewer）: Lane A/Bの成果反映後に旧path参照、hook、catalog/logs、symlink、全テストを扱う。
- worktree方針: Lane A/Bは同一base SHAからtask-scoped Git worktreeを分け、各lane内で対象path限定commitを作る。Integrationは両commitを現在worktreeへ順に反映し、競合を推測で解決しない。
- 維持する契約:
  - 計画本文・状態・履歴は各area/repoの計画箱が正本で、plan-registryへ集めない。
  - reviewer / explorerはread-only。implementerだけworkspace-writeを許す。
  - Claude=`.md`、Codex=`.toml` のruntime必須形式は維持し、共通role本文だけをagents-registry/AGENTS.mdに一本化する。
  - hookは案内・検査だけで、計画作成やagent選択・レビュー合否を所有しない。
  - runtime露出先は正本にせず、registry正本へのdirect symlinkにする。
- 検証:
  - plan-registryのscaffold・lint・状態遷移・syncのテストが全PASS
  - plan-create-reviewが10行以内でplan-registryだけを参照
  - Claude/Codexのexplorer・implementer・reviewer定義がruntime形式・権限契約を満たす
  - reviewer/explorerがread-only、codex-consultの本文とpermissionが矛盾しない
  - `rg` で旧 `skills/plan-triage`、`skills/plan-ops`、`agents-registry/harness`、`/codex-impl`、`impl-reviewer` の生きた参照が0（deleted log等の履歴は除外）
  - hook/session-boardの対象tests、Global Skill露出drift check、runtime symlink解決が全PASS
- 停止・エスカレーション条件: lane間path重複、未コミットユーザー変更との衝突、runtime仕様不明、削除対象に未把握consumer、テストFAILの原因が今回範囲外
- 完了時に返す情報: lane commit、変更path、削除path、runtime露出、テスト、残存リスク、未対応legacy

## 方針

### 1. plan-registryを中間粒度へ集約する

最終構成は次とする。`execution/`、`compat/`、新しい状態台帳は作らない。

```text
plan-registry/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── workflows/      # create-or-join / triage / manage-program / review-and-transition
├── templates/      # plan / program / 子 / 評価 / 修正 / 終了記録
├── scripts/        # scaffold / lint / 状態遷移 / sync
└── tests/          # 上記scriptの契約確認だけ
```

`plan-create-review/SKILL.md` はplan-registryを読むだけの10行以内にする。既存workflow本文はplan-registryへ移し、Skill内に基準や状態を複製しない。

### 2. agents-registryをcustom agentだけへ戻す

最終構成は次とする。共通role本文と登録一覧はAGENTS.md、runtime固有ファイルは短いadapterにする。

```text
agents-registry/
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
├── claude/
│   ├── explorer.md
│   ├── implementer.md
│   ├── reviewer.md
│   └── codex-consult.md
└── codex/
    ├── explorer.toml
    ├── implementer.toml
    └── reviewer.toml
```

計画を実行する指揮官はplan-registryのworkflowからagents-registryの登録一覧を読み、現在runtimeのnative custom agentを直接起動する。custom-agent-creatorは定義作成・検証のSkillとして残し、旧harness既定の説明をこの導線へ改める。

### 3. 重複入口と独自harnessを廃止する

- 正本削除: `skills/plan-triage/`、`skills/plan-ops/`（吸収後）、`agents-registry/harness/`
- 互換入口削除: `agents-registry/claude/commands/codex-impl.md`、`agents-registry/claude/agents/impl-reviewer.md`
- 旧構造削除: `agents-registry/roles/`、旧 `claude/agents/`、旧 `codex/agents/`（新しいflat構造へ内容を吸収後）
- runtime露出削除・張替え: plan-triage / plan-ops Skillの全露出、`/codex-impl`、`impl-reviewer`、custom agent 3役の新正本へのdirect symlink
- Global Skill deleted logとcatalog更新を同じ変更単位で行う。

### 4. hookとグローバル導線を新構成へ追従する

- session-boardの `/codex-impl` 案内を、plan-registry→agents-registryのnative custom agent導線へ置換する。
- plan-closeout・post-commit等の固定pathを `plan-registry/scripts` へ更新する。
- GLOBAL_AGENTS、AIエージェント基盤AGENTS、custom-agent-creator referencesから旧harness/Skill責務を除く。
- hookはcustom agentを自動起動せず、必要な正本pathを短く案内するだけに保つ。

### 5. テストは決定的scriptへ限定する

plan-opsの既存テストをplan-registry/testsへ追従させる。harness本体を廃止するためfake CLI E2E・role adapter存在テストは残さない。最低限、scaffold→lint、状態遷移拒否、評価同期の失敗時無変更、syncのsecret境界、旧path非参照を確認する。

## 実行順

1. 計画更新を対象path限定で記録し、同一baseのtask-scoped worktreeを2つ作る。
2. Wave 1: Lane A / Lane BをTerraで並列実装し、それぞれ対象path限定commitとテスト結果を返す。
3. Wave 2: 指揮官が両commitを統合し、旧path consumerを更新する。必要ならTerra reviewerをread-onlyで起動する。
4. runtime symlinkを新正本へ張り替え、削除Skillの露出・catalog・logsを整える。
5. 全検証を通し、評価01.mdを作る。FAILなら修正01.mdで最大2回差し戻す。
6. 全PASS後、結果を本計画へ反映する。pushは行わない。

## 完了条件（レビュー項目）

- [ ] `plan-registry/` がAGENTS・workflows・templates・scripts・testsの中間構成になり、個別plan本文・agent定義・execution engineを持たない。
- [ ] `plan-create-review/SKILL.md` が10行以内の参照窓になり、計画基準・route・状態・workflow本文を複製していない。
- [ ] `plan-triage` と `plan-ops` の有効な内容がplan-registryへ一度だけ吸収され、両Skill正本・runtime露出・catalog行が削除され、deleted logへ理由と吸収先が残る。
- [ ] `agents-registry/` がAGENTS・claude・codexの3要素だけで説明でき、custom agent以外のharness・command・runner・manifestを持たない。
- [ ] Claude/Codexのexplorer・implementer・reviewerが同じ共通roleを参照し、Claude/Codex必須形式を守る。reviewer/explorerはread-onlyで、implementerだけwrite可である。
- [ ] `codex-consult` のread-only本文とpermissionが一致し、`impl-reviewer` と `/codex-impl` の役割がreviewer / implementerへ吸収されている。
- [ ] plan-registryの実行workflowがagents-registryを参照してruntime native custom agentを直接使い、独自delegate・program runner・第2状態台帳を要求しない。
- [ ] hooks・GLOBAL_AGENTS・AIエージェント基盤AGENTS・custom-agent-creatorが新しい正本と責務だけを案内し、旧固定pathの生きた参照が0である。
- [ ] plan-registry tests、session-board/plan-closeout対象tests、Skill露出drift checkが全PASSし、secret・未コミットユーザー変更・対象外pathを巻き込んでいない。
- [ ] runtime露出が正本へのdirect symlinkで、Codex Skillが `.agents/skills` と `.codex/skills` に二重登録されていない。pushは行われていない。

## 人間ゲート

2026-07-19の対話で、上記中間構成による実装、既存計画の修正、Terraサブエージェントによる並列実装の開始が承認された。削除・移動・runtime symlink張替えは、この計画に対象pathを列挙した範囲で承認済みとする。対象外legacyの削除、push、main以外への外部反映は未承認。

## 実装結果

実装・レビュー後に追記する。実行前は記入しない。

## 終了記録

archive時に終了区分・人間確認とともに追記する。実行中は記入しない。
