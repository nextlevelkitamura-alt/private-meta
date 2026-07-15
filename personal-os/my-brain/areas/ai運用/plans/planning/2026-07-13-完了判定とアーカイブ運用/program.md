分類: 横断 ／ 種別: 既存改善 ／ 形態: program ／ 規模: フル

# 計画立案・実行・完了基盤

人間確認方針: 最終一括（危険操作は実行前に個別承認）

※ 本programは「完了判定とアーカイブ運用」（2026-07-13起案）を親として拡張した（2026-07-15・references/2026-07-15-計画実行基盤/ の3資料を採用）。フォルダ名の変更は人間ゲートのため未実施。rename案は「人間ゲート」節に記す。

## 目的

計画運用を「起案 → Task分割 → Claude/Codexへ委譲 → task-scoped worktreeで実装 → 異系統レビュー → 計画・Programの決定的同期 → 理由付きで閉じる」まで、一貫した機械手続きで扱えるようにする。実装後の計画・Programマップ更新が手動のまま残る穴を塞ぐ。

状態遷移は次の一本道を正本とし、実装結果（result packet）と評価結果（評価NN.md）から機械的に同期する。

```text
planning → active → done → archive
             │        │        └ 人間の明示確認＋終了記録がある時だけ
             │        └ 実装済み・最終評価md全PASS（人間のクローズ判断待ち）
             └ 実装・修正・AIレビュー中
```

`archive` は「成功済み」ではなく「閉じた計画」とし、終了区分（completed／superseded／merged／conflict／cancelled）と終了記録を必須にする。未完了計画を completed に偽装しない。

容量は各 `plans/` 直下ごとに `planning=無制限 / active=3 / paused=3 / done=8 / archive=無制限` とし、移動先へ入る直前に判定する。満杯でもAIが別計画を勝手に paused・done・archive へ移して枠を作ることはしない。

## 非対象

- Orca資産の削除（任意アダプターとして残す。既定経路にはしない）
- 全areaの一括破壊的移行、過去計画の一括改名、全archiveの自動修正
- Hookによる完了の意味推測、Hookからのplan/program直接編集
- 固定モデルID・worktree・branch・session IDを計画本文やagent定義へ埋め込むこと
- 未確認のClaude CLIフラグの決め打ち
- hook登録、symlink変更、Codex trust、push、main反映、本番変更の無断適用

## 正本境界

- 規模・段階・レビュー・責務地図: `plan-registry/AGENTS.md`。本programは同registryへの変更を提案・実装するが、規約本文をここへ複製しない。
- 物理バケット・テンプレ配置・評価文書の置き方: `my-brain/areas/AGENTS.md`
- テンプレ・lint・計画同期script（planctl 含む）: `AIエージェント基盤/skills/plan-ops/`
- 委譲harness・役割定義（roles／harness）: `AIエージェント基盤/agents-registry/`
- hookイベント実装: `hooks-registry/events/` ＋ 共通エンジン `hooks-registry/shared/`。旧 `hooks-registry/hooks/` 構造は復活させない（2026-07-06再編済み。設計資料02が指す旧pathは本programの子で読み替える）。
- セッション記録: session-board（計画本文・計画状態・レビュー合否を所有しない）
- 実行時情報（runtime・worktree・branch・base SHA・run ID）: run manifest（git管理しない）。計画本文には書かない。
- 今回の設計資料: `references/2026-07-15-計画実行基盤/`（01=全体設計と採用判断、02=マスター実装仕様、03=Task Packet実行指示テンプレート）

## 全体像・実行Wave

```text
Wave 1  05 テンプレートとplan lint（共通契約を先に固定）
          ↓
        06 委譲入口のruntime非依存化
Wave 2  01 完了判定と遷移統制（bucketctl拡張・終了区分）
          ↓
        07 planctlと計画同期
Wave 3  08 runtime非依存harness
          ↓
        09 最小カスタムエージェントと/codex-impl互換
Wave 4  04 上限超過の警告とAIガード ／ 10 plan-closeout guard
          ↓
        02 PromptSubmit計画注入の再設計（hook再編安定＋露出承認後）
Wave 5  11 ai運用area pilot → 03 既存計画の整合監査と上限是正
Wave 6  12 E2Eと横展開準備
```

