分類: 横断 ／ 種別: 既存改善 ／ 形態: program ／ 規模: フル

# 計画立案・実行・完了基盤

人間確認方針: 最終一括（危険操作は実行せず承認セットへ遅延し、即時実行が避けられない場合だけ個別承認）

※ 本programは「完了判定とアーカイブ運用」（2026-07-13起案）を親として拡張した（2026-07-15・references/2026-07-15-計画実行基盤/ の3資料を採用）。同日、12子構成を6子へ統合（細分化しすぎると実装が遅くなるため。基本は6〜7子・OSレベルの大改修だけ10前後まで）。フォルダ名の変更は人間ゲートのため未実施。rename案は「人間ゲート」節に記す。

## 目的

計画運用を「起案 → Task分割 → Claude/Codexへ委譲 → task-scoped worktreeで実装 → 異系統レビュー → 計画・Programの決定的同期 → 理由付きで閉じる」まで、一貫した機械手続きで扱えるようにする。実装後の計画・Programマップ更新が手動のまま残る穴を塞ぎ、**program+子計画を作り終えたら、ゴールコマンド（program-run）1つで実装からレビューまで人間なしで完走できる**状態を作る。

状態遷移は次の一本道を正本とし、実装結果（result packet）と評価結果（評価NN.md）から機械的に同期する。

```text
planning → active → done → archive
             │        │        └ 人間の明示確認＋終了記録がある時だけ
             │        └ 実装済み・最終評価md全PASS（人間のクローズ判断待ち）
             └ 実装・修正・AIレビュー中
```

`archive` は「成功済み」ではなく「閉じた計画」とし、終了区分（completed／superseded／merged／conflict／cancelled）と終了記録を必須にする。未完了計画を completed に偽装しない。容量は各 `plans/` 直下ごとに `planning=無制限 / active=3 / paused=3 / done=8 / archive=無制限` とし、移動先へ入る直前に判定する。満杯でもAIが別計画を勝手に動かして枠を作ることはしない。

## 非対象

- Orca資産の削除（任意アダプターとして残す。既定経路にはしない）
- 全areaの一括破壊的移行、過去計画の一括改名、全archiveの自動修正
- Hookによる完了の意味推測、Hookからのplan/program直接編集
- 固定モデルID・worktree・branch・session IDを計画本文やagent定義へ埋め込むこと
- 未確認のClaude CLIフラグの決め打ち
- hook登録、symlink変更、Codex trust、push、main反映、本番変更の無断適用

## 完走スキームと人間確認（このprogramの運転ルール）

1. **完走ライン**: 全子とも「実装＋テスト＋（適用系は）候補・差分の一覧化」までを人間なしで進める。計画完成後は `program-run`（ゴールコマンド・子08）がWave順に 委譲→実装→レビュー→planctl同期 を自動進行する。
2. **人間に聞くのは2種類だけ**: (a) 全子完走・統合評価後の**最終一括確認**（承認セット1枚で判断）、(b) 途中で危険操作（削除・移動・hook登録・trust・push等）の**即時実行が避けられない**場合の個別承認。原則(b)は発生させない設計にする — 適用系の操作は実行せず `承認セット` へ差分・根拠・推奨を積んで先へ進む。
3. **承認セット**: program-runと各子が蓄積し、子12が1文書へ整形する。中身は hook登録差分／rename案／既存計画の是正候補／identity・知識の移動候補／横展開可否。人間は最後にこれを見て一括判断する。
4. 認証・質問・waiting・利用上限は指揮官が解消し、人間へは上の(a)(b)だけを上げる。

## レビュー運用（都度と一括の使い分け）

