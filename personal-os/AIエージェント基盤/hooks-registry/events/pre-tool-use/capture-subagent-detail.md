# capture-subagent-detail — サブ起動ツールの詳細を捕捉する（子03）

`PreToolUse` で、サブエージェント起動ツール（`Agent` / `Task`）の `tool_input` から
`prompt` / `subagent_type` / `model` を抜き、親セッションキーで一時スプールへ積む観測 hook。

## 2段構え（Claude 経路）

1. **PreToolUse（この hook）**: 起動ツール呼び出しを見て詳細を `shared/session-board/subspool.py` へ push する。
   `permissionDecision` を返さず stdout も出さない＝ツール挙動を一切変えない「観測のみ」。
2. **SubagentStart（`../subagent/sync-subagent-status.py`）**: 直後に最古1件を pop し、
   `board.py sub-start --runtime/--model/--type/--via/--prompt` へ渡して個体行に enrich する。

FIFO で受け渡す（`session_subagents` の close も started_at 昇順 FIFO 近似なので整合）。

## 規律

- **完全 fail-open（非ブロッキング）**: 例外・詳細欠落・スプール失敗でも本体のサブ起動を止めない。
- `session_id` は親セッションの id（サブ起動を発行した側）。`session_key` は親キーで正しい。
- Codex 直接exec駆動はこの hook に乗らない。Codex 経路は `board.py sub-start --via exec` の呼び出し規律で捕捉する。
- prompt のマスキングは保存直前の `board.py`（`_mask_secrets`）が担う。このスプールは平文の中継バッファで当日限り。

## 登録（人間ゲート・未適用）

`~/.claude/settings.json` の `PreToolUse` へ matcher `^(Agent|Task)$` で追加する。差分案は
`../../claude/settings-diff-子03-capture-subagent.md`。適用は人間が行う（基盤の hook 登録ゲート）。

## payload 実形

stdin JSON の実測結果は `../../references/claude-hooks.md`「§5.1 サブ起動ツールの PreToolUse 実測」を参照。
