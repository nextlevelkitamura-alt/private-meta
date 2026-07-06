# session-board — セッション宣言型ボードの正本

当日デイリーに「動いているエージェントセッション」を宣言・可視化する機構。
機構=Python（`board.py` エンジン）／runtime別の受け口／エージェント向け手順md。
状態は 🟢動作中・⏸停止確認待ち・🔵サブ稼働中 の3値（意味と遷移は `README.md`）。

## 正本の考え方（共有と分離の層）

- 共有（runtime非依存・唯一の正本）: `board.py`（ボード編集エンジン）／手順md（`session-start.md`・`session-end.md`）／`daily-template.md`／`README.md`。Claude も Codex もこの同じファイルを参照する。二重化しない。
- runtime別（受け口だけ分ける）: フックの入出力・登録先・trust が違うため、受け口だけ `claude/`・`codex/` に分ける。受け口は「stdinのJSONを読んで `board.py` を叩く」薄い層に徹する。

## フォルダ構成

- `board.py` … エンジン（当日デイリーの行を key で操作・flock付き・冪等）【共有】
- `daily-template.md` … デイリー雛形【共有】
- `session-start.md` … 開始時の宣言手順（runtime中立）【共有】
- `session-end.md` … 完了・git仕上げ手順（節目のみ）【共有】
- `README.md` … 登録スニペット・`board.py`コマンド・状態の意味・制約【共有】
- `claude/` … Claude Code 受け口（詳細は `claude/AGENTS.md`）
  - `session-start.py`（SessionStart→手順注入）／`prompt-register.py`（UserPromptSubmit→登録・🟢復帰）／`session-end.py`（Stop→🟢→⏸ flip）／`milestone.md`（Stop prompt型→節目確認・Claude専用）
- `codex/` … Codex 受け口【実装・登録・trust 済み／サブ🔵自動は未実測】（詳細は `codex/AGENTS.md`）
  - `session-start.py`／`prompt-register.py`／`session-end.py`／`subagent.py`（SubagentStart/Stop→🔵/🟢 自動）／`hooks.json`（`~/.codex/hooks.json` へ merge する雛形）

## Claude と Codex の共通運用

- エンジンと手順は1つ: ボード形式・宣言/完了手順は `board.py`＋手順md に集約。両runtimeの入出力はほぼ同型（hook入力=stdinのJSON／文脈注入=`hookSpecificOutput.additionalContext`）なので、受け口はほぼ写しで動く。
- 各runtimeの hook 一般知識（型・trust・入出力・イベント）は `../references/claude-hooks.md` / `../references/codex-hooks.md` に runtime 別で集約する。session-board 固有の受け口説明は `claude/AGENTS.md` / `codex/AGENTS.md`。ここでは重複させない。

## 触るときの規律

- 本文の正本はこのフォルダ。runtime登録（`~/.claude/settings.json`・`~/.codex/hooks.json`）は露出＝人間ゲート（session-board関連のClaude登録のみ包括承認＝承認ルールB。Codexのtrustは別途）。
- `board.py` の行フォーマット（`LINE_RE`）を割る変更をしない。状態は3値で増やさない。
- 上位の索引・規律は `../AGENTS.md`。設計判断の経緯（3状態・Codex調査）は `research/2026-07-05/`。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
