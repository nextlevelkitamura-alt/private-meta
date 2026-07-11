分類: 横断 ／ 種別: 統合整理 ／ 規模: フル

# ai-jobs 完全廃止（モードA実行レーンの撤去）

## 目的

休眠中の ai-jobs（モードA＝run-card フォルダキュー）を、dangling 参照を残さず完全撤去し、
実行経路をモードB（session-board＋orca-cockpit の対話ワーカー並列）へ一本化する。
旧「2026-07-08 ai-jobs縮小」を、ユーザー裁定（2026-07-11・完全削除）で「廃止」へ格上げしたもの。

## 現状（2026-07-11 調査確定）

- ai-jobs は 2026-07-03 裁定で休眠。`ready`〜`archive` は空、`done/` に `exec-audit-20260702.md` が1枚のみ。
- dispatcher（`loops-registry/loops/ai-jobs-dispatcher/`・TS実装＋tests＋plist）は **launchd 未ロード**。
- 現役で稼働中の loop はどれも ai-jobs フォルダを読まない
  （renderer・exec-audit は停止中、board-sweep は `AIJOBS_RUN` フラグのみ）。→ 削除は現在の自動実行を壊さない。
- `AIJOBS_RUN` env は ai-jobs キューと独立の headless ガード（board-sweep / session-board hook で現役）。名前が由来なだけ。
- `com.nextlevel.dispatcher.plist` は仕事repo（`projects/active/仕事/scripts/nextlevel-dispatcher`）の別物。無関係。
- `feat/ai-jobs-*` ローカル branch は既に存在しない（`git branch -a | grep ai-jobs` = 0件確認済み）。
- `references/loop-runbook.md` の dispatcher 言及は仕事repoのリファレンス実装の話で ai-jobs 非依存。
- （実行時判明・2026-07-11）並行セッションが停止 loop 群の大掃除を同時進行中（daily-digest・exec-audit・inbox-patrol・renderer・references/loop-runbook.md・loop-types.md をフォルダ/ファイルごと削除・unstaged・本計画スコープ外）。層3の 2〜3 と層1-6 の loop-types 書換は対象消滅により作業不要となった。復元・上書きはしない。

## 方針（ユーザー裁定・確定）

1. **(Q1) 完全削除**: dispatcher 実装・plist も含め削除。git 履歴（コミット）が保険＝将来の無人並列（モードA）が必要になれば履歴から復元 or 再設計。
2. **(Q2) 運用契約§1をモードB単一へ簡素化**＋決定ログに廃止1件（契約§8: 改訂=人間承認＋決定ログとセット。人間承認は 2026-07-11 の本裁定）。
3. **(Q3) 順序**: 参照側（層1〜3）を先に外し、本体（層4）を最後に消す（dangling 防止）。
4. **(Q5) 実行**: 逐次・Codex 直接委任（/codex-impl・メインが codex exec を駆動）。並列はしない。
5. **温存**: `AIJOBS_RUN` env（名前ごと・機能ごと）。
6. **触らない**: 下記「触らないもの」節。

## 実行手順（層1→6・ファイル別指示）

パスは `~/Private/` 基準。書換は「該当箇所だけ」を外科的に。行番号は目安（他セッションが並行編集中のため、**実行時に必ず rg で現物を確認**してから編集する）。

### 層1. 正本ルールの書換（7ファイル）

