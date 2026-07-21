---
name: daily-start
description: 朝のデイリースタート。月週目標・前日の引き継ぎ・繰越しを読み、今日の大課題(themes)と今日やること(todos)をボードへ確定起票する。無人モード(--auto・loopから10:03起動)と対話モード(人間が発話)の両方を持つ。Use when 人間が「デイリースタート」「daily-start」「今日の起票」「朝の起票」と言った時、または loop `daily-start` が朝に自動起動する時。朝会の対話進行そのものは morning-routine が持つ(役割分担は本文末尾)。
---

# daily-start（朝の起票）

朝いちばんに、月週の的・前日の引き継ぎ・繰越しを読み、**今日の大課題（themes・3〜5個／目安4個）と、その下にぶら下げる今日やること（todos）をボードへ確定起票する**。
themes は「今日はこれをします」と言い切れる大きな塊で、todos は各 theme の子（`--theme` で紐付け）として立てる。
承認バーは置かない（AIが確定して起票し、人間はスマホで質問に答えるだけ）。無人モードと対話モードで同じ文脈を集め、同じ実行ログを書く。

正本ポインタ（本文に複製しない）:

- 集約CLI（当日ボード・themes・todos・質問）: `../../hooks-registry/shared/session-board/board.py`
- 決定的な文脈収集: `scripts/fetch-context.sh`（当日/前日/月間計画のパス解決＋繰越しtodos＋前日session_logsをJSON出力）
- 月間計画・的の行フォーマット: `../../../my-brain/ゴール/AGENTS.md`
- 役割別モデル・レーン規約: `../../AIモデル一覧.md`
- 計画: `../../../my-brain/areas/ai運用/plans/planning/2026-07-09-デイリー運用刷新/plans/03-儀式の自動実行.md`（子03スコープB）

## 集める文脈（両モード共通）

`scripts/fetch-context.sh` を1回実行してJSONを受け取る（`--date YYYY-MM-DD` で日付注入可。既定は今日JST）。

```
bash /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/daily-start/scripts/fetch-context.sh
```

JSONに含まれるもの:

- `paths.monthly_plan` / `paths.yesterday_daily` / `paths.today_daily`（存在フラグ付き）— **本文はこのスクリプトは読まない。呼び出し元が Read で開く。**
- `carried_todos`（inbox: `do_date < today AND status='open'` の繰越し候補）
- `active_themes`（inbox: `status='active'` の既存テーマ＝重複作成を避ける照合元）
- `yesterday_session_logs`（board: 前日の「終わったこと」実行ログ＝文脈）
- `turso.inbox_read` / `turso.board_read`（`ok`/`unavailable`。`unavailable` の時は繰越し・前日ログを反映せず、質問で人間に確認する）

そのうえで自分で Read するもの:

1. `paths.monthly_plan` の月間計画（今月の的・週の大枠）。
2. `paths.yesterday_daily` の前日デイリー、特に「明日へ」節があればそこ（8節化前は未整備な日もある＝無ければスキップ）。

## 無人モード（`--auto`・loop `daily-start` から10:03起動）

1. **冪等ガード**: `../../loops-registry/loops/daily-start/state/done-<YYYY-MM-DD>` が存在すれば、起票せず即終了する（手動実行済みの日の二重起票を防ぐ）。
2. **収集**: 上の「集める文脈」を実行し、月間計画・前日「明日へ」・繰越し候補・前日session_logsを把握する。
3. **themes（今日の大課題 3〜5個・目安4個）を確定**:
   - 粒度は「**今日はこれをします**」と言い切れる単位（例:「focusmap の当日ボードSQL化を評価まで進める」）。
     月間計画の的・週の大枠・前日「明日へ」・繰越しから、今日ぶつかる大きな塊を **3〜5個** 立てる。
   - **1〜2個で済ませない**。themes は今日の見取り図なので、粗く2件でまとめない（material が本当に無い日＝
     予定が薄い休日等だけ少なくてよい。その時は少ない理由を1件目の theme note か `ask` で1行残す）。
   - `fetch-context.sh` の `active_themes` と照合し、**すでに在るテーマは作り直さない**（重複作成禁止・名称や目的が実質同じものは既存を使う）。既存テーマも今日の大課題なら手順4で todos を足す対象にする。
   - 不足分だけ新規作成する。作成は
     `board.py theme-add --name "<テーマ名>" --purpose "<目的>" --done "<完了条件>" [--goal <的slug>] [--plan <計画slug> ...]`。
   - `theme-add` は theme_id を stdout に返す。手順4の todos 紐付け（`--theme <theme_id>`）に使う。既存テーマの theme_id は `active_themes` の id を使う。
