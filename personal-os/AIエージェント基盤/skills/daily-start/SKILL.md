---
name: daily-start
description: 朝のデイリースタート（朝会準備）。active計画の工程進捗を確認し、今日進める計画を選択→次工程のAI割り振り案を承認→繰越し・滞留を確認する。起票は選択した計画の「## 工程」節をそのままDBへ登録する（テーマ名/やることをAIが作文しない）。テーマは意図1行の任意ラベル。無人モード(--auto・loopから10:03起動)と対話モード(人間が発話)の両方を持つ。Use when 人間が「デイリースタート」「daily-start」「今日の起票」「朝の起票」「朝会準備」と言った時、または loop `daily-start` が朝に自動起動する時。朝会の対話進行そのものは morning-routine が持つ(役割分担は本文末尾)。
---

# daily-start（朝の朝会・計画確認と割り振り）

朝は「テーマの何を実行するか整理・AI割り振り・計画確認」の時間にする（2026-07-22 子03「朝会刷新」）。
毎朝テーマ3〜5個とやることを**書き起こす作文起票は廃止**した。起票は**選択した計画の「## 工程」節をそのままDBへ登録する**（AIが工程を創作しない＝作文ゼロ）。テーマは複数計画を束ねる上位の**意図1行の任意ラベル**で、完了条件の正本は計画md側に一本化する。

朝会の骨子は4手順:
① active計画の工程進捗を要約提示 → ② 今日進める計画を選択（テーマ=意図1行・任意） → ③ 選択計画の「次の工程」を「どのAIで・並列可か」の割り振り案として提示し承認 → ④ 繰越し・滞留質問の確認。
承認バーは無人モードでは置かない（無人は既定案で確定し、分岐だけ人間へ質問）。無人モードと対話モードで同じ文脈を集め、同じ実行ログを書く。

正本ポインタ（本文に複製しない）:

- 集約CLI（当日ボード・テーマ・todos・工程steps・質問）: `../../hooks-registry/shared/session-board/board.py`
- 決定的な文脈収集: `scripts/fetch-context.sh`（active計画の「## 工程」節進捗＋当日/前日/月間計画のパス解決＋繰越しtodos＋既存テーマ＋前日session_logsをJSON出力）
- 「工程」の正本と まとめ評価既定: 各計画の「## 工程」節（`../plan-ops/templates/plan.md`・`子計画.md`）／規約は `../../plan-registry/AGENTS.md` §2
- 役割別モデル・レーン規約（③のAI割り振りの根拠）: `../../AIモデル一覧.md`
- 月間計画・的の行フォーマット: `../../../my-brain/ゴール/AGENTS.md`
- 計画の置き場・状態語彙: `../../../my-brain/areas/AGENTS.md`
- 計画: `../../../my-brain/areas/ai運用/plans/active/2026-07-21-計画工程化と朝会刷新/plans/03-朝会刷新とテーマ簡素化.md`

## 集める文脈（両モード共通）

`scripts/fetch-context.sh` を1回実行してJSONを受け取る（`--date YYYY-MM-DD` で日付注入可。既定は今日JST）。

```
bash /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/daily-start/scripts/fetch-context.sh
```

JSONに含まれるもの:

- `active_plans`（**①③の中核**）: area の active 計画ごとに `doc_path`・`is_program`・`priority`（◎/○）・`steps_done`/`steps_total`・`has_process_section`・`next_steps`（未消化の工程行を verbatim）。program は `children[]` に子ごとの同項目。**工程行の文面は計画mdからそのまま**取る（作文しない）。
- `paths.monthly_plan` / `paths.yesterday_daily` / `paths.today_daily`（存在フラグ付き）— **本文はこのスクリプトは読まない。呼び出し元が Read で開く。**
- `carried_todos`（inbox: `do_date < today AND status='open'` の繰越し候補）
- `active_themes`（inbox: `status='active'` の既存テーマ＝**紐付け候補・重複回避の照合元**。作文の種ではない）
- `yesterday_session_logs`（board: 前日の「終わったこと」＝滞留・繰越し判断の文脈）
- `turso.inbox_read` / `turso.board_read`（`ok`/`unavailable`。`unavailable` の時は繰越し・前日ログ・既存テーマを反映せず、質問で人間に確認する。**`active_plans` はファイル走査なので Turso 不通でも取れる＝計画確認は継続できる**）

