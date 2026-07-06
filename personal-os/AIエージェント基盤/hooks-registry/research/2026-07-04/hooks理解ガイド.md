# Claude Code hooks 理解ガイド

日付: 2026-07-04
対象読者: Skillの構造（SKILL.mdを小さく保ち、詳細は`references/`へ逃す等）は理解しているが、hooksはほぼ初見の個人開発者。

出典の扱い: 事実には出典URLを付ける。公式ドキュメントに明記が無く筆者が補った解釈には「推測」と明記する。secret/token/認証値は書かない。

---

## 1. hooksとは何か

**Skill = モデルが読む手順書。hooks = イベントで必ず走る機械。**

Skillは「こういう状況ならこう振る舞ってほしい」とモデルに指示を渡す仕組みであり、最終的に従うかどうかはモデルの判断に委ねられる。これに対しhooksは、Claude Codeのライフサイクル上の特定タイミング（ツール実行前、応答終了時など）で、ユーザー定義のシェルコマンドを**モデルの意思とは無関係に必ず実行する**仕組みである（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

公式ドキュメントはこの違いをはっきり書いている。

> Hooks are user-defined shell commands that execute at specific points in Claude Code's lifecycle. They provide deterministic control over Claude Code's behavior, ensuring certain actions always happen rather than relying on the LLM to choose to run them.
> （[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）

つまり「フォーマッタを毎回かけたい」「危険なコマンドは絶対に止めたい」「セッション終了時に必ずログを残したい」のように、**モデルの気分やコンテキスト量に依存させたくない処理**をhooksに任せる。逆に「この状況ではこう考えて動いてほしい」という手順・判断はSkillの領分のままでよい。

役割分担のイメージ:

| | Skill | hooks |
|---|---|---|
| 何を渡す | 手順書・参考情報 | 決まった処理そのもの |
| 実行者 | モデルが読んで自分で判断・実行 | Claude Codeのランタイムが機械的に実行 |
| 確実性 | モデルの解釈次第（読まない・忘れることがある） | イベントが起きれば必ず発火 |
| 得意なこと | 複雑な判断、状況に応じた分岐 | 通知・ログ・フォーマット・ブロック等の定型処理 |

---

## 2. 全イベント一覧と発火タイミング

Claude Codeのhookイベントは非常に多い。公式ドキュメントの目次を数えると30種類前後ある（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。カテゴリ別にまとめる。

### セッション単位

| イベント | 発火タイミング |
|---|---|
| `SessionStart` | セッション開始・再開（`resume`/`clear`/`compact`後も含む）時 |
| `Setup` | `--init-only`、または`-p`モードで`--init`/`--maintenance`実行時（CI等の一度きり準備向け） |
| `SessionEnd` | セッション終了時 |

### ターン単位

| イベント | 発火タイミング |
|---|---|
| `UserPromptSubmit` | プロンプト送信後・Claude処理前 |
| `UserPromptExpansion` | ユーザーが打ったコマンドがプロンプトへ展開される直前（ブロック可） |
| `Stop` | Claudeの応答が終わった時 |
| `StopFailure` | APIエラーでターンが終了した時（出力・exit codeは無視される） |

### ツール呼び出し（エージェントループ内）

| イベント | 発火タイミング |
|---|---|
| `PreToolUse` | ツール呼び出し実行前（ブロック可） |
| `PermissionRequest` | 権限確認ダイアログが表示される時 |
| `PermissionDenied` | オートモード分類器がツール呼び出しを拒否した時 |
| `PostToolUse` | ツール呼び出し成功後 |
| `PostToolUseFailure` | ツール呼び出し失敗後 |
| `PostToolBatch` | 並列ツール呼び出しのバッチが全て解決した後、次のモデル呼び出し前 |

### サブエージェント・チーム

| イベント | 発火タイミング |
|---|---|
| `SubagentStart` | サブエージェント起動時 |
| `SubagentStop` | サブエージェント終了時 |
| `TeammateIdle` | agent teamのチームメイトがアイドルになる直前 |

### タスク・コンパクション

| イベント | 発火タイミング |
|---|---|
| `TaskCreated` | `TaskCreate`でタスク作成時 |
| `TaskCompleted` | タスク完了マーク時 |
| `PreCompact` | コンテキスト圧縮（コンパクション）前 |
| `PostCompact` | コンパクション完了後 |

### 設定・環境・通知

| イベント | 発火タイミング |
|---|---|
| `Notification` | Claude Codeが通知を送る時（権限確認待ち・入力待ち等） |
| `MessageDisplay` | アシスタントのメッセージテキストが表示されている間 |
| `InstructionsLoaded` | CLAUDE.mdや`.claude/rules/*.md`が読み込まれた時 |
| `ConfigChange` | 設定ファイルがセッション中に変更された時 |
| `CwdChanged` | 作業ディレクトリが変わった時（`cd`実行等） |
| `FileChanged` | 監視対象ファイルがディスク上で変化した時 |
| `WorktreeCreate` / `WorktreeRemove` | worktreeの作成・削除時 |

### MCP関連

| イベント | 発火タイミング |
|---|---|
| `Elicitation` | MCPサーバーがツール呼び出し中にユーザー入力を要求した時 |
| `ElicitationResult` | ユーザー応答後、サーバーへ送信される前 |

（以上、[出典: hooks-guide.md「How hooks work」](https://code.claude.com/docs/en/hooks-guide.md)の一覧表および[hooks.md目次](https://code.claude.com/docs/en/hooks.md)より）

個人利用でまず押さえるべきは太字級の5つ: `SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `Stop`。自分の`~/.claude/settings.json`でもこの5つのうち3つ（`SessionStart`, `UserPromptSubmit`, `Stop`）を使っている。

---

## 3. 登録方法（settings.jsonの構造）

### 3.1 ファイルの置き場所と優先順位

| 場所 | スコープ | 共有可否 |
|---|---|---|
| `~/.claude/settings.json` | 全プロジェクト共通 | 不可（マシンローカル） |
| `.claude/settings.json` | 単一プロジェクト | 可（repoにcommit可能） |
| `.claude/settings.local.json` | 単一プロジェクト | 不可（`.gitignore`対象） |
| 管理ポリシー設定（Managed policy） | 組織全体 | 可（管理者制御） |
| プラグインの`hooks/hooks.json` | プラグイン有効時 | 可（プラグインに同梱） |
| Skill / subagentのfrontmatter | そのSkill/agentが動いている間 | 可（コンポーネントファイル内で定義） |

（[出典: hooks-guide.md「Configure hook location」](https://code.claude.com/docs/en/hooks-guide.md)）

複数の場所に同じイベントのhookが設定されていた場合にどう扱われるかについて、公式ドキュメントに明示的な優先順位・上書きルールの記述は見当たらなかった。ただし「plugin有効時はプラグインのhooksがuser/projectのhooksとmergeされる」という記述（"its hooks merge with your user and project hooks"）と、後述の「マッチした全hookが並列実行される」という原則から、**同一イベントに複数箇所からhookが登録されていれば、それらは基本的に全部実行される（上書きではなく加算的）**と考えられる。（推測。根拠: [hooks.md](https://code.claude.com/docs/en/hooks.md)の当該記述と一般原則からの類推。上書きの明示ルールは見つからず）

### 3.2 基本構造

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code needs your attention\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）

構造は「イベント名 → マッチャーグループの配列 → そのグループで走るhookの配列」の3階層。既存の`hooks`キーがあれば、イベント名をその兄弟として追加する（丸ごと置き換えない）。

### 3.3 matcher（マッチャー）

| 値 | 評価方法 | 例 |
|---|---|---|
| `"*"` / `""` / 省略 | 全マッチ | 毎回発火 |
| プレーンな文字列のみ | 完全一致・リスト | `"Bash"`, `"Edit\|Write"` |
| それ以外の文字を含む | 正規表現（unanchored） | `"^Notebook"`, `"mcp__memory__.*"` |

イベントごとにマッチ対象フィールドが異なる。主なもの:

| イベント | マッチ対象 |
|---|---|
| `PreToolUse`/`PostToolUse`等ツール系 | tool名（`Bash`, `Edit\|Write`, `mcp__.*`） |
| `SessionStart` | `startup`/`resume`/`clear`/`compact` |
| `SessionEnd` | `clear`/`resume`/`logout`/`prompt_input_exit`/`bypass_permissions_disabled`/`other` |
| `Notification` | `permission_prompt`/`idle_prompt`/`auth_success`等 |
| `SubagentStart`/`SubagentStop` | agent種別（`general-purpose`, `Explore`, カスタム名） |
| `ConfigChange` | `user_settings`/`project_settings`/`local_settings`/`policy_settings`/`skills` |
| `FileChanged` | 監視するリテラルなファイル名（正規表現ではない。`.envrc\|.env`） |
| `UserPromptSubmit`, `Stop`, `PostToolBatch`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate/Remove`, `CwdChanged`, `MessageDisplay` | マッチャー非対応。常に発火 |

（[出典: hooks-guide.md「Filter hooks with matchers」](https://code.claude.com/docs/en/hooks-guide.md)）

`v2.1.191`以降はtool名マッチャーで`|`と`,`が相互互換（`"Edit,Write"`と書ける）（同出典）。

### 3.4 `timeout`

| hook type | デフォルト |
|---|---|
| `command` / `http` / `mcp_tool` | 600秒 |
| ただし`UserPromptSubmit`ではこれが30秒に短縮 |
| `MessageDisplay`ではこれが10秒に短縮 |
| `prompt` | 30秒 |
| `agent` | 60秒 |

（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）

### 3.5 `type`: command / http / mcp_tool / prompt / agent の違い

| type | 何をするか | 主な用途 |
|---|---|---|
| `command`（既定） | シェルコマンドを実行 | 大半のケース。フォーマット・ログ・通知・ブロック |
| `http` | イベントデータをURLへPOST | 外部サービス連携、チーム共有の監査サービス等 |
| `mcp_tool` | 既に接続済みのMCPサーバーのツールを呼ぶ | MCP経由でのセキュリティスキャン等 |
| `prompt` | Claudeモデル（既定Haiku）に1ターンだけ判断させる | ルールベースでは書きにくい「これは妥当か」の判断 |
| `agent`（実験的） | サブエージェントを起動しファイル読み取り等を行った上で判断 | テスト実行結果の確認等、実際の状態検証が要る判断 |

`command`のexample:

```json
{
  "type": "command",
  "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh",
  "args": ["--strict"],
  "timeout": 30,
  "statusMessage": "Running linter...",
  "shell": "bash"
}
```

`args`を指定すると**exec form**（シェルを介さず直接実行。パイプや`&&`は使えない）、省略すると**shell form**（`sh -c`等で実行。パイプ・グロブが使える）になる（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

`prompt`のexample:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Check if all tasks are complete. If not, respond with {\"ok\": false, \"reason\": \"what remains to be done\"}."
          }
        ]
      }
    ]
  }
}
```

モデルは`{"ok": true}`か`{"ok": false, "reason": "..."}`のJSONだけを返す。`ok: false`のとき何が起きるかはイベントによって異なる。`Stop`/`SubagentStop`なら`reason`がClaudeへ渡され作業続行、`PreToolUse`ならツール呼び出しが拒否されエラーとして返る、`PostToolUse`等ならターンが終わり`reason`が警告として表示される（[出典: hooks-guide.md「Prompt-based hooks」](https://code.claude.com/docs/en/hooks-guide.md)）。

`agent`は実験的機能であり、公式も「production workflowsではcommand hookを推奨」と明記している（同出典）。

### 3.6 `if`フィールド（matcherより細かいフィルタ、v2.1.85以降）

`matcher`はtool名レベルのフィルタだが、`if`は権限ルール構文（`Bash(git *)`のような）でツール引数まで見てフィルタできる。

```json
{
  "type": "command",
  "if": "Bash(git *)",
  "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/check-git-policy.sh"
}
```

ただしBashコマンドがパースできない場合は**fail open**（＝hookは実行される）ため、公式は「ハードな許可/拒否は`if`ではなくpermission systemで行うべき」と注意している（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）。`if`が効くのはツール系イベント（`PreToolUse`/`PostToolUse`/`PostToolUseFailure`/`PermissionRequest`/`PermissionDenied`）のみで、それ以外に付けるとhookごと動かなくなる。

---

## 4. フックからモデルへ情報を渡す方法

### 4.1 入力（stdin JSON）

イベント発火時、Claude Codeはイベント固有のJSONをhookスクリプトのstdinへ渡す。全イベント共通のフィールド:

```json
{
  "session_id": "abc123",
  "cwd": "/Users/sarah/myproject",
  "hook_event_name": "PreToolUse",
  "transcript_path": "/home/user/.claude/projects/.../transcript.jsonl",
  "permission_mode": "default"
}
```

（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md) / [hooks.md](https://code.claude.com/docs/en/hooks.md)）

イベントごとの追加フィールド例（`PreToolUse`）:

```json
{
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

### 4.2 出力（exit code）

| exit code | 意味 |
|---|---|
| `0` | 成功・異議なし。stdoutのJSONが解析される（後述） |
| `2` | ブロッキングエラー。stderrに書いた理由がClaudeへフィードバックされる |
| それ以外 | 非ブロッキングエラー。stderr先頭1行がtranscriptに表示され、処理は継続 |

（[出典: hooks-guide.md「Hook output」](https://code.claude.com/docs/en/hooks-guide.md)）

**exit 2とJSON出力は混在させてはいけない**。公式は「exit 2でstderrメッセージを返すか、exit 0でJSONによる構造化制御を行うかのどちらかにせよ。両方使うとClaude CodeはJSONを無視する」と明記している（同出典）。

exit 2でブロックできるかどうかはイベントごとに異なる。ブロック可能な主なもの: `PreToolUse`, `PermissionRequest`, `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `SubagentStop`, `TaskCreated`, `TaskCompleted`, `ConfigChange`, `PreCompact`, `WorktreeCreate`。一方`SessionStart`/`Setup`/`Notification`等はブロック不可で、exit 2でもstderrがユーザーに見えるだけで処理は継続する（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

### 4.3 出力（exit 0 + JSON構造化制御）

exit 0でstdoutにJSONを書くと、より細かい制御ができる。全イベント共通のフィールド:

```json
{
  "continue": true,
  "suppressOutput": false,
  "systemMessage": "警告メッセージ",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "Claudeのコンテキストに追加したいテキスト"
  }
}
```

| フィールド | 既定値 | 説明 |
|---|---|---|
| `continue` | `true` | `false`にするとClaudeを完全停止させる |
| `suppressOutput` | `false` | `true`でスクリプトのstdoutを非表示 |
| `systemMessage` | なし | 警告メッセージを表示 |
| `hookSpecificOutput.additionalContext` | なし | Claudeのコンテキストへテキストを追加 |

（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）

イベントごとの決定制御（decision control）は書式が異なる:

- **top-level `decision: "block"`パターン**（`UserPromptSubmit`, `PostToolUse`, `Stop`, `SubagentStop`, `ConfigChange`, `PreCompact`等）:
  ```json
  { "decision": "block", "reason": "Test suite must pass" }
  ```
- **`PreToolUse`用パターン**（`hookSpecificOutput.permissionDecision`）:
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Use rg instead of grep for better performance"
    }
  }
  ```
  `permissionDecision`は`"allow"`（対話プロンプトを飛ばす。ただしdeny/askルールは依然有効）/`"deny"`（拒否しClaudeへ理由を返す）/`"ask"`（通常通りプロンプト表示）/`"defer"`（非対話モード`-p`限定でAgent SDK側へ委ねる）の4種。
- **`PermissionRequest`用パターン**（`hookSpecificOutput.decision.behavior`）:
  ```json
  {
    "hookSpecificOutput": {
      "hookEventName": "PermissionRequest",
      "decision": { "behavior": "allow" }
    }
  }
  ```

（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md) / [hooks.md](https://code.claude.com/docs/en/hooks.md)）

**`additionalContext`を使うか`decision:block`+`reason`を使うか**の使い分けの目安:

- 「これは知っておいてほしい情報を足すだけ」→ `additionalContext`（`UserPromptSubmit`/`SessionStart`等で使う。Claudeは system reminderとして平文で読む）
- 「これはダメだから止めて、こう直してほしい」→ `decision: "block"` + `reason`（`PostToolUse`/`Stop`等）、またはツール実行前段階なら`permissionDecision: "deny"` + `permissionDecisionReason`（`PreToolUse`）

なお`additionalContext`はコンテキストに注入された後、セッションのtranscriptに保存される。`--continue`/`--resume`で再開した場合、`PostToolUse`や`UserPromptSubmit`のような「ターン中」イベントは**過去分のhookを再実行するのではなく、保存済みのテキストをそのまま再生する**。そのためタイムスタンプやcommit SHAのような動的な値はresume時に古いまま残る。一方`SessionStart`は`source: "resume"`として**再実行**されるため、こちらは最新情報に更新できる（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

---

## 5. 「設定を小さく保つ」パターン

読者が最も気にする論点。Skillの`SKILL.md`本体を小さく保ち、詳細手順や参考情報を`references/`へ逃す構造に相当するものが、hooksの世界にも存在する。

### 5.1 公式が示す最小限のパターン

公式ガイドの「Block edits to protected files」の例では、settings.jsonには実行するスクリプトの**パスだけ**を書き、ロジック本体は別ファイルに持たせている。

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# .claude/hooks/protect-files.sh
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
PROTECTED_PATTERNS=(".env" "package-lock.json" ".git/")
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
    exit 2
  fi
done
exit 0
```

（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）

これは、Skillの`SKILL.md`が「詳細はreferences/xxx.mdを見よ」と書くのと同じ発想である。settings.jsonは「いつ・何にマッチしたら・どのスクリプトを呼ぶか」という**索引**だけを持ち、判断ロジックの本文は正本フォルダのスクリプトに置く。

### 5.2 一歩進んだパターン: スクリプトがmdを読んで注入する

さらに進んだパターンとして、「スクリプトが手順書（md）を実行時に読み込んでClaudeへそのまま注入する」という構成がある。これは筆者自身の運用実例（`personal-os/AIエージェント基盤/hooks/session-board/`）にある。

- `settings.json`には`start-inject.sh`・`stop-guard.sh`・`prompt-register.sh`という**パスだけ**が書かれている。
- `start-inject.sh`（`SessionStart`）は、`session-start.md`という正本の手順書を実行時に読み込み、その本文をそのまま`additionalContext`としてClaudeへ注入する。
- `stop-guard.sh`（`Stop`）は、条件を満たさない場合に`session-end.md`の本文を丸ごと読み込んで注入し、`{"decision":"block"}`で1回だけ止める。

この設計の利点は、**手順書の更新がスクリプトの変更を伴わない**こと。「セッション開始時に何を伝えるか」を変えたい時は`session-start.md`を編集するだけでよく、settings.jsonにもシェルスクリプトにも触れる必要がない。これはSkillの`references/`と全く同じ発想を、hooksの注入内容に対して適用したものと言える。

（この節は筆者自身の運用実例に基づく記述であり、公式ドキュメント上に同一パターンの明記は無い。設計上の解釈として提示する）

### 5.3 実践者の言及（初期調査）

zenn.devの記事（kazuph氏）では、Stop hookが呼ぶスクリプト本体を`~/.claude/hooks/ai-principles-reminder.sh`という外部ファイルに置いていたが、記事の主眼は「ルールを強制する仕組み」であり、整理術としての言及は薄い（[出典: zenn.dev/kazuph/articles/483d6cf5f3798c](https://zenn.dev/kazuph/articles/483d6cf5f3798c)）。

### 5.4 package.json / npm scriptへの集約（suntory-n-water氏）

suntory-n-water氏の記事（2025-12-07公開、Biome v2連携の実装が動作確認済み）は、**「settings.jsonを小さく保つ」ことを明示的な目的として書いている**、今回の調査で最も直接的な実例だった。

複数のチェックコマンド（format/lint:ai/type-check:ai）を`package.json`の`scripts`に集約し、settings.json側は実行時に**どのスクリプト名を渡すか**だけを書く。

```json
// package.json
{
  "scripts": {
    "lint:ai": "set -o pipefail && biome lint . --reporter=github 2>&1 | { grep '^::' || true; }",
    "format": "biome format --write .",
    "type-check:ai": "tsc --noEmit --pretty false"
  }
}
```

```json
// .claude/settings.json 側は引数で呼び分けるだけ
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bun run -c format,lint:ai,type-check:ai" }
        ]
      }
    ]
  }
}
```

これは「settings.jsonにパスだけ置く」（5.1節）よりもう一段進んだ発想で、**ロジックの正本をシェルスクリプトのファイルにすら分散させず、既存のpackage.jsonという1箇所に集約する**アプローチ。プロジェクトが元々npm/bun scriptsで検証コマンドを管理している場合、hooksの正本探しがそこで完結する利点がある（[出典: https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2](https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2)）。

同記事はさらに、**AIに渡す出力そのものを削ぎ落とす**という、Skillのreferences分割とは違う軸の「小さく保つ」も実践している。Biomeの`--reporter=github`オプションと`grep '^::'`で、エラー行だけを抽出してClaudeへ渡し、人間向けの色付け・詳細説明（AIにとってはトークンノイズ）を渡さない設計にしている。

```bash
set -o pipefail && biome lint . --reporter=github 2>&1 | { grep '^::' || true; }
```

`set -o pipefail`を先頭に置いているのは、pipe後段の`grep`が成功（exit 0）を返すとパイプライン全体のexit codeも成功に化けてしまう罠への対処（詳細は7.11節）。

### 5.5 「実行可能なドキュメントとして書く」という運用哲学（playpark氏）

playpark氏の記事（2026-05-15公開、「業務で半年運用して気づいた」という実運用ベース）は、settings.jsonの位置づけそのものについて次のように述べている。

> 「settings.jsonを動かすための設定ではなく実行可能なドキュメントとして書く」

コメントに運用ルールの意図そのものを記述することで、後から読み返したときに設定の意図が失われない、という考え方。加えて、Skillとhooksの役割分担について次の指摘をしている。

> 「毎回確定実行したい挙動はskillではなくhookで実装する」

理由は、skillはLLMの判断を介すため「呼び忘れ」が起きうるが、フォーマット確認・テスト実行・秘匿情報のマスクのような**決定論的に必ず実行してほしい処理**はhookに置いた方が安定する、というもの。これは本ガイド1章の「Skill=モデルが読む手順書／hooks=イベントで必ず走る機械」という整理と完全に一致する、実務者側からの裏付けと言える（[出典: https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort)）。

### 5.6 「CLAUDE.mdは確率的、hooksは確定的」（amanity-haray氏）

amanity-haray氏の記事（2026-07-02公開）は、この違いを次のように言い切っている。

> CLAUDE.mdに書いたルールはエージェントが「読んで判断する」（確率的）のに対し、hooksは「ランタイムが直接実行する」（確定的）

これは本ガイド1章の整理と同じ趣旨を実践者の言葉で表現したもの。同記事はディレクトリ構成の実例も示している。

```
.claude/
├── settings.json          ← 参照パスのみ記載
└── hooks/
    ├── check-mv-overwrite.sh
    ├── check-sed-awk-inplace.sh
    └── check-process-completion.sh