- **都度**（完了ごとに即レビュー）: 後続の全子が成果物を直接使う子だけ。このprogramでは **05（共通契約）** と **12（最終統合）**。
- **一括**（3子程度を束ねてまとめてレビュー）: 依存が「契約の共有」に留まる子。**01・08・02はWave 4完了時に3子まとめて**レビューする。**03はWave 6のE2E時に**消化する。
- **例外＝即差し戻し**: 一括予定の子でも、schema・CLI引数・テンプレ等の**共通契約を変える修正**が必要と判明した時点で即座に評価・修正へ回す（後続の手戻りを防ぐ）。
- 一括待ちの子のmanifest phaseは `implemented` に留まり、Stop guard（子02）は止めずにレビュー待ち件数を案内する。委譲時のTask Packetとsession-end案内に、この一括/都度の判断を含める（子02・08が実装）。

## 正本境界

- 規模・段階・レビュー・責務地図: `plan-registry/AGENTS.md`。本programは同registryへの変更を提案・実装するが、規約本文をここへ複製しない。
- 物理バケット・テンプレ配置・評価文書の置き方: `my-brain/areas/AGENTS.md`
- テンプレ・lint・計画同期script（planctl含む）: `AIエージェント基盤/skills/plan-ops/`
- 委譲harness・役割定義・ゴールコマンド: `AIエージェント基盤/agents-registry/`
- hookイベント実装: `hooks-registry/events/` ＋ 共通エンジン `hooks-registry/shared/`。旧 `hooks-registry/hooks/` 構造は復活させない（2026-07-06再編済み。設計資料02が指す旧pathは各子で読み替える）。
- セッション記録: session-board（計画本文・計画状態・レビュー合否を所有しない）
- 実行時情報（runtime・worktree・branch・base SHA・run ID）: run manifest（git管理しない）。計画本文には書かない。
- 今回の設計資料: `references/2026-07-15-計画実行基盤/`（01=全体設計と採用判断、02=マスター実装仕様、03=Task Packet実行指示テンプレート）

## 全体像・実行Wave

```text
Wave 1  05 計画テンプレート・lint・委譲入口     ← 共通契約。完了時に都度レビュー
Wave 2  01 遷移統制とplanctl同期               ← bucketctl拡張＋planctl＋終了区分
Wave 3  08 harness・エージェント・ゴールコマンド ← delegate＋roles＋program-run
Wave 4  02 Prompt Submitとhookガード           ← 注入更新＋PreTool＋Stop/SubagentStop
          └ Wave 4完了時: 01・08・02 を3子一括レビュー
Wave 5  03 既存計画とarea標準の適用             ← 監査・pilot（候補一覧まで＝完走ライン）
Wave 6  12 E2Eと承認セット                     ← 03の一括レビュー消化＋統合評価＋承認セット
          └ 人間の最終一括確認 → 承認後に適用（hook登録・移動・rename等）
```

- 同時write workerは最大2。各子の内部では、その子の変更可能範囲内でファイル非交差の作業だけ並列化してよい。
- 実装は原則、子計画単位で `codex exec` へ委譲し、reviewerは実装担当と異系統かつread-onlyにする。FAIL時は評価MD→修正MD→同じthreadへのresumeで戻す（差し戻し上限2・超過は人間へ）。
- worktreeはTask単位で親ハーネスが明示baseから作る。workerに固定worktreeを持たせない。
- Task Packetは `references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md` 由来のテンプレ（05で正本化）から具体値を埋めて作り、workerへテンプレ全文を渡さない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新（番号はID・並びはWave順）

- [ ] 05  計画テンプレート・lint・委譲入口 … 計画
    役割: 契約（テンプレ・plan-lint・triage/handoff統一）
    並列: 不可 ／ レビュー: 都度(全子が依存する共通契約)
    人間ゲート: なし
    次: テンプレ拡張＋新規3枚＋plan-lint＋構成カード実行形化＋実行指示.md一本化を実装する
    場所: plans/05 ／ 依存: ―
