# shared/session-board — session-board の共通エンジン

当日デイリーの「動いているエージェント」を管理するruntime非依存の共通エンジン。実行イベント本体は `../../events/`、登録表はClaudeの `~/.claude/settings.json` とCodexの `../../codex/hooks.json` に分かれる。

## このフォルダにあるもの

| ファイル・フォルダ | 役割 |
| --- | --- |
| `board.py` | CLI調停。Markdown確定後にTursoへベストエフォート送信 |
| `common.py` | 全イベント本体が使う共通ロジック・注入文生成 |
| `md/` | デイリーのMarkdown永続化、ロック、原子的置換 |
| `turso/` | DBミラー送信と失敗時spool |
| `session-end.md` | 節目の完了・git仕上げ手順 |
| `daily-template.md` | デイリー雛形 |
| `registered.sh` | 登録とsymlinkの読み取り専用診断 |
| `tests/` | 単体・E2Eテスト |

状態は 🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中 の3値。新しい状態は作らない。

## board.py コマンド（当日デイリー＝MD/board DB系）

`add` / `update` / `flip` / `sub-start` / `sub-end` / `log` / `finish` / `check` / `show` / `goals` / `reconcile` / `goal-add`。`log` / `finish` は任意で `--todo <id>` を取り、`session_logs.todo_id`（inboxの todos への紐付け・migration適用後のみ）を刻む。

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
- SessionStart は生存照合とキー通知だけ。最初の UserPromptSubmit が行を登録する。全体フローは `../../events/session-start/AGENTS.md`。
- subagent/headless（`AIJOBS_RUN=1`）は独立行を登録しない。
- 永続化失敗は本体を止めない。secret/tokenの値を書かない。

## 変更時

`md/store.py` の行形式と3状態を壊さない。変更後は `tests/`、`registered.sh`、各runtimeの登録表を確認する。Claudeは設定ファイルの `hooks` 項目を直接確認し、Codexは `/hooks` の再trustが必要になる。
`CLAUDE.md` は `AGENTS.md` への相対symlink。README は置かない。
