# session-board — セッション宣言型ボードの正本（共有本体）

当日デイリーに「動いているエージェントセッション」を宣言・可視化する機構。
このフォルダ（`hooks-registry/hooks/session-board/`）は **runtime非依存の共有本体**。
runtime 別の受け口は sibling の箱 `../../claude/session-board/`・`../../codex/session-board/` にある。
状態は 🟢動作中・⏸停止確認待ち・🔵サブ稼働中 の3値（意味と遷移は `README.md`）。

## 共有と分離の層

- **共有（このフォルダ・唯一の正本）**: `board.py`（編集エンジン）／`common.py`（受け口の共通ロジック）／
  手順md（`session-start.md`・`session-end.md`）／`daily-template.md`／`README.md`／`registered.sh`。
  Claude も Codex もこの同じファイルを参照する。二重化しない。
- **runtime別（受け口の箱）**: フックの入出力・登録先・trust が違うので、受け口だけ箱に分ける。
  受け口は「stdinのJSONを読んで `common.py` 経由で `board.py` を叩く」**薄いシム**に徹する。
  - `../../claude/session-board/` … Claude 受け口（`session-start.py`/`prompt-register.py`/`session-end.py`＋prompt型 `milestone.md`）
  - `../../codex/session-board/` … Codex 受け口（＋`subagent.py`／`hooks.json`）

## フォルダ構成（共有本体）

- `board.py` … エンジン（当日デイリーの行を key で操作・flock付き・冪等）
- `common.py` … 受け口の共通ロジック（`load_input`／`session_key`／`repo_of`／`start_lines`／`register_prompt`／`stop_flip` 等）。受け口が `realpath` で解決して import する。
- `session-start.md` … 開始時の宣言手順（runtime中立）
- `session-end.md` … 完了・git仕上げ手順（節目のみ）
- `daily-template.md` … デイリー雛形
- `README.md` … 登録スニペット・`board.py` コマンド・状態の意味・制約
- `registered.sh` … 現況診断（登録・symlink窓の一覧・読み取りのみ）

## Claude と Codex の共通運用

- エンジン・共通ロジック・手順は1つ: `board.py`＋`common.py`＋手順md に集約。両受け口は薄いシムで、差は
  **SessionStart 出力（Claude=plain / Codex=JSON）**・**Codex専用 `subagent.py`**・**Claude専用 prompt型 `milestone.md`**・**登録/trust** だけ。
- 各runtimeの hook 一般知識（型・trust・入出力・イベント）は `../../references/claude-hooks.md`／`codex-hooks.md`。
  受け口固有の説明は各箱の `AGENTS.md`。ここでは重複させない。

## 触るときの規律

- 本文の正本はこの共有本体と各受け口の箱。runtime登録（`~/.claude/settings.json`・`~/.codex/hooks.json`）は
  窓（`~/.claude`・`~/.codex` の `agent-hooks`／hooks.json symlink）経由＝露出。session-board の登録・露出は包括承認（ルールB）。Codex の trust は別途 `/hooks`。
- `board.py` の行フォーマット（`LINE_RE`）を割る変更をしない。状態は3値で増やさない。
- 受け口を増やすときは共通を `common.py` に寄せ、シムには runtime 差だけ残す。
- 上位の索引・構造は `../../AGENTS.md`。設計判断の経緯は `../../research/2026-07-05/`。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
