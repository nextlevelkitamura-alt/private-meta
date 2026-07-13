# session-board — セッション宣言型ボードの機構

当日デイリー2節ボード（`## 動いているエージェント` / `## 終わったこと`）を駆動する一式。
**skillは廃止**（2026-07-05）。**registry再編済み**（2026-07-06）。**2列ボード再設計**（2026-07-08・設計は
`my-brain/areas/ai運用/plans/active/2026-07-08-計画実行フロー統一/plans/01-session-board責務再設計.md`）。
手順md・エンジン・受け口すべて正本はこの repo（runtime へは symlink 窓で露出）。

境界原則: **Python＝枠と機械処理**（速く確実に・記録を落とさない）／**AI＝意味づけ**（種別・目標・今・置き場の判断）。
hook は AI が考える前に同期実行されるため、hook 側に意味の判断を入れない。

## 所有境界と計画ルーティング

- session-boardが所有するのは、現在のsession状態とDaily「終わったこと」の時刻付き実行ログ。plan本文、planのバケット状態、
  program子計画マップは所有・更新しない。Dailyの計画列と完了親行は参照・実行記録であり、計画正本の代替ではない。
- 計画は `repo-registry/repo概要.md` で担当repoだけを解決し、対象repoの最寄り `AGENTS.md` で領域・プロジェクト・
  計画箱を解決し、その宣言範囲で既存planを先に検索する。既存があれば合流し、無ければ宣言された箱へ作る。
  repo未登録、AGENTSなし、計画箱未宣言・複数候補、既存plan競合では、root `plans/` を推定・作成せず人間確認で止める。
- Private起点で対象repoへ書き込む場合は、canonical repo path・plan参照・worktree cwd・許可path・開始時Git snapshotを渡し、
  対象repoをrootとする新しい可視sessionへhandoffする。session IDの移管・reparentはしない。新sessionの登録と対象repo
  `AGENTS.md` の読込みを確認後、Private行は引継ぎ完了としてfinishする。調整役として残す場合だけ役割・終了責任付きで2行併存する。

## 内部構成と確定順

```text
hook / loop → common.py → board.py → md/store.py → turso/{store,spool}.py
                                      MD確定・flock解放   ベストエフォート
```

- `board.py`: CLI・コマンド調停と、既存外部向けの互換re-export。
- `md/store.py`: デイリーpath、parse・描画、生存照合、flock、原子的置換。HTTP/keychainへ依存しない。
- `turso/store.py`: token取得、SQL builder、HTTP送信。デイリーMarkdownを直接書き換えない。
- `turso/spool.py`: events/logsだけの失敗スプールと再送。
- MD用hookとTurso用hookは分けない。1回のコマンドで**MD確定→flock解放→Turso送信**の順を守り、Turso失敗でMDを巻き戻さない。

## 行フォーマット v3（2026-07-10〜・入れ子ボード）

「動いているエージェント」節は、goals-summary マーカー内に**目標→セッション→サブ**の入れ子で
機械再描画される（`board.py render_body`・手で編集しない）:

```
<!-- goals-summary -->
### 本日の目標
- 🟢 <目標>（N件）
  - 🟢 HH:MM | <目標> | 今:<今> | <repo> | <種別> | <runtime/model> | 計画:<計画> <!-- s:KEY sub:N -->
    ↳ 🔵 サブN体
<!-- /goals-summary -->
```

- **目標親行**（`- <代表絵文字> <目標>［（N件）］`）: 旧サマリ行の昇格。代表絵文字＝グループ内最良状態
  （🟢>🔵>⏸）。（N件）は2件以上のみ。目標未記入（`?`）グループのラベルは「目標未記入」。
- **セッション行**（2字インデント・列構成は v2.2 と同じ）。**↳サブ行**（4字インデント・体数のみ・
  ラベル無し）は `sub>0` の行の直下に自動描画される派生行。