4. **todos（今日やること）を各テーマの子として確定起票**: 手順3の各 theme の下に、その大課題を進めるための
   具体的な「今日やること」をぶら下げる。各やることを
   `board.py todo-add --title "<やること>" --theme <theme_id> [--note ...] [--date <今日>] [--repo <slug>] [--assignee self|ai] [--route plan|single] [--carried-from <YYYY-MM-DD>] [--source cli]` で起票する。
   - **`--theme <theme_id>` を必ず付けて、どの大課題の子かを紐付ける**（テーマ›タスクの入れ子で表示される）。
     `todos.theme_id` 列はこの紐付けを保持する（`board.py todo-add` → `stmt_todo_insert(theme_id=...)`）。
   - **テーマに紐付かない todo を原則作らない**。どの theme にも属さない突発・単発の思いつきは、その場で無所属 todo を
     増やさず、`board.py ask` で「これは今日やるべきか／どのテーマに入れるか」を人間に確認してから起票する
     （themes を今日の見取り図に保つため）。
   - 各 theme に最低1件は「今日やること」をぶら下げる（大課題だけ立てて todos ゼロにしない）。塊が大きければ複数件に割る。
   - 計画（`plans/` 配下の program/plan）に対応するやることは、**`--plan <slug#NN>` で計画リンクを付ける**
     （例: `--plan "2026-07-21-ボードUI計画統合#02"`。program子は `slug#NN`、単発は `slug`）。
     `todos.plan_slug` 列に入り、ボードのやること行に計画チップが出て詳細のライブ進行タブへ繋がる。
     `--route plan` と併せて出所を辿れるようにする（`--note "計画: .../plans/03-….md"` の併記も可）。
     計画リンク付き todo は全step消化でも自動完了せず「本日分は済み・斜線」で残る（完了判定は計画のdone移動）。
     着手時は次節「全工程一括登録」で未来工程まで `steps` を積む。
   - **繰越し**: `carried_todos` から今日やると判断したものは、**新todoを起票し `--carried-from <元do_date>` を付ける**（既存todoの `do_date` は動かさない＝focusmap todos.ts の「未来先送りは人間タップのみ」契約を破らない。朝の昨日→今日引き寄せだけが自動可）。繰越し todo も該当テーマへ `--theme` で紐付ける。計画リンク付きの繰越しは次節「繰越し継承」に従い `--plan` と未完stepを引き継ぐ。
   - `--assignee` / `--route` は自己判定する。**`route=routine` を自称起票しない**（routine は skill/loop正本の `board_route: routine` 宣言照合＝`board.py flow-done` 経由のみ。迷ったら `plan`）。
   - repo slug は inbox repos マスタ（`shigoto`/`focusmap`/`private`/`ai-platform`/`none`）に合わせる。私用・repo無しは `none`。
5. **質問（気になる点だけ）**: 過多・不明玉・衝突・繰越し要否の迷いだけを、該当todoに対して
   `board.py ask --todo <todo_id> --q "<質問>" [--choice A --choice B --choice C] [--free 0|1] [--gate 0|1]` で発行する（`--q` は `--question` でも可）。質問はスマホで答えられる粒度に絞る。全件に質問を付けない。
6. **実行ログ＋成果1行**:
   - `../../loops-registry/loops/daily-start/state/done-<YYYY-MM-DD>` を書く（内容: 起票したthemes/todos件数・時刻など1行要約で可。存在＝実行済みマーカー）。
   - `board.py log --key <このセッションのキー> --entry "デイリースタート: themes N件・todos M件を起票（繰越しK件）"` で成果を「終わったこと」へ1行残して finish する。
7. **デイリーmd本文は編集しない**（8節構成は本program他子の領分。themes/todosはボード＝DB側にだけ持つ）。

## 対話モード（人間が「デイリースタート」と発話）

1. 無人モードと同じ「集める文脈」を実行し、月間計画・前日引き継ぎ・繰越し・前日ログを把握する。
2. 今日の大課題（themes・3〜5個／目安4個）と、各テーマにぶら下げる今日やること（todos）の案を人間へ短く提示し、対話で確定する。粗い2件で終わらせず、言い切れる大課題に割る。
3. 確定したら 無人モードの 手順3〜4 と同じCLIで themes/todos を起票する（todos は必ず `--theme <theme_id>` で親テーマへ紐付ける）。繰越しも同じく `--carried-from` で引き寄せる。
4. 無人版と**同じ実行ログ**（`state/done-<YYYY-MM-DD>` ＋ `board.py log`）を書く。
   これにより、手動で回した日は10:03の定期実行が冪等ガードでスキップされる。
