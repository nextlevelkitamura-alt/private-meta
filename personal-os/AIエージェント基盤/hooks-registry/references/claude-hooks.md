# Claude Code Hooks 実務リファレンス

Claude Code の hooks とサブエージェントをカスタマイズするための恒久リファレンス。
Codex 版（`codex-hooks.md`）と対になり、両者の比較・設計は `claude-vs-codex-hooks.md` にまとめる。同じ「イベント直後に処理を挟む」機構を、Claude 側でどう設定するかをミクロまで整理する。

> 対象範囲: 2026-07-06 時点、公式ドキュメント（code.claude.com/docs/en の hooks / sub-agents / claude-directory）とローカル確認に基づく。Claude Code は変化が速いため、細かい仕様は実装前に公式で再確認すること。

## 1. 概要

Claude Code の hook は、ライフサイクルのイベント直後に決まった処理を挟む仕組み。記録・文脈注入・停止/継続の判断ができる。
Codex との最大の違いは2つ。**hook の型が複数**あり（コマンド実行だけでなくモデルに判定させる prompt 型が使える）、**trust 承認が要らない**（設定ファイルに書けば保存で自動反映）。

## 2. いつ hook を使うか

- イベントごとに記録を取りたい（例: セッション開始を当日ボードに登録）。
- Claude に文脈を注入したい（例: 開始時に宣言手順を渡す）。
- 危険操作を止めたい（例: `PreToolUse` で破壊的コマンドを deny）。
- 節目で完了確認をさせたい（prompt 型でモデルに「大目標達成＋満足の気配か」を判定させる）。

## 3. 設定できる hook イベント（タイミング）

公式は「once per session / once per turn / per tool call ＋ 他に20+のイベント」と説明する。**詳細まで確認できた確定イベント**は次の通り。ここに無いものは公式に20+あると明記されているだけで、実装前に個別確認する（記憶で確定扱いにしない）。

- `SessionStart`: セッション開始・再開・clear・compact後。matcher=`startup`/`resume`/`clear`/`compact`。【session-board使用】
- `SessionEnd`: セッション終了。後片付け向け。
- `UserPromptSubmit`: ユーザーがプロンプトを送信した時（matcher無し）。【session-board使用】
- `Stop`: メインターンが停止しようとする時。未完了なら継続させられる。【session-board使用（command型＝flip／prompt型＝節目判定）】
- `StopFailure`: APIエラー等での異常終了時。ログ向け。
- `PreToolUse`: ツール実行前。ツール名で matcher、`if` 条件でも絞れる。ブロック・書き換えができる。
- `PostToolUse`: ツール成功後。lint/test・ログ・補足文脈。
- `SubagentStart`: サブエージェント開始時（matcher=agent型名）。追加文脈注入。
- `SubagentStop`: サブエージェント終了時（matcher=agent型名）。薄い結果のやり直し。
- `FileChanged`: watched file が変わった時（matcher=ファイル名リテラル）。`.env` 変更検知など。

> 注意: 元マニュアル（GDrive版）は約30イベントを列挙していたが、公式ドキュメントで詳細確認できたのは上記。`Setup` `PermissionDenied` `TeammateIdle` `MessageDisplay` `InstructionsLoaded` `ConfigChange` `CwdChanged` `Elicitation` `ElicitationResult` などは公式リファレンスに記載が見当たらず、**未確認扱い**。`PreCompact`/`PostCompact` `Notification` `PermissionRequest` `PostToolUseFailure` `UserPromptExpansion` `WorktreeCreate/Remove` `TaskCreated/Completed` は名前は出るが詳細未確認。使う時に公式で確定させる。

## 4. hook の型（5種・session-board は command を使用）

- `command`: シェル/スクリプトを実行。stdin に JSON を受ける。【session-board使用: `events/` の `.py`】
- `prompt`: 単一ターンでモデルに判定させる（yes/no）。fast-model で走る。
- `http`: 指定 URL に HTTP POST（2xx＋JSON で応答）。Webhook・社内API・監査。
- `mcp_tool`: 接続済み MCP ツールを呼ぶ（GitHub・DB・filesystem など）。
- `agent`: サブエージェントを起動して条件を検証させる。**実験的（may change）**。強力だがコスト・遅延・挙動変化があるため、重要なガードは `command` に寄せる。