- 同時write workerは最大2。共通契約（05）を固定してから、それへ依存する子だけを並列化する。
- 実装は原則、子計画単位で `codex exec` へ委譲し、reviewerは実装担当と異系統かつread-onlyにする。FAIL時は評価MD→修正MD→同じthreadへのresumeで戻す。
- worktreeはTask単位で親ハーネスが明示baseから作る。workerに固定worktreeを持たせない。
- Task Packetは `references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md` から具体値を埋めて作り、workerへテンプレート全文を渡さない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  完了判定と遷移統制 … 計画
    役割: 実装（遷移・容量・終了区分の統制）
    並列: 不可 ／ レビュー: 都度(規約・CLI・テストの同時照合)
    人間ゲート: なし（既存計画の実移動は03が所有）
    次: 02指示書§9-10を統合済み。05のテンプレ確定後、bucketctl拡張（遷移グラフ・容量・done/archiveゲート・終了記録検証）を実装する
    場所: plans/01 ／ 依存: 05
- [ ] 02  Prompt Submit計画注入の再設計 … 計画
    役割: 実装（hook注入文の同期）
    並列: 不可 ／ レビュー: 都度(common.py と runtime双方の注入テスト)
    人間ゲート: 既存5イベントE2E後のCodex再trust（人間が一度だけ実施）
    次: 01の遷移・容量契約と計画運用ハーネス子04の最小計画ゲートに合わせ、Prompt Submit・session-start/end・AGENTSの計画案内を最小化して統一する。着手はhook再編差分の安定と `plan-management` 露出承認の後
    場所: plans/02 ／ 依存: 01, 10, 計画運用ハーネス子04
- [ ] 03  既存計画の整合監査と上限是正 … 計画
    役割: 統合（既存データの新規約適用）
    並列: 不可 ／ レビュー: 都度(一覧と移動候補を独立照合)
    人間ゲート: 既存計画のバケット移動は候補ごとに個別承認
    次: 全バケットを監査し、状態矛盾・上限超過・終了区分未記録の移動候補を提示する。実際の移動は人間の個別承認後に01の遷移手順で行う
    場所: plans/03 ／ 依存: 01, 02, 04, 11
- [ ] 04  上限超過の警告とAIガード … 計画
    役割: 実装（PreToolガード）
    並列: 可 ／ レビュー: 都度(Codex/ClaudeのPreTool出力と拒否経路を別々に検証)
    人間ゲート: 新hookのruntime登録・Codex再trustは実装後に個別承認
    次: 生のバケット移動を止めるPreToolガード、超過警告、AGENTS/Skill導線を共通契約へ統一する
    場所: plans/04 ／ 依存: 01
- [ ] 05  計画テンプレートとplan lint … 計画
    役割: 契約（全子が依存する共通契約）
    並列: 不可 ／ レビュー: 都度(テンプレ・lint・既存fixtureの互換照合)
    人間ゲート: なし
    次: plan/program/子テンプレへ実行契約・非対象・形態判定を追加し、実行指示.md・実行結果.json・終了記録.mdを新設、plan-lintを実装する
    場所: plans/05 ／ 依存: ―
- [ ] 06  委譲入口のruntime非依存化 … 計画
    役割: 実装（triage出力とhandoffの契約統一）
    並列: 可 ／ レビュー: 都度(route契約fixtureと実行指示テンプレ参照を照合)
    人間ゲート: なし
    次: plan-triageの構成カードを実行形（direct/delegated-single/delegated-parallel/integration）へ拡張し、handoff-plan-supervisorを実行指示.md参照へ統一する
    場所: plans/06 ／ 依存: 05