- **状態**（セッション行頭・絵文字3値）: 🟢動作中／⏸停止・確認待ち／🔵サブ稼働中。
- **目標**: 達成したらこのセッションを閉じられる1行（〜30字）。**AIが記入**（未記入は `?`）。
- **今**: いま着手している一歩（〜20字）。**AIが記入**。初回だけUPSフックがプロンプト先頭24字を仮置きし、以降Pythonは上書きしない。
- **repo**: フックが機械記入（cwd の git トップ）。
- **種別**: 5種（下記）。フックは `その他` で仮置きし、AIが正す。
- **runtime/model**: runtime（claude/codex）はフックが機械確定して `claude/?` を仮置き、モデル名はAIが自己申告で正す（例 `claude/fable5`）。
- **計画**（末尾・`計画:<値>`）: この作業の拠り所（実装・レビュー）／これから置く先（計画）。**AIが記入**（未記入は `?`）。値は3種で、**この節が語彙の正本**:
  - `?` … 未記入（催促対象）。フックの既定値。
  - `なし` … 構造3条件（①1〜2ファイル ②容易に戻せる ③人間ゲート無し）を全部満たすサクッと作業の宣言。**正当な最終値**（未記入ではない）。
  - **短縮参照** … repo計画は `企画名[/NN]`、area計画は `ai運用:企画名[/NN]`（子計画番号 `NN` は任意）。**バケットは書かない**（フォルダが状態。必要時はrepo列＋対象repo `AGENTS.md`＋既存plan検索から正本pathを解決する）。
- **サブ体数**（末尾コメント `<!-- s:KEY sub:N -->`・sub欠落=0の後方互換な任意グループ）: 稼働中の
  サブエージェント体数。`sub-start`/`sub-end`（SubagentStart/Stop 受け口）が機械増減し、
  reconcile の🔵→⏸降格で0クリア。**AIが手で書かない**（sub=0 のとき `sub:` は書かれない）。
- **読み取り互換**: v2.2（フラット・計画列あり・〜2026-07-10）／v2（計画列なし・`計画:?` を補って読む）／
  v1（旧1要約列・状態語末尾・〜2026-07-08）を読める。書き込みは常に v3（どの書き込みでも自然移行）。
- 行の並びは **目標グループ（生存優先）→ 状態 → 時刻**。同じ目的のセッションが親行の下に隣接する。
  再描画はマーカー内の派生行（見出し・親行・↳）だけを作り直し、耐久行（`<!-- s:KEY -->`）と
  手書きメモ・空行は保全する。

## 種別（5種・この節が定義の正本）

- **計画** … 何をやるか・どう進めるかを決めて文書に落とす。成果物＝plan.md / program.md。
- **実装** … コード・設定・文書を変更して動く状態にする。成果物＝diff・commit。
- **リサーチ** … 調べて分かったことをまとめる。何も変更しない。成果物＝調査メモ・回答。
- **レビュー** … 既存の成果物を評価して指摘を返す。自分では直さない。成果物＝指摘・判定。
- **その他** … 上のどれでもない・まだ分からない。
- 運用原則: **迷ったらその他でよく、分かった時点で `update --type` で直すのが正常**（直しは失敗ではない）。
  定義は「一言＋成果物」以上に厚くしない（定義への固執で誤分類を生まないため）。境界例はここに追記して育てる。
  - 境界例: 「調べてから直して」＝実装（変更が成果物だから。調査はその途中工程）。

## 動作モデル（①開始通知→②初回プロンプトで枠登録＋二段注入→③AIが意味づけ→④機械flip）

1. **開始通知**（SessionStart / `session-start.py`）: reconcile ＋ キー通知1行だけ注入。
   **枠（行）はここでは登録しない**（2026-07-08〜）。プロンプトを持たない/ガードで弾かれる補助セッションが
   🟢の幽霊枠として残るのを防ぐため、枠登録を②の初回プロンプトへ一本化した。旧設計の手順md全文注入は廃止。
