# turso — DB送信層（board.py の運用データ正本＝board DB への読み書き）

- token取得、SQL builder（書き＝upsert/insert/update/delete・読み＝session読み/生存中全件/目標一覧）、HTTP送信・読み取り、spool再送を所有する。
- 2026-07-21 正本反転（子03・案b）で当日デイリーMDは廃止。`board.py` は `stmt_session_read`/`stmt_sessions_alive`/`stmt_goals_distinct` の読みでDBから現在状態を得て遷移計算し、DBへ書く。
- スキーマ変更DDLは `migrations/*.sql` に置く。適用は人間が `turso db shell <DB> < ファイル` で行う（本番DB書込は人間ゲート）。
  - board DB(personal-os-board): sessions・session_events・session_logs・session_subagents・goals・daily_summary。
  - inbox DB(personal-os-inbox): todos・goals、および `plan_docs`・`plan_progress`（子06・計画ミラーの表示キャッシュ。書込みは plan-ops `plansync.py` のみ・md→DB一方向）。
- 当日デイリーMarkdownを読み書きしない（正本反転で廃止）。受け取ったrow・event・entryを送り、SELECT結果を返す。
- 送信失敗は本体セッションを止めない（best-effort）。
- spool再送許可(`spool.spoolable`)は**追記式で冪等な文だけ**＝board=session_events/logs と inbox=plan_docs/plan_progress(＋DELETE)。**sessions の upsert/delete は spool しない**（オフライン中に古い状態を溜め、復帰時に死んだ行を復活させるのを防ぐ）。sessions の整合は再送でなく次回コマンド/`board.reconcile_db` の自己修復で回復する。spoolはDBを判定しないので、inbox宛は plansync が専用spool名(`plansync-spool`)＋inbox宛senderで隔離して回す（board既定replayへ混ぜない）。
- `CLAUDE.md` はこのファイルへの相対symlinkにする。
