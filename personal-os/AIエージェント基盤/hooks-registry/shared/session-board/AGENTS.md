# shared/session-board — session-board の共通エンジン

当日の「動いているエージェント」を管理するruntime非依存の共通エンジン。実行イベント本体は `../../events/`、登録表はClaudeの `~/.claude/settings.json` とCodexの `../../codex/hooks.json` に分かれる。

**2026-07-21 正本反転（program「当日ボードSQL化」子03・案b）**: 当日デイリーMarkdownへの書き込み・読み取りを**完全廃止**し、運用データ（sessions・session_events・session_logs・session_subagents）の正本を **board DB（Turso）へ一本化**した。`board.py` は MD を一切読み書きしない。「動いているエージェント」「終わったこと」の表示は focusmap 側がDBから描画する（旧デイリーmd 2節への機械描画は無くなった。デイリーmd の人間記入節は別レーンで存続）。

## このフォルダにあるもの

| ファイル・フォルダ | 役割 |
| --- | --- |
| `board.py` | CLI調停。board DB から現在行を読んで遷移計算し、DBへベストエフォート書き込み（MDは介さない） |
| `common.py` | 全イベント本体が使う共通ロジック・注入文生成 |
| `routing.py` | Git common-dir由来repo key・canonical repo、worktree root、実cwd、branch、非Git folderの機械判定 |
| `sanitize.py` | routingの安全な短文をsecret・連絡先マスク＋文字数上限へ揃える共通境界 |
| `md/` | デイリー日付解決・生存照合のトランスクリプト/時刻ユーティリティ（MD描画・parse・原子的置換は廃止） |
| `turso/` | board/inbox DB への読み書きと、追記系のみの失敗spool再送 |
| `session-end.md` | 節目の完了・git仕上げ手順 |
| `daily-template.md` | デイリー雛形（board.py は不参照。デイリーmd の人間記入節向け・別レーン所有） |
| `registered.sh` | 登録とsymlinkの読み取り専用診断 |
| `tests/` | 単体・E2Eテスト（fake DB で状態遷移を in-process 検証。`tests/_fakedb.py`） |

状態は 🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中 の3値。新しい状態は作らない。

## オフライン・障害時の劣化動作（正本反転の耐障害設計）

MDという受け皿が消えたため、DB送信失敗時の記録喪失を次の方針で扱う（本体セッションは常に止めない＝非ブロッキング）。

- **追記・冪等な文**（`session_events` / `session_logs`）は失敗時 `state/turso-spool.jsonl` へspoolし、次回送信時に再送する（記録は復帰時に復元される）。
- **`sessions` の upsert / delete は spool しない**。オフライン中に古い状態を溜め込み、復帰時に「もう死んだセッションの行」を復活させるのを防ぐため。よって**オフライン中の状態変化（add/update/flip/sub の1回分）は失われうる**。
- 失われた `sessions` 状態は再送でなく**自己修復**で回復する: 次回コマンド実行時にDBから現在行を読み直し、`board.py reconcile`（`reconcile_db`）が DB上の run/sub 行 × 実トランスクリプト生存を照合して沈黙行を⏸へ降格する（board-reconcile loop / SessionStart / Stop から呼ばれる）。
- **読み系（check/show/goals）はオフライン時 `missing`/空を返す**（例外を投げない）。hookのガイダンスは新規セッション扱いで進む（枠登録の best-effort も送信ドロップ）。復帰後は正しい状態を読む。
- 沈黙判定の起点は、旧MDの行開始時刻でなく `sessions.updated_at`（最終書込）を使う（正本反転の帰結）。transcript が見つかる通常セッションは従来どおり transcript mtime で判定するため主経路の挙動は不変。transcript 皆無のセッションのみ「最終更新から15分（サブ30分）沈黙」で降格する。

## board.py コマンド（board DB系・正本反転後はMDに触れない）

`add` / `update` / `flip` / `sub-start` / `sub-end` / `log` / `finish` / `check` / `show` / `goals` / `reconcile` / `goal-add`。反転後は add/flip/sub/log/finish が board DB から現在行を読み（`stmt_session_read`）、遷移を計算して upsert/delete する。`check` / `show` / `goals` も board DB を読む（出力フォーマットは現行互換＝check=状態word1行・show=7タブフィールド・goals=1行1目標。`who` フィールドは `model` 列由来で runtime 接頭辞は非永続）。`log` / `finish` は任意で `--todo <id>` を取り、`session_logs.todo_id`（inboxの todos への紐付け・migration適用後のみ）を刻む。

`update` は任意で `--todo <id>` / `--theme <id>` を取り、そのセッションの所属先を `sessions.todo_id/theme_id`（board DB・migration `turso/migrations/*_sessions_todo_theme.sql` 適用後のみ）へ宣言する（子09）。focusmap 側のエージェント行「テーマ›タスク」表示と「終わったこと」格納先判定に使う board DB 限定列（focusmap が読む）。宣言なしのupdateはこのUPDATEを送らない（毎回の無駄書きを避ける）。宣言文の注入は `_first_guide`（初回のみ）にあり、`_mirror`（毎ターン）には入れない＝コスト規律。

