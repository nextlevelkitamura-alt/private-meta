分類: 横断 ／ 種別: 既存改善 ／ 形態: program ／ 規模: フル

# 計画立案・実行・完了基盤

人間確認方針: 最終一括（危険操作は実行せず承認セットへ遅延し、即時実行が避けられない場合だけ個別承認）

※ 本programは「完了判定とアーカイブ運用」（2026-07-13起案）を拡張・改名したもの（2026-07-15人間承認でフォルダ日付を最新化し12子→6子へ統合。references/2026-07-15-計画実行基盤/ の3資料を採用）。今後、計画を大幅更新した時はフォルダ日付を最新化する（規約化は子01・機械コマンドは子02・hook担保は子04が実装）。

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

0. **実行開始ゲート（計画合意・2026-07-15人間指示）**: フル規模のprogram/planは、実行開始（active昇格・program-run起動）の前に次の3点を満たす。(a) **並列宣言（delegated-parallel）の子は、レーンごとの変更可能範囲（ファイル担当マップ）とworktree方針が実行契約に記載済み**であること（未記載なら走らせない。plan-lintとprogram-runが機械検査）。(b) **視覚的な説明（`explain/` の図解HTML）が計画の最新内容と一致**していること。(c) それを**人間へ提示し、双方の理解に相違がないことの明示（「これでいい」）を得てから**走らせる。合意前に実装を開始しない。
1. **完走ライン**: 全子とも「実装＋テスト＋（適用系は）候補・差分の一覧化」までを人間なしで進める。計画完成後は `program-run`（ゴールコマンド・子03）がWave順に 委譲→実装→レビュー→planctl同期→worktree統合 を自動進行する。
2. **人間に聞くのは2種類だけ**: (a) 全子完走・統合評価後の**最終一括確認**（承認セット1枚で判断）、(b) 途中で危険操作（削除・移動・hook登録・trust・push等）の**即時実行が避けられない**場合の個別承認。原則(b)は発生させない設計にする — 適用系の操作は実行せず `承認セット` へ差分・根拠・推奨を積んで先へ進む。
3. **承認セット**: program-runと各子が蓄積し、子06が1文書へ整形する。中身は hook登録差分／既存計画の是正候補／identity・知識の移動候補／横展開可否。人間は最後にこれを見て一括判断する。
4. 認証・質問・waiting・利用上限は指揮官が解消し、人間へは上の(a)(b)だけを上げる。

### worktreeのライフサイクル（write実装の1 Taskはこの流れで閉じる）

```text
① 作成    planctl prepare + harness: 明示base SHAからtask専用worktree（task_id命名）
② 実装    workerがworktree内で実装し、対象path限定でcommit → result packet
③ 検証    result packetのschema検証・禁止範囲違反チェック
④ レビュー 子の宣言どおり（都度=即 ／ 一括=Wave束ねまで worktree保持のまま待機）
⑤ 同期    全PASS → planctl apply-evaluation（計画・マップを機械更新）
⑥ 統合    program-runが統合branchへ merge --no-ff → 対象テストのスモーク
⑦ 削除    worktreeを削除（cleanup）。branchは統合branchへ集約済み
⑧ main反映 最終承認セットの人間承認後に一括（それまでmainへ触れない）
```

- read-only task（explorer/reviewer）はworktreeを作らない（①⑥⑦なし）。
- conflict（⑥）は自動解決せず停止して人間へ。mergeと削除を実行するのはharness/program-run（子03）であり、**hookは検知・案内・検証のみ**（子04）。
- SubagentStart（worker起動時）: 割当worktree・base・branchが manifest と一致するかを検査し、不一致なら編集前に止める。SubagentStop（worker終了時）: result packet の存在とschemaを検査する。両hookはCodex/Claude双方の受け口（`events/subagent/`）に置く。

## 直列・並列の実行判断（正本）