- [ ] 07  planctlと計画同期 … 計画
    役割: 実装（result/evaluation→計画の決定的同期）
    並列: 不可 ／ レビュー: 都度(同期の安全条件を負ケース含めて照合)
    人間ゲート: なし
    次: planctl（prepare/progress/apply-evaluation/close/sync-check）とresult packet検証を実装し、完了条件の文言完全一致PASSだけを [x] へ同期する
    場所: plans/07 ／ 依存: 01, 05
- [ ] 08  runtime非依存harness … 計画
    役割: 実装（委譲実行の土台）
    並列: 不可 ／ レビュー: 都度(worktree分離・schema検証・secret非表示を照合)
    人間ゲート: なし（worktree削除は明示cleanupのみ）
    次: agents-registry/harness/ に delegate・manifest・task-scoped worktree・codex/claude adapterを実装する。Claude adapterは実機CLI仕様を確認してから有効化する
    場所: plans/08 ／ 依存: 05, 07
- [ ] 09  最小カスタムエージェントと/codex-impl互換 … 計画
    役割: 実装（役割定義と互換維持）
    並列: 可 ／ レビュー: 都度(役割定義の禁止事項と互換動作を照合)
    人間ゲート: なし
    次: explorer/implementer/reviewerの3役割を定義し、/codex-implを共通delegateの互換ラッパーへ置き換える。custom-agent-creatorの旧Codex記述も更新する
    場所: plans/09 ／ 依存: 08
- [ ] 10  plan-closeout guard … 計画
    役割: 実装（Stop/SubagentStopの同期ガード）
    並列: 可 ／ レビュー: 都度(runtime別stdout契約と無限ループ防止を照合)
    人間ゲート: runtime登録・settings/hooks.json変更・symlinkは実装後に個別承認
    次: run manifest検査型のStop/SubagentStopガードを events/＋shared/ の責務境界で実装する。Hookは計画を編集せず、review_passed未同期だけを継続させる
    場所: plans/10 ／ 依存: 07, 08
- [ ] 11  ai運用area pilot … 計画
    役割: 統合（Area標準の物理適用）
    並列: 不可 ／ レビュー: 都度(統合先の網羅と参照切れを照合)
    人間ゲート: identity.md削除・知識/移動は候補一覧提示後に個別承認
    次: ai運用areaでidentity→AGENTS統合と知識/の所有先監査を行い、移動候補一覧を人間へ提示する。work/money/healthはpilot合格後の別作業
    場所: plans/11 ／ 依存: 05
- [ ] 12  E2Eと横展開準備 … 計画
    役割: 統合（全体検証と承認セット提示）
    並列: 不可 ／ レビュー: 都度(E2E 5系統と未適用項目の棚卸しを照合)
    人間ゲート: なし（承認セットの提示までが範囲。適用は各子の人間ゲート）
    次: 単発plan・2子Program・conflict archive・completed archive・Stop guardのE2Eを合成データで実施し、hook登録・rename・移動の承認セットを人間へ提示する
    場所: plans/12 ／ 依存: 01, 02, 03, 04, 06, 07, 08, 09, 10, 11

## 人間ゲート

- 新hookのruntime登録、`~/.claude/settings.json`・`~/.codex/hooks.json` の変更、symlinkの追加・削除、Codex `/hooks` 再trust（子02・04・10）
- planフォルダの移動・改名。本programフォルダのrename案（例: `2026-07-15-計画立案実行完了基盤` への改名）は12の承認セットで提示し、承認まで現名を維持する
- 既存計画のバケット移動・是正（子03。候補ごとに個別承認）
- `identity.md` の削除、`知識/` 配下の移動（子11。候補一覧提示後）
- 先行資料 `2026-07-08-並列実装フロー` の `終了区分: merged` での close（終了区分の実装完了後に候補提示）
- push、mainへのmerge、本番・DB migration・launchd変更

## 完了条件（レビュー項目）

