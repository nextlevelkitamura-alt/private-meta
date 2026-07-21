親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 一括（Wave4後に02・03・04を3子一括。共通契約を変える修正のみ即差し戻し）
人間ゲート: runtime登録・注入文の有効化・Codex再trustは実行せず承認セットへ（適用は承認後）

# Prompt Submitとhookガード（Wave 4）

## 目的

hook層を1子でまとめて新しい規律に揃える。(a) UserPromptSubmitの計画案内を新しい一本道（planning→active→done→archive・容量・レビュー方式）と一致させ、(b) 計画バケットへの生の `git mv`/`mv` を止めるPreToolガード、(c) 計画同期が済んでいない終了を止めるStop／SubagentStopガード（plan-closeout）を、再編後の `events/`＋`shared/` 境界で実装する。**hookは検査と案内だけを行い、計画を編集しない。**

## 非対象

- planctl・bucketctl本体（02。ガードは実行を「要求・案内」するだけで代行しない）
- session-boardの所有境界の変更（セッション記録の所有者のまま。session-end.md等はcloseout案内の追記のみ）
- runtime登録・trust・symlinkの実施（本体・テスト・登録差分の用意まで＝完走ライン。適用は承認セット承認後）
- 旧 `hooks-registry/hooks/` 構造の復活

## 現状

共有本体 `shared/session-board/common.py` の `_first_guide` と `_mirror` が、計画の3判定、`評価NN.md`、`全PASS=done` を文字列で直接注入している。`session-start.md` はそのガイド相当を説明し、`session-end.md` は人間確認後に `finish` するセッション終了手順を持つ。これらは計画バケットの archive 操作と独立であること、active=3／paused=3／done=8の容量、レビューの一括/都度の使い分けを明示していない。