Focusmap分類用の追加CLIは `context-upsert` / `route-pending` / `route-prepare` / `route-context` / `route-propose`。既存3状態や`sessions`表を変更せず、migration `20260723_session_routing.sql` の追加2表だけを使う。UserPromptSubmitは`route-prepare`でContextと`pending`を同一batchにし、今日＋対象repoのTodoからTheme、Themeの`plan_refs`からPlanを読む。AIは意味判断後に`route-propose`し、書戻し後はreadback結果を受ける。採用済み行は再試行でpendingへ戻さない。Prompt全文・Prompt由来hash・remote URLは保存しない。追加表が未適用でも既存session-boardを止めない。

`sub-start` / `sub-end` は体数±1・🔵⇄🟢 の既存遷移（`sessions`）に加えて、`session_subagents`（board DB・migration `turso/migrations/20260719_session_subagents.sql` 適用後のみ）へサブ個体行を積む/閉じる（開始=running行を1本INSERT・終了=最古のrunning1本をclose・FIFO近似。同一バッチ=HTTP往復1回）。ラベル（何をやっているか1行）は `sub-label --key <s:xxxx> --label "<1行>" [--seq <n>]` で**AIだけ**が書く（意味づけはboard.py経由のみ・hookは文面を創作しない・`--seq` 未指定=直前に起動したrunning行）。「稼働中N体」は `status='running'` の集計でSQL導出し、主観値・第2の状態台帳を保存しない（子08）。migration未適用・オフライン・`SESSION_BOARD_NO_TURSO` では best-effort 送信がドロップし、体数±1の状態変化は自己修復（reconcile）で回復する。`--time` 引数は後方互換で受理するが、反転後は開始時刻列を持たないため無視される。

## board.py 子05コマンド（inbox DB＝todos/todo_steps系・MDには触れない）

focusmap 今日ボードの「タスク入れ子と2層チェック」を駆動する。inbox DBへ直接best-effort送信し、board既定spoolへは載せない（cross-DB replay汚染を避ける）。migration適用後にだけ実挙動する（`db/turso/migrations/*` は focusmap 側・inbox宛）。

- `steps --todo <id> --entry "<step>" [--entry ...] [--kind step|review|fix] [--session-key s:xxxx]`: 計画ステップを追記登録（seqは todo 内 MAX+1）。手直しは `--kind fix`。
- `step-done|step-doing|step-skip --todo <id> --seq <n>`: ステップ状態を前進。完了済み(done)行は触らない＝過去行UPDATE禁止の機械保証（`status != 'done'`）。
- `ask --todo <id> --q "<質問>" [--choice A --choice B --choice C] [--free 0|1] [--gate 0|1]`: 質問文＋選択肢最大3＋自由入力可否を todos へ。`--gate 1` は人間ゲート承認（ボードに回答UIを出さずセッション誘導のみ）。
- `flow-done --todo <id> --skill <slug>`: 定型自動流入。`scan_board_routes()` が skill/loop正本frontmatterの `board_route: routine` 宣言を照合し、宣言済み かつ 未完了stepが残らない時だけ done へ直行（宣言のない実行は自動完了しない）。
- `answers --key <session-key>`: 当該セッションに紐づく未消費の質問回答を注入文へ整形し消費済みへ落とす。`common.register_prompt` が ⏸→🟢 の再開時だけ呼ぶ（毎プロンプトの読取を避ける）。

`%` と「レビュー待ち」は保存せず focusmap 側のSQL集計で導出する（AI・人間の主観値をDBに持たない）。ボードの見出し完了（human）と手直し付け替えは focusmap の server action 側にある。

## 境界

- `common.py` に状態遷移を集める。`events/` の `.py` は入力を受け、runtime別の出力形式だけを選ぶ。`.py` と対になるイベント説明は `../../events/<イベント>/` にある。
- SessionStart は生存照合、キー通知、repo実行Context記録、そのSessionStartイベントでの固定分類policy注入を行う。resume/compact時も方針復元のため再注入される。最初の UserPromptSubmit がsession行を登録する。全体フローは `../../events/session-start/AGENTS.md`。
- subagent/headless（`AIJOBS_RUN=1`）は独立行を登録しない。
- 永続化失敗は本体を止めない。secret/tokenの値を書かない。

## 変更時

3状態（🟢⏸🔵 = run/wait/sub）・体数・`check`/`show`/`goals` の出力フォーマット・イベント発行の意味を壊さない（hookのガイダンス文がCLI出力に依存する）。CLI引数仕様も壊さない（呼び出し側hook・skillとの互換）。`sessions`/`session_events`/`session_logs`/`session_subagents` のスキーマは変更しない。変更後は `tests/`（fake DB で状態遷移を検証。`_fakedb.py` は本番と同じ列のin-memory sqlite）・`registered.sh`・各runtimeの登録表を確認する。Claudeは設定ファイルの `hooks` 項目を直接確認し、Codexは `codex/trust-current.py` で自動trust・readbackする。
通常は`SESSION_BOARD_NO_TURSO`とfake DBで先に検証する。実DBでしか確認できない接続・migration・readbackは、対象DB・対象行・冪等性・rollbackを確定し、AIが実書込みと読戻しまで行う。`CLAUDE.md` は `AGENTS.md` への相対symlink。README は置かない。