そのうえで自分で Read するもの:

1. `paths.monthly_plan` の月間計画（今月の的・週の大枠）。
2. `paths.yesterday_daily` の前日デイリー、特に「明日へ」節があればそこ（無ければスキップ）。
3. **②で選択した計画の `doc_path`**（program子は該当の `children[].path`）の「## 工程」節。起票（steps登録）の**正文はここから verbatim で取る**（`next_steps` は要約提示用・確定起票は必ず選択計画を Read して工程行そのものを渡す＝作文ゼロの担保）。

## 朝会4手順（無人・対話 共通の骨子）

1. **① 計画確認（工程進捗の要約提示）**: `active_plans` を優先（◎/○）と工程進捗（`steps_done/steps_total`）で並べ、各計画の「次の工程」（`next_steps` の先頭）を短く提示する。`has_process_section=false` の計画は「工程未整備」と印を付ける（子01の「## 工程」節が入る前に作られた既存計画＝遡及適用しない）。
2. **② 今日進める計画を選択**: 提示から今日動かす計画を1〜数件選ぶ（対話は人間と、無人は月間の的・優先・工程の残りから）。選んだ計画の意図を **テーマ＝意図1行** として任意で立てられる（`board.py theme-add --name "<意図1行>"`。**目的・完了条件は付けない**＝完了条件の正本は計画md側）。テーマは複数計画を束ねる上位ラベルで、`active_themes` に合うものがあれば新規作成せず再利用する。**テーマを3〜5個作る義務は無い**（無理に埋めない・当てはまるテーマが無ければ立てなくてよい）。
3. **③ 次工程のAI割り振り案を提示し承認**: 選択計画の「次の工程」を、`AIモデル一覧.md` の役割別モデルと計画の `並列:` に照らし「**どのAIで・並列可か**」の割り振り案として提示する。人間の承認（無人は既定案）を得てから起票へ進む。
4. **④ 繰越し・滞留質問の確認**: `carried_todos` と `yesterday_session_logs` から、繰越すもの・滞留（止まっている工程）を確認する。迷い（繰越し要否・過多・衝突・不明玉）だけを `board.py ask` で人間に投げる。

## 起票（承認後・作文ゼロ）

③で承認された計画について、次の順で確定投入する。**新しい文面を書き起こさない**（title は計画・工程名、steps は工程節の verbatim）。

1. 「今日やること」todo を起票する:
   `board.py todo-add --title "<計画/工程の実行>" --plan <slug#NN> [--theme <theme_id>] [--repo <slug>] [--date <今日>] [--carried-from <YYYY-MM-DD>] --route plan`。
   - **title は計画名・工程名をそのまま使う**（テーマ名≒やること名≒計画名の三重コピー作文をしない）。
   - `--plan <slug#NN>` で計画リンクを付ける（program子は `slug#NN`、単発は `slug`）。`todos.plan_slug` に入り、ボードのやること行に計画チップが出て詳細のライブ進行へ繋がる。計画リンク付き todo は全step消化でも自動完了せず「本日分は済み・斜線」で残る（完了は計画のdone移動）。
   - `--theme <theme_id>` は②で立てた（or既存の）テーマID。テーマを立てない計画は `--theme` を付けなくてよい（テーマは任意）。
   - repo slug は inbox repos マスタ（`shigoto`/`focusmap`/`private`/`ai-platform`/`none`）に合わせる。私用・repo無しは `none`。