Codex と Claude の prompt-register は薄いシムで、注入本文の正本は `common.py` である。PreToolUseの登録は現在無く、計画バケットへの生の `git mv`/`mv` を止めるガードが無い。Stop系は現行の共有コマンドがボードを⏸へ変えるだけで、「レビュー全PASSなのに計画未同期」を検知しない。hooks-registryは2026-07-06再編で `events/`（イベント受け口）＋`shared/`（共通エンジン）＋`claude/`・`codex/`（登録表）構成になっており、設計資料02 §16の旧 `hooks/plan-closeout/` 指定はこの構造へ読み替える。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/hooks-registry/AGENTS.md`・`events/AGENTS.md`・`shared/session-board/`（common.py・session-start/end.md・tests）
  2. `../program.md`（レビュー運用と完走スキーム）・この計画（下の接続契約を含む）
  3. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §16-17
  4. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §14（Hook設計原則）
- 実行形: delegated-single（注入文・PreTool・Stop/Subagentガードは同じ登録表と共通エンジンを触るため1 workerで直列）
- 依存成果: 02のrun manifest契約（phase語彙）・`bucketctl check`、03のresult packet schema・`PLAN_RUN_MANIFEST` 受け渡し・program-runのレビューキュー仕様、Codex調査による hooks設計書（`../references/2026-07-15-hooks設計調査.md`・着手前に必読）
- 変更可能範囲: `shared/session-board/common.py` の注入文と `tests/`、`shared/plan-closeout/`（新規・ガード本体とテスト）、`events/` の対応受け口（PreToolUse・session-end・subagent系シム）、`hooks-registry/claude/`・`codex/` の登録表（記載のみ）、`hooks-registry/AGENTS.md` 構成節、session-boardの手順MD（session-end.md・milestone のcloseout/レビュー方式案内）
- 変更禁止範囲: `~/.claude/settings.json`・`~/.codex/hooks.json`・symlink実体・Codex trust（承認セット経由）、`skills/plan-ops/`、`agents-registry/`、session-boardの所有境界
- 維持する契約: 注入本文の唯一の生成元は `common.py`（シムへ本文コピーしない）／hookは軽量・決定的で計画本文・バケットを編集しない／manifest不在なら必ず通す／既存5イベントと共存／`finish`≠archive承認
- 検証: `shared/session-board/tests/test_common.py` 拡張＋plan-closeout・PreToolのstdin/stdout fixtureテスト（runtime別）＋無限ループ防止テスト
- 停止・エスカレーション条件: Claude/Codex Hookの現行wire formatがローカルversionと公式説明で不一致／既存session-board Stopとの共存が壊れる／hooks-registryの未コミット再編差分と衝突
- 完了時に返す情報: result packet＋登録に必要な差分一覧（承認セット向け・未適用を明記）

## 計画運用ハーネスからの接続契約（2026-07-15）

- 依存元: `../../../active/2026-07-14-計画運用ハーネス検証/plans/04-PromptSubmitへの接続契約を引き継ぐ.md`。この子04（旧plans/02）が、Prompt Submit本文の実装とテストを一意に所有する。
- 注入する最小ゲート: **サクッと3条件が全YESでない、または不明なら `plan-management`。** 実装前に使い、既存planがあれば合流し、なければ対象repoの最寄りAGENTS.mdが宣言する計画箱へ起案する。
- hookの境界: UserPromptSubmitは上の入口を短く案内するだけで、`plan-triage` を実行しない。repo、AGENTS、計画箱、レビュー合否、バケット遷移を決めず、plan本文・状態も所有しない。
- 本文の唯一の生成元は引き続き `shared/session-board/common.py`。runtime別シム、event説明MD、AGENTSへ同じ注入本文をコピーしない。
- 実装着手条件（2026-07-15更新・完走スキーム対応）: `hooks-registry/` の再編差分が安定してから本体実装とテストを進める。**注入文の有効化・runtime登録・symlink・Codex再trustは実行せず承認セットへ積む**（`plan-management` の対象runtime露出が未承認の間は、Skill名を有効な実行導線として注入する文面を有効化しない）。既存5イベントのruntime別E2Eは、承認後の適用時に最終差分へ一度だけ行う。

## 方針

### A. Prompt Submit注入の更新

1. 02で固定した語彙で、初回ガイドを「既存計画確認 → planningに起案 → 指揮官がactive化 → 最終評価PASSでdone → 人間が明示確認してarchive」の5段階＋容量（active=3/paused=3/done=8/planning・archive=無制限）として短く案内する。詳細規約は正本へのポインタに留める。
2. ミラー注入は状態を推測せず、`bucketctl check` を容量の事実確認先にし、「満杯なら人間へ候補を返し自動退避しない」の境界だけを出す。
3. **レビュー方式の意識づけを注入に含める**: 計画・実装種別のミラーに「子のレビュー宣言を確認 — `一括` なら束ねてまとめて実施、後続が成果を直接使う子だけ都度」を1行で足す。
4. `finish` はセッション記録を閉じる操作でありarchiveの許可・実行ではないことを、common.py・session-start/end.md・対応AGENTSで同じ責務境界にする。自動 `git mv` をフックに足さない。

### B. PreToolガード（バケット移動の門番）

5. 計画バケットを対象にする生の `git mv`/`mv` をdenyし `bucketctl` へ誘導するPreToolUseを、runtime別の薄いシムとして `events/` に置く。対象パスを含まないコマンドは無処理で通す。拒否時は件数・上限・対象一覧・必要な人間判断を案内する（02の `check --json` を使う）。

### C. plan-closeout guard（同期忘れ・割当ずれの見張り）

6. `PLAN_RUN_MANIFEST` がある時だけ作用するStopガード: `running/implemented`→通す／`review_passed` かつ未 `synced`→継続させ `planctl apply-evaluation`/`sync-check` を要求／`synced/closed`→通す／`blocked`→通すがblockerを残す。**一括レビュー運用との整合**: 一括宣言の子はWave束ねのレビュー完了までphaseが `implemented` に留まるため、ガードは止めず、program-runのレビュー待ちキュー件数を案内するだけにする。
7. **SubagentStart**（worker起動時・Codex/Claude両runtimeの `events/subagent/` 受け口）: manifestのrole=implementerなら、割当worktree_path・branch・base_commitと実際の作業場所の一致を検査し、不一致なら編集開始前に警告して継続させる（03のTask Packet「base commitまたは作業場所が割当と違う場合はblockedで返す」の機械側の裏付け）。read-only role（explorer/reviewer）はworktree検査を省略する。既存session-boardのsub-start（🔵体数同期）とは責務を分けて共存する。
8. **SubagentStop**（worker終了時・同じく両runtime）: implementerでresult packet無し→継続、reviewerで必須評価項目無し→継続、explorerは構造化結果で通す。worktreeの削除・mergeはhookでは行わず（03のprogram-runが所有）、未mergeのworktreeが残っている事実の案内だけを返す。session-end.md・milestoneへ「planあり完了前は `planctl sync-check`」「一括レビュー待ちがN件あれば次Wave前にまとめて実施」の案内を追記する。
9. **計画日付の陳腐化検知**（2026-07-15人間指示）: session-end系の案内に「このセッションで計画の目的・子構成を大幅更新した場合は、02の `planctl rename` でフォルダ日付を最新化してから終了する」を含める。hookは検知と案内だけを行い、rename自体は実行しない。
10. 具体の配置（events/のフォルダ名・shared/plan-closeout/の構成）・登録表差分（settings.json／codex/hooks.json）・runtimeイベント語彙の対応は、`../references/2026-07-15-hooks設計調査.md`（Codex調査・2026-07-15）の設計を正として実装し、references/の実runtime仕様と食い違う場合は実機確認を優先する。
8. 無限ループ防止（`stop_hook_active`・連続block上限・失敗時fail-open）とruntime別stdout JSON契約テストを必須にする。本体・fixture・E2Eまで作り、登録差分は承認セットへ。

## 完了条件（レビュー項目）

- [x] 初回・ミラー注入の**候補文**（common.pyが生成）に planning→active→done→archive の責務分離、容量案内、レビュー方式（一括/都度）の1行、`bucketctl check` への誘導があり、旧 `done=未評価` や自動archiveを示す文言が残っていないことをテストで検証できる。本文の生成元はcommon.pyのみで、runtime別シムに本文コピーを増やしていない。候補文の実注入への接続（有効化）は人間承認後の適用ラウンドで行い、**この子の完走ラインは候補文＋テスト＋登録差分まで**（実行契約の未有効化と両立させる。評価01の指摘で明確化・2026-07-15）。
- [x] サクッと3条件が全YESでない、または不明な入力を `plan-management` へ案内し、hookがrepo・計画箱・レビュー合否・バケット遷移を決めないことを、**候補文とそのテスト**で確認できる（実注入での確認は承認後の適用ラウンドで再評価）。
- [x] PreToolガードが計画バケットへの生の `git mv`/`mv` を拒否して `bucketctl` へ誘導し、対象パスを含まない通常コマンドと `bucketctl` 自身を拒否しないことをruntime別stdin fixtureで検証できる。
- [x] Stopガードが manifest不在／running／review_passed未同期／synced／blocked の5ケースで宣言どおり動き、review_passed未同期だけが継続を要求する。一括宣言の子（implemented滞留）を止めない。
- [x] SubagentStartが implementerの割当ずれ（worktree_path・branch・base_commitの不一致）を編集開始前に検出し、read-only roleでは省略する。SubagentStopが implementerのresult欠落・reviewerの評価欠落を検出する。どちらもCodex/Claude両方のstdin fixtureで検証でき、ガードは計画本文・チェックボックス・バケット・worktreeを一切変更しない（実行前後の状態不変テスト）。
- [x] `stop_hook_active`・連続block上限・失敗時fail-openの防止テストと、既存session-board Stopとの共存テストがあり、旧 `hooks/` 構造を復活させていない。
- [x] `finish`≠archive承認が common.py・session-start/end・README・milestoneの対象箇所で一致し、session-boardの所有境界が変わっていない。
- [x] runtime登録・settings変更・symlink・再trust・注入文の有効化が未適用のまま、適用に必要な差分一覧（既存5イベントE2E＋Codex再trustの人間操作を含む）が承認セットに揃っている。

## 実装結果

- 2026-07-15 評価02で全PASS（8/8・修正01の4項目対応を実測確認）。実装=task/pf04（base e9a6e16 → 81772b2・codex terra）。runtime登録・注入文有効化は未適用（登録差分=hooks-registry/registration-diff-04-plan-closeout.md・適用は承認セット確認後）。統合branchへのmergeは02・03の評価後にWave順で実施。
