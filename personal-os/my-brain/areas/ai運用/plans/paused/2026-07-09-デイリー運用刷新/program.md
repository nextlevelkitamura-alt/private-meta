分類: 横断 ／ 種別: 既存改善 ／ 形態: program
規模: フル
優先: ◎

# デイリー運用刷新（Terra並列実装）

## 目的

Dailyを1日1枚・work/privateの2レーンで運用し、Daily start（共通開始）→ Work end（従事仕事だけ中間締め）→ Daily end（全日封印）の3儀式を安定運転する。3年→年間→月間→週→Dailyを接続し、月末レビューと翌月反映までを人間確認つきで回せる状態にする。

この `program.md` は、Terra並列実装の全体地図・時系列・人間ゲート・統合判定だけを持つ。各実装agentへ渡す必読正本、編集許可範囲、実装内容、自己テストは `plans/NN-*.md` を正本とし、workerは原則としてこのprogramを読まない。

## Terra並列実装の役割

- **実装worker**: `gpt-5.6-terra`。各自が独立worktreeで自分の子planと編集先の最寄り `AGENTS.md` だけを読み、許可されたファイルだけを変更する。headless実行ではなく、人間と統合担当から見えるCodex worktree threadまたは同等の可視ペインで動かす。
- **統合担当**: Plan 09の担当。唯一 `program.md` と全子planを読み、merge順、共有ファイル、Checkpoint、最終テストを所有する。
- **テスト担当**: コードを直さず、Plan 09に定義したGate A / Gate B / Final Gateをまとめて実行する。
- **レビュー担当**: Terraとは別系統のClaude系を推奨。コードを直さず、Checkpoint単位と全実装後の統合diffを評価する。
- **人間**: 目標本文、モデル例外、active昇格、正本変更を伴う改名・削除、runtime露出、launchd load、main反映、push、1週間運用の合格を決める。

> **今回限定のレビュー時機例外**: ユーザー指定により、各worker完了時には自己テストと完了報告だけを行い、正式レビューでは止めない。正式テストと異系統レビューは同一Waveを統合したCheckpointと全実装後へ集約する。FAIL時は最小の所有planへ差し戻すが、修正後は該当Checkpoint全体を再実行する。

## 実装できるもの／人間なしでは実装できないもの

### Terraが実装できるもの

- 8節Dailyテンプレと生成経路の一本化、現役path参照の修正。
- 業務行CRUD、`lane: work|private`、`work_closed`、`closed`、封印後の翌日回送。
- Daily start / Work end / Daily end の対話Skillと、09:50以降の起動候補を作る未ロードの自動化部品。
- 当月＋次月＋翌々月の月間計画ensure、月末レビュー、論理archive、直近7日予定。
- 業務進捗推定、計画slug照合、承認前は無変更・承認後だけ正本と履歴を更新する処理。
- 既存board-sweepと手動inbox-triageの互換テスト、古い参照pathの修正案。
- sandbox、fixture、時刻注入による決定的テスト。実時刻09:50や1週間経過を待たずに機械検証する。

### 人間確認がないと進めないもの

- `gpt-5.6-terra` を実装workerにする今回のモデル例外と、Claude系を正式reviewerにする裁定の正本反映。
- 3年・2026年間・当月の目標本文、固定slug、達成条件。AIはドラフトまで。
- `standup` / `morning-routine` の改名・縮退・削除。
- このpaused programのactive昇格と、未コミットの計画一式だけを範囲指定commitしてTerra worktreeの共通基点を作ること。
- runtime skill露出、hook trust、launchdのload/unload、Desktop scheduled task登録、main反映、worktree削除、push。
- 実機1週間の運用結果を合格と判定すること。

## 時系列とテスト・レビューゲート

### Gate 0 — 人間裁定と共通基点

