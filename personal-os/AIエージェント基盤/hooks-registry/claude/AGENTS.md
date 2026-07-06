# claude/ — Claude Code 受け口の箱（イベント別）

Claude Code は **SessionStart / UserPromptSubmit / Stop** の hooks を使う。
この箱は Claude の受け口を **イベント別フォルダ**に置く（`runtime → イベント → 機構ファイル`）。
中身は薄いシムで、実処理は共有本体 `../hooks/<機構>/`（session-board なら `board.py`・`common.py`）に集約。

## レイアウト

- `session-start/session-board-session-start.py` … SessionStart: 手順注入（plain text）
- `prompt-register/session-board-prompt-register.py` … UserPromptSubmit: 未登録→🟢登録／⏸→🟢復帰
- `session-end/session-board-session-end.py` … Stop(command): run のとき⏸へ flip・**ブロックしない**
- `milestone/session-board-milestone.md` … Stop(**prompt型**): 節目確認（**Claude専用**・Codex は型が無い）

ファイル名は `<機構>-<イベント>` で自己記述（folder＝イベントと二重確認）。
将来フックが増えたら同じイベントfolderに `<新機構>-<イベント>.py` を足す。

## 受け口の共通ルール

- 各 `.py` は `realpath` で実体を解決し `../../hooks/session-board/common.py` を import
  （`~/.claude/agent-hooks` 窓越しで起動されても `board.py` を正しく指す）。
- Claude hook の一般知識（5型・trust不要・終了コード）は `../references/claude-hooks.md`。

## 登録（窓経由・包括承認）

- `~/.claude/settings.json`（SessionStart＋UserPromptSubmit＋Stop×2＝command と prompt）。
  パスは窓 `~/.claude/agent-hooks/<イベント>/<機構>-<イベント>.py`（→ `hooks-registry/claude/`）。
- **trust 不要**・保存で自動反映。session-board の登録・露出は**包括承認**（ルールB・2026-07-05）。現況は `../hooks/session-board/registered.sh`。

対の Codex 箱は `../codex/AGENTS.md`、共有本体は `../hooks/session-board/AGENTS.md`、Claude hooks 契約は `../references/claude-hooks.md`。`CLAUDE.md` は `AGENTS.md` への相対symlink。
