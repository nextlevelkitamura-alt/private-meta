分類: repo ／ 種別: 既存改善 ／ 形態: program ／ 規模: フル

# Focusmap自動処理統合 program

## 目的

デイリーの目標・セッション・完了履歴と、Global / Focusmap固有のhook・loop・常駐serviceを、Focusmapの「AI運用ハブ」で一望できるようにする。同時に、自動処理の正本・発火・writer・失敗・停止・承認を共通契約で管理し、古い設定や二重writerが見えないまま動く状態をなくす。

一本化するのは **管理画面と契約** であり、実装正本をFocusmapへ物理移動することではない。

- 当日デイリー / session-board: ローカルMDが正本。
- Global hook / loop: `personal-os/AIエージェント基盤/` が正本。
- Focusmap専用hook / service / agent loop: `projects/active/focusmap/` が正本。
- Turso: 再生成可能な表示ミラー / 状態snapshot。ローカルpath・host・process詳細は送らない。
- Focusmap: 閲覧・異常確認・承認の窓口。任意shellやlaunchctlをWebから直接実行しない。

## 元のやりたいこと

2026-07-11の人間依頼。第一軸は、デイリーやセッション、自動処理一覧をFocusmap UIへ集約すること。第二軸は、hook / loop / agent内部巡回をscopeごとに分散配置しながら、共通ルール・folder・manifest・検証で管理できるようにすること。2〜3サブエージェントで現状を詳細調査し、その結果から計画を作る。

## 現状調査の結論

### 既に使えるもの

- Global loopは4本（`board-reconcile` / `board-sweep` / `daily-notion-sync` / `session-record-prune`）がloaded。`loop.md`、plist、scripts、一覧正本、`verify.py`まで揃っている。
- Global hookはsession-board 1機構。Claude / Codexの薄いshimから共通本体を呼び、MD確定後にTursoへベストエフォート送信する。
- Focusmapの `/dashboard/workspace/sessions` とTurso読取層は既にmainへ存在する。既存 `projects/active/focusmap/plans/active/2026-07-11-セッション時間ダッシュボード/program.md` を「今日」画面の実行計画として再利用する。
- FocusmapにはTurso snapshot / heartbeat / activityと、`focusmap-agent` のheartbeat・claim・command・Codex monitorの実装がある。

### 先に塞ぐリスク

1. FocusmapのClaude / Codex Stop hookが `git add -A` でrepo全差分を自動commitし、Global規約とrepo規約に反する。
2. main push禁止hookの文言が、現在の「明示依頼時はmain push可」というrepo規約と矛盾する。
3. `board-sweep` にrun全体のlockがなく、並行実行で同じ行の `[auto]` 完了ログが重複し得る。
4. Turso spoolはevents / logsだけで、`sessions` のupsert / delete、reconcile、goal-addの欠測を修復しない。Focusmapに幽霊runや失敗した目標追加が成功表示され得る。
5. runtime hookの10秒timeoutに対し、複数の同期Turso送信とspool replayが連なると時間超過・部分反映の余地がある。
6. Focusmapの実機は旧 `com.focusmap.codex-app-server` だけloadedで、現行設計のofficial agent / app-serverは停止中。コード上の現行と実動状態がずれている。
7. 旧 `task-runner.ts` と現行 `focusmap-agent` の責務がまだ重複し、旧runnerを再導入できる導線も残る。
8. hook側にはloop側と同等の一覧正本・manifest・verifyがなく、文書とruntime登録にドリフトがある。

## 全体方針

### 軸A: Focusmapへ管理画面を集約

- 「今日」: 既存sessions画面を使い、目標・稼働・完了・待ちを表示する。
- 「自動処理」: hook / loop / serviceの意図状態、実機状態、最終成功 / 失敗、遅延、ownerを論理IDで表示する。
- 「異常」: stale、意図と実機の不一致、mirror欠測、未解決の完了判定を集約する。
- 「接続」: Mac agent、Codex app-server、Turso、runtime露出の状態を表示する。
- 初期はread-only。操作窓口は別子計画でdefault OFFから始める。

### 軸B: 分散実装を共通契約で管理