## 5. command hook の入力仕様（stdin JSON）

入力は stdin に渡される1つの JSON オブジェクト。共通フィールドは `session_id`・`prompt_id`・`transcript_path`・`cwd`・`permission_mode`・`hook_event_name` など。ツール系イベントは `tool_name`・`tool_input` を含む。

```python
import sys, json
d = json.load(sys.stdin)
sid, cwd, ev = d["session_id"], d["cwd"], d["hook_event_name"]
```

終了コードは、`0` が成功（stdout の JSON を解釈）、`2` がブロッキングエラー（stderr がフィードバックになり、`PreToolUse` なら tool 呼び出しをブロック）、その他の非ゼロは非ブロッキング。**注意: 終了コード `1` も「継続」扱い**（Unix 慣習では失敗コードだが、Claude は非ブロッキングとして扱う）。

### 5.1 サブ起動ツールの PreToolUse 実測（子03・2026-07-21）

子03「サブエージェント詳細化」で、サブエージェント起動（`Agent` / `Task` ツール）の `PreToolUse` から
`prompt`・`subagent_type`・`model` を捕捉できるか調べた記録。**推測と確認を分けて書く。**

**確認できたこと（本 SDK の Agent ツール JSONSchema と §5 の共通スキーマから）**
- `PreToolUse` の stdin JSON は `tool_name`・`tool_input`・`session_id`・`hook_event_name`・`cwd` を含む（§5 の共通スキーマ）。
- サブ起動は Agent ツール。その `tool_input`（＝ツール引数）のキーは JSONSchema 上 `description`・`prompt`・`subagent_type`・`model`・
  `run_in_background`・`isolation`。よって**プロンプト（`prompt`）・種別（`subagent_type`）・モデル（`model`）は tool_input から取れる**（＝子03計画の「PreToolUseでプロンプトが取れるか」への答えは Yes）。
- `session_id` はサブ起動を発行した**親セッション**の id。`common.session_key()` の `sid[:8]` が親キーになり、
  積み先（`session_subagents.session_key`）と一致する。

**登録後のE2Eで実測する（推測で確定扱いにしない）**
- 実配信での `tool_name` の literal 値が `Agent` か `Task` か（本体は `^(Agent|Task)$` の両対応で吸収済み）。
- `model` がユーザー未指定でも `tool_input` に現れるか（現状の実装は明示指定時のみ抜き、未指定は表示側で親モデル補完）。
- `PreToolUse`（push）→ 直後の `SubagentStart`（pop）の発火順序が確実に FIFO で対応するか（多重同時起動時）。
- 実装は完全 fail-open（`events/pre-tool-use/capture-subagent-detail.py`）＝上記が外れても本体・サブ起動は止まらない。

## 6. 出力と制御（stdout JSON）

hook は stdout に JSON を返せる。主なフィールド:

- **コンテキスト注入**: `hookSpecificOutput.additionalContext`（Claude に渡す追加情報）または `systemMessage`（警告文）。
- **ブロック/誘導**: トップレベルの `decision: "block"` ＋ `reason`、または終了コード `2`＋stderr。
- **PreToolUse の権限判定**: `hookSpecificOutput.permissionDecision`（`deny` / `allow` / `ask` / `defer`）＋ `permissionDecisionReason`。入力書き換えは `updatedInput`。
- **その他**: `continue`（false で停止）・`suppressOutput` など。

出力スキーマの形（イベント共通の骨格）:

```json
{
  "decision": "block",
  "reason": "…",
  "systemMessage": "…",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "…",
    "additionalContext": "…",
    "updatedInput": { }
  }
}
```

Codex との大きな差: **Claude は `Stop` でも `additionalContext` を注入できる**（Codex は Stop で注入不可）。

## 7. prompt 型 hook（Codex にはない）

`{"type":"prompt","prompt":"<判定文>"}` で、hook 発火時にモデルへ単一ターンの判定をさせる。fast-model で走り、既定 timeout は30秒程度。

session-board は prompt 型を使わない。導入する場合は、停止を不必要に繰り返しブロックしない設計にする。

## 8. サブエージェント & カスタムエージェント

### 8.1 定義（`.claude/agents/*.md`）

1ファイル1エージェント。**上部の `---` frontmatter が機械向け設定、本文が AI 向け指示**。

