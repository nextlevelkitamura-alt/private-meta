# Codex Hooks 実務リファレンス

Codex CLI の hooks とサブエージェントをカスタマイズするための恒久リファレンス。
Claude 版（`claude-hooks.md`）と対になり、両者の比較・設計は `claude-vs-codex-hooks.md` にまとめる。同じ調査を繰り返さないよう、公式ドキュメントとローカル確認結果をミクロまで整理する。

> 対象範囲: 2026-07-06 時点、公式（developers.openai.com/codex の hooks / subagents / config）と `codex-cli 0.142.5` のローカル確認に基づく。Codex は変化が速いため、細かい仕様は実装前に公式で再確認すること。

## 1. 概要

Codex には、ライフサイクルに処理を差し込む仕組みが2つある。

- `hooks`: セッション開始、ユーザープロンプト送信、ツール使用前後、権限要求、停止、サブエージェント、圧縮前後など、複数イベントに応じてコマンドを実行できる仕組み。コンテキスト注入や、処理のブロック・誘導ができる。
- `notify`: ターン完了時だけに発火する軽量通知。基本的に外部通知向けで、出力は無視される。

## 2. hooks と notify の使い分け

イベントごとの情報を取りたい、Codex に文脈を注入したい、処理を止めたり誘導したい場合は `hooks` を使う。

単に「1ターン終わった」ことを外部通知したいだけなら `notify` で足りる。ただし `notify` は1枠しかなく、既に別クライアント（このマシンでは Computer Use client の可能性）に使われていることがある。競合を避けるなら `Stop` hook を優先する。

入出力も違う。`hooks` は stdin から JSON を読み、stdout に JSON を返せる。`notify` は JSON を argv[1] で受け取り、出力は無視される。

## 3. 設定できる hook イベント（10）

公式が列挙するのはこの10イベント。

- `SessionStart`: セッション開始、再開、クリア、圧縮後の再開。
- `UserPromptSubmit`: ユーザーがプロンプトを送信した時。
- `PreToolUse`: Bash、`apply_patch`、MCP ツールの実行前。
- `PermissionRequest`: Codex が権限承認を求める時。
- `PostToolUse`: ツール実行後。
- `SubagentStart`: サブエージェント開始時。
- `SubagentStop`: サブエージェント停止時。
- `Stop`: メインターン停止時。
- `PreCompact` / `PostCompact`: 会話圧縮の前後。

### 3.1 matcher が効く対象

`matcher` は正規表現。省略・空文字・`*` は全一致。イベント別の対象は次の通り。

- `PreToolUse` / `PostToolUse` / `PermissionRequest`: tool名（`Bash` / `apply_patch` / `Edit` / `Write` / MCP名）。
- `PreCompact` / `PostCompact`: `manual` / `auto`。
- `SessionStart`: `startup` / `resume` / `clear` / `compact`。
- `SubagentStart` / `SubagentStop`: サブエージェントの型。
- `UserPromptSubmit` / `Stop`: matcher は無視される。

ツール hook が拾うのは Bash・`apply_patch`・MCP ツールが中心。通常のファイル書き込みすべてを拾えるわけではない。WebSearch などは対象外として考える。

## 4. command hook の入力仕様（stdin JSON）

現在実行されるのは `type: "command"` の hook のみ。**`prompt` と `agent` は解析されるが実行されない。`async: true` も未対応でスキップされる**。高度な判定をしたい場合は、hook から Python/Node/Bash を呼び、そのスクリプト側で判定する。

hook コマンドは、そのセッションの `cwd` を作業ディレクトリとして実行される。

入力は stdin に渡される1つの JSON オブジェクト。共通フィールドには `session_id`・`cwd`・`hook_event_name`・`model` があり、多くは `permission_mode`、ターン系は `turn_id` を含む。

```python
import sys, json
d = json.load(sys.stdin)
sid, cwd, ev = d["session_id"], d["cwd"], d["hook_event_name"]
```

終了コードは、`0` が成功、`2` がブロック（stderr の内容が理由として扱われる）、その他の非ゼロが hook エラー。環境変数で情報が渡る前提は置かず、stdin の JSON を読む。

## 5. 出力と制御（stdout JSON）

hook は stdout に JSON を返せる。

- **コンテキスト注入**: `additionalContext`（developer context として注入）または `systemMessage`（UI 警告）。
- **停止・誘導**: `continue: false` ＋ `stopReason`。古い形式として `decision: "block"` ＋ `reason` もある。終了コード `2`＋stderr でもブロックできる。
- **権限判定**: `PreToolUse` / `PermissionRequest` は `permissionDecision: "deny" | "allow"`。

継続を扱える主なイベントの共通出力: `continue` / `stopReason` / `systemMessage` / `suppressOutput`。

### 5.1 Stop と SubagentStop の注意（重要）

