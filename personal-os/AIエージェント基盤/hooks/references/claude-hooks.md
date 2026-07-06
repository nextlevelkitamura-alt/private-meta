# Claude Code Hooks 実務リファレンス

Claude Code の hooks をカスタマイズするための恒久リファレンス。
Codex 版（`codex-hooks.md`）と対になる。同じ「イベント直後に処理を挟む」機構を、Claude 側でどう設定するかを整理する。

> 対象範囲: 2026-07-06 時点。Claude Code は変化が速いため、細かい仕様は実装前に公式ドキュメントで再確認すること。

## 1. 概要

Claude Code の hook は、ライフサイクルのイベント直後に決まった処理を挟む仕組み。記録・文脈注入・停止/継続の判断ができる。
Codex との最大の違いは2つ。**hook の型が複数**あり（コマンド実行だけでなくモデルに判定させる prompt 型が使える）、**trust 承認が要らない**（設定ファイルに書けば自動で効く）。

## 2. いつ hook を使うか

- イベントごとに記録を取りたい（例: セッション開始を当日ボードに登録）。
- Claude に文脈を注入したい（例: 開始時に宣言手順を渡す）。
- 節目で完了確認をさせたい（prompt 型でモデルに「大目標達成＋満足の気配か」を判定させる）。

## 3. 主なイベント

session-board が使うのは `SessionStart` / `UserPromptSubmit` / `Stop` の3つ。他にも多数ある。

- `SessionStart`: セッション開始・再開・clear・compact後。【session-board使用】
- `UserPromptSubmit`: ユーザーがプロンプトを送信した時。【session-board使用】
- `Stop`: メインターン停止時。【session-board使用（command型＝flip／prompt型＝節目判定）】
- `PreToolUse` / `PostToolUse`: ツール実行の前後。
- `SubagentStart` / `SubagentStop`: サブエージェントの開始・停止。
- `SessionEnd` / `Notification` ほか: 終了・通知系。

## 4. hook の型（5種・うち2種を使用）

Claude の hook には5つの型がある。

- `command`: シェル/スクリプトを実行。【session-board使用: 受け口 `.py` 3本】
- `prompt`: 単一ターンでモデルに判定させる（yes/no）。【session-board使用: `milestone.md`】
- `http`: 指定 URL に HTTP POST。
- `mcp_tool`: MCP ツールを呼ぶ。
- `agent`: サブエージェントを起動して条件を検証させる。

> session-board が使うのは `command` と `prompt` のみ。`http` / `mcp_tool` / `agent` は現状未使用のため、各型の詳細は必要になった時に追記する（この粒度は要相談・保留中）。

## 5. command hook の入力仕様

入力は stdin に渡される1つの JSON オブジェクト。共通フィールドは `session_id`、`transcript_path`、`cwd`、`permission_mode`、`hook_event_name` など（`prompt_id` もある）。

終了コードは、`0` が成功、`2` がブロッキングエラー（stderr がフィードバックになり、`PreToolUse` なら tool 呼び出しをブロック）、その他の非ゼロは非ブロッキング。**注意: 終了コード `1` も「継続」扱い**（Unix 慣習では失敗コードだが、Claude は非ブロッキングとして扱う）。

```python
import sys, json
d = json.load(sys.stdin)
sid, cwd = d["session_id"], d["cwd"]
```

## 6. 出力と制御

hook は stdout に JSON を返せる。

- コンテキスト注入: `hookSpecificOutput.additionalContext` または `systemMessage`。
- ブロック/誘導: `decision: "block"` と `reason`、または終了コード `2` と stderr。
- `PreToolUse` では `permissionDecision`（allow/deny/ask）なども返せる。

Codex との大きな差: **Claude は `Stop` でも `additionalContext` を注入できる**（Codex は Stop で注入不可）。

## 7. prompt 型 hook（Codex にはない）

`{"type":"prompt","prompt":"<判定文>"}` で、hook 発火時にモデルへ単一ターンの判定をさせる。fast-model で走り、既定 timeout は30秒程度。

session-board の `milestone.md` がこれ。返す JSON は `{"ok":true}`（停止してよい）／ `{"ok":false,"reason":"..."}`（reason を注入して継続）。**`ok` 形式が正**で、`decision` 形式ではない。

## 8. 登録と反映

登録先は `~/.claude/settings.json`（user）。project は `.claude/settings.json`、ローカルは `.claude/settings.local.json`。**上書き型**（低優先の層は置き換えられる。Codex のマージ型と逆）。

反映は**保存で自動**（file watcher が拾う）。**trust は不要**（Codex との最大の違い）。`/hooks` コマンドで内容確認・個別無効化はできるが、実行の必須ゲートではない。

session-board の登録スニペットは `../session-board/README.md`。session-board 関連の Claude 登録は包括承認済み（承認ルールB）。

## 9. 注意点

- 終了コード `1` は非ブロッキング（直感に反する）。ブロックは `2`。
- prompt 型の戻りは `ok` 形式（`decision` 形式ではない）。
- `Stop` を無条件に `{"ok":false}` で止め続けると連続ブロックの上限に当たる。節目だけ false に倒す。
- hook は非ブロッキング設計にする（内部失敗で本体セッションを止めない）。

## 10. Claude と Codex の違い（早見）

| 観点 | Claude Code | Codex |
|---|---|---|
| 登録場所 | `~/.claude/settings.json`（上書き型） | `~/.codex/hooks.json`＋`config.toml`（マージ型） |
| trust | 不要・保存で自動反映 | 必須・`/hooks` で信頼登録 |
| hook の型 | 5種（command/prompt/http/mcp_tool/agent） | command のみ |
| prompt 型 | あり（`milestone.md`） | なし（型が非対応） |
| Stop で文脈注入 | 可（`additionalContext`） | 不可（`stopReason` 経由） |

session-board では、この差を「受け口 `.py` を runtime 別に分ける／prompt 型の `milestone` は Claude だけ」で吸収している。

## 11. 参照元

- 公式: Claude Code Hooks（`settings.json` の hooks / イベント / 出力仕様）
- 対の Codex 版: `codex-hooks.md`
- ローカル確認: `~/.claude/settings.json`、session-board 実装（`../session-board/claude/`）
- 確認日: 2026-07-06