```md
---
name: reviewer
description: Review code changes for correctness, security, regressions, missing tests.
tools: Read, Grep, Glob, Bash
model: sonnet
---

You are a strict code reviewer. Do not edit files. ...
```

### 8.2 frontmatter の対応フィールド（公式確認・全16）

- `name`（必須）: 一意な識別子。
- `description`（必須）: いつ委譲すべきかを Claude に伝える説明。
- `tools`: 許可ツールの allowlist（省略時は全ツール）。
- `disallowedTools`: denylist（先に適用される）。
- `model`: エイリアスまたは完全 model ID。
- `hooks`: このサブエージェントに閉じたライフサイクル hook（§8.3）。
- `initialPrompt`: セッション開始時に自動投入されるプロンプト。
- `permissionMode`: `default` / `acceptEdits` / `auto` / `dontAsk` / `bypassPermissions` / `plan` / `manual`。
- `skills`: 事前にコンテキストへ載せる skill。
- `mcpServers`: インラインまたは参照の MCP サーバ設定。
- `memory`: 永続メモリのスコープ（`user` / `project` / `local`）。
- `maxTurns`: 停止までの最大エージェンティックターン数。
- `background`: `true` で常にバックグラウンドタスクとして実行。
- `effort`: 推論努力（`low` / `medium` / `high` / `xhigh` / `max`）。
- `isolation`: `worktree` で隔離 git worktree。
- `color`: タスク一覧の表示色。

> 元マニュアルは `name/description/tools/model` 程度しか挙げていなかったが、実際はこれだけ豊富。特に `hooks` `memory` `maxTurns` `background` `effort` `isolation` は便利機能として活用できる（Codex 側には無い）。

### 8.3 agent 別 hook（frontmatter の `hooks`）

サブエージェントの frontmatter に `hooks` を書ける。**そのサブエージェントが動いている間だけ有効**なので、project 全体の hook より細かく制御できる。5つの型すべて使える。frontmatter に書いた `Stop` hook は、実行時に自動で `SubagentStop` イベントへ変換される。

```md
---
name: reviewer
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_PROJECT_DIR}/.claude/hooks/pre_tool_use_policy.py"
  Stop:                       # 実行時に SubagentStop に変換される
    - hooks:
        - type: prompt
          prompt: |
            Verify concrete findings / file refs / severity / tests exist. If missing, block.
            Hook input: $ARGUMENTS
---
```

project 全体の `SubagentStart` / `SubagentStop`（`settings.json`・matcher=agent型名）は「メインセッション側で全サブエージェントの開始/終了に反応する」もの。frontmatter hook は「そのサブエージェント内で完結する」もの。用途で使い分ける。

### 8.4 呼び出し方

- 自動委譲（Claude が `description` を見て必要時に Agent tool で呼ぶ）。
- 明示呼び出し `@reviewer`。
- session agent（`--agent` / `agent` 設定）でセッション全体を特定エージェントに動かす。

## 9. フォルダ管理（`.claude/`）

### 9.1 settings の階層と優先順位

- `~/.claude/settings.json` … user（全プロジェクトに効く）
- `<repo>/.claude/settings.json` … project（user を上書き）
- `<repo>/.claude/settings.local.json` … local（project を上書き・最優先に近い）
- CLI フラグ … すべてを上書き
- plugin の `hooks/hooks.json` … plugin 有効時

同じ層で衝突したら上書き型（低優先の層が置き換えられる。Codex のマージ型と逆）。

### 9.2 hooks の登録スキーマ

```json
{
  "hooks": {
    "EventName": [
      {
        "matcher": "pattern",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/x.py", "timeout": 30 }
        ]
      }
    ]
  }
}
```

### 9.3 matcher の規則

- 省略・`"*"` … 全一致。
- 英数字＋`_ - , |` … 完全一致または pipe 区切りリスト（例 `Bash|Edit`）。
- それ以外の文字 … アンカー無しの正規表現。
- MCP ツール … `mcp__<server>__<tool>` パターン（例 `mcp__memory__.*`）。

### 9.4 フォルダの置き方

- `.claude/hooks/*.py`（`.sh`）… hook の実処理。`${CLAUDE_PROJECT_DIR}` はプロジェクトルートに解決される。絶対パスかこの変数基準で呼ぶ。
- `.claude/agents/*.md` … カスタムサブエージェント定義。
- `.claude/skills/*/SKILL.md`・`.claude/rules/*.md` … 手順・トピック別ルール。