2. **枠登録＋機械処理＋二段注入**（UserPromptSubmit / `prompt-register.py`）: 未登録なら枠を `add`
   （時刻・🟢・repo・runtime/?・**既存行は上書きしない**冪等＝**枠登録の主経路**）／⏸→🟢復帰／
   「今」未記入なら先頭24字を初回だけ仮置き。注入は**目標未記入=フルガイド**（updateコマンド・種別5定義・
   既存目標一覧と合流規約・計画チェーン）／**記入済み=2〜3行ミラー**（現在行＋ズレ回収の催促。計画種別のみ置き場1行追加）。
   ミラーが「今」の書き忘れ回収網を兼ねる。注入文の生成は `common.py`（動的要素があるためmdでなくコード側）。
3. **意味づけ**（AI・応答ターン）: `update --type --goal --now --model` で行を正す。
   既存目標と同じ目的なら**文言をそのままコピーして合流**（親名=目標名で成果が1親に集まる）。
4. **状態flip**（Stop / `session-end.py`）: run のとき⏸へ機械flip＋reconcile。**ブロックしない**。
5. **節目確認**（Stop / prompt型 `../../claude/milestone/session-board-milestone.md`・**Claude専用**）:
   大目標達成＋満足の気配でのみ `session-end.md` の完了手順を促す。
6. **入れ子記録**: 節目ごとに `log`、完了は人間確認後に `finish`。「終わったこと」節は**時系列（上→下＝古→新）**で、
   追記は常に末尾方向: 新しいrepo見出し＝節末尾・新しい親＝repoブロック末尾・新しい子＝親の子リスト末尾
   （複数 `--entry` も記載順のまま・2026-07-11〜。それ以前の板は最新が上のまま＝過去分の並べ替え変換はしない）。
   子には**所要時間 `(+Nm)` を自動付与**（基準＝同じ親の直前＝**最後**の子 → 無ければセッション行の開始時刻。
   日跨ぎは+24h補正。AIが所要を推測で書かない）。
   行の計画値が参照（`?`/`なし` 以外）なら、親行末尾に `‹計画: <値>›` を**自動転記**（Pythonが運ぶ＝AIの追加作業ゼロ。
   既に `‹計画:` を含む親行には付けない＝先勝ち・重複禁止）。

## board.py コマンド

```
board.py add    --key K --repo R [--type T] [--goal G] [--now N] [--who W] [--time HH:MM]
                                   # 既存行があれば何もしない（枠のみ）
board.py update --key K [--repo R] [--type T] [--goal G] [--now N] [--model M] [--who W]
                                   # --summary は --goal の別名（旧互換）。--model は who のモデル部だけ置換
board.py flip   --key K --state run|wait|sub       # 手動フォールバック（サブの自動増減は sub-start/sub-end）
board.py sub-start --key K         # サブ体数+1・🔵へ（SubagentStart 受け口が呼ぶ・行が無ければ何もしない）
board.py sub-end   --key K         # サブ体数-1（0でクランプ）・0になったら🔵→🟢（SubagentStop 受け口が呼ぶ）
board.py log    --key K --repo R --parent P --entry E [--entry E ...]   # 時刻・(+Nm) 自動付与
board.py finish --key K --repo R --parent P [--entry E ...]             # 自行削除＋子追記
board.py reconcile                 # 🟢/🔵を実体照合し沈黙(🟢≥10分/🔵≥30分)を⏸／実体皆無の枠は開始15分超で⏸＋整列（--key不要）
board.py check  --key K            # missing|run|wait|sub
board.py show   --key K            # state/goal/now/type/repo/who のタブ区切り（無ければ missing）
board.py goals                     # 現在の目標一覧（重複なし・未記入除外・表示順）
board.py goal-add --name "<目標>" [--date YYYY-MM-DD] [--source chat]  # inboxへ目標宣言（md無変更）
```

## 状態（3値）

- 🟢 **動作中**（run）… 自分が処理中
- 🔵 **サブ稼働中**（sub）… バックグラウンドのサブエージェント待ち。**Stopで⏸にならず維持**され、
  プロンプト送信でも🟢に戻さない。サブの開始・終了は SubagentStart/SubagentStop 受け口が
  `sub-start`/`sub-end` で体数ごと自動増減（Codex=登録済み・Claude=受け口あり・登録は下のスニペット）。
  `flip --state sub/run` は手動フォールバック。