- Globalとrepo-localの実装を無理に同じfolderへ移さない。
- 全unitへ共通manifest項目を要求し、一覧はmanifestから生成する。
- `意図状態` と `実機状態` を分離する。設定上稼働中でもprocessが無ければ不一致として表示する。
- 正本 / mirror / UI / writerを明記し、1状態に複数writerを作らない。
- runtime登録・plist・entrypoint・文書・実機状態をローカルverifyで照合し、Cloudへは公開allowlist済みの要約だけを送る。
- 変更・停止・再開・DB schema・本番反映は人間ゲートを保つ。

## 目標データフロー

```text
正本実装・設定
  Global hooks / loops ─┐
  Focusmap local units ─┼─ manifest + verify(JSON) ─ snapshot ─┐
  launchd / runtime ────┘                                      │
                                                                 ├─ Focusmap AI運用ハブ
MD session-board ─ board.py ─ Turso sessions/events/logs ───────┘

Focusmapの操作要求 ─ intent（固定unit ID・固定action）
                  └─ local作用器が承認・冪等性を確認して実行
                     ※ Webから任意shell / launchctlは実行しない
```

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  現役自動処理台帳と責務境界 … 計画
    次: 監査結果を初期inventoryへ落とし、人間がscopeとownerを確認
    場所: plans/01-現役自動処理台帳と責務境界.md ／ 依存: ―

- [ ] 02  Focusmap今日UI統合 … 計画
    次: 既存sessions programの実装済み / 未実装を正し、addGoalを安全化完了までOFFにする
    場所: plans/02-Focusmap今日UI統合.md ／ 依存: 01, 09

- [ ] 03  自動処理管理UI … 企画
    次: 07の公開snapshot schemaが確定した後、read-only UIを設計
    場所: plans/03-自動処理管理UI.md ／ 依存: 02, 07, 08, 09

- [ ] 04  Hooks / Loopsガバナンス標準 … 計画
    次: Global共通contract、hook一覧、loop schema、verify契約を人間確認
    場所: plans/04-Hooks-Loopsガバナンス標準.md ／ 依存: 01

- [ ] 05  段階移行と安全化 … 計画
    次: Focusmap危険Stop hookとagent / legacy runnerの移行順を人間確認
    場所: plans/05-段階移行と安全化.md ／ 依存: 01（04と並行可）

- [ ] 06  安全な操作窓口 … 企画
    次: read-only UIの観察後、許可actionと人間承認手順を決める
    場所: plans/06-安全な操作窓口.md ／ 依存: 03, 04, 05, 07, 08, 09

- [ ] 07  状態snapshot基盤 … 企画
    次: 公開allowlist・認可・保持・publisher / retry / stale契約を設計
    場所: plans/07-状態snapshot基盤.md ／ 依存: 04, 08, 09

- [ ] 08  Focusmapガバナンス適用 … 計画
    次: repo-local manifest / registry / verifyの置き場と対象unitを確定
    場所: plans/08-Focusmapガバナンス適用.md ／ 依存: 01, 04

- [ ] 09  Global整合保証 … 計画
    次: board-sweep冪等化とMD / Turso parity修復を別commit境界で設計
    場所: plans/09-Global整合保証.md ／ 依存: 01, 04

## 実行順

1. 01で現役・停止・legacy・正本・writerを確定する。
2. 04（Global契約）と05（Focusmap安全化）を別repoレーンで並行する。
3. 04の契約確定後、08（Focusmap適用）と09（Global整合保証）を別repoレーンで進める。
4. 09のparity修復後に02の「今日」をread-onlyで統合する。既存addGoalは安全化までOFFにする。
5. 04 / 08 / 09のverify出力が揃った後、07で公開snapshot基盤を作る。
6. 03のread-only自動処理UIをつなぎ、最低1週間観察する。
7. 人間が必要と判断した操作だけ06で開放する。

## 人間ゲート

- hook追加・削除・挙動変更、runtime登録 / trust変更。
- launchd load / unload、発火条件変更。
- DB schema、token / env、snapshot送信先の変更。
- snapshot publisherの有効化、Cloudへ公開するfield allowlist・認可・保持期間の変更。
- Focusmap main push / Cloud Run deploy。
- 自動処理の停止 / 再開、旧runner / route / Notion経路の廃止。
- 操作窓口の有効化、許可actionの追加。
- MD正本を別のstoreへ変更する判断。

## ロールバック原則