1. **`personal-os/説明書/運用契約.md`**
   - §1（現9〜14行）を次の本文へ全置換（見出しごと）:

     ```
     ## 1. 状態の持ち方（テキスト状態・単一指揮官）

     - 状態はテキストで持つ。単一の指揮官（人＋中央Claude、orca-cockpit）が直接配る。writerが1人なので同時書き込み衝突が無く、フォルダロック不要。
     - 状態は1箇所（§5）。当日デイリー行注記＋レーン実況（Notion盤面）が持つ。
     - 無人・並行実行（複数AIが調停者なしで同じ列を取り合う）を将来必要とする場合は、その時点でキュー機構を再設計する（旧ai-jobs＝モードAは2026-07-11廃止・決定ログ#NN。実装はgit履歴に残る）。
     ```
   - §3 記録の保証（現41行）: 「（Claude transcript / Codex sessions / 各repoのgit履歴 / ai-jobs）」→「（Claude transcript / Codex sessions / 各repoのgit履歴）」。
   - §6（現57行）: 「自動実行は ai-jobs レーン / loop-runbook の上に乗せる。」→「自動実行は loop-runbook（基盤 loops-registry の loop entry）の上に乗せる。」。
   - 注意: §2等に残る「モードB」という語は「（旧称。現在は単一モード）」等へ丸めず**そのまま残してよい**が、§1から「モードA/B」の対比が消えるため、契約内で「モードB」を参照している箇所（あれば）を「テキスト状態（§1）」参照へ直す。

2. **`personal-os/説明書/README.md`**
   - §3（現20〜24行）: モードA/B 2モード説明を「状態はテキスト（当日デイリー＋Notion盤面）で持つ。ai-jobsキュー（旧モードA）は2026-07-11廃止（決定ログ#NN）」の趣旨へ書換。契約正本行（24行）は残す（「モードA活性化条件」の語だけ除去）。
   - §4（現28〜30行）: 「ai-jobs は捨てず、モードA として将来用に温存」→「2026-07-11 にキュー機構（ai-jobs）ごと廃止。無人並列が再び要る時は再設計（git履歴に実装が残る）」。
   - §5（現37行）: 「loop / ai-jobs の正本」→「loop の正本」。

3. **`personal-os/my-brain/areas/AGENTS.md`**
   - §3「レビュー項目と実行ゲート」1: 「area計画は run-card を ai-jobs/ready へ出す（§4.2）。」→「area計画は指揮官がペインへ配って実行する（§4.2）。」。
   - §3「プログラム計画」4: 「子が並列実行で複数作業に割れる時だけ、その子をフォルダにし、実行は ai-jobs へ（§4.2）。」→「…その子をフォルダにする。実行の配り方は §4.2。」。
   - §4 見出し「## 4. 計画状態語彙 と タスク実行（ai-jobs）」→「## 4. 計画状態語彙 と タスク実行」。
   - §4.2 を見出しごと次へ全置換:

     ```
     ### 4.2 計画から派生する作業の実行

     計画から派生する「実行する作業」は、area 内にフォルダを作らず、指揮官（orca-cockpit）が実装/レビューのペインへ直接配って実行する。

     1. 実行の状態はテキスト（当日デイリー行注記＋Notion盤面）で持つ。フォルダキューは使わない（旧 ai-jobs は 2026-07-11 廃止＝決定ログ#NN）。
     2. **human 作業は実行レーンに入れない。** 人間のやることは program.md マップの「次の一手」か 子.md に書く。
     3. 完了したら plan-ops が出所の計画（program.md マップ／子.md）を更新する（ジョブ→計画へ集約。コピーしない）。
     4. 旧 `ops/` 5フォルダ構成は廃止。既存計画に残る `ops/` は legacy（新規には作らない・破壊しない）。
     ```
   - §5-3 卒業先判断: 「（human作業は program.md マップ／子.md、AI実行は ai-jobs。§4.2）」→「（human作業は program.md マップ／子.md、AI実行は §4.2）」。
   - §6-2: 「基盤の ai-jobs キューに run-card で出す（§4.2）」→「指揮官がペインへ配って実行する（§4.2）」。
   - §4.2 を参照している他の文（§3 テンプレ節・my-brain/AGENTS.md 側の「派生する作業は §4.2 に従う」）は参照先が生きるので**そのまま**。