1. Terra実装・Claude系reviewer・Checkpoint一括レビューの今回限定例外を確定する。
2. 年間/月間slug、Skill名、Work end / Daily endの通知方針を確定する。未確定の目標本文はfixture実装と分離して後から確定してよい。
3. 本program一式だけをpath指定でcommitし、他の未コミット変更を混ぜない共通基点を作る。
4. 実行GOならprogramを `paused` から `active` へ移す。移動・commitは人間ゲート。
5. 現行baseline（session-board 263 checks＋board-sweep 31 checks＝294 checks、loop verify、program lint）を記録する。

### Wave 1 — 4体のTerraを並列実装

- **Terra-01 / Plan 01**: ゴール構造・8節テンプレ。
- **Terra-02 / Plan 02**: session-boardの業務・lane・封印コア。
- **Terra-07 / Plan 07**: Monthly Reset、3か月ensure、月末レビュー、論理archive。
- **Terra-08 / Plan 08**: 3年→年→月→週→Dailyの照合と承認transaction。

4体は同じ基点から開始し、各planの編集許可範囲を越えない。worker完了時は自己テスト結果とcommit hashを統合担当へ渡すだけで、個別正式レビューはしない。

### Checkpoint A — 土台の統合テスト＋まとめレビュー

統合順は Plan 01 → 02 → 07 → 08。既存294 checks、8節テンプレ完全一致、2回ensureの2回目diffなし、業務CRUD冪等、work/private分離、`work_closed`ではprivate継続可、`closed`後だけ翌日回送、3か月月間ensure、承認前の計画本文無変更をまとめて検証する。PASS後だけWave 2を開始する。

### Wave 2 — 2体のTerraを並列実装

- **Terra-03 / Plan 03**: Daily start / Work end / Daily end と09:50起動候補。
- **Terra-04 / Plan 04**: 進捗推定、lock、debounce、LLM失敗時の無変更。

Plan 05（board-sweep）とPlan 06（inbox-triage）は新規実装レーンを立てず、Plan 09が既存稼働の回帰対象として扱う。

### Checkpoint B — 1日と月跨ぎの合成E2E＋まとめレビュー

fixture上で「未封印前日 → Daily start → work/private実行 → Work end → private継続 → Daily end → 遅着翌日回送」を通す。月末を跨ぐ直近7日、月間3枚だけの生成、計画変更の承認前後diff、進捗推定の冪等・並行lock・LLM失敗、board-sweep / inbox-triage回帰、plist構文をまとめて検証する。PASS後だけWave 3を開始する。

### Wave 3 — Plan 09が直列統合

Plan 09だけが共有README / AGENTS / catalog / loop overview / 旧Skill参照 / trigger配線を更新し、古い `plans/active/...` path、旧儀式名、二重テンプレ、未実装参照を整理する。runtime symlink、trust、launchd loadはまだ実行しない。

### Final Gate — 全実装後のテストと正式レビュー

1. clean worktreeで既存294 checks、Gate A / B全suite、`git diff --check`、program lint、loop verify、stale path/name scan、secret・追跡log混入scanを実行する。
2. 全テストPASS後にだけ、異系統reviewerがprogram、全子plan、統合diff、Checkpoint結果を一括レビューする。レビュー担当はコードを直さない。
3. FAILなら統合担当がprogram直下に `評価01.md` / `修正01.md` を作り、最小の所有planへ差し戻す。修正後は失敗箇所だけでなくFinal Gate全体を再実行する。差し戻し上限2回。
4. PASS後に人間がruntime露出・trust・launchd load・main反映を承認する。
5. 安全なcanary後に1週間実運用し、最後に人間がprogram完了を判定する。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  土台（ゴール構造と8節テンプレ） … 人間確認（構造移行済み・runtime生成との断線解消が残る）
    並列: 可 ／ レビュー: 一括
    次: Gate 0後、Terra-01が許可範囲だけを実装しCheckpoint Aへ渡す
    場所: plans/01-土台構成とテンプレ.md ／ 依存: Gate 0
