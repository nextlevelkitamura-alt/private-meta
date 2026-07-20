# md — デイリー日付・生存照合ユーティリティ層

2026-07-21 正本反転（program「当日ボードSQL化」子03・案b）で、当日デイリーMarkdownへの描画・parse・
原子的置換・flock は廃止した。運用データの正本はDB（board）に一本化し、`board.py` は MD を一切読み書きしない。
このフォルダは MD I/O を持たず、次の純ユーティリティだけを所有する（`board.py` が import する）。

- `daily_path()`: 当日デイリーの日付・path 解決。`date_s` は `session_events` / `session_logs` の `session_date` に使う（ファイルは開かない）。
- `tx_roots` / `list_transcripts` / `newest_for` / `minutes_between`: reconcile の生存照合が使うトランスクリプト探索と時刻差の純関数（DB上の run/sub 行が実セッションで生きているかの照合に流用）。
- 3状態の絵文字（🟢⏸🔵）・`STATE_WORD`・沈黙しきい値（`STALE_MIN*` / `NOFILE_MAX`）・`clean` の共有定数。

- HTTP・keychain・secret・DB送信には依存しない（`board.py`・送信層が持つ）。
- `CLAUDE.md` はこのファイルへの相対symlinkにする。