- **Wave間は直列**（前Waveの成果が次Waveの契約になるため）。**Wave内・子内の並列は、各子の実行契約 `実行形:` の宣言を正本にする**。
- 実行形の語彙: `direct`（指揮官が直接編集）／`delegated-single`（worker 1体へ委譲・内部直列）／`delegated-parallel`（ファイル非交差の2レーンまで並列委譲）／`integration`（統合検証の1体）。
- 本programの判断: 01=delegated-single ／ 02=delegated-single ／ 03=**delegated-parallel**（A=harness本体・B=roles+互換、非交差。program-runはA・B統合後） ／ 04=delegated-single ／ 05=**delegated-parallel**（A=監査read-only・B=pilot） ／ 06=integration。
- 同時write workerは全体で最大2。**`delegated-parallel` を宣言した子は、レーンごとの変更可能範囲（どのレーンがどのpathを書くか）とworktree方針を実行契約に記載しなければ起動できない**（記載が計画に無いまま並列workerを走らせない。plan-lint＝子01とprogram-runの起動前検査＝子03が機械担保する）。

## どこで動くか（personal-osのareaと各repoの両対応・2026-07-15人間指示で明文化）

- **機構はすべて「明示path」を受けるrepo非依存の作りにする**。planctl・bucketctl（子02）、delegate・program-run（子03）、plan-lint（子01）、hookガード（子04・`PLAN_RUN_MANIFEST` の `repo_root` 基準）は、`~/Private` のarea計画でも `projects/active/仕事` などのrepo-local `plans/` でも同じに動く。バケット語彙（planning/active/paused/done/archive）はrepo-local `plans/` 規約と同語彙（`areas/AGENTS.md` §3）。
- **「どの計画箱に入れるか」の解決は本programの対象外＝既存 `plan-triage` の二段ルーティングが正本のまま**: repo内起点は最寄り `AGENTS.md`、Private起点は `repo-registry/repo概要.md` で担当repoを判定 → 対象repoの最寄り `AGENTS.md` が宣言する計画箱 → 既存plan検索。本programはこのroute契約を壊さない（子01の維持する契約）。
- **各repoへの展開の分担**: repo側のAGENTS・計画箱の整備はactiveの「2026-07-13-全repoへのAI運用標準移植」programが所有する。本programは機構をrepo非依存に作って合成repoで検証するまでを担い、実repoへの適用可否は子06の承認セットで移植program側へ引き継ぐ（同じ機構を二重実装しない）。

## レビュー運用（都度と一括の使い分け）

- **都度**（完了ごとに即レビュー）: 後続の全子が成果物を直接使う子だけ。このprogramでは **01（共通契約）** と **06（最終統合）**。
- **一括**（3子程度を束ねてまとめてレビュー）: 依存が「契約の共有」に留まる子。**02・03・04はWave 4完了時に3子まとめて**レビューする。**05はWave 6のE2E時に**消化する。
- **例外＝即差し戻し**: 一括予定の子でも、schema・CLI引数・テンプレ等の**共通契約を変える修正**が必要と判明した時点で即座に評価・修正へ回す（後続の手戻りを防ぐ）。
- 一括待ちの子のmanifest phaseは `implemented` に留まり、Stop guard（子04）は止めずにレビュー待ち件数を案内する。委譲時のTask Packetとsession-end案内に、この一括/都度の判断を含める（子03・04が実装）。

## 正本境界

- 規模・段階・レビュー・責務地図: `plan-registry/AGENTS.md`。本programは同registryへの変更を提案・実装するが、規約本文をここへ複製しない。
- 物理バケット・テンプレ配置・評価文書の置き方: `my-brain/areas/AGENTS.md`
- テンプレ・lint・計画同期script（planctl含む）: `AIエージェント基盤/skills/plan-ops/`
- 委譲harness・役割定義・ゴールコマンド: `AIエージェント基盤/agents-registry/`
- hookイベント実装: `hooks-registry/events/` ＋ 共通エンジン `hooks-registry/shared/`。旧 `hooks-registry/hooks/` 構造は復活させない（2026-07-06再編済み。設計資料02が指す旧pathは各子で読み替える）。
- セッション記録: session-board（計画本文・計画状態・レビュー合否を所有しない）
- 実行時情報（runtime・worktree・branch・base SHA・run ID）: run manifest（git管理しない）。計画本文には書かない。
- 今回の設計資料: `references/2026-07-15-計画実行基盤/`（01=全体設計と採用判断、02=マスター実装仕様、03=Task Packet実行指示テンプレート。資料が指す旧フォルダ名 `2026-07-13-完了判定とアーカイブ運用` と旧子番号は本programの旧構成）