- [ ] 02  業務レイヤ（Dailyコア） … 計画（現在時刻注入のみ実装済み）
    並列: 可 ／ レビュー: 一括
    次: Terra-02が業務CRUD・lane・work_closed/closed・翌日回送を実装
    場所: plans/02-業務レイヤboard拡張.md ／ 依存: Gate 0
- [ ] 03  3儀式と起動候補 … 計画（standup骨格のみ）
    並列: 可 ／ レビュー: 一括
    次: Checkpoint A PASS後、Terra-03が3Skillと未ロード自動化部品を実装
    場所: plans/03-儀式の自動実行.md ／ 依存: Checkpoint A, 01, 02, 07, 08
- [ ] 04  進捗推定エンジン … 計画
    並列: 可 ／ レビュー: 一括
    次: Checkpoint A PASS後、Terra-04が確定済みCLIを使って独立実装
    場所: plans/04-進捗推定エンジン.md ／ 依存: Checkpoint A, 02
- [ ] 05  board-sweep互換確認 … 人間確認（実装・60分毎稼働・31 tests PASS。新規実装なし）
    並列: 可 ／ レビュー: 一括
    次: Plan 09がCheckpoint A/B/Finalの回帰対象に含め、古い計画pathだけ整理
    場所: plans/05-停止行自動判定sweep.md ／ 依存: 02, 09
- [ ] 06  inbox-triage互換確認 … 人間確認（手動指定経路は実装済み。自動巡回は廃止済み）
    並列: 可 ／ レビュー: 一括
    次: Plan 09が8節Dailyでの手動起案回帰と古い計画pathを確認
    場所: plans/06-インボックス即時起案.md ／ 依存: 01, 09
- [ ] 07  月次ライフサイクル … 計画（設計済み・未実装）
    並列: 可 ／ レビュー: 一括
    次: Terra-07がmonthly-reset Skillとfixtureを独立実装
    場所: plans/07-日次ライフサイクルと未来予定.md ／ 依存: Gate 0
- [ ] 08  ゴール照合と変更反映 … 計画（設計済み・未実装）
    並列: 可 ／ レビュー: 一括
    次: Terra-08がgoal-alignment Skillと承認transaction fixtureを独立実装
    場所: plans/08-計画照合と変更反映.md ／ 依存: Gate 0
- [ ] 09  統合テストと最終レビュー … 計画
    並列: 不可 ／ レビュー: 一括
    次: Gate 0から統合担当がmerge順・Checkpoint・共有ファイル・Final Gateを所有
    場所: plans/09-統合テストと最終レビュー.md ／ 依存: 01〜08

## 完了条件（レビュー項目）

- [ ] `plans/01-*.md`〜`plans/09-*.md` のレビュー項目が全て満たされ、programの子計画マップが全て `[x] ... 完了` になっている
- [ ] workerごとの正式レビューでは停止せず、Checkpoint A / B / Final Gateの結果と一括レビュー記録が残っている
- [ ] Daily start / Work end / Daily endが1週間、work/private誤締め・8節消失・未封印持越漏れ・既存テスト赤なしで運用されている
- [ ] 当日Dailyから今日の業務、進捗と根拠、動いているエージェント、終わったこと、明日へが1枚で読める
- [ ] 当月＋次月＋翌々月の月間計画、直近7日、月末レビュー、論理archiveが二重正本なしで動く
- [ ] 3年・年間・月間・週・Dailyの接続と、人間承認前後の変更範囲がfixtureと実ファイルで一致する
- [ ] goal / session-board / Skill / loop / registryの正本pathにドリフトがなく、runtime露出・launchd状態が人間承認内容と一致する

## 関連

- 実装正本: `personal-os/AIエージェント基盤/`
- ゴール正本: `personal-os/my-brain/ゴール/`
- 作業パイプライン: `personal-os/説明書/運用契約.md`
- モデル正本: `personal-os/AIエージェント基盤/AIモデル一覧.md`（Terra例外はGate 0で正本反映）
- 並列実装の既存計画: `../../planning/2026-07-08-並列実装フロー/plan.md`
- 人間向け説明: `explain/program.html`