- ⏸ **停止・確認待ち**（wait）… 手が空いた。次プロンプトで🟢復帰。

`session-end.py`（Stop）は `run` のときだけ⏸へflip（`sub`/`wait`は触らない）。
`prompt-register.py` は `wait` のときだけ🟢復帰（`sub`は触らない）。

## 生存照合と並び替え（2026-07-08 更新）

イベント駆動だけでは「閉じる合図」が鳴らないと🟢/🔵が固着する。これを現実と突き合わせて解く。

- **並び替え**: どの書き込み後も「目標グループ（グループ内の最良状態が代表）→ 目標 → 状態 → 時刻」で整列。
  生きている目的が上・同じ目的が隣接。目的別サマリも同時に再生成。
- **生存照合**（`reconcile`）: 🟢/🔵の各行について、**パスにキー（sid先頭8字）を含む** `.jsonl` の最新mtimeを見る。
  パス照合なのでサブエージェント実体（`<親uuid>/subagents/agent-*.jsonl`）の書き込みが**親の生存として数えられる**
  （長いサブ委託中の🔵誤降格を防ぐ・2026-07-08修正）。沈黙の閾値は **🟢=10分・🔵=30分**。
- **幽霊枠掃除**（2026-07-08）: 実体トランスクリプトが探索ルートに**1つも無い**枠は、行の開始時刻から**15分超**なら
  幽霊枠（プロンプトを持たない補助セッション等の取りこぼし）とみなし⏸へ。**行削除はせず⏸止まり**（翌日の新ボードで消える）。
  日跨ぎは開始時刻に+24h補正（`_minutes_between`）。15分以内は判定保留で触らない（起動直後を誤って落とさない）。
- **降格時のsubクリア**（2026-07-10）: 🔵→⏸へ降格するとき、サブ体数（`sub:N`）も0へクリアする
  （死んだセッションの `sub-end` は届かない前提で仕切り直す。次の `sub-start` から数え直し）。
- **発火**: `common.stop_flip`（Stop）と `common.start_register`（SessionStart）から毎回。
  **UserPromptSubmit には乗せない**（開始レイテンシを守る）。保険として launchd 5分毎の
  `loops-registry/loops/board-reconcile/`（**未ロード**・有効化は人間ゲート）が全セッション放置中の残留を埋める。
- 探索根は `SESSION_BOARD_TX_ROOTS`（:区切り）で差し替え可（テスト・移設用）。

## 登録（窓経由・登録は人間ゲート／session-board は包括承認）

正本は repo、runtime には **symlink 窓**で露出する。

- **Claude** `~/.claude/settings.json`（パスは窓 `~/.claude/agent-hooks/<イベント>/…`・trust不要・保存で自動反映）:

```json
{ "hooks": {
  "SessionStart":     [{ "matcher":"startup|resume|clear|compact",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-start/session-board-session-start.py","timeout":10}] }],
  "UserPromptSubmit": [{ "matcher":"",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py","timeout":10}] }],
  "Stop": [
    { "matcher":"", "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-end/session-board-session-end.py","timeout":10}] },
    { "hooks":[{"type":"prompt","prompt":"<claude/milestone/session-board-milestone.md の内容>"}] }
  ],
  "SubagentStart": [{ "matcher":"",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/subagent/session-board-subagent.py","timeout":10}] }],
  "SubagentStop": [{ "matcher":"",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/subagent/session-board-subagent.py","timeout":10}] }]
}}
```
（実ファイルは絶対パス `/Users/…/.claude/agent-hooks/<イベント>/…` で記述。
SubagentStart/SubagentStop は受け口実装済み・**settings.json への登録は人間適用**＝2026-07-10 子02時点で未適用）

- **Codex** `~/.codex/hooks.json` → `../../codex/hooks.json` への **symlink**（repo が正本）。
  パスは窓 `~/.codex/agent-hooks/<イベント>/…`。**hook を変えたら `/hooks` 再 trust**（hash/パスに紐づく）。