4. **`personal-os/AIエージェント基盤/loops-registry/AGENTS.md`**
   - 冒頭説明行: 「（実行レーン・loop本体・共通参照・loop計画）」→「（loop本体・共通参照・loop計画）」。
   - 構成 tree: `worker-prompt.md` 行・`ai-jobs/` 行・`ai-jobs-dispatcher/` 行を削除。
   - 規律: 「`ai-jobs/` の実行レーン運用（…）は `ai-jobs/AGENTS.md` が正本。」行を削除。

5. **`personal-os/AIエージェント基盤/AGENTS.md`**
   - フォルダ一覧の loops-registry 行: 「loop 運用の一式（実行レーン・loop本体・共通参照・loop計画）」→「loop 運用の一式（loop本体・共通参照・loop計画）」。
   - ※このファイルは他セッションが並行編集中（agents-registry 行が新設済み）。**該当1行だけ**を Edit すること。

6. **`personal-os/AIエージェント基盤/loops-registry/references/`**
   - `worker-prompt.md`: **丸ごと削除**（全編 run-card 実行の型）。
   - `loop-types.md`: 冒頭（現4行）「実行レーンの契約は `../ai-jobs/AGENTS.md`」を削除。①節（現6〜13行）を「① ペイン実行（orca-cockpit）← 基本はこれ」へ書換＝「指揮官が orca-cockpit のペインへ直接配る。ai-jobs キューは 2026-07-11 廃止」の趣旨。`loops/ai-jobs-dispatcher` 言及（現13行）を除去。②③の定義は変えない。
   - `loop-runbook.md`: **触らない**（dispatcher 言及は仕事repoの別物の話）。

7. **`personal-os/AIエージェント基盤/.gitignore`**
   - 現11〜13行（`# ai-jobs spool: …` ＋ `/loops-registry/ai-jobs/*/*` ＋ `!/loops-registry/ai-jobs/*/.gitkeep`）の3行を削除。

### 層2. plan-ops 窓口の外科除去

対象: `personal-os/AIエージェント基盤/skills/plan-ops/`

- `scripts/jobctl.sh` と `scripts/new-run-card.sh` を `git rm`。
- `SKILL.md` から ai-jobs 節を除去（残す5機能: progctl / new-plan / new-child / program-lint / check-section）:
  - frontmatter description: 「ai-jobs run-cardの状態遷移・生成」「run-cardをready/runningで掴む・進める, 計画からrun-cardを起こす, ai-jobsのclaim/done/差し戻し」を削除し文を繋ぐ。
  - 冒頭「規約の正本」リスト: ai-jobs 行（現14行）を削除。12行の「状態の持ち方（モードA/B）」→「状態の持ち方」。
  - §0: モードA/ai-jobs 休眠の段落（現21行）を削除。§0 見出しは「## 0. 状態の持ち方（テキスト状態）」へ。20行の「モードB」表現は「テキスト状態」へ。
  - §1: 項目4（jobctl）・項目5（new-run-card）を削除（番号を詰める）。
  - §2.4（jobctl）・§2.5（new-run-card）: 節ごと削除（§2.6 を §2.4 へ繰上げ）。
  - §4 規律: 項目2（ai-jobs の card を削除しない…）を削除（番号を詰める）。
  - §5 早見: `jobctl.sh` 行・`new-run-card.sh` 行を削除。
- runtime 露出の確認: `~/.claude/skills/plan-ops` が symlink なら実体編集で追従される（コピーなら要同期）。

### 層3. runtime 実装の除去（停止中 loop）