## 全体像・実行Wave（番号＝実行順）

```text
Wave 1  01 計画テンプレート・lint・委譲入口     ← 共通契約。完了時に都度レビュー
Wave 2  02 遷移統制とplanctl同期               ← bucketctl拡張＋planctl＋終了区分＋日付rename
Wave 3  03 harness・エージェント・ゴールコマンド ← delegate＋roles＋program-run
Wave 4  04 Prompt Submitとhookガード           ← 注入更新＋PreTool＋Stop/SubagentStop
          └ Wave 4完了時: 02・03・04 を3子一括レビュー
Wave 5  05 既存計画とarea標準の適用             ← 監査・pilot（候補一覧まで＝完走ライン）
Wave 6  06 E2Eと承認セット                     ← 05の一括レビュー消化＋統合評価＋承認セット
          └ 人間の最終一括確認 → 承認後に適用（hook登録・移動等）
```

- 同時write workerは最大2。各子の内部では、その子の変更可能範囲内でファイル非交差の作業だけ並列化してよい。
- 実装は原則、子計画単位で `codex exec` へ委譲し、reviewerは実装担当と異系統かつread-onlyにする。FAIL時は評価MD→修正MD→同じthreadへのresumeで戻す（差し戻し上限2・超過は人間へ）。
- worktreeはTask単位で親ハーネスが明示baseから作る。workerに固定worktreeを持たせない。
- Task Packetは `references/2026-07-15-計画実行基盤/03_サブエージェント実行指示テンプレート.md` 由来のテンプレ（子01で正本化）から具体値を埋めて作り、workerへテンプレ全文を渡さない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新（番号＝実行順）

- [x] 01  計画テンプレート・lint・委譲入口 … 完了
    役割: 契約（テンプレ・plan-lint・triage/handoff統一）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 都度(全子が依存する共通契約)
    人間ゲート: なし
    次: 評価02全PASS(6/6)・統合branchへmerge済み(スモーク120pass)・worktree削除済み。成果は子02以降が使用
    場所: plans/01 ／ 依存: ―
    参照: task/pf01=5583899・評価01→修正01→評価02(全PASS)
- [ ] 02  遷移統制とplanctl同期 … 修正
    役割: 実装（bucketctl拡張・終了区分・planctl同期・日付rename）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 一括（Wave4後に02・03・04を3子一括。共通契約を変える修正のみ即差し戻し）
    人間ゲート: なし（既存計画の実移動は05が所有）
    次: 一括レビュー評価01(4PASS/2FAIL: planctl明示path・実差分照合・progress不変・rename --check・回帰テスト)の修正01を、write worker枠(最大2)が空き次第codex resumeで差し戻す
    場所: plans/02 ／ 依存: 01
    参照: task/pf02=8d7fc3a・評価01→修正01
- [ ] 03  harness・エージェント・ゴールコマンド … 修正
    役割: 実装（delegate・roles・program-run）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 一括（Wave4後に02・03・04を3子一括。共通契約を変える修正のみ即差し戻し）
    人間ゲート: なし（worktree削除は明示cleanupのみ・露出は承認セットへ）
    次: 一括レビュー評価01(4PASS/5FAIL: schema検証・Claudeレビュー経路・resume・実gitテスト・承認セット同期)の修正01をcodex resumeで対応中
    場所: plans/03 ／ 依存: 01, 02
    参照: task/pf03=fec91a9・評価01→修正01
- [ ] 04  Prompt Submitとhookガード … 修正
    役割: 実装（注入更新・PreTool・plan-closeout guard）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 一括（Wave4後に02・03・04を3子一括。共通契約を変える修正のみ即差し戻し）
    人間ゲート: runtime登録・注入文の有効化・Codex再trustは実行せず承認セットへ（適用は承認後）
    次: 実装完了(登録未適用・差分ファイル化済み)→一括レビュー評価01(2PASS/6FAIL: PreTool回避・schema fail-open・fixture不足ほか。注入2件は完了条件明確化で解消)の修正01をcodex resumeで対応中
    場所: plans/04 ／ 依存: 02, 03, 計画運用ハーネス子04
    参照: task/pf04=0c51934・評価01→修正01・登録差分=hooks-registry/registration-diff-04-plan-closeout.md
