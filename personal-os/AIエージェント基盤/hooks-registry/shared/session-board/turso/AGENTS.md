# turso — Turso送信層

- token取得、SQL builder、HTTP送信、spool再送を所有する。
- スキーマ変更DDLは `migrations/*.sql` に置く。適用は人間が `turso db shell <DB> < ファイル` で行う（本番DB書込は人間ゲート）。
  - board DB(personal-os-board): sessions・session_events・session_logs・goals・daily_summary。
  - inbox DB(personal-os-inbox): todos・goals、および `plan_docs`・`plan_progress`（子06・計画ミラーの表示キャッシュ。書込みは plan-ops `plansync.py` のみ・md→DB一方向）。
- デイリーMarkdownを直接読み書きしない。受け取ったrow・event・entryだけを送る。
- 送信失敗は呼び出し元のMarkdown確定を巻き戻さない。
- spool再送許可(`spool.spoolable`)は board=session_events/logs と inbox=plan_docs/plan_progress(＋DELETE)。spoolはDBを判定しないので、inbox宛は plansync が専用spool名(`plansync-spool`)＋inbox宛senderで隔離して回す（board既定replayへ混ぜない）。
- `CLAUDE.md` はこのファイルへの相対symlinkにする。