## 10. 最低限のルール（床）を Claude に守らせる

Codex と揃える共通の床。Claude では次の hook で実現する（`claude-vs-codex-hooks.md` §3 と対応）。

- **危険コマンド block**: `PreToolUse`（matcher=`Bash`）→ `permissionDecision: "deny"` で `rm -rf` / force push / `git reset --hard` を止める。
- **開始文脈**: `SessionStart` → `additionalContext` で状態・作業ルールを注入。
- **返却フォーマット**: `SubagentStart` → 共通書式（Summary / Evidence / Risks / Next）を注入。
- **薄い結果のやり直し**: `SubagentStop` → 必須節が欠けたら1回だけ `block`（`stop_hook_active` を見て無限ループ防止）。
- **完了確認**: `Stop` → 変更 / テスト / リスク / 次 を確認。
- **secret を出さない・非ブロッキング**: 値は書かずポインタのみ。内部失敗で本体を止めない。

その上に §8・§3 の便利機能（prompt型・agent別hook・worktree隔離・豊富な frontmatter）を上乗せする。

## 11. 登録と反映

登録先は `~/.claude/settings.json`（user）／project は `.claude/settings.json`／ローカルは `.claude/settings.local.json`。

反映は**保存で自動**（file watcher が拾う）。**trust は不要**（Codex との最大の違い）。`/hooks` コマンドで内容確認・個別無効化はできるが、実行の必須ゲートではない。

現在のsession-boardのClaude登録表は `~/.claude/settings.json` の `hooks` 項目そのもの。repo側は共通実行本体 `../events/` と登録規則 `../claude/AGENTS.md` を管理し、Claude専用の `hooks.json` や同期スクリプトは置かない。settings全体はsymlinkにせず、変更時は必要な `hooks` 項目だけを直接更新する。現在のイベントと実行本体の対応は `../claude/AGENTS.md` が正本。変更後はJSON構文・登録表・実イベントをAIがreadbackする。

## 12. 注意点

- 終了コード `1` は非ブロッキング（直感に反する）。ブロックは `2`。
- prompt 型の戻りは `ok` 形式（`decision` 形式ではない）。
- `Stop` を無条件に `{"ok":false}` で止め続けると連続ブロックの上限に当たる。節目だけ false に倒す。
- hook は非ブロッキング設計にする（内部失敗で本体セッションを止めない）。
- `agent` 型 hook は実験的。重要ガードは `command` に寄せる。
- イベント名は確定分だけ使い、未確認イベントは公式で確認してから使う（§3の注記）。

## 13. Claude と Codex の違い（早見）

| 観点 | Claude Code | Codex |
|---|---|---|
| 登録場所 | `~/.claude/settings.json`（上書き型） | `~/.codex/hooks.json`＋`config.toml`（マージ型） |
| trust | 不要・保存で自動反映 | 必須・`/hooks` で信頼登録 |
| hook の型 | 5種（command/prompt/http/mcp_tool/agent） | command のみ |
| prompt 型 | あり（session-boardでは未使用） | なし（型が非対応） |
| Stop で文脈注入 | 可（`additionalContext`） | 不可（`stopReason` / `reason` 経由） |
| agent 別 hook | frontmatter に記述（稼働中だけ） | matcher で agent 型に分岐 |

比較と「1ワークフローを2エージェントに従わせる」設計の全体像は `claude-vs-codex-hooks.md`。

## 14. 参照元

- 公式: Claude Code Hooks（`settings.json` の hooks / イベント / 出力仕様）、Custom Subagents（frontmatter フィールド / agent別hook）、`.claude` directory（settings 階層 / matcher / `${CLAUDE_PROJECT_DIR}`）。code.claude.com/docs/en。
- 対の Codex 版: `codex-hooks.md`／比較: `claude-vs-codex-hooks.md`。
- ローカル確認: `~/.claude/settings.json`、session-board 実装（`../events/`・`../shared/session-board/`）。
- 元資料: GDrive `claude_codex_hooks_subagents_manual_v1.md`（v1.0）。イベント一覧は未確認分を含むため確定分のみ反映。
- 確認日: 2026-07-06
