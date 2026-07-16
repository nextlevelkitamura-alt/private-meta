# 子04 hook登録差分案（未適用）

状態: **未適用**。この文書は承認セット用の差分案であり、runtime設定、symlink、Codex trust、Prompt Submit本文の有効化は行わない。

## Claude `~/.claude/settings.json` の`hooks`追加断片

既存の`Stop`（`mark-wait.py`）と`SubagentStart/Stop`（`sync-subagent-status.py`）を残し、次を別handlerとして追加する。

```json
{
  "PreToolUse": [{"matcher":"^Bash$","hooks":[{"type":"command","command":"/Users/kitamuranaohiro/.claude/agent-hooks/events/pre-tool-use/guard-plan-bucket-move.py --runtime claude","timeout":10}]}],
  "Stop": [{"hooks":[{"type":"command","command":"/Users/kitamuranaohiro/.claude/agent-hooks/events/session-end/guard-plan-closeout.py --runtime claude","timeout":10}]}],
  "SubagentStart": [{"hooks":[{"type":"command","command":"/Users/kitamuranaohiro/.claude/agent-hooks/events/subagent/verify-plan-worker.py --runtime claude","timeout":10}]}],
  "SubagentStop": [{"hooks":[{"type":"command","command":"/Users/kitamuranaohiro/.claude/agent-hooks/events/subagent/verify-plan-worker.py --runtime claude","timeout":10}]}]
}
```

## Codex `hooks.json` の追加案

`codex/hooks.json`は変更しない。承認後に既存`hooks`へ、上と同じ4イベント・同じmatcherを追加する。commandの`~/.claude/agent-hooks`を`~/.codex/agent-hooks`、runtimeを`codex`へ置換する。既存5イベントの配列は削除・置換しない。

## 適用前後の手順

1. 本体とfixtureテストを実行する。
2. 人間承認後にClaude settingsの`hooks`項目だけを追加する。
3. 人間承認後にrepo正本`codex/hooks.json`を更新しJSON検証する。
4. symlinkは読み取り確認だけを行い、壊れている場合は別承認にする。
5. `shared/session-board/registered.sh`で読み取り診断する。
6. 人間がCodex `/hooks`で差分を確認し再trustする。
7. 両runtimeで既存5イベント＋PreToolUse/Stop/SubagentのE2Eを行う。`PLAN_RUN_MANIFEST`継承とsubagent cwdも実測する。

未解決: runtimeに`PLAN_RUN_MANIFEST`が継承されること、SubagentStart payloadのcwd、実runtimeでの既存handlerとの並列共存は、承認後のE2Eまで確定しない。