- [ ] 05  既存計画とarea標準の適用 … 計画
    役割: 統合（既存計画の監査・ai運用pilot）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 一括（Wave6のE2E・統合評価と合わせて消化）
    人間ゲート: バケット移動・identity削除・知識/移動は実行せず承認セットへ（適用は承認後）
    次: 全バケット監査＋identity→AGENTS統合＋知識/分類＋代表計画の新テンプレ移行を行い、候補一覧を承認セットへ記録する
    場所: plans/05 ／ 依存: 01, 02, 04
    参照: ―
- [ ] 06  E2Eと承認セット … 計画
    役割: 統合（E2E 6系統・一括レビュー消化・承認セット整形）
    対象repo: ~/Private（private-meta）
    並列: 不可 ／ レビュー: 都度（この子自体が最終の統合レビュー。05の一括もここで消化）
    人間ゲート: なし（承認セットの提示まで。適用は承認後）
    次: program-run経由のE2E・05の一括レビュー・全lintを通し、承認セット1枚を人間の最終一括確認へ上げる
    場所: plans/06 ／ 依存: 01, 02, 03, 04, 05
    参照: ―

## 本programの計画承認に含まれる承認事項（Q1承認と同時に有効になる）

- **task worktreeの自動削除**: 「統合branchへの `merge --no-ff` 完了＋対象テストのスモーク通過」を満たしたtask worktreeに限り、program-runが⑦段として自動削除してよい。条件未達・conflict・一括レビュー待ちのworktreeは削除せず保持して報告する（mainへのmerge・pushは引き続き人間ゲート）。
- **統合branchへのmerge**: mainではない作業branch（例: `program/計画立案実行完了基盤`）への `merge --no-ff` は、レビュー全PASS＋planctl同期後の⑥段としてprogram-runが自動実行してよい。

## 人間ゲート（承認セットで最後に一括判断する項目）

- 新hookのruntime登録、`~/.claude/settings.json`・`~/.codex/hooks.json` の変更、symlinkの追加・削除、Codex `/hooks` 再trust、注入文の有効化（子04）
- 既存計画のバケット移動・是正（子05の候補。承認後に対象限定で適用）
- `identity.md` の削除、`知識/` 配下の移動（子05の候補一覧）
- push、mainへのmerge、本番・DB migration・launchd変更
- ※ 本programフォルダの日付rename・子番号の1〜6振り直し・先行資料（並列実装フロー）の整理は2026-07-15に人間承認済み（rename・振り直しは実施済み）
- ※ 上記の**即時実行が避けられない**事態が途中で起きた場合のみ、承認セットを待たず個別に確認する（原則発生させない）

## 完了条件（レビュー項目）

