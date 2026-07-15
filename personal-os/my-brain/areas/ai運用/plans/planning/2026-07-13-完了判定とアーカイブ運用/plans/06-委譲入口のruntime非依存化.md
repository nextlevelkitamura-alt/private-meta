親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 可 ／ レビュー: 都度
人間ゲート: なし

# 委譲入口のruntime非依存化

## 目的

計画から実行への入口2つ（plan-triage の構成カード、handoff-plan-supervisor の実装指示生成）を、Orca・特定runtimeへ依存しない共通の実行構成語彙へ揃える。委譲Task Packetの正本を plan-ops `templates/実行指示.md` の1箇所にする。

## 非対象

- harness本体の実装（08）、カスタムエージェント定義（09）
- plan-triage の二段ルーティング・route契約（`plan-triage.route/v1`）の変更
- Orca資産（orca-cockpit・cockpit-supervisor）の削除・改修。任意アダプターとして残す
- kickoff・plan-management の本文変更（責務境界に影響が出た場合のポインタ修正のみ許す）

## 現状

`plan-triage/SKILL.md` は2026-07-14の再編で46行に短縮済みで、Orcaの直接言及は既に無い。ただし出力の「構成カード（規模・起動形・モデル）」の起動形語彙は `workflows/triage.md` 側にあり、Orcaペイン編成前提の語彙が残っているかを実装時に確認して置き換える。`handoff-plan-supervisor` は独自の引き継ぎ書・実装プロンプト形式を持ち、plan-opsのテンプレとは別系統のため、Task Packetの二重管理が起きている（references/2026-07-15-計画実行基盤/01 §1.3・§15）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/skills/plan-triage/SKILL.md`・`workflows/triage.md`・`references/route-contract.md`
  2. `personal-os/AIエージェント基盤/skills/handoff-plan-supervisor/SKILL.md`
  3. `../program.md`・この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §18-19
- 依存成果: 05の `実行指示.md` テンプレ（正本として参照する）
- 変更可能範囲: `skills/plan-triage/`（SKILL.md・workflows・references・fixtures）、`skills/handoff-plan-supervisor/`、両Skillの `SKILL.html`（対で更新する場合）
- 変更禁止範囲: `skills/plan-ops/`（05所有）、`skills/kickoff/`・`skills/plan-management/`（ポインタ修正を除く）、`agents-registry/`、route契約のJSON schema互換
- 維持する契約: plan-triageは書き込まない経路解決器のまま／fail-closed（exit 3停止）／`plan-triage.route/v1` の後方互換
- 検証: `plan-triage/scripts/validate-route-cases.mjs`・`validate-inbox-contract.mjs` が通る＋構成カードの新旧出力例の照合
- 停止・エスカレーション条件: route契約の互換が保てない／実行指示.mdテンプレ（05）が未確定のまま着手期限になった
- 完了時に返す情報: 02指示書§24の完了報告形式

## 方針

1. plan-triage の構成カードを、runtime非依存の実行構成へ拡張する: `実行形`（direct／delegated-single／delegated-parallel／integration）、`必要役割`（implementer／reviewer／explorer）、`write lane数`（0／1／N）、`worktree`（不要／task-scoped）、`レビュー`（自己／1pass／full）、`人間ゲート`（あり／なし）、`判定理由`。Orcaペイン編成はカードから外し、任意アダプターとして関連節へ移す。
2. モデル選択は `AIモデル一覧.md` への参照とし、モデルIDをカード・plan本文に固定しない。
3. handoff-plan-supervisor の実装指示生成を `plan-ops/templates/実行指示.md` 参照へ置き換え、独自テンプレートを持たない。必須情報（目的・非対象・読む順番・対象repo・base・変更可能/禁止path・依存成果・実装内容・検証・停止条件・result packet・worktreeはハーネス割当済み）はテンプレ側が持つ。長い背景はplan本文・referencesへ逃がす。
4. 両Skillの責務境界を明文化する: triage=書き込みなしの経路・構成解決、handoff=Task Packetへの具体値充填、実行・worktree作成はハーネス（08）。

## 完了条件（レビュー項目）

- [ ] plan-triage の構成カード出力に 実行形・必要役割・write lane数・worktree・レビュー・人間ゲート・判定理由 が含まれ、Orcaペイン編成が既定出力に無い。
- [ ] route契約 `plan-triage.route/v1` の既存fixture（route-cases.json）と検証scriptが変更後も通る。
- [ ] 構成カード・SKILL本文にモデルIDの固定が無く、`AIモデル一覧.md` を参照している。
- [ ] handoff-plan-supervisor が `plan-ops/templates/実行指示.md` を正本参照し、独自の実行指示テンプレ本文を持たない。
- [ ] Task Packetに必須情報（読む順番・変更可能/禁止path・検証・停止条件・result packet）が実行指示.md経由で揃うことを、記入例1件で確認できる。
- [ ] 両SKILL.mdがOrcaを任意アダプターとして案内し、既定経路と誤読される記述が無い。
