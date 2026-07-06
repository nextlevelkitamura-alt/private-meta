# claude/ — Claude Code 用受け口（登録・稼働 済み）

Claude Code は **SessionStart / UserPromptSubmit / Stop** の hooks を使う。
入力＝stdin JSON、注入＝`hookSpecificOutput.additionalContext`＝Codex とほぼ同型。
Codex との差は **Stop で追加の prompt 型フック**（モデルに節目判定させる）が使えることと、
**trust 承認が要らない**こと（設定ファイルに書けば自動で効く）。

## 受け口（`board.py`・手順md は `../` を共有）

- `session-start.py` … SessionStart: ボードキー＋`../session-start.md` を additionalContext で注入
- `prompt-register.py` … UserPromptSubmit: 未登録なら🟢登録／⏸→🟢復帰（sub は触らない）
- `session-end.py` … Stop（command型）: run のときだけ⏸へ機械flip・**ブロックしない**
- `milestone.md` … Stop（**prompt型**）: 節目だけ「大目標達成＋満足の気配か」を判定し、
  `{"ok":false,"reason":…}` で完了手順（`../session-end.md`）を注入（**Claude専用**・Codex は型が無い）

## 使う hook の型

- `command`（`.py` 3本）＋ `prompt`（`milestone.md`）の2型のみ。
- Claude hook の一般知識（5型・trust不要・終了コード・登録場所）は
  `../../references/claude-hooks.md`。ここでは重複させない。

## 登録（包括承認済み・稼働中）

- 登録先 `~/.claude/settings.json`（SessionStart＋UserPromptSubmit＋Stop×2＝command と prompt）。
  スニペットは `../README.md`。
- **trust 不要**・保存で自動反映（Codex と違い信頼登録のステップが無い）。
- session-board 関連の Claude 登録は**包括承認済み**（承認ルールB・2026-07-05）。現況は `../registered.sh`。

構造と共通運用は `../AGENTS.md`、Claude hooks の契約は `../../references/claude-hooks.md`、
対の Codex 受け口は `../codex/AGENTS.md`。`CLAUDE.md` は `AGENTS.md` への相対symlink。