1. **`loops-registry/loops/ai-jobs-dispatcher/`**: フォルダごと `git rm -r`（TS実装・tests・plist。launchd 未ロード確認済み）。
2. **`loops-registry/loops/exec-audit/`**（停止中・loop.md frontmatter は維持）:
   - `scripts/audit.sh`: readycard 旧経路を除去（現6・17・23・101・222行付近＝`READY=` 定義・`EXEC_AUDIT_OUTPUT=readycard` 分岐・`pending_cards` の ai-jobs glob・案内文）。出力は inbox 一本へ。
   - `loop.md`: readycard 記述（現53行・80行の設定表・90行の実行レーン契約参照）を除去。
   - `tests/run-tests.sh`: sandbox の ai-jobs ディレクトリ作成（現38行）と readycard 系テスト（現106〜166行付近）を除去。**テストを実行して緑を確認**。
3. **`loops-registry/loops/renderer/`**（停止中）:
   - `scripts/build-align.sh`: 「／ai-jobs done ${done_count} 件」の出力と done_count 集計ロジックを除去（done カード探索コードごと）。
   - `loop.md`: auto:done の ai-jobs 言及（現27行）・done カード探索（現48行）・`AIJOBS_BASE`（現189・198行）を除去。
   - `tests/`: fixture（`daily-2026-07-01-legacy.md` 等）と期待値から ai-jobs 集計部分を更新。**テストを実行して緑を確認**。fixture はテスト資材なので更新可（実デイリーは触らない）。
4. **`loops-registry/実行一覧/personal-os.md`**: ai-jobs-dispatcher 行（現24行）を「2026-07-11 廃止（決定ログ#NN）」へ書換 or 削除。現50行の「`loops-registry/ai-jobs/AGENTS.md`」参照を除去。

### 層4. 本体フォルダの削除（人間ゲート済み・最後に実行）

1. `ai-jobs/done/exec-audit-20260702.md`（**非追跡**＝git で戻せない）を読み、要点1行を層6の決定ログエントリに含める。
2. `loops-registry/ai-jobs/` をフォルダごと削除（追跡分は `git rm -r`、非追跡 card は 1. の転記後に rm）。

### 層5. branch 確認

- `git branch -a | grep -i 'ai-jobs'` が 0 件であることを確認（既に無い＝作業不要の見込み）。

### 層6. 記録と現役計画の追従

1. **`my-brain/areas/ai運用/決定ログ.md`** に新エントリ（番号は実行時に採番・現状 #12 まで）:

   ```
   - #NN（2026-07-11・ユーザー裁定）: ai-jobs（モードA＝run-cardフォルダキュー）を完全廃止。
     背景: 2026-07-03以来「将来のモードA用に温存」としてきたが、orca-cockpit＋session-boardのモードB運用が定着し、休眠キューが宙に浮いた残骸になっていた。
     決定: 契約§1を「テキスト状態・単一指揮官」の1モードへ簡素化。ai-jobs本体・dispatcher実装・plist・plan-opsのjobctl/new-run-card・references/worker-prompt.mdを削除。AIJOBS_RUN env（headlessガード・キューと独立）は名前ごと温存。feat/ai-jobs-* branchは既に無し。done唯一のカード exec-audit-20260702.md の要点=<転記>。
     追従: areas/AGENTS.md §3-6・README§3-5・loops-registry/AGENTS.md・基盤AGENTS.md・loop-types.md・実行一覧・.gitignore・exec-audit/renderer実装を同作業でgrep追従（契約§8）。
     再開: 無人並列が再び必要になれば、その時点でキュー機構を再設計（実装はgit履歴に残る）。
   ```
2. **`plans/active/2026-07-03-マルチ指揮官体制/program.md`**: 方針47行「ai-jobs: 休眠のまま温存。…」→「ai-jobs: 2026-07-11 完全廃止（決定ログ#NN・廃止計画へ）。」へ1行化。98行「run-cardは使わない=ai-jobs休眠」→「run-cardは使わない=ai-jobs廃止(2026-07-11)」。
3. **`plans/active/2026-07-09-デイリー運用刷新/plans/05-停止行自動判定sweep.md`** 38行: 流用資産から「`loops-registry/loops/ai-jobs-dispatcher/scripts/`（headless起動パターン）」を削除（headless 起動パターンの現物は board-sweep が持つ）。
4. **`plans/planning/2026-07-08-並列実装フロー/plan.md`** 84行: 完了条件「ai-jobs 縮小の方向と AIJOBS_RUN ガード温存が、縮小実行の別計画へ引き継がれている」を `[x]` にし「（→ 2026-07-11-ai-jobs廃止 で実行）」を注記。59・91行は履歴・参照として触らない。