`Stop` と `SubagentStop` はブロックや継続判断はできるが、**`additionalContext` は注入できない**。文面を返したい場合は `reason` / `stopReason` 経由にする。

- **`Stop` の `decision:"block"` は「ターン拒否」ではない**。Codex に「続行せよ」と伝え、`reason` を**新しい継続プロンプト**（ユーザープロンプト相当）として自動生成する。誘導文＝次に何をさせたいか、を `reason` に書く。
- **`SubagentStop`**: `{"decision":"block","reason":"…"}` でサブエージェントを続行させる。`systemMessage` はサブエージェント向けの文脈として足せる。

## 6. 設定の読み込み順とフォルダ

hooks は次の順で読み込まれる。上位が下位を置き換えるのではなく、条件に一致する hook はすべて実行される（マージ型）。

1. `~/.codex/hooks.json`（user）
2. `~/.codex/config.toml` の `[hooks]`（user）
3. `<repo>/.codex/hooks.json`（project・trust 必要）
4. `<repo>/.codex/config.toml` の `[hooks]`（project・trust 必要）
5. plugin 同梱の hooks
6. `requirements.toml` の管理 hook（system / MDM・後述）

同じ層に `hooks.json` と `[hooks]` の両方があると、警告付きで両方読み込まれる。

### 6.1 書き方（2形式）

`hooks.json` の形:

```json
{ "hooks": { "SessionStart": [ { "matcher": "startup|resume",
  "hooks": [ { "type": "command", "command": "python3 ~/.codex/hooks/x.py",
              "statusMessage": "...", "timeout": 600 } ] } ] } }
```

TOML で書く場合（`config.toml` の `[hooks]`）:

```toml
[[hooks.SessionStart]]
matcher = "startup|resume"
[[hooks.SessionStart.hooks]]
type = "command"
command = "python3 ~/.codex/hooks/x.py"
timeout = 600
```

`command` を絶対パスまたは `$(git rev-parse --show-toplevel)` 基準にして、cwd に依存しないようにする。

## 7. 有効化と信頼（trust）

hooks は `[features] hooks = true` で有効（デフォルト有効・`false` で全 hook 無効）。

管理外の command hook は、実行前に Codex 側で確認・信頼登録が必要。**信頼状態は hook の SHA ハッシュに紐づくため、hook を1文字でも変更すると再レビューが要る**。

- 確認と信頼登録は `/hooks` コマンド。信頼状態は `~/.codex/config.toml` の `[hooks.state]` に保存される。
- `requirements.toml` の管理 hook（system / MDM 配布）は**事前に信頼済み**で、ユーザーが無効化できない。
- 1回だけ trust を飛ばすなら `--dangerously-bypass-hook-trust`（名前どおり危険。常用しない）。

## 8. サブエージェント & カスタムエージェント

### 8.1 定義（`.codex/agents/*.toml`）

> **注記（2026-07-10 実機検証）**: この `.codex/agents/*.toml` 方式は codex-cli 0.142.5 の実機では確認できなかった（`~/.codex/agents/` 不在・CLIヘルプ/doctor/バイナリに読み込み痕跡なし）。§8.1〜8.2 は公式ドキュメント由来の記述として残すが、実装前に現バージョンでの有効性を必ず確認すること。ClaudeからCodexへの委任は `codex exec --json`＋`exec resume` が実機確認済みの経路（`skills/custom-agent-creator/references/codex.md` §7）。

1ファイル1エージェント。標準の Codex セッション設定と同じキーを上書きできる。置き場所は user が `~/.codex/agents/`、project が `<repo>/.codex/agents/`。

```toml
name = "reviewer"
description = "PR reviewer focused on correctness, security, and missing tests."
model = "gpt-5.5"
model_reasoning_effort = "high"
sandbox_mode = "read-only"

developer_instructions = """
You are a strict code reviewer. Do not edit files.
Prioritize correctness, security, regressions, missing tests. Cite concrete files.
"""
```

### 8.2 対応フィールド（公式確認）

- 必須: `name`（識別子）／`description`（いつ spawn すべきか）／`developer_instructions`（固定プロンプト）。
- 任意: `model`／`model_reasoning_effort`／`sandbox_mode`（調査・レビューは `read-only` にしやすい）／`nickname_candidates`（表示名の候補配列）／`mcp_servers`（ツール面）／`skills.config`（skill 定義）。
- その他、通常の `config.toml` キーも書ける。

### 8.3 呼び出し方（明示 spawn）

**Codex は明示的に頼んだ時だけ subagent を spawn する**。`AGENTS.md` に「subagent を使え」と書くだけでは安定しない。プロンプトで明示するか `/agent` CLI を使う。依頼後の spawn・追指示のルーティング・結果待ちは Codex が自動でオーケストレーションする。

```text
このタスクは subagents を使ってください。
explorer / worker / reviewer を spawn し、各結果を待ってから main が統合してください。
```