2. その todo に**選択計画の「## 工程」節をそのまま一括登録**する（次節「全工程一括登録」）。計画mdを Read して工程行（`- [ ] NN 種別: 内容`）を取り出し、`board.py steps --todo <todo_id> --entry "<工程1>" --entry "<工程2>" ...` で登録する。**entry の文面は工程節の verbatim**（AIが工程を創作しない）。→ これが「選択計画の工程がそのままDB登録される」（完了条件2）。
3. 着手する工程だけ `board.py step-doing --todo <todo_id> --seq <n>` で `doing` にする。
4. 迷いだけ `board.py ask --todo <todo_id> --q "<質問>" [--choice ...] [--free 0|1] [--gate 0|1]` で人間へ（過多・不明玉・衝突・繰越し要否）。全件に質問を付けない。

## 無人モード（`--auto`・loop `daily-start` から10:03起動）

1. **冪等ガード**: `../../loops-registry/loops/daily-start/state/done-<YYYY-MM-DD>` が存在すれば、起票せず即終了する（手動実行済みの日の二重起票を防ぐ）。
2. **収集**: 上の「集める文脈」を実行する。
3. **① 計画確認**: `active_plans` を優先・工程進捗で把握する。
4. **② 選択（自動）**: 月間の的・優先（◎優先）・工程の残り（`steps_total - steps_done` が残る計画）から、今日進める計画を選ぶ。選んだ計画に意図が要るなら `board.py theme-add --name "<意図1行>"` を任意で立てる（既存 `active_themes` に合えば再利用）。テーマを無理に作らない。
5. **③ 割り振り（既定案）**: 選択計画の次工程を `AIモデル一覧.md` の役割別モデルと計画の `並列:` から既定の割り振り案として決める。無人なので承認は取れない＝**判断が割れる分岐だけ `board.py ask` に逃がし**、明快な既定はそのまま進める。
6. **起票**: 「起票（承認後・作文ゼロ）」の手順で選択計画の工程節を steps 登録する。繰越しは新todoを起票し `--carried-from <元do_date>` を付ける（次節「繰越し継承」）。
7. **④ 質問**: 繰越し要否・過多・不明玉・衝突の迷いだけ `board.py ask` で発行する。
8. **実行ログ＋成果1行**:
   - `../../loops-registry/loops/daily-start/state/done-<YYYY-MM-DD>` を書く（内容: 選択計画数・登録step数・時刻など1行要約で可。存在＝実行済みマーカー）。
   - `board.py log --key <このセッションのキー> --entry "デイリースタート: 計画N件を選択・工程steps M件を登録（繰越しK件）"` で成果を「終わったこと」へ1行残して finish する。
9. **デイリーmd本文は編集しない**（themes/todos/工程steps はボード＝DB側にだけ持つ）。

## 対話モード（人間が「デイリースタート」と発話）

1. 無人モードと同じ「集める文脈」を実行する。
2. **① 計画確認**を人間へ短く提示（優先×工程進捗×次工程）→ **② 選択**を人間と決める（テーマ=意図1行は任意）→ **③ 割り振り案**を提示し人間の承認を取る → **④ 繰越し・滞留**を確認する。
3. 承認後、「起票（承認後・作文ゼロ）」と同じCLIで todo＋工程steps を確定投入する（作文しない・工程節 verbatim）。繰越しも `--carried-from` で引き寄せる。
4. 無人版と**同じ実行ログ**（`state/done-<YYYY-MM-DD>` ＋ `board.py log`）を書く。手動で回した日は10:03の定期実行が冪等ガードでスキップされる。
5. 起票後の修正は通常セッション（チャット）で受ける。

## 全工程一括登録（計画リンク付き todo）

計画（program子/単発）に着手する日は、そのやること todo に**全工程を最初から一括登録する**。未来工程まで時系列で見えることが討論裁定の中核（「今ここ・この先」がボードのタイムラインに並ぶ）。

1. `--plan <slug#NN>` を付けて todo を起票し、返る `todo_id` を控える。
2. 選択計画の「## 工程」節を Read し、その工程行（`- [ ] NN 種別: 内容`）を **1コマンドで一括登録**する。`--entry` を並べる:
   `board.py steps --todo <todo_id> --entry "<工程1>" --entry "<工程2>" --entry "<工程3>"`。
   **`--entry` の文面は工程節そのまま**（fetch-context の `next_steps` ／ 計画mdの工程行を verbatim。文面を作り直さない）。seq は登録順に自動採番される（`todo` 内 MAX+1）。手直し工程は後から `--kind fix` で追記する。