窓の実体: `~/.claude/agent-hooks → hooks-registry/claude/`、`~/.codex/agent-hooks → hooks-registry/codex/`。現況は `registered.sh`。

## ガード（登録・作用しないもの）

- `AIJOBS_RUN` 非空（headless）／ session id が `agent-*`（subagent）／ transcript が `*/subagents/*`／
  スラッシュコマンド・空・添付のみのプロンプト。

## テスト用 env

- `GOAL_BASE`（デイリー基点）／ `SESSION_BOARD_DATE`（YYYY-MM-DD）／ `SESSION_BOARD_TEMPLATE`／`SESSION_BOARD_TX_ROOTS`／
  `SESSION_BOARD_NO_TURSO`（非空でTurso送信・スプール追記・再送をすべてスキップ。テストが本番Tursoへデータを漏らさないためのガード。全E2Eテストで設定済み）。
- `SESSION_BOARD_STATE_DIR` はスプール単体テスト用の隔離先。未指定時はこのフォルダの `state/` を使う。
- 受け口は窓越しに叩いて検証できる（例: `echo '{...}' | ~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py`）。
  `realpath` で共有本体を解決するので窓経由でも `board.py` を正しく指す。

## Turso連携（2026-07-08〜・MDのミラー。2026-07-11 session_events 追加）

`add`/`update`/`flip`/`sub-start`/`sub-end`/`log`/`finish`/`reconcile` は MD書き込み・flock解放後、ベストエフォートで Turso（`personal-os-board`・
focusmapの `focusmap-codex-monitoring` とは独立DB）へも送る。**MDが唯一の正本**、Tursoは失敗しても無視される
下流ミラー（本体の成功・失敗に一切影響しない）。設計判断の経緯は
`../../../my-brain/areas/ai運用/plans/active/2026-07-08-デイリーTurso表反映/plan.md`（層1・2）と
`../../../my-brain/areas/ai運用/plans/active/2026-07-10-デイリーボード改善/plans/03-Turso時間計測と同期安定化.md`（層3）。

| コマンド | `sessions` 現在値 | `session_events` | `session_logs` / inbox |
|---|---|---|---|
| `add` / `update` / `flip` | upsert | `add`の新規行、`flip`の状態変化時のみ | — |
| `sub-start` / `sub-end` | 毎回upsert（`sub_n` を更新） | run/wait→sub、最後のsub-endのsub→runのみ | — |
| `reconcile` | 降格行をwaitでupsert | 降格行にwait（`trig=reconcile`） | — |
| `log` | — | — | `session_logs` へinsert |
| `finish` | 自行をdelete | done | `session_logs` へinsert |
| `goal-add` | — | — | 別DB `personal-os-inbox` の `goals` へpendingでinsert |

`sessions` の現在値は `session_key`、goal、now、type、repo、model、plan、state、**`sub_n`**、updated_at。
`log`/`finish` のentryはAIが既に要約済みの1行をそのまま送り、追加のLLM API呼び出しはしない。
- **状態遷移イベント**（層3・2026-07-11〜）→ `session_events` へ**追記式**で insert（上書きしない・時間集計の入力。
  mdには時間情報を書かない）。打つのは**状態が実際に変わる瞬間だけ**:
  `add`（新規挿入時のみ・冪等no-opは打たない）＝run／`flip`（変化時のみ・同状態flipは打たない）＝新state／
  `finish`＝done（行削除前のスナップショット）／`reconcile` の⏸降格＝wait／
  `sub-start` のrun/wait→sub／最後の `sub-end` のsub→run。体数だけの増減では打たない。
  `update`・`log` は打たない（Stop経路= flip wait→reconcile でも wait は1本だけ）。
  列: session_key／state(run|wait|sub|done)／at(ISO ms)／trig(add|flip|sub-start|sub-end|finish|reconcile・
  trigger はSQLite予約語のため trig)／goal／repo／type／plan／session_date。
- 送信は1コマンド1バッチに合流: sessions upsert・logs・delete・events を同一 `_turso_execute`
  パイプラインで送る（HTTP往復1回。reconcileも降格行のupsertとeventを同梱）。
