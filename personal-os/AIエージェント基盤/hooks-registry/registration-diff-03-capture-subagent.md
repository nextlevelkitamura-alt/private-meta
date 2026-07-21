# 子03 hook登録差分案（未適用）

状態: **未適用**。この文書は人間ゲート用の差分案であり、runtime設定・symlink・Codex trust・DB migration適用は行わない。
子03「サブエージェント詳細化」の捕捉hook（`events/pre-tool-use/capture-subagent-detail.py`）を PreToolUse へ足す案。

## 前提（同じ人間ゲートで揃える）

- migration `shared/session-board/turso/migrations/20260721_session_subagents_detail.sql` を board DB へ適用済みであること。
  未適用のままこの hook を登録しても、詳細付き INSERT は best-effort 送信でドロップするだけ（体数±1・running行のMD/DB挙動は不変）。
- 既存の `PreToolUse`（`guard-plan-bucket-move.py`・matcher `^Bash$`）と `SubagentStart/Stop`（`sync-subagent-status.py`）は残す。これは**別handlerの追加**。

## Claude `~/.claude/settings.json` の `hooks` 追加断片

既存の `PreToolUse` 配列へ、次の1要素を**追記**する（`^Bash$` の要素は消さない）。

```json
{
  "PreToolUse": [
    {"matcher":"^(Agent|Task)$","hooks":[{"type":"command","command":"/Users/kitamuranaohiro/.claude/agent-hooks/events/pre-tool-use/capture-subagent-detail.py","timeout":10}]}
  ]
}
```

- matcher `^(Agent|Task)$`: サブ起動ツールだけに絞る（`Agent`＝SDK名・`Task`＝旧CLI名の両方）。
- この hook は `permissionDecision` を返さず stdout も出さない＝ツール挙動を変えない観測専用。`--runtime` 引数は不要（分岐しない）。

## Codex `hooks.json` の扱い

Codex は Agent/Task ツールを持たず、サブ依頼は直接exec駆動なので、**この PreToolUse は Codex へ登録しない**。
Codex 経路の捕捉は `board.py sub-start --runtime codex --model <model> --via exec --prompt <text>` の呼び出し規律で行う（`codex/hooks.json` は変更しない）。

## 適用前後の手順

1. 本体とテスト（`tests/test_subagents.py`・`tests/test_subspool.py`・`tests/test_capture_subagent.py`）を実行する。
2. 人間承認後に migration を `turso db shell personal-os-board < 20260721_session_subagents_detail.sql` で適用する（1回だけ・再実行不可）。
3. 人間承認後に Claude settings の `PreToolUse` 配列へ上の1要素を追記する（保存で自動反映・trust不要）。
4. `shared/session-board/registered.sh` で読み取り診断する。
5. E2E: 実セッションで `Agent`/`Task` を1回起動し、`session_subagents` の新5列に runtime/model/agent_type/launch_via/prompt が乗るか実測する（下記「未解決」を確定させる）。

## 未解決（承認後のE2Eで確定）

- PreToolUse の stdin JSON における `tool_name` の実値（`Agent` か `Task` か）と、`tool_input` に `model` が
  ユーザー未指定でも現れるか（現状: 明示指定時のみ抜ける前提・未指定は表示側で親モデル補完）。
- PreToolUse→SubagentStart の発火順が確実に「push→pop」の順序になるか（並列多重起動時の FIFO 対応の実測）。
- 実測結果は `references/claude-hooks.md`「§5.1」へ追記する。