5. 起票後の修正は通常セッション（チャット）で受ける。最初は無人版で運用し、対話で決めたくなったら対話モードを既定へ切り替えればよい。

## 全工程一括登録（計画リンク付き todo・子02）

計画（program子/単発）に着手する日は、そのやること todo に**全工程を最初から一括登録する**。未来工程まで
時系列で見えることが討論裁定の中核（「今ここ・この先」がボードのタイムラインに並ぶ）。

1. `--plan <slug#NN>` を付けて todo を起票し、返る `todo_id` を控える。
2. その計画の工程（例: 実装 → レビュー → 評価 …）を **1コマンドで一括登録**する。`--entry` を並べる:
   `board.py steps --todo <todo_id> --entry "実装" --entry "レビュー" --entry "評価"`。
   seq は登録順に自動採番される（`todo` 内 MAX+1）。手直し工程は後から `--kind fix` で追記する。
3. 着手する工程だけ `board.py step-doing --todo <todo_id> --seq <n>` で `doing` にする（`started_at` が打刻され
   「経過◯分」がSQL導出で出る）。完了したら `step-done`、飛ばす工程は `step-skip`。
4. 全工程を消化しても todo は自動完了しない（`plan_slug` 付きは flow-done 抑止）。「本日分は済み・斜線のまま」を
   維持し、計画そのものの完了は計画の done 移動（bucket）で表す。

## 繰越し継承（計画リンク付き todo・子02）

計画リンク付き todo を翌日へ繰り越すときは、**リンクと未完ステップを新todoへ継承する**（毎朝ゼロから積み直さない）。

1. 繰越しは既存流儀どおり**新todoを起票**し `--carried-from <元do_date>` を付ける（元todoの `do_date` は動かさない）。
2. 元todoの `--plan <slug#NN>` と `--theme <theme_id>` を新todoにも**そのまま引き継ぐ**。
3. 未完ステップ（`todo` / `doing` / 未着手の `review` `fix`）だけを新todoへ `board.py steps` で**再登録する**。
   - **seq は新todo内で振り直す**（1 から採番＝MAX+1 で自然に連番になる）。
   - **`done`（完了済み）ステップは継承しない**（昨日やり切った工程を今日また出さない）。`skipped` も継承しない。
   - `doing` だった工程は新todoでは未着手(`todo`)として積み直し、今日あらためて `step-doing` で始める。
4. これで「計画リンクとステップが繰越し翌日も継続する」（完了条件2）。継承の判断に迷う工程は `board.py ask` で確認する。

## routine の自称禁止（重要）

- `todo-add --route routine` を daily-start が自分で付けることはしない。routine は skill/loop正本 frontmatter の `board_route: routine` 宣言を `board.py flow-done --skill <slug>` が照合した時だけ成立する。
- daily-start が起票するtodoの route は `plan` か `single` のどちらか。判断に迷ったら `plan`。

## Turso が読めない時（`unavailable`）

- `fetch-context.sh` の `turso.inbox_read`/`board_read` が `unavailable` なら、繰越し候補と前日ログが取れていない。
- その状態で繰越しを勝手に補完しない。themesとtodosは月間計画＋前日デイリーmd（Readで取れる分）から起票し、繰越しの要否は `board.py ask` で人間に確認する。

## morning-routine との分担

- **daily-start = 朝の起票**（themes/todosをボードへ確定投入する。この子03スコープB）。
- **morning-routine = 対話の朝会・夜会**（usage確認・優先順位決め・起動プロンプト生成・夜の締め）。現状維持で、縮退・改名は人間判断待ち。
- 両者は競合しない。起票は daily-start、進行と締めは morning-routine。

## 制約

- board.py / store.py は読み取り・呼び出しのみ（変更しない）。themes/todos/質問はすべて board.py 経由で書く。
- デイリーmd本文・月間計画mdは読むだけ（書き込み禁止）。
- secret / token / DB URL の auth 部を表示・記録・commitしない（token は Keychain 経由・値は扱わない）。
- 起票は確定行為。誤りは通常セッションで人間が直す前提で、迷いは `ask` に逃がして起票自体は止めない。