- **送信失敗スプール**（2026-07-11〜）: 例外・タイムアウト・keychainトークン欠落でバッチ送信に失敗した場合、
  追記式で欠測を自己修復できない `session_events` / `session_logs` のINSERT文だけを
  `state/turso-spool.jsonl` へ保存する（1行＝失敗した1バッチ中の対象statements）。`at` / `created_at` は
  文の組立時の値を保持する。`sessions` のupsert/deleteは古い現在値による追い越し上書きを避けるため保存せず、
  次回コマンドの通常同期で自己修復する。別DBのinbox `goal-add` も対象外。
- 再送は各コマンドの送信フェーズ末尾で、**以前から残る文を古い順・最大50文**まとめてboard DBへ送る。
  成功時だけ該当文をtmp書き→`os.replace`で原子的に削除し、失敗時は全て残す。今回新たに失敗・追記した行は
  同じ実行では再試行せず、次回から対象。`state/.turso-spool.lock` の専用 `flock` を読込・再送・置換まで保持し、
  並行プロセスの追記/再送と二重insertを防ぐ。`state/` は生成物のため `.gitignore` 対象。
- `goal-add` はデイリーmdの存在に依存せず、name/sourceをtrimして `goals`に
  `(name, goal_date, created_at, source, status=pending)` をinsert。日付既定はJST当日、source既定は`chat`。
- 時間集計はSQL（実行時間=run区間・待ち時間=wait区間・LEAD窓関数・走行中はnow止め・1区間720分上限）。
  保存クエリは `queries/`（使い方: `turso db shell personal-os-board < queries/xxx.sql`）:
  - `session-durations.sql` … セッション別の run/wait/sub 分。
  - `daily-totals.sql` … `:date` 指定日の日次合計（未バインド時は当日JST。shellが `:date` を
    エラーにする場合は sed で実日付に置換して流す＝ファイル内コメント参照）。
  - `stuck-wait.sql` … 最新イベントが wait のまま15分超の一覧（board-sweep 発火条件・夜会の拾い漏れ確認の入力想定）。
- 認証: keychain `turso-personal-os-board`（`sessions`/`session_logs`/`session_events` を読み書きできる
  限定トークン・2026-07-11再発行）。値は一切ログ・stdout・commitに出さない
  （実体は `turso/store.py`、`board.py` の同名関数は外部互換アダプター）。
  `goal-add` だけは別keychain service `turso-personal-os-inbox` と別DBを使う（値は同様に非表示）。
- タイムアウト3秒・例外はMD運用へ伝播させない（`_turso_execute`）。ネットワーク非依存のロジックのみテストで担保
  （イベント構築= `tests/test_events.py`・送信関数モック／スプール= `tests/test_spool.py`・urlopenモック／
  集計SQL= `tests/test_events_sql.py`・in-memory sqlite3 に実DDL）。
- 決定ログ（2026-07-11）: 一本化調査の結果はA案（MD正本＋Tursoミラー）を維持し、欠測対策にスプールを導入、非同期化は見送る。

## 既知の制約

- **日付跨ぎは未解決**: `reconcile` は当日ボード対象。前日ボードの固着行は自動掃除されない。
  当面は必要時に `SESSION_BOARD_DATE=YYYY-MM-DD board.py reconcile` を手動実行。恒久対応は別途検討。
- 節目判定（milestone）はモデル依存＝確率的。迷ったら素通し設計で「聞かなさすぎ」に倒す。
- **Codex には prompt型フックが無く、「終わったこと」記載を促す網が無い**（状態⏸への機械flipは漏れない）。
  既知の制約として受け入れ、人間の「締めて」声かけ（夜会等）で補う。
- Codex接続（`codex/`）は実装・登録・trust 済みだが、**2026-07-08 の受け口更新で要再trust**。
  UPS注入（JSON `additionalContext`）は実測未確認。`board.py`・`common.py` は runtime非依存で共用。詳細は `../../codex/AGENTS.md`。

計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/`（2列ボード再設計は `active/2026-07-08-計画実行フロー統一/`）。