- 子計画ごとに独立commitし、UIはfeature flagで切れるようにする。
- snapshot失敗時は前回値を `stale` と表示し、成功に見せない。
- 操作面はdefault OFF。異常時はUI / intent consumerをOFFにし、**安全なread-only baseline**（危険auto-commit無効・旧runner停止・MD継続）へ戻す。
- MD / session-boardと既存sessions routeは観察期間中維持する。
- DB変更は追加型から始め、破壊migrationを初期段階で行わない。
- 削除・移動・alias終了は観察後の別人間ゲートにする。

## 完了条件（レビュー項目）

- [ ] `plans/01-現役自動処理台帳と責務境界.md` の対象inventoryで、現役・停止・legacyの全unitが重複なく列挙され、実体・登録先・entrypoint・停止方法が解決する。
- [ ] Global hooks / loopsとFocusmap repo-local unitの全manifestが、それぞれのverifyでPASSする。
- [ ] Cloud snapshotが論理unit IDと公開allowlist項目だけを持ち、絶対path・host名・PID・runtime登録path・log/state pathを含まない。
- [ ] snapshot APIが対象user / tenant以外から読めず、保持期間とpayload上限を超えない。
- [ ] MD正本 → Tursoミラー → Focusmap表示の境界が逆転せず、UIがMD / launchd / runtime設定を直接編集しない。
- [ ] Focusmapの「今日」「自動処理」「異常」「接続」で、意図状態 / 実機状態 / stale / 最終成功 / 最終失敗を区別して読める。
- [ ] `board-sweep`の二重起動で同じsession keyの自動完了が重複せず、条件不成立 / unknown / LLM失敗では0件変更になる。
- [ ] session finish / reconcile / goal-addの送信失敗が再試行または明示エラーになり、Focusmapで幽霊runや偽成功として表示されない。
- [ ] Focusmap Stop hookに `git add -A` がなく、push guard・runtime設定が現行AGENTSと一致する。
- [ ] 旧task-runnerの通常起動導線と現行agentの責務重複が解消され、意図したlabel / processだけが実機で動く。
- [ ] 未承認action、未知unit ID、任意commandは操作窓口から1件も実行できない。
- [ ] secret / token / credential値がmanifest、snapshot、UI、ログ、commitへ0件である。
- [ ] feature flag OFFで既存session-board、Focusmap sessions画面、Global 4 loopsに回帰がない。
- [ ] 全子計画の最終 `評価NN.md` が全PASSし、ロールバック手順を実測している。

## 計画レビュー

- 2026-07-11 初回レビュー: FAIL。snapshot担当不在、addGoalとread-onlyの矛盾、contract正本二重化、repo境界混在、Cloud情報保護不足、危険な旧状態へのrollback余地を検出。
- 修正: 子07〜09を追加し、Global標準 / Focusmap適用 / Focusmap安全化 / Global整合保証 / snapshot publisherを別repo・別責務へ分離。addGoalを子09完了までOFF、安全なread-only baselineへのrollbackに固定。
- 再レビュー: **PASS**。依存順、addGoal OFF、snapshot担当 / 情報保護、contract単一正本、repo境界、安全baseline rollback、人間ゲートに重大FAILなし。

## 関連（正本を複製せず参照）

- Focusmap今日UI: `/Users/kitamuranaohiro/Private/projects/active/focusmap/plans/active/2026-07-11-セッション時間ダッシュボード/program.md`
- Focusmap agent一本化: `projects/active/focusmap/docs/ai/plans/active/20260607-codex-mac-agent-unification.md`
- task-runner退役案: `projects/active/focusmap/docs/ai/plans/active/20260623-task-runner-retirement-agent-single-path.md`（監査時未追跡。正本化判断が必要）
- Global hook再編: `../2026-07-06-hooks-registry再編とsymlink露出/plan.md`
- Turso mirror: `../2026-07-08-デイリーTurso表反映/plan.md`
- 自動完了: `../2026-07-09-デイリー運用刷新/plans/05-停止行自動判定sweep.md`
- 時間計測 / 二重鍵: `../2026-07-10-デイリーボード改善/plans/03-Turso時間計測と同期安定化.md`、`04-board-sweep二重鍵化とLLM接続.md`
- session-board責務分離: `../2026-07-11-session-board出力分離/plan.md`