- [ ] 01  遷移統制とplanctl同期 … 計画
    役割: 実装（bucketctl拡張・終了区分・planctl同期）
    並列: 不可 ／ レビュー: 一括(Wave4後に01・08・02、契約変更時のみ即差し戻し)
    人間ゲート: なし（既存計画の実移動は03が所有）
    次: 遷移グラフ・容量・終了記録検証のbucketctl拡張と、planctl 5サブコマンド＋result packet検証を実装する
    場所: plans/01 ／ 依存: 05
- [ ] 08  harness・エージェント・ゴールコマンド … 計画
    役割: 実装（delegate・roles・program-run）
    並列: 不可 ／ レビュー: 一括(Wave4後に01・08・02、契約変更時のみ即差し戻し)
    人間ゲート: なし（worktree削除は明示cleanupのみ・露出は承認セットへ)
    次: delegate/manifest/worktree/adapter、roles3種と/codex-impl互換、Wave自動進行のprogram-runを実装する
    場所: plans/08 ／ 依存: 05, 01
- [ ] 02  Prompt Submitとhookガード … 計画
    役割: 実装（注入更新・PreTool・plan-closeout guard）
    並列: 不可 ／ レビュー: 一括(Wave4後に01・08・02、契約変更時のみ即差し戻し)
    人間ゲート: runtime登録・注入文の有効化・Codex再trustは実行せず承認セットへ（適用は承認後）
    次: hooks再編差分の安定後、注入文・PreToolガード・Stop/SubagentStopガードを本体＋テストまで実装し、登録差分を承認セットへ積む
    場所: plans/02 ／ 依存: 01, 08, 計画運用ハーネス子04
- [ ] 03  既存計画とarea標準の適用 … 計画
    役割: 統合（既存計画の監査・ai運用pilot）
    並列: 不可 ／ レビュー: 一括(Wave6のE2E時に消化)
    人間ゲート: バケット移動・identity削除・知識/移動は実行せず承認セットへ（適用は承認後）
    次: 全バケット監査＋identity→AGENTS統合＋知識/分類＋代表計画の新テンプレ移行を行い、候補一覧を承認セットへ記録する
    場所: plans/03 ／ 依存: 01, 02, 05
- [ ] 12  E2Eと承認セット … 計画
    役割: 統合（E2E 5系統・一括レビュー消化・承認セット整形）
    並列: 不可 ／ レビュー: 都度(この子自体が最終の統合レビュー)
    人間ゲート: なし（承認セットの提示まで。適用は承認後）
    次: program-run経由のE2E・03の一括レビュー・全lintを通し、承認セット1枚を人間の最終一括確認へ上げる
    場所: plans/12 ／ 依存: 05, 01, 08, 02, 03

## 人間ゲート（承認セットで最後に一括判断する項目）

- 新hookのruntime登録、`~/.claude/settings.json`・`~/.codex/hooks.json` の変更、symlinkの追加・削除、Codex `/hooks` 再trust、注入文の有効化（子02）
- planフォルダの移動・改名。本programフォルダのrename案（例: `2026-07-15-計画立案実行完了基盤`）は子12の承認セットで提示し、承認まで現名を維持する
- 既存計画のバケット移動・是正（子03の候補。承認後に対象限定で適用）
- `identity.md` の削除、`知識/` 配下の移動（子03の候補一覧）
- 先行資料 `2026-07-08-並列実装フロー` の `終了区分: merged` での close
- push、mainへのmerge、本番・DB migration・launchd変更
- ※ 上記の**即時実行が避けられない**事態が途中で起きた場合のみ、承認セットを待たず個別に確認する（原則発生させない）

## 完了条件（レビュー項目）