```

内容として、`mv`コマンドで移動先が既に存在する場合に`permissionDecision: "ask"`を返して一時停止させる上書き防止、`sed -i`（バックアップなし）を正規表現で検知して警告する保護など、破壊的操作を防ぐ具体パターンを含む。記事内に実装の動作確認記録は無いが、設定例・スクリプトは具体的（[出典: https://qiita.com/amanity-haray/items/55b5fb9ebb403ea02ff3](https://qiita.com/amanity-haray/items/55b5fb9ebb403ea02ff3)）。

### 5.7 まとめ: hooksの「小さく保つ」流儀

調査結果を踏まえると、hooksにおける「小さく保つ」パターンは次の3段階に整理できる。

1. **最小限**: settings.jsonにはコマンドのパスだけを書き、ロジックは`.claude/hooks/*.sh`のような別ファイルに分離する（公式ガイドが推奨する標準パターン。5.1節・5.6節のamanity-haray氏の実例も同型）。
2. **既存資産への集約**: シェルスクリプトすら新設せず、プロジェクトの`package.json`等の既存scriptsにロジックを集約し、settings.jsonからは呼び出す名前だけを渡す（suntory-n-water氏の実例。5.4節）。
3. **発展形**: スクリプトすら「何をするか」の判断を持たず、正本のmdファイルを実行時に読み込んで注入するだけの薄いレイヤーにする（筆者の実例。Skillのreferences方式をhooksの注入内容にまで拡張したパターン。5.2節）。

どれも共通するのは、**settings.json自体をロジックの置き場にしない**という一点。settings.jsonは「いつ・何に・何を渡すか」という索引に徹し、判断ロジックの本体は正本が別にある。

---

## 6. 実践者の活用パターン集

日本語圏の実践者記事から、実際に動かした形跡がある事例を紹介する。いずれも筆者（本ガイドの執筆者）がWebFetchで本文まで遡って内容を検証した上で採用している。信頼度の判定基準は「実際に動かした形跡があるか」（具体的な実行結果・エラーメッセージ・スクリーンショット・更新履歴・実装コード全文の有無）で、記事ごとに個別に付記する。

### 6.1 完了ガード（Stopイベントでルール強制）

zenn.dev（kazuph氏、2025-07-03公開）は「Claude Codeのすぐルール忘れる問題」を`Stop`イベントで解決している。Claudeの応答終了時にtranscriptファイルを検査し、「PRINCIPLES_DISPLAYED」というキーワードが含まれていなければ`decision: "block"`を返して5つの運用原則を強制表示する。スクリーンショット付きで「Claudeが何かしようとするたびに5原則が表示され」という実際の動作結果を示しており、信頼度は高い（[出典: https://zenn.dev/kazuph/articles/483d6cf5f3798c](https://zenn.dev/kazuph/articles/483d6cf5f3798c)）。

### 6.2 通知（イベントごとに音を変える）

zenn.dev（shivase氏、2026-02-20公開・2026-02-26更新）は、`Stop`（Glass音）/`SubagentStop`（Pop音）/`TeammateIdle`（Tink音）/`Notification`（Glass音）の4イベントに異なる通知音を割り当て、「画面を見なくてもどのイベントか分かる」仕組みを作っている。実装上の工夫として、`stop_hook_active`が`true`ならスキップして無限ループを防止すること、`jq`が無い環境向けに`python3`へフォールバックすること（macOS標準搭載のため追加インストール不要）、通知メッセージ中のダブルクォート・バックスラッシュ・改行を除去して引数解析の崩れを防ぐことが挙げられている。信頼度は高い（実装の具体詳細が多く、動作確認済みの記述がある）（[出典: https://zenn.dev/shivase/articles/020-claude-code-team-notification](https://zenn.dev/shivase/articles/020-claude-code-team-notification)）。

### 6.3 Stop hookの無限ループ防止（基本パターン）

Qiita（ohakutsu氏、2026-06-01公開・2026-07-01更新）は、`stop_hook_active`チェックの最小実装を示している。

```bash
#!/usr/bin/env bash
INPUT="$(cat)"
if [ "$(echo "${INPUT}" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi
```

また`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`環境変数（既定値8＝連続8回のブロックで強制終了）についても言及している。ただし記事内に具体的なエラー再現や実行結果の記載は無く、信頼度は中程度（[出典: https://qiita.com/ohakutsu/items/bc97ebfdc87877b94561](https://qiita.com/ohakutsu/items/bc97ebfdc87877b94561)）。

### 6.4 hooksの基礎検証（シェルセッションの非継承・pstree検証）

DevelopersIO（Classmethod、2025-07-06/07公開）は、公式ドキュメントの記述を鵜呑みにせず**自分で検証した**内容が特徴的。「hookで起動されるcommandのシェルセッションは、その後Bashツールが使うシェルセッションとは別物であり、hook内で設定した環境変数はBashツールに引き継がれない」ことを実証している。また`pstree`コマンドの実行結果を引用してプロセスの親子関係を確認し、Stop hookでexit code 2を返すと「応答完了→Stop hook実行（exit 2）→エラー解消処理→応答完了…」という無限ループが起きる実例も示している。著者は自分の推測に対しても「※下記内容にはハルシネーションと思われる回答が含まれています」と注記するなど、検証姿勢が明確。信頼度は非常に高い（[出典: https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/](https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/)）。

### 6.5 18イベント活用ガイド（網羅的だが検証形跡は薄い）

Qiita（kai_kou氏）は18イベントを一通り紹介し、通知・自動フォーマット・ファイル保護・ログ記録・コンパクション後の規則再注入という6レシピを示している。内容は公式ガイドの構成に近く、独自の落とし穴（速度低下、並列実行の非決定性、8回ブロック上限）への言及は無い。実行検証の痕跡も見当たらないため、信頼度は中〜低（[出典: https://qiita.com/kai_kou/items/2250545254288e6cca6d](https://qiita.com/kai_kou/items/2250545254288e6cca6d)）。

### 6.6 完了音通知とWindows特有の罠（zenn.dev/lumichy氏）

zenn.dev（lumichy氏、2026-06-01公開）は、`Stop`イベントでタスク完了音を鳴らす実装をWindows環境向けに示している。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "(New-Object Media.SoundPlayer 'C:\Users\username\.claude\sounds\done.wav').PlaySync()"
```

2つの実務的な注意点を挙げている。1つは、**既にsettings.jsonに`hooks`設定が存在する状態でStop hookを追加する際、丸ごと上書きすると既存の自動フォーマットやログ記録の設定が消えてしまう**という事故リスク（3.2節で述べた「イベント名は既存hooksキーの兄弟として追加せよ」という公式の注意と一致する）。もう1つは、JSON文字列内でWindowsパスを書く際の**バックスラッシュの多重エスケープ**（JSONパーサーの段階とPowerShell実行の段階の2層でエスケープが必要になるため、`C:\Users\username`を`C:\\\\Users\\\\username`のように書く必要がある）。設定変更後は`/hooks`コマンドでの検証を推奨している。信頼度は中程度（[出典: https://zenn.dev/lumichy/articles/claude-code-stop-hook-sound-2026](https://zenn.dev/lumichy/articles/claude-code-stop-hook-sound-2026)）。

### 6.7 Stop Hooks × Biome v2によるルール強制（suntory-n-water氏）

5.4節で紹介したsuntory-n-water氏の記事は、無限ループの実体験も詳しく記録している。「test.tsを修正→Stop hook発動→Lintエラー検出→ブロックして継続指示→Claudeが『エラーが検出されました』と報告→Stop hook再発動→前の編集が残っているため同じエラーを再検知」という繰り返しに実際に陥り、根本原因を「作業指示が与えられていないのにエラーが出ているから作業しなければいけない、という状態にAIが陥ること」と分析している。

もう1つの実務的な罠は、**パイプでexit codeが消える**問題。`biome check . --reporter=github 2>&1 | grep '^::'`のような組み立てでは、Biomeがエラー(exit 1)でも後段の`grep`が成功(exit 0)を返せばパイプライン全体のexit codeは0になってしまう。対処は`set -o pipefail`をコマンド先頭に置くこと。

```bash
set -o pipefail && biome lint . --reporter=github 2>&1 | { grep '^::' || true; }
```

TypeScriptによる完全な実装コード（`multi-command-check.ts`等）と「初期実装から見えた課題」セクションを公開しており、信頼度は高い（[出典: https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2](https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2)）。

### 6.8 Stop Hooksの連鎖ワークフロー（zenn.dev/azumag氏）

zenn.dev（azumag氏、2025-07-07公開・2025-07-11更新）は、`decision: "block"`の`reason`に「REVIEW_COMPLETED」のような終了条件フレーズを埋め込み、次のStop hook発火時に`transcript_path`をtail+jqで解析してフレーズの有無を見て次のタスクへ連鎖させる、というワークフロー制御を実装している。

```bash
LAST_MESSAGES=$(tail -n 100 "$TRANSCRIPT_PATH" | jq -r 'select(.type == "assistant")')
```

この方式のリスクとして、LLMが終了フレーズを誤って出力する可能性、無限ループ、および「stack level too deepな再帰リミットに達してしまうこともあるみたい」という具体的な失敗モードを挙げ、ループカウントや`stop_hook_active`による安全脱出機構を備えるべきと注意している。実装は`github.com/azumag/cc-gc-review`として公開されており、レビュー→コミット→プッシュという連鎖の実例を示している。信頼度は高い（[出典: https://zenn.dev/azumag/articles/00b36e074ac220](https://zenn.dev/azumag/articles/00b36e074ac220)）。

### 6.9 半年運用で見えた3つの罠（playpark氏）

5.5節で運用哲学を紹介したplaypark氏の記事は、「業務でClaude Codeを半年使って気づいた」という実運用ベースで、settings.json/permissions/hooks/effortにまたがる罠を報告している。hooksに関連する3点。

1. **環境変数依存によるexit 127**: hookスクリプトのパスを`$SKILLS_DIR/pr-iterate/scripts/check-ci.sh`のように未定義になりうる変数で組み立てると、変数が空文字列に展開されて意図しないパスになりexit code 127で失敗する。対策は`$HOME/.claude/skills/`のようにClaude Code起動時に必ず存在する変数をベースにした絶対パスで書くこと。
2. **終了コードを素直に信じない**: `gh pr checks`はpending状態でexit code 8を返す仕様があり、これを単純に「失敗」として扱うと誤判定が積み重なる（記事ではjournalの失敗率が60%という異常値として現れたと報告）。対策はラッパースクリプトでexit codeをJSONのstatusフィールドに構造化してから読むこと。
   ```bash
   case $rc in
     0) echo '{"status": "passed"}'; exit 0 ;;
     8) echo '{"status": "pending"}'; exit 0 ;;
     *) echo "{\"status\": \"failed\"}"; exit 1 ;;
   esac
   ```
3. **stateファイルにTTLが必須**: hook間で情報を引き継ぐために一時ファイル（`/tmp/claude-skill-ctx-*`等）を使う場合、前回の処理が途中で死ぬとファイルが残り続け、後続の無関係な処理から誤検出される。対策はmtimeベースで一定時間（記事では30分）より古いファイルは無視すること。

具体的な失敗の数値（failure_rate 60%等）を伴っており、信頼度は高い（[出典: https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort)）。

### 6.10 品質ゲートのキーワード方式は迂回されうる（takahirom氏）

takahirom氏の記事（初版2025-08-03、2025-08-04更新）は、`Stop`で品質チェックを強制する際に、当初「パスフレーズ方式」（Claudeが特定の文言を出力すればチェック通過）を使っていたが、**パスフレーズさえ言えば品質チェックを実際にはバイパスできてしまう**という脆弱性に気づき、方式を変更したという経緯を報告している。6.1節のkazuph氏の「PRINCIPLES_DISPLAYED」というキーワード検知方式も同じ弱点を抱えうる、という教訓として読める。

変更後は、`transcript`から最新の`Final Result:`行を検索し、`✅ APPROVED`/`❌ REJECTED`という判定文字列そのものを直接チェックする方式にした。さらに、一度`APPROVED`が出た後に`Edit`/`Write`等のファイル編集があれば、その承認を自動的に無効化する仕組みを加え、「古い承認のままコミットしてしまう」問題を防いでいる。更新履歴があり、実際に方式を切り替えた形跡があるため信頼度は高い（[出典: https://qiita.com/takahirom/items/16fd60f611e52410e928](https://qiita.com/takahirom/items/16fd60f611e52410e928)）。

### 6.11 hooksと権限モードの評価順序（ino_h氏、内容は公式ドキュメントの整理）

ino_h氏の記事（2026-05-07公開）は、hooksと権限（permission）の関係を次の評価順序で整理している。

```
Hooks → Deny rules → Permission mode → Allow rules → canUseTool callback
```

deny ruleは`bypassPermissions`モードでも有効（"the tool is blocked, even in `bypassPermissions` mode"）、ブロック可能な決定を返せるのは`PreToolUse`のみで値は`allow`/`deny`/`ask`/`defer`の4つ、競合時の優先順位は`deny > defer > ask > allow`という内容は、本ガイド4.3節・7.8節の記述と一致する。加えて、サブエージェントは親の権限モード（`bypassPermissions`/`acceptEdits`/`auto`）を継承しオーバーライドできないという公式の注意も引用している。

記事自体は「本記事の検証時点：2026年5月7日」と自称しつつ公式ドキュメントの実物確認に基づく整理と説明しているが、公開日が今回のガイド作成日（2026-07-04）に対して未来寄りの日付であることには留意する。内容自体は本ガイドが独自に確認した公式一次情報と矛盾しないため、権限周りの補助的な整理として扱う（[出典: https://zenn.dev/ino_h/articles/2026-05-07-claude-code-gate-mechanisms](https://zenn.dev/ino_h/articles/2026-05-07-claude-code-gate-mechanisms)）。

### 6.12 その他の活用パターン（簡潔に集約）

深掘りはしていないが、タイトルと概要から確認できた実用パターンをまとめて記録する。

- **型チェック/ESLint/Prettier + rm -rf防御 + コンテキスト注入の15例集**: `PostToolUse`で型チェック・ESLint・Prettierを連続実行、`PreToolUse`で`rm -rf`をexit 2でブロック、`UserPromptSubmit`で時刻やgit statusを注入、という15パターンを段階導入する構成（[出典: https://qiita.com/kawabe0201/items/3fcf698abe60d57b211b](https://qiita.com/kawabe0201/items/3fcf698abe60d57b211b)）。
- **Slack通知**: Webhook URLを`.env`に分離し`settings.local.json`側で参照。matcherを`Write|Edit`から`.*`へ広げる試行錯誤の過程が書かれている（[出典: https://qiita.com/har1101/items/4097bee8c98abedd3117](https://qiita.com/har1101/items/4097bee8c98abedd3117)）。
- **フォーマッタ自動実行**: `jq`で`tool_input.file_path`を抽出し`xargs -r prettier`へ渡す、本ガイド6.1節の公式例と同型の実装（[出典: https://azukiazusa.dev/blog/claude-code-hooks-run-formatter/](https://azukiazusa.dev/blog/claude-code-hooks-run-formatter/)）。
- **ntfy.sh経由のスマホ通知**: 無料のプッシュ通知サービスntfy.shを使う実装。topic名が他人と衝突しうる点に注意を促している（[出典: https://zenn.dev/keit0728/articles/bfb68f669755a7](https://zenn.dev/keit0728/articles/bfb68f669755a7)）。
- **SessionEnd/PreCompactでのCLAUDE.md更新提案**: セッション終了やコンパクション時に、CLAUDE.mdの更新提案を行う実装。VS Code拡張の`/hooks`はCLIでしか使えないという注意、macOSで`notify-send`が使えず`terminal-notifier`が必要という環境差の指摘がある（[出典: https://zenn.dev/91works/articles/4a32368ec94253](https://zenn.dev/91works/articles/4a32368ec94253)）。

### 6.13 その他、今回深掘りしなかったが候補として見つかった記事

検索で見つかったが本ガイドでは本文を確認していない記事群（タイトルのみ）。関心があれば個別にあたるとよい。

- 「Claude Codeの新機能『Hooks』イベントトリガーとコマンド実行の解説」zenn.dev/buddypia
- 「Claude Code の Hooks 機能で遊んでみた」zenn.dev/91works（セッション終了時にCLAUDE.md自動更新）
- 「Claude Code の /hooks コマンドを使って、承認依頼とタスク完了時にスマホへ通知」zenn.dev/keit0728
- 「Claude Codeのhooksで危険コマンドを自動ブロックする — テスト21件全PASSの3つのレシピ」zenn.dev/seeda_yuto（タイトルから見て検証志向が強そうで有望）
- 「How Claude Code stop hooks work」amitkoth.com（英語。Stop hookの制御反転についての考察）
- 「GitHub: disler/claude-code-hooks-mastery」（英語。hooks活用のOSSまとめ）

---

## 7. 落とし穴と制約

### 7.1 速度要件（"keep these hooks fast"）

`UserPromptSubmit`は毎プロンプト送信のたびに発火するため、既定timeoutは（他が600秒である中）30秒に短縮されている（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。`SessionStart`も毎セッションで走るため高速性が重要とされる（同出典）。処理を重くすると、プロンプト送信のたびに待たされることになる。公式ガイドも「Hook スクリプトはテストして遅延を検出せよ」と述べている。

### 7.2 stop_hook_activeと無限ループ

`Stop`イベントで`decision: "block"`を返すと、Claudeは作業を続行し再び応答を終えようとして、また`Stop`イベントが発火する。ここでチェックを入れないと**無限ループ**になる。`stop_hook_active`フィールドは「今のstopは、直前のstop hookのブロックによって強制的に継続させられている状態かどうか」を示す。これが`true`の時は即座に`exit 0`で抜けるのが定石。

```bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi
```

（[出典: hooks-guide.md「Stop hook hits the block cap」](https://code.claude.com/docs/en/hooks-guide.md)）

### 7.3 8回連続ブロックで強制終了

Claude Codeは、Stop hookが**進捗なく8回連続でブロック**すると強制的にオーバーライドして停止させる（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）。この上限は`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`環境変数で引き上げ可能（[出典: hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)。ただし変数自体の詳細説明は公式のenv-varsページには見当たらず、hooks-guide.md内の言及のみ確認できた）。

### 7.4 resume時のadditionalContext再生

前述（4.3節）の通り、`--continue`/`--resume`で再開すると、ターン中イベント（`PostToolUse`/`UserPromptSubmit`等）は過去のhookを再実行せず、**保存済みのテキストをそのまま再生**する。git commit SHAや現在時刻など動的な値を注入していた場合、それらはresume後は古いまま表示され続ける。最新化したい情報は`SessionStart`（`source: "resume"`で再実行される）に置く必要がある（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

### 7.5 並列実行と非決定性

同一イベントに複数のhookがマッチした場合、**それらは並列実行**され、同一のコマンド/URLを持つハンドラは自動的に重複排除される（[出典: hooks-guide.md「How hooks work」](https://code.claude.com/docs/en/hooks-guide.md)）。

一方の結果が他方に影響することはない。ある`PreToolUse`ハンドラが`deny`を返しても、同じイベントにマッチした他のハンドラの実行は止まらない。公式は「一方のhookの`deny`が、他方のhookの副作用（ログ書き込み等）を抑止すると考えるな」と明示的に注意している（[出典: hooks-guide.md「Combine results from multiple hooks」](https://code.claude.com/docs/en/hooks-guide.md)）。

複数の`PreToolUse`ハンドラがそれぞれ`updatedInput`でツール引数を書き換えようとした場合、**並列実行であるがゆえに、どちらが最後に反映されるかは非決定的**（"the order is non-deterministic"）。公式は「同じツールの入力を複数のhookで書き換えるのは避けよ」と注意している（[出典: hooks-guide.md「Limitations and troubleshooting」](https://code.claude.com/docs/en/hooks-guide.md)）。

`PreToolUse`の許可判定自体は非決定的ではなく、複数hookの結果は`deny > defer > ask > allow`の優先順位で統合される（＝最も制限が強い判定が勝つ）（同出典）。

### 7.6 出力サイズの上限

hookのstdout出力（テキスト）は10,000文字でキャップされ、それを超える出力はファイルに保存される（[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)。詳細な保存先の仕様までは今回のfetchで確認できず）。

### 7.7 `PermissionRequest`は非対話モード(`-p`)で発火しない

自動化・CI用途で`-p`フラグを使う場合、`PermissionRequest`フックは発火しない。自動的な権限判定をしたい場合は`PreToolUse`を使う必要がある（[出典: hooks-guide.md「Limitations and troubleshooting」](https://code.claude.com/docs/en/hooks-guide.md)）。

### 7.8 hookが緩めても既存の拒否ルールは覆せない

`PreToolUse`が`permissionDecision: "allow"`を返しても、settingsの`deny`ルールに一致するツール呼び出しは依然としてブロックされる。逆に`deny`を返すhookは、`bypassPermissions`モードや`--dangerously-skip-permissions`が有効でも強制的に効く。つまり**hookは制約を強める方向には常に効くが、緩める方向には既存の拒否ルールを超えられない**（[出典: hooks-guide.md「Hooks and permission modes」](https://code.claude.com/docs/en/hooks-guide.md)）。

### 7.9 シェルプロファイルによるJSON汚染

shell form（`args`省略）のhookは`sh -c`等で実行されるが、環境によっては`~/.bashrc`等のプロファイルが無条件に`echo`していると、その出力がhookのJSON出力の前に混入し、パースエラーになる。対策は「対話シェルでのみechoする」ようプロファイル側をガードすること（`[[ $- == *i* ]]`で判定）（[出典: hooks-guide.md「JSON validation failed」](https://code.claude.com/docs/en/hooks-guide.md)）。

### 7.10 その他、実践者記事から見つかった制約

DevelopersIO記事の検証によれば、hookが起動するシェルセッションは、その後Claudeが`Bash`ツールで使うシェルセッションとは別物であり、hook内で`export`した環境変数は`Bash`ツールに引き継がれない（[出典: https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/](https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/)。ただし`SessionStart`/`Setup`/`CwdChanged`/`FileChanged`イベントに限っては`$CLAUDE_ENV_FILE`という専用の仕組みがあり、そこに書いた内容は後続のBashコマンドの前置スクリプトとして実行されるため、この経路なら環境変数を引き継がせられる。[出典: hooks.md](https://code.claude.com/docs/en/hooks.md)）。

なお、公式ドキュメント上に明示的な「Security Considerations」という単独セクションは、今回参照した`hooks.md`のfetch結果内には見当たらなかった（hooks-guide.mdの「Learn more」に`/en/hooks#security-considerations`というリンク表記はあるが、実体を確認できなかった）。hookは任意のシェルコマンドを実行できる仕組みである以上、**信頼できないsettings.jsonやプラグインのhookは、フルユーザー権限で任意コードを実行しうる**という前提を推測として付記する（推測。公式の明文化は確認できず）。

### 7.11 パイプでexit codeが消える

`command | grep ...`のようにパイプで組み立てたhookコマンドは、パイプ最後のコマンド（`grep`等）のexit codeだけが全体の結果として扱われる。例えば`biome check . 2>&1 | grep '^::'`は、biomeがエラー(exit 1)を返していても、`grep`がマッチ行を見つけて成功(exit 0)を返せば、hook全体としては「成功」扱いになってしまう。対策は`set -o pipefail`をコマンドの先頭に置き、パイプのどこかで失敗したら全体を失敗として扱わせること（[出典: https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2](https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2)）。

### 7.12 hookが呼ぶ外部コマンドのexit codeも額面通りに信じない

これはClaude Code自体の制約というより、hookスクリプトを書く際の一般的な注意点だが、実務上重要なので明記する。hookから呼ぶ外部CLI（`gh pr checks`等）が、必ずしも「0=成功、非0=失敗」という単純な対応をしているとは限らない。`gh pr checks`はpending状態でexit code 8を返す仕様があり、これを単純に失敗として扱うhookを書くと誤判定が積み重なる。対策は、外部コマンドの終了コードをそのままhookの判断に使わず、一度ラッパースクリプトでJSONのstatusフィールドのような構造化された値に変換してから読むこと（[出典: https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort)）。

### 7.13 hook間で共有する一時ファイルにはTTLを持たせる

複数のhookやSkillの実行をまたいで一時ファイル（`/tmp/claude-skill-ctx-*`等）で状態を引き継ぐ設計にすると、前回の処理が正常終了せずファイルが残留した場合、後続の無関係な処理がそれを誤って読んでしまう。対策はファイルのmtimeを見て、一定時間（実践例では30分）より古ければ無視すること（[出典: https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort)）。

### 7.14 hookスクリプトのパスを環境変数で組み立てる時の罠

`$SKILLS_DIR/xxx/script.sh`のように、未定義になりうる環境変数でパスを組み立てると、変数が空文字列に展開された場合に意図しない絶対パス（`/xxx/script.sh`）になり、exit code 127（コマンドが見つからない）で静かに失敗することがある。対策は`$HOME`や`$CLAUDE_PROJECT_DIR`のような、Claude Code起動時に必ず値が入っている変数をベースに絶対パスを組み立てること（[出典: https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort)）。

### 7.15 settings.jsonの丸ごと上書きで既存hooksが消える

Stop hook等を新規追加する際、既に`hooks`キーが存在するsettings.jsonに対して、ツール（またはClaude自身）がファイル全体を生成し直すような編集をすると、既存の別イベント（自動フォーマットやログ記録等）のhooks設定を意図せず消してしまうことがある。対策は3.2節・hooks-guide.mdが述べる通り、既存の`hooks`オブジェクトに新しいイベント名を**兄弟キーとして追加する**こと（丸ごと置き換えない）（[出典: https://zenn.dev/lumichy/articles/claude-code-stop-hook-sound-2026](https://zenn.dev/lumichy/articles/claude-code-stop-hook-sound-2026) / [hooks-guide.md](https://code.claude.com/docs/en/hooks-guide.md)）。

### 7.16 hookの中からclaudeコマンド（AIそのもの）を呼ぶと即座に無限ループになる

`Stop`や`SubagentStop`の中で`claude`コマンドを呼び出す（＝AIの応答をAI自身のhookからさらに呼ぶ）設計は、極めて起きやすい無限ループの原因として複数の実践者が独立に警告している。

- syu-m-5151氏（2025-07-14公開）は、「ファイルを編集するたびに新しいClaude Codeのセッションを起動しようとして、それがまたファイルを編集して…という連鎖反応を起こしかけた。すぐに気づいてCtrl+Cで止めた」という一次体験を報告している（[出典: https://syu-m-5151.hatenablog.com/entry/2025/07/14/105812](https://syu-m-5151.hatenablog.com/entry/2025/07/14/105812)）。
- nanasess氏（2025-07-04公開）も同様に「`Stop`や`SubagentStop`の中で`claude`コマンドをコールすると、hookが無限ループしてしまいます」と警告し、回避策として`gemini`等の別のLLM CLIを使うことを提案している（具体的な実装例までは示されていない。[出典: https://zenn.dev/nanasess/articles/claude-code-notifications-hook-to-slack](https://zenn.dev/nanasess/articles/claude-code-notifications-hook-to-slack)）。

これは7.2節の`stop_hook_active`チェックだけでは防ぎきれない種類の危険で、そもそも「hookからAI CLIそのものを再帰的に呼ばない」という設計上の原則として扱うべきである。

### 7.17 全イベントに仕込むと見通しが悪化する

76Hata氏の記事（2026-03-13公開・2026-03-14更新）は、「すべてのイベントにhookを仕込むと、設定の見通しが悪くなりデバッグも困難になる」として、本当にブロックが必要なケースに絞って導入することを勧めている。実務上の使い分けとして、危険操作のブロックや自動フォーマットのような「操作制御系」は同期実行（`async: false`）、イベント記録や外部API通知のような「ログ・通知系」は非同期実行（`async: true`）にするという整理も示している。またexit codeについて「0=許可、1=hook自体のバグ（Claudeは処理継続）、2=意図的な操作ブロック」という規約を明示しており、**意図的なブロックには必ず2を使い、1（バグ）と2（意図的拒否）を混同しない**という注意は他記事では見られなかった観点（[出典: https://qiita.com/76Hata/items/81fed794acef9adb82c6](https://qiita.com/76Hata/items/81fed794acef9adb82c6)）。

### 7.18 無限ループのコスト実害（伝聞情報。信頼度は低い）

note.com（taku_sid氏、2025-07-09公開）は、hookの無限ループによって1日あたり$3,600ものAPIコストが発生したという事例に言及している。ただし検証の結果、この記事は**AIエージェントが執筆し飼い主が検証したという体裁**であり、どのhook設定が原因だったか・いつ気づいたか・どう対処したかという一次情報が本文になく、Reddit投稿やYouTube動画への伝聞的な言及にとどまっている。「無限ループがコスト面でも実害になりうる」という警鐘そのものは、7.3節（8回ブロック上限）・7.16節（claudeコマンド呼び出し無限ループ）と方向性が一致するため紹介するが、**この記事単体を実証的根拠として扱うべきではない**（[出典: https://note.com/taku_sid/n/n5aeafca98c73](https://note.com/taku_sid/n/n5aeafca98c73)。信頼度: 低）。

### 7.19 今回の調査で見つからなかったこと（正直な限界）

- **resume時のadditionalContext再生・並列実行の非決定性**は、公式ドキュメント（4.3節・7.5節）には明記があるが、今回検索した日本語実践者記事の範囲では、これらを実際に体験した・検証したという言及は見つからなかった。
- **LINE通知の実装記事**（ユーザー自身の`session-daily-log`等ではLINE通知を使っているが）は、今回の検索範囲では日本語圏の実践者記事として見つからなかった。Slack・macOS通知・ntfy.sh経由のスマホ通知の実例はあった。
- matcherの評価規則（空文字は全マッチ・プレーン文字列は完全一致・`|`区切りでOR・それ以外は正規表現・大文字小文字を区別する等）を扱っているとみられる記事（[zenn.dev/tmasuyama1114のmatcher解説ページ](https://zenn.dev/tmasuyama1114/books/claude_code_basic/viewer/hooks-matcher)）が検索結果に挙がったが、本文までは確認できていない。3.3節の記述は公式ドキュメント（hooks.md/hooks-guide.md）のみを一次情報として書いており、この記事固有の追加情報は反映していない。

---

## 8. 編集とデバッグの方法

### 8.1 設定変更の反映タイミング

settings.jsonを直接編集した場合、通常はファイルウォッチャーが自動的に変更を検知して反映する。数秒待っても`/hooks`に反映されない場合は、セッションを再起動すると確実（[出典: hooks-guide.md「/hooks shows no hooks configured」](https://code.claude.com/docs/en/hooks-guide.md)）。

一方、**スクリプト本体（`.claude/hooks/*.sh`等）の変更は即座に反映される**。settings.json側はコマンドのパスを指すだけなので、次にそのhookが発火した時には新しいスクリプト内容がそのまま実行される。これが「5章: 設定を小さく保つパターン」の実務上の利点でもある。手順書（md）を実行時に読み込む方式であれば、mdの編集すら即反映になる。

### 8.2 `/hooks`メニュー

`/hooks`コマンドで、設定済みの全hookをイベントごとの件数付きで一覧表示できる。個別選択するとイベント・マッチャー・type・ソースファイル・コマンドの詳細を見られる。ただし**読み取り専用**で、追加・変更・削除はsettings.jsonの直接編集（またはClaudeへの依頼）で行う（[出典: hooks-guide.md「Set up your first hook」](https://code.claude.com/docs/en/hooks-guide.md)）。

### 8.3 デバッグ

transcript画面（`Ctrl+O`で切替）には、発火した各hookの1行サマリが出る。成功時は無言、ブロック時はstderrが表示され、非ブロッキングエラー時は`<hook name> hook error`という通知の後にstderrの1行目が出る。

より詳細な実行内容（マッチしたhook・exit code・stdout・stderr全文）を見るには、デバッグログを使う。

```bash
claude --debug-file /tmp/claude.log
```

別ターミナルで`tail -f /tmp/claude.log`すれば、リアルタイムに追える。既にセッション起動済みで`--debug-file`を付け忘れた場合は、セッション中に`/debug`を実行することでログ出力を有効化し、ログパスを確認できる（[出典: hooks-guide.md「Debug techniques」](https://code.claude.com/docs/en/hooks-guide.md)）。

### 8.4 動作確認の簡易テクニック

hookスクリプトを実際にClaude Code経由で試す前に、サンプルJSONを直接パイプして手元で検証できる。

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | ./my-hook.sh
echo $?  # exit codeを確認
```

（[出典: hooks-guide.md「Hook error in output」](https://code.claude.com/docs/en/hooks-guide.md)）

---

## 9. 用語集

- **hook**: Claude Codeのライフサイクル上の特定タイミングで、モデルの意思とは無関係に必ず実行されるユーザー定義のシェルコマンド（またはHTTP/MCPツール/プロンプト評価）。
- **matcher**: hookをどのツール名・イベント種別に絞って発火させるかを決めるフィルタ条件。プレーン文字列は完全一致、それ以外は正規表現として評価される。
- **`if`フィールド**: `matcher`より細かく、ツールの引数まで見てフィルタする条件（権限ルール構文）。ベストエフォートで、パース不能時はfail open。
- **exit code 2**: hookが処理をブロックする合図。stderrに書いた理由がClaudeへフィードバックされる。
- **`decision: "block"`**: exit 0 + JSON出力で使う、イベント処理をブロックする明示的な指示。`reason`とセットで使う。
- **`additionalContext`**: hookの出力からClaudeのコンテキストへ追加できるテキスト。system reminderとして平文でモデルに読まれる。
- **`stop_hook_active`**: `Stop`イベントの入力に含まれるフラグ。直前のStop hookのブロックによって強制継続させられている最中かどうかを示す。無限ループ防止の判定に使う。
- **CLAUDE_CODE_STOP_HOOK_BLOCK_CAP**: `Stop`hookが連続ブロックできる回数の上限を決める環境変数（既定8）。
- **CLAUDE_PROJECT_DIR**: hook実行時に常に設定される、プロジェクトルートを指す環境変数。settings.json内でパス指定に使う。
- **CLAUDE_ENV_FILE**: `SessionStart`/`Setup`/`CwdChanged`/`FileChanged`イベントのhookでのみ使える、後続のBashコマンド実行前に読み込まれる環境変数ファイルへのパス。
- **exec form / shell form**: command hookの実行方式。`args`指定時はシェルを介さない直接実行（exec form）、省略時は`sh -c`等を介した実行（shell form。パイプ・グロブが使える）。

---

## 参照記事一覧

### 公式（一次情報）

- [Hooks reference](https://code.claude.com/docs/en/hooks.md) — 全イベントスキーマ、JSON入出力仕様、matcher、hook type別設定の詳細リファレンス
- [Automate actions with hooks (hooks-guide)](https://code.claude.com/docs/en/hooks-guide.md) — 実践的な設定例、デバッグ方法、落とし穴（8回ブロック上限・JSON汚染等）を含む導入ガイド

### 実践者記事（日本語圏、本文を確認したもの）

- [Claude CodeのStop hookで無限ループを防ぐ](https://qiita.com/ohakutsu/items/bc97ebfdc87877b94561) — Qiita、ohakutsu氏。`stop_hook_active`実装コードと`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`。信頼度: 中（実行検証の記載は薄い）
- [Claude Codeの「すぐルール忘れる問題」をHooksで解決する](https://zenn.dev/kazuph/articles/483d6cf5f3798c) — zenn.dev、kazuph氏、2025-07-03。Stop hookで完了ガード、スクリーンショット付きで動作確認あり。信頼度: 高
- [Claude Codeのhook通知、イベントごとに音を変えたら快適だった](https://zenn.dev/shivase/articles/020-claude-code-team-notification) — zenn.dev、shivase氏、2026-02-20/26。4イベントでの通知音使い分け、jq/python3フォールバック。信頼度: 高
- [Claude Code Hooks完全ガイド — 開発ワークフローを自動化する18イベントの活用法](https://qiita.com/kai_kou/items/2250545254288e6cca6d) — Qiita、kai_kou氏。網羅的だが検証形跡は薄い。信頼度: 中〜低
- [Claude Code hooksについて解説してみる](https://dev.classmethod.jp/articles/claude-code-hooks-basic-usage/) — DevelopersIO（Classmethod）、2025-07-06/07。シェルセッション非継承の実証、pstree検証、著者自身のハルシネーション注記あり。信頼度: 非常に高い
- [Stop Hookで完了音を鳴らす](https://zenn.dev/lumichy/articles/claude-code-stop-hook-sound-2026) — zenn.dev、lumichy氏、2026-06-01。Windows PowerShell実装例、settings.json丸ごと上書き事故、JSONバックスラッシュ4重エスケープ。信頼度: 中
- [Stop HooksとBiome v2でルールを強制する](https://suntory-n-water.com/blog/enforce-rules-with-stop-hooks-and-biome-v2) — suntory-n-water、2025-12-07。無限ループの実体験、`set -o pipefail`、settings.json肥大化をpackage.json集約で回避、TypeScript実装公開。信頼度: 高
- [Stop Hooksによる連鎖ワークフロー](https://zenn.dev/azumag/articles/00b36e074ac220) — zenn.dev、azumag氏、2025-07-07/11。`decision:block`のreasonに終了フレーズを埋め込みtranscript解析で連鎖制御、再帰リミットのリスク、実装repo `azumag/cc-gc-review`公開。信頼度: 高
- [settings.json運用の罠（半年運用）](https://www.playpark.co.jp/blog/claude-code-settings-json-permissions-hooks-effort) — playpark、2026-05-15。exit 127・exit code誤読・stateファイルTTL・「実行可能なドキュメント」哲学。具体的な失敗数値を伴う実運用記録。信頼度: 高
- [mv/sed上書き防止フック集](https://qiita.com/amanity-haray/items/55b5fb9ebb403ea02ff3) — Qiita、amanity-haray氏、2026-07-02。「CLAUDE.mdは確率的、hooksは確定的」、破壊的操作防止の具体スクリプト。信頼度: 中
- [Claude Code Hooks実践パターン集](https://qiita.com/76Hata/items/81fed794acef9adb82c6) — Qiita、76Hata氏、2026-03-13/14。チーム共有/個人設定分離、exit code規約(0/1/2の使い分け)、async使い分け、「全イベントに仕込むな」という警告。信頼度: 中
- [Hooksでルールを強制する（グローバル/プロジェクト分離、claudeコマンド呼び出し禁止）](https://syu-m-5151.hatenablog.com/entry/2025/07/14/105812) — hatenablog、syu-m-5151氏、2025-07-14。hook内から`claude`コマンドを呼んで無限ループになりかけた一次体験（Ctrl+Cで停止）。信頼度: 高
- [Slack通知＋Claude要約](https://zenn.dev/nanasess/articles/claude-code-notifications-hook-to-slack) — zenn.dev、nanasess氏、2025-07-04。`Stop`/`SubagentStop`内での`claude`コマンド呼び出しは無限ループになると警告、別LLM CLI（gemini等）を提案。信頼度: 中
- [$3,600/日の暴走という報告](https://note.com/taku_sid/n/n5aeafca98c73) — note.com、taku_sid氏、2025-07-09。AIエージェントが執筆し飼い主が検証という体裁で、一次情報に乏しい伝聞記事。信頼度: 低
- [三層ゲート設計（Hooks/Deny/Permission mode/Allow/canUseTool）](https://zenn.dev/ino_h/articles/2026-05-07-claude-code-gate-mechanisms) — zenn.dev、ino_h氏、2026-05-07。公式ドキュメントの評価順序・サブエージェントの権限継承ルールを整理。公開日が調査時点より先行しており内容の再検証が必要な点に留意。信頼度: 中
- [パスフレーズ方式の品質ゲートの脆弱性と直接判定方式への移行](https://qiita.com/takahirom/items/16fd60f611e52410e928) — Qiita、takahirom氏、2025-08-03/04。キーワード検知方式がバイパスされる実例、`Final Result: APPROVED/REJECTED`直接チェックへの切り替え。信頼度: 高

### 実践者記事（タイトルのみ確認・本文未確認、候補として記録）

- [Claude Codeの新機能「Hooks」イベントトリガーとコマンド実行の解説](https://zenn.dev/buddypia/articles/99abea47607225)
- [Claude CodeのHooksとは？ライフサイクルイベントで処理を自動化する](https://zenn.dev/tmasuyama1114/books/claude_code_basic/viewer/what-is-hooks)
- [Claude CodeのHooks matcher解説ページ](https://zenn.dev/tmasuyama1114/books/claude_code_basic/viewer/hooks-matcher) — matcherの評価規則（完全一致/正規表現/大文字小文字区別等）を扱っているとみられるが本文未確認
- [Claude Code の新機能 Hooks 使って通知しよ！](https://zenn.dev/kiva/articles/66f40dccf504bf)
- [Claude Codeのhooksで危険コマンドを自動ブロックする — テスト21件全PASSの3つのレシピ](https://zenn.dev/seeda_yuto/articles/claude-code-hooks-practical-guide)
- [How to Use Claude Code Hooks | Setup Guide and 5 Practical Examples for Work](https://note.com/ai_jissennkai/n/n55b3dea07765?hl=en)
- [settings.json完全リファレンス](https://note.com/ryo_ailab/n/n360c16f2e096)
- [【Claude Codeセキュリティ設定】setting.json, CLAUDE.md, Hooksの活用法](https://note.com/rindesign/n/ne2cd7fac6447)
- [Claude Code Hooks試してみた](https://note.com/kamechan_usagi/n/nc55a57d50c88)
- [How Claude Code stop hooks work](https://amitkoth.com/claude-code-stop-hooks/)
- [GitHub: disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery)
- [型チェック/ESLint/Prettier/rm-rf防御など15のhook集](https://qiita.com/kawabe0201/items/3fcf698abe60d57b211b) — 本文は6.12節で簡潔に要約済み
- [Slack通知（matcher試行錯誤）](https://qiita.com/har1101/items/4097bee8c98abedd3117) — 本文は6.12節で簡潔に要約済み
- [フォーマッタ自動実行](https://azukiazusa.dev/blog/claude-code-hooks-run-formatter/) — 本文は6.12節で簡潔に要約済み
- [ntfy.sh経由のスマホ通知](https://zenn.dev/keit0728/articles/bfb68f669755a7) — 本文は6.12節で簡潔に要約済み
- [SessionEnd/PreCompactでのCLAUDE.md更新提案](https://zenn.dev/91works/articles/4a32368ec94253) — 本文は6.12節で簡潔に要約済み

### 参考: 筆者自身の既存運用（一次情報として本文中で使用）

- `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/hooks/session-board/` — SessionStart/UserPromptSubmit/Stopの実運用実装。「スクリプトが正本mdを読んで注入する」パターンの実例。
- `~/.claude/settings.json` — 実際に登録されているhook構成（本ガイド作成時点の実機確認）。