3. 着手する工程だけ `board.py step-doing --todo <todo_id> --seq <n>` で `doing` にする（`started_at` 打刻→「経過◯分」がSQL導出で出る）。完了は `step-done`、飛ばす工程は `step-skip`。
4. 全工程を消化しても todo は自動完了しない（`plan_slug` 付きは flow-done 抑止）。「本日分は済み・斜線のまま」を維持し、計画そのものの完了は計画の done 移動（bucket）で表す。

## 繰越し継承（計画リンク付き todo）

計画リンク付き todo を翌日へ繰り越すときは、**リンクと未完ステップを新todoへ継承する**（毎朝ゼロから積み直さない）。

1. 繰越しは**新todoを起票**し `--carried-from <元do_date>` を付ける（元todoの `do_date` は動かさない＝focusmap todos.ts の「未来先送りは人間タップのみ」契約を破らない。朝の昨日→今日引き寄せだけが自動可）。繰越し todo も該当テーマへ `--theme` で紐付ける（テーマがあれば）。
2. 元todoの `--plan <slug#NN>` と `--theme <theme_id>` を新todoにも**そのまま引き継ぐ**。
3. 未完ステップ（`todo` / `doing` / 未着手の `review` `fix`）だけを新todoへ `board.py steps` で**再登録する**。
   - **seq は新todo内で振り直す**（1 から採番＝MAX+1 で自然に連番になる）。
   - **`done`（完了済み）ステップは継承しない**（昨日やり切った工程を今日また出さない）。`skipped` も継承しない。
   - `doing` だった工程は新todoでは未着手(`todo`)として積み直し、今日あらためて `step-doing` で始める。
4. これで「計画リンクとステップが繰越し翌日も継続する」。継承の判断に迷う工程は `board.py ask` で確認する。

## routine の自称禁止（重要）

- `todo-add --route routine` を daily-start が自分で付けることはしない。routine は skill/loop正本 frontmatter の `board_route: routine` 宣言を `board.py flow-done --skill <slug>` が照合した時だけ成立する。
- daily-start が起票するtodoの route は `plan` か `single` のどちらか。計画リンク付きは `plan`。判断に迷ったら `plan`。

## Turso が読めない時（`unavailable`）

- `fetch-context.sh` の `turso.inbox_read`/`board_read` が `unavailable` なら、繰越し候補・前日ログ・既存テーマが取れていない。
- **`active_plans` はファイル走査なので Turso 不通でも取れる**＝①計画確認と②選択・③割り振り案の提示は継続できる。
- その状態で繰越しを勝手に補完しない。繰越しの要否は `board.py ask` で人間に確認する（起票の送信自体は best-effort で spool 側が復帰時に再送する）。

## morning-routine との分担

- **daily-start = 朝会の準備と起票**（active計画の工程確認→選択→AI割り振り案→承認→工程steps起票）。
- **morning-routine = 対話の朝会・夜会進行**（usage確認・優先順位決め・起動プロンプト生成・夜の締め）。朝会本体（②選択・③割り振り承認の対話）は morning-routine の朝会モードが進め、daily-start が計画確認と確定起票を担う。
- 両者は競合しない。工程進捗の収集と起票は daily-start、進行と締めは morning-routine。

## 制約

- board.py / store.py は読み取り・呼び出しのみ（変更しない）。テーマ/todos/工程steps/質問はすべて board.py 経由で書く。
- **工程steps・todo title は計画mdの工程節・計画名を verbatim で使う**（AIが工程・タスク名を作文しない）。
- 計画md本文・デイリーmd本文・月間計画mdは読むだけ（書き込み禁止）。
- テーマは意図1行（`--name`）だけで立てる。目的・完了条件を board へ二重入力しない（正本は計画md）。
- secret / token / DB URL の auth 部を表示・記録・commitしない（token は Keychain 経由・値は扱わない）。
- 起票は確定行為。誤りは通常セッションで人間が直す前提で、迷いは `ask` に逃がして起票自体は止めない。