- [ ] `active → done` が「実装済みかつ最終評価mdが全PASS」でのみ進み、`done → archive` は人間の明示確認と終了記録がある時だけ進むことを、規約・CLIテストで確認できる。`planning/active/paused → archive` は非completedの終了区分＋終了記録＋人間確認がある時だけ通る。
- [ ] `archive` 配下の計画に終了区分・理由・人間確認が必ず残り、conflict/merged/cancelled/supersededの計画をcompletedとして偽装していない。archive lintがこれを機械検査する。
- [ ] 各 `plans/` root で `active≤3`、`paused≤3`、`done≤8` を移動先ごとに強制し、`planning` と `archive` は上限なしである。超過済みの既存バケットは可視化・流入拒否するが、自動退避しない。
- [ ] 新規のライト以上の計画が、実行契約を持つ新テンプレートで作成され、plan lintが必須項目・placeholder残存・親backlink不整合を検出する。
- [ ] result packetと評価MDから、完了条件チェックボックス・実装結果・Programマップを `planctl` で同期でき、未評価・対象外・文言不一致を自動PASSにしない。
- [ ] **`program-run`（ゴールコマンド）が、合成programでWave順の 委譲→実装→レビュー→同期 を人間の介在なしに完走し、危険操作を実行せず承認セットへ蓄積し、完走後に統合評価＋承認セットを1回で人間へ提示できる。**
- [ ] **レビュー運用が宣言どおり動く: 05は都度、01・08・02はWave 4後の3子一括、03はE2E時。一括待ちの子をStop guardが止めず、共通契約を変える修正だけが即差し戻しになる。**
- [ ] workerは親会話を知らなくても、計画本文とrun manifestだけで作業でき、実装agent定義に固定worktree・branch・Program固有背景が無い。write laneごとに明示baseからtask-scoped worktreeを作れる。
- [ ] OrcaなしでClaude→Codex委譲が動き、既存 `/codex-impl` は互換を維持する。Codex→Claudeは実機CLI仕様の確認後だけ有効化され、未確認フラグを決め打ちしていない。
- [ ] Stop Hookは計画を直接編集せず、run manifestが `review_passed` かつ未同期の時だけ継続を要求する。SubagentStopはwrite workerのresult packet欠落を検出する。manifest不在時は通す。
- [ ] UserPromptSubmit の初回ガイドとミラーが、planning起案・active実行・done待機・archive人間確認・バケット上限・レビュー方式（一括/都度）を、過剰な本文複製なしに案内する。session-board はセッション状態の所有者のままで、`finish` が計画archiveの承認・実行にならない。
- [ ] 既存計画の監査結果と是正候補・identity/知識の移動候補が承認セットに揃い、承認なしの一括移動・削除をしていない。
- [ ] 新hookのruntime登録・settings変更・symlink・Codex再trust・planフォルダ移動改名は人間承認前に行われず、承認後の適用時に既存5イベント＋追加イベントのruntime別E2EとCodex再trustを一度だけ行う。
- [ ] 変更対象のテスト・plan lint・program-lint・archive lint・E2E 5系統（単発plan／2子Program／conflict archive／completed archive／Stop guard）が合成データで通り、実Turso・実secret・実Dailyを触っていない。既存の未コミット変更（hooks-registry再編差分）を巻き込まず、各Waveが対象path限定の別commitになっている。

## 関連

- 設計資料（今回の採用判断・実装仕様・Task Packetテンプレ）: `references/2026-07-15-計画実行基盤/`
- 先行資料: `../2026-07-08-並列実装フロー/plan.md`（本programへ統合。終了区分の実装＋人間確認後に `merged` で閉じる候補）
- 接続契約: `../../active/2026-07-14-計画運用ハーネス検証/program.md`（同program子04が本program子02へPrompt Submit接続契約を引き継ぎ済み・2026-07-15）
- 状態・計画規約: `../../../../AGENTS.md` §3-4 ／ `../../../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §7 ／ `../../../../../../AIエージェント基盤/plan-registry/AGENTS.md`
- 計画操作: `../../../../../../AIエージェント基盤/skills/plan-ops/`
- 委譲・役割・ゴールコマンド: `../../../../../../AIエージェント基盤/agents-registry/`
- hookイベント: `../../../../../../AIエージェント基盤/hooks-registry/`（`events/`＋`shared/`）