### 8.4 並列の設定（`config.toml` の `[agents]`）

- `max_threads`: 同時に開くエージェントスレッド上限（既定 6）。
- `max_depth`: spawn の入れ子深さ（既定 1）。
- `job_max_runtime_seconds`: CSV ジョブのワーカー既定タイムアウト。

### 8.5 hook との関係

`SubagentStart` → 🔵、`SubagentStop` → 🟢 のように、サブエージェント稼働を自動で記録できる（Codex は自動 flip・Claude の自己申告に相当）。複数サブエージェントが同時に動く可能性があるため、`agent_id` で参照カウントするのがよい。

## 9. 最低限のルール（床）を Codex に守らせる

Claude と揃える共通の床。Codex には prompt 型が無いので、判定はすべて command hook のスクリプト側で行う（`claude-vs-codex-hooks.md` §3 と対応）。

- **危険コマンド block**: `PreToolUse`（matcher=`Bash|apply_patch`）→ スクリプトで `rm -rf` / force push 等を検知し `permissionDecision:"deny"` か終了コード `2`。
- **開始文脈**: `SessionStart` → `additionalContext` で状態・作業ルールを注入。
- **返却フォーマット**: `SubagentStart` → 共通書式（Summary / Evidence / Risks / Next）を注入。
- **薄い結果のやり直し**: `SubagentStop` → 必須節が欠けたら `decision:"block"`＋`reason` で続行（`stop_hook_active` を見て無限ループ防止）。
- **完了確認**: `Stop` → 変更 / テスト / リスク / 次 が揃わなければ `decision:"block"`＋`reason`（＝継続プロンプト）で促す。
- **secret を出さない・非ブロッキング**: 値は書かずポインタのみ。内部失敗で本体を止めない。

Codex 側は prompt/agent hook が無いぶん、床は command hook で堅く作り、便利機能（節目判定・agent別hook・worktree隔離）は Claude 側に寄せる。

## 10. notify

`notify` は `config.toml` に `notify = ["program", "arg", ...]` として設定する。発火するのは `agent-turn-complete` のみ。payload は stdin ではなく argv[1] に JSON で渡され、出力は無視される。

```python
import sys, json
n = json.loads(sys.argv[1])
```

このマシンでは notify 枠が Computer Use client に使われている可能性がある。競合を避けるなら `notify` より `Stop` hook を優先する。

## 11. 注意点

- 現状は command hook のみ。Claude の prompt 型 hook のように、モデル判断で hook を動かす仕組みはない。
- `Stop` / `SubagentStop` ではコンテキスト注入できない。誘導は `reason` / `stopReason`（Stop の `block` は継続プロンプト化）。
- ツール hook が拾うのは Bash・`apply_patch`・MCP ツールなど。ファイル書き込みすべてではない。
- hook を編集するたびに `/hooks` で再信頼（SHA 変更で信頼が外れる）。
- `notify` はターン完了通知専用で、出力は無視される。
- subagent は明示 spawn が基本（自動起動を期待しない）。

## 12. 実装例の意味

`~/.codex/hooks.json` に `SessionStart`・`UserPromptSubmit`・`Stop` の3つを登録すれば、セッション開始時・ユーザー入力時・ターン停止時にそれぞれ Python スクリプトを実行できる。スクリプト側で stdin の JSON を読み、必要なら `additionalContext` を返して作業ルールやワークスペース文脈を注入する。`SubagentStart`／`SubagentStop` を足せば、サブエージェント稼働状態を記録できる。

## 13. Claude との違い（早見）

| 観点 | Codex | Claude Code |
|---|---|---|
| 登録場所 | `~/.codex/hooks.json`＋`config.toml`（マージ型） | `~/.claude/settings.json`（上書き型） |
| trust | 必須・`/hooks`・SHA紐付け | 不要・保存で自動反映 |
| hook の型 | command のみ | 5種（command/prompt/http/mcp_tool/agent） |
| Stop で文脈注入 | 不可（`reason` を継続プロンプト化） | 可（`additionalContext`） |
| subagent 呼び出し | 明示 spawn（`/agent`） | 自動委譲＋`@mention` |
| agent 定義 | `.codex/agents/*.toml` | `.claude/agents/*.md`（frontmatter） |

比較と「1ワークフローを2エージェントに従わせる」設計の全体像は `claude-vs-codex-hooks.md`。

## 14. 参照元

- 公式: Codex Hooks（https://developers.openai.com/codex/hooks）／Subagents（https://developers.openai.com/codex/subagents）／Advanced config・notify（https://developers.openai.com/codex/config-advanced）。
- 対の Claude 版: `claude-hooks.md`／比較: `claude-vs-codex-hooks.md`。
- ローカル確認: `~/.codex/config.toml`、`codex --help`、session-board 実装（`../session-board/codex/`）。
- 確認日: 2026-07-06（`codex-cli 0.142.5`）