## 触らないもの（欠陥回避の肝）

- **履歴**: done/archive の過去計画・デイリー・決定ログの過去エントリ・`plans/done/**` の ai-jobs 言及。歴史なので改竄しない。
- **`com.nextlevel.dispatcher.plist`** と仕事repoの nextlevel-dispatcher 一式（別物）。`references/loop-runbook.md` の同 dispatcher 言及も残す。
- **`AIJOBS_RUN` env**: board-sweep（sweep.sh/sweep.py/llm-judge.sh/loop.md/tests）・session-board hook（common.py/README/session-start.md/tests）の参照は**全て温存**。改名もしない。
- **指揮官ロースター.md 41行**（閉鎖済み指揮官Cの失効注記＝履歴・朝会で行ごと削除予定）。
- **`plans/active/2026-07-04-指揮官体制の縮小と安定化/*.html`**（過去時点の説明資料・正本でない）。
- **`~/orca/workspaces/` などの runtime 領域**。

## 完了条件（レビュー項目）

- [ ] 現役の正本ルール（運用契約.md・README.md・areas/AGENTS.md・loops-registry/AGENTS.md・基盤AGENTS.md・plan-ops SKILL.md・基盤.gitignore・実行一覧/personal-os.md）で、ai-jobs への**生きた導線**（実在パス参照・使用手順・「〜へ出す」等の指示）が 0 件。**廃止注記は許容**（「旧ai-jobsは2026-07-11廃止＝決定ログ#14」形式の tombstone と README§4 の経緯記述。廃止の明記指示と文字列 grep 0件は両立しないため 2026-07-11 実行時に明確化）。loop-types.md は並行セッションの削除により対象から外す。
- [ ] `loops-registry/ai-jobs/`・`loops-registry/loops/ai-jobs-dispatcher/`・`references/worker-prompt.md`・`plan-ops/scripts/jobctl.sh`・`plan-ops/scripts/new-run-card.sh` が存在しない。
- [ ] 運用契約 §1 が1モード（テキスト状態）で、「モードA」「モードB」の対比が契約から消えている。
- [ ] 決定ログに廃止エントリが1件あり、done カード exec-audit-20260702.md の要点が転記されている。
- [ ] `AIJOBS_RUN` が board-sweep と session-board hook に残っている（`rg AIJOBS_RUN` で従来どおりヒット）。
- [ ] board-sweep・session-board の各テストが緑（tests/ を実行）。exec-audit・renderer は並行セッションの大掃除でフォルダごと消滅＝対象喪失につきテスト対象から外す（復元しない）。
- [ ] plan-ops の残機能が動く（`program-lint.sh` を任意の program.md へ実行してエラーなく判定が出る）。
- [ ] `git branch -a | grep -i ai-jobs` が 0 件。
- [ ] launchd に ai-jobs 系がない（`launchctl list | grep -i ai-jobs` 0件・`~/Library/LaunchAgents` に該当 plist なし）。
- [ ] secret 混入なし・`git add -A` 不使用（パス指定 commit）。

## 関連

- 裁定元: `../2026-07-08-並列実装フロー/plan.md`（縮小方向の初裁定）→ 本計画で完全廃止へ格上げ（2026-07-11 ユーザー裁定）。
- 説明資料: 理解ゲートHTML（2026-07-11・scratchpad・v1 承認済み）。
- 決定ログ: `../../決定ログ.md`（廃止エントリ #NN）。