- [ ] `active → done` が「実装済みかつ最終評価mdが全PASS」でのみ進み、`done → archive` は人間の明示確認と終了記録がある時だけ進むことを、規約・CLIテストで確認できる。`planning/active/paused → archive` は非completedの終了区分＋終了記録＋人間確認がある時だけ通る。
- [ ] `archive` 配下の計画に終了区分・理由・人間確認が必ず残り、conflict/merged/cancelled/supersededの計画をcompletedとして偽装していない。archive lintがこれを機械検査する。
- [ ] 各 `plans/` root で `active≤3`、`paused≤3`、`done≤8` を移動先ごとに強制し、`planning` と `archive` は上限なしである。超過済みの既存バケットは可視化・流入拒否するが、自動退避しない。
- [ ] 新規のライト以上の計画が、実行契約（対象repo・読む順番・変更可能/禁止範囲・検証・停止条件・返す情報）を持つ新テンプレートで作成され、plan lintが必須項目・placeholder残存・親backlink不整合を検出する。
- [ ] result packetと評価MDから、完了条件チェックボックス・実装結果・Programマップを `planctl` で同期でき、未評価・対象外・文言不一致を自動PASSにしない。
- [ ] workerは親会話を知らなくても、計画本文とrun manifestだけで作業でき、実装agent定義に固定worktree・branch・Program固有背景が無い。write laneごとに明示baseからtask-scoped worktreeを作れる。
- [ ] OrcaなしでClaude→Codex委譲が動き、既存 `/codex-impl` は互換を維持する。Codex→Claudeは実機CLI仕様の確認後だけ有効化され、未確認フラグを決め打ちしていない。
- [ ] Stop Hookは計画を直接編集せず、run manifestが `review_passed` かつ未同期の時だけ継続を要求する。SubagentStopはwrite workerのresult packet欠落を検出する。manifest不在時は通す。
- [ ] UserPromptSubmit の初回ガイドとミラーが、planning起案・active実行・done待機・archive人間確認・バケット上限という契約を、過剰な本文複製なしに案内する。
- [ ] session-board はセッション状態の所有者のままで、`finish` が計画archiveの承認・実行にならないことがテストと手順MDで明確である。
- [ ] 既存の active/paused/done/archive の監査結果と、状態矛盾・上限超過ごとの人間承認待ち移行候補一覧があり、承認なしの一括移動・削除をしていない。
- [ ] 新hookのruntime登録・settings変更・symlink・Codex再trust・planフォルダ移動改名は人間承認前に行われず、全hook変更後に既存5イベント＋追加イベントのruntime別E2EとCodex再trustを一度だけ行う。
- [ ] 変更対象の plan-ops・session-board・harness・hookのテスト、plan lint、program-lint、E2E 5系統（単発plan／2子Program／conflict archive／completed archive／Stop guard）が合成データで通り、実Turso・実secret・実Dailyを触っていない。
- [ ] 既存の未コミット変更（hooks-registry再編差分）を巻き込まず、各Waveが対象path限定の別commitになっている。

## 関連

- 設計資料（今回の採用判断・実装仕様・Task Packetテンプレ）: `references/2026-07-15-計画実行基盤/`
- 先行資料: `../2026-07-08-並列実装フロー/plan.md`（本programへ統合。終了区分の実装＋人間確認後に `merged` で閉じる候補）
- 接続契約: `../../active/2026-07-14-計画運用ハーネス検証/program.md`（同program子04が本program子02へPrompt Submit接続契約を引き継ぎ済み・2026-07-15）
- 状態・計画規約: `../../../../AGENTS.md` §3-4 ／ `../../../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §7 ／ `../../../../../../AIエージェント基盤/plan-registry/AGENTS.md`
- 計画操作: `../../../../../../AIエージェント基盤/skills/plan-ops/`
- 委譲・役割: `../../../../../../AIエージェント基盤/agents-registry/`
- hookイベント: `../../../../../../AIエージェント基盤/hooks-registry/`（`events/`＋`shared/`）
