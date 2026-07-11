# session-board — セッション宣言型ボードの正本（共有本体）

当日デイリーに「動いているエージェントセッション」を宣言・可視化する機構。
このフォルダ（`hooks-registry/hooks/session-board/`）は **runtime非依存の共有本体**。
runtime 別の受け口は sibling の箱 `../../claude/`・`../../codex/` に**イベント別folder**で置かれる。
状態は 🟢動作中・⏸停止確認待ち・🔵サブ稼働中 の3値（意味と遷移は `README.md`）。

## 共有と分離の層

- **共有（このフォルダ・唯一の正本）**: `board.py`（CLI調停・互換re-export）／`common.py`（受け口の共通ロジック）／
  `md/`（Markdown永続化）／`turso/`（DBミラー送信）／
  手順md（`session-start.md`・`session-end.md`）／`daily-template.md`／`README.md`／`registered.sh`。
  Claude も Codex もこの同じファイルを参照する。二重化しない。
- **runtime別（受け口の箱）**: フックの入出力・登録先・trust が違うので、受け口だけ箱に分ける。
  受け口は「stdinのJSONを読んで `common.py` 経由で `board.py` を叩く」**薄いシム**に徹する。
  - `../../claude/<イベント>/session-board-<イベント>.py` … Claude 受け口（session-start／prompt-register／session-end／subagent＋prompt型 milestone）
  - `../../codex/<イベント>/session-board-<イベント>.py` … Codex 受け口（session-start／prompt-register／session-end／subagent／箱直下 `hooks.json`）

## フォルダ構成（共有本体）

- `board.py` … CLI・コマンド調停と既存import名の互換re-export。MD確定後だけTursoを呼ぶ。
- `md/store.py` … デイリーpath・行parse/描画・生存照合・flock・原子的置換。Turso/HTTP/keychain非依存。
- `turso/store.py` … token取得・SQL builder・HTTP送信。Markdownを直接読み書きしない。
- `turso/spool.py` … `session_events` / `session_logs` の失敗追記・最大50文再送・専用flock。
- `common.py` … 受け口の共通ロジック（`load_input`／`session_key`／`repo_of`／`start_register`／`register_prompt`／`stop_flip`／`board_reconcile`＋注入文の生成 等）。受け口が `realpath` で解決して import する。
- `session-start.md` … 開始時の宣言手順（runtime中立）
- `session-end.md` … 完了・git仕上げ手順（節目のみ）
- `daily-template.md` … デイリー雛形
- `README.md` … 登録スニペット・`board.py` コマンド・状態の意味・制約
- `registered.sh` … 現況診断（登録・symlink窓の一覧・読み取りのみ）

## Claude と Codex の共通運用

- 調停・共通ロジック・手順は1つ: `board.py`＋`common.py`＋`md/`＋`turso/`＋手順md に集約。両受け口は薄いシムで、差は
  **SessionStart 出力（Claude=plain / Codex=JSON）**・**Claude専用 prompt型 `milestone.md`**・**登録/trust** だけ
  （subagent 受け口は両runtime同型＝`sub-start`/`sub-end` でサブ体数を自動増減・2026-07-10 子02）。
- 各runtimeの hook 一般知識（型・trust・入出力・イベント）は `../../references/claude-hooks.md`／`codex-hooks.md`。
  受け口固有の説明は各箱の `AGENTS.md`。ここでは重複させない。

## 触るときの規律

- 本文の正本はこの共有本体と各受け口の箱。runtime登録（`~/.claude/settings.json`・`~/.codex/hooks.json`）は
  窓（`~/.claude`・`~/.codex` の `agent-hooks`／hooks.json symlink）経由＝露出。session-board の登録・露出は包括承認（ルールB）。Codex の trust は別途 `/hooks`。
- `md/store.py` の行フォーマット（`LINE_RE`・2026-07-10〜の v3 入れ子形式＝2列ボード＋任意 `sub:N`）を割る変更をしない。`board.py` の同名は外部互換re-export。旧形式（v2.2/v2/`OLD_LINE_RE`）は読み取り互換のみ・書き込みは常に新形式。状態は3値で増やさない（生存照合 `reconcile` も死体を⏸へ落とすだけで新状態を作らない。🔵→⏸降格では sub体数を0へクリア）。
- 生存照合は**実体トランスクリプトのmtime**を真実とする（パスにキーを含む `.jsonl` を照合＝サブ実体も親の生存に数える。閾値は🟢=`STALE_MIN`(10分)・🔵=`STALE_MIN_SUB`(30分)）。発火は Stop / SessionStart（開始=UserPromptSubmit には乗せない）＋保険 loop `loops-registry/loops/board-reconcile/`（未ロード）。詳細は `README.md` の「生存照合と並び替え」。
- 受け口を増やすときは共通を `common.py` に寄せ、シムには runtime 差だけ残す。
- 上位の索引・構造は `../../AGENTS.md`。設計判断の経緯は `../../research/2026-07-05/`。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