- [ ] `active → done` が「実装済みかつ最終評価mdが全PASS」でのみ進み、`done → archive` は人間の明示確認と終了記録がある時だけ進むことを、規約・CLIテストで確認できる。`planning/active/paused → archive` は非completedの終了区分＋終了記録＋人間確認がある時だけ通る。
- [ ] `archive` 配下の計画に終了区分・理由・人間確認が必ず残り、conflict/merged/cancelled/supersededの計画をcompletedとして偽装していない。archive lintがこれを機械検査する。
- [ ] 各 `plans/` root で `active≤3`、`paused≤3`、`done≤8` を移動先ごとに強制し、`planning` と `archive` は上限なしである。超過済みの既存バケットは可視化・流入拒否するが、自動退避しない。
- [ ] 新規のライト以上の計画が、実行契約を持つ新テンプレートで作成され、plan lintが必須項目・placeholder残存・親backlink不整合・並列宣言のレーン担当未記載を検出する。program子数の目安（基本6〜7・大改修のみ10前後）・計画フォルダ日付の最新化・**計画合意ゲート（explain図解の提示→相違なしの明示→実行開始）**が規約に記載されている。
- [ ] result packetと評価MDから、完了条件チェックボックス・実装結果・Programマップを `planctl` で同期でき、未評価・対象外・文言不一致を自動PASSにしない。計画の大幅更新時に `rename` サブコマンドで日付最新化と参照追従が機械的にでき、hookが陳腐化（大幅更新なのに日付が古い）を検知して案内する。
- [ ] **`program-run`（ゴールコマンド）が、起動前検査（lint全緑・並列子のレーン担当記載）を通過した計画だけを走らせ、合成programでWave順の 委譲→実装→レビュー→同期 を人間の介在なしに完走し、危険操作を実行せず承認セットへ蓄積し、完走後に統合評価＋承認セットを1回で人間へ提示できる。**
- [ ] **レビュー運用が宣言どおり動く: 01は都度、02・03・04はWave 4後の3子一括、05はE2E時。一括待ちの子をStop guardが止めず、共通契約を変える修正だけが即差し戻しになる。**
- [ ] workerは親会話を知らなくても、計画本文とrun manifestだけで作業でき、実装agent定義に固定worktree・branch・Program固有背景が無い。write laneごとに明示baseからtask-scoped worktreeを作れる。
- [ ] OrcaなしでClaude→Codex委譲が動き、既存 `/codex-impl` は互換を維持する。Codex→Claudeは実機CLI仕様の確認後だけ有効化され、未確認フラグを決め打ちしていない。
- [ ] Stop Hookは計画を直接編集せず、run manifestが `review_passed` かつ未同期の時だけ継続を要求する。SubagentStopはwrite workerのresult packet欠落を検出する。manifest不在時は通す。
- [ ] UserPromptSubmit の初回ガイドとミラーが、planning起案・active実行・done待機・archive人間確認・バケット上限・レビュー方式（一括/都度）を、過剰な本文複製なしに案内する。session-board はセッション状態の所有者のままで、`finish` が計画archiveの承認・実行にならない。
- [ ] 既存計画の監査結果と是正候補・identity/知識の移動候補が承認セットに揃い、承認なしの一括移動・削除をしていない。
- [ ] 新hookのruntime登録・settings変更・symlink・Codex再trust・計画フォルダの承認なき移動改名は行われず、承認後の適用時に既存5イベント＋追加イベントのruntime別E2EとCodex再trustを一度だけ行う。
- [ ] 変更対象のテスト・plan lint・program-lint・archive lint・E2E 6系統（単発plan／2子Program／conflict archive／completed archive／Stop guard／**repo-local: Private以外の合成repoのplans/での一巡**）が合成データで通り、実Turso・実secret・実Dailyを触っていない。既存の未コミット変更（hooks-registry再編差分）を巻き込まず、各Waveが対象path限定の別commitになっている。

## 関連

- 設計資料（今回の採用判断・実装仕様・Task Packetテンプレ）: `references/2026-07-15-計画実行基盤/`
- 先行資料: `2026-07-08-並列実装フロー`（本programへ統合。2026-07-15人間承認で分析・整理 — 判定と移動先は同計画の終了記録を参照）
- 接続契約: `../../active/2026-07-14-計画運用ハーネス検証/program.md`（同program子04が本program子04＝旧 `完了判定とアーカイブ運用/plans/02` へPrompt Submit接続契約を引き継ぎ済み・2026-07-15）
- repo展開の分担先: `../../active/2026-07-13-全repoへのAI運用標準移植/program.md`（repo側AGENTS・計画箱の整備を所有。本programは機構のrepo非依存化と合成repo検証まで）
- 置き場解決の正本: `../../../../../../AIエージェント基盤/repo-registry/repo概要.md`（担当repo判定）＋ `../../../../../../AIエージェント基盤/skills/plan-triage/`（二段ルーティング・変更しない）
- 状態・計画規約: `../../../../AGENTS.md` §3-4 ／ `../../../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §7 ／ `../../../../../../AIエージェント基盤/plan-registry/AGENTS.md`
- 計画操作: `../../../../../../AIエージェント基盤/skills/plan-ops/`
- 委譲・役割・ゴールコマンド: `../../../../../../AIエージェント基盤/agents-registry/`
- hookイベント: `../../../../../../AIエージェント基盤/hooks-registry/`（`events/`＋`shared/`）

## 終了記録

archive時に終了区分・人間確認とともに追記する（テンプレ: plan-ops `templates/終了記録.md`）。
