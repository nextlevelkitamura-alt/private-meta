# Claude × Codex hooks — 1ワークフローを2エージェントに従わせる（比較・概要）

Claude Code と Codex の hooks の違いと、**1つのワークフローを両エージェントに従わせる**ための概要。
ミクロの詳細は runtime 別に `claude-hooks.md`（Claude）／`codex-hooks.md`（Codex）へ委譲する。ここは比較と設計の地図に徹する（二重管理しない）。

> 対象範囲: 2026-07-06 時点。両 runtime とも変化が速いため、細かい仕様は実装前に各 runtime の詳細ref＋公式ドキュメントで再確認すること。

## 1. 方針（この2つを守る）

hooks は「イベント直後に決まった処理を挟む機構」。運用方針は2つ。

- **最低限のルールは Claude・Codex どちらにも守らせる**（共通の床）。安全と品質の土台は runtime に関係なく揃える。
- **Claude だけで拡張できる部分は便利機能として上乗せする**。無理に Codex へ移植しない。
- 入出力がほぼ同型（入力=stdin JSON／注入=`additionalContext`）なので、**イベント実行本体を1組だけ共通化し、登録表と出力形式だけをruntime別にする**と、同じワークフローを両方に従わせられる。実例が session-board。

## 2. 比較（8観点）

同型の入力と、型・trust・Stopの差が設計の要点。差分はruntime別Pythonを増やさず、登録表と出力形式に閉じる。

| 観点 | Claude Code | Codex |
|---|---|---|
| 登録場所 | `~/.claude/settings.json`（上書き型） | `~/.codex/hooks.json`＋`config.toml`（マージ型） |
| trust | 不要・保存で自動反映 | 必須・`/hooks` で信頼登録 |
| hook の型 | 5種（command/prompt/http/mcp_tool/agent） | command のみ実行（prompt/agent/async は skip） |
| prompt 型 | あり（session-boardでは未使用） | なし（型が非対応） |
| Stop で文脈注入 | 可（`additionalContext`） | 不可（`reason` を継続プロンプト化） |
| subagent 呼び出し | 自動委譲＋`@mention` | 明示 spawn（`/agent`） |
| agent 別 hook | frontmatter に記述（稼働中だけ有効） | matcher で agent 型に分岐 |
| matcher 対象 | tool名・agent型・source ほか | tool名・agent型・compact・source |

## 3. 床は両方に守らせ、Claudeの拡張は便利機能として上乗せ

まず両 runtime で必ず守る安全・品質の**床**を敷く。その上に Claude だけの拡張を**便利機能**として足す。床は必ず揃え、便利機能は無理に Codex へ移植しない。

### 3.1 床（最低限の共通ルール・Claude も Codex も）

- **危険コマンドを止める**: `PreToolUse` で `rm -rf` / force push / `git reset --hard` 等を deny。
- **開始時に前提を注入**: `SessionStart` で状態・作業ルールを渡す。
- **返却フォーマット**: `SubagentStart` で共通の書式（Summary / Evidence / Risks / Next）を注入。
- **薄い結果はやり直し**: `SubagentStop` で必須節が欠けていたら1回だけ再pass（`stop_hook_active` を見て無限ループを防ぐ）。
- **完了確認**: `Stop` で 変更／テスト・確認／リスク／次のアクション を確認。
- **secret を出さない・非ブロッキング**: 値は書かずポインタのみ。内部失敗で本体セッションを止めない。

### 3.2 上乗せ（Claude だけの便利機能）

- **agent 別 hook**: subagent の frontmatter に `hooks` を書け、そのサブエージェント稼働中だけ有効（frontmatter の `Stop` は実行時に `SubagentStop` へ自動変換）。
- **LLM 判定**: prompt / agent hook で曖昧なレビュー・完了判定をモデルに委ねられる。
- **worktree 隔離**: subagent frontmatter の `isolation: worktree` で並列作業を分離。
- **豊富な frontmatter**: `memory` / `maxTurns` / `background` / `effort` / `permissionMode` など（詳細は `claude-hooks.md`）。
- **呼び出しの自由度**: 自動委譲＋`@mention`＋session agent。

## 4. 設計パターン（1ワークフローを2エージェントに従わせる3層）

「両方に同じことをさせる」ために、実行Pythonをruntime別に写さない。共通正本を1組置き、登録表と出力形式だけで差分を吸収する。

- **層1: 共通の正本（runtime非依存）** — エンジンは `shared/session-board/`、イベント本体は `events/<イベント>/` に1つだけ持つ。各 `.py` には同名 `.md` を対に置く。
- **層2: runtime別の登録表** — Claudeは `~/.claude/settings.json` の `hooks` 項目から、Codexはrepoの `codex/hooks.json` から、同じ `events/*.py` を指す。Claudeのsettings全体はrepoへsymlinkしない。
- **層3: 差分の吸収（3点だけ）** — ①注入出力はClaude=plain text・Codex=JSON、②Claudeは保存で反映・Codexはhooks.jsonをsymlink露出、③Codexは `codex/trust-current.py` が現在hashを公式APIから取得して自動trustする。

実例: session-boardはこの3層で動く。`events/` がruntime実行本体、`shared/session-board/` が状態エンジン、`claude/` と `codex/` は登録規則・登録表の置き場である。

## 5. 導入4ステップ

最初からruntime別の実装を作り込まない。共通正本を1本通し、次に各runtimeの登録表をつなぎ、最後に出力・trust差分を確認する順が壊れにくい。

1. **共通正本を1つ書く** — エンジン `shared/` と、イベントごとの `.py` ＋同名 `.md` をruntime非依存で用意する。
2. **登録表をつなぐ** — Claudeのsettingsの `hooks` 項目とCodexのrepo `hooks.json` を、共通のイベントPythonへ向ける。
3. **差分3点を吸収** — 注入出力、登録方式、Codexのtrustをruntime別に確認する。実行Pythonは複製しない。
4. **実機で1回ずつ検証** — 開始🟢 / Stop⏸ / サブ🔵 を各 runtime で実測。Codexはhook編集後に自動trustとreadbackを実行する。

## 6. 使い分け（同じ流れの中で役割を割る）

どちらか一方に寄せるのではなく、1ワークフローの中で得意な工程を割り当てる。

- **Claude ＝ 設計・司令塔・品質ゲート**: 司令塔 agent、agent別hook、prompt/agent hook による LLM判定、worktree隔離。
- **Codex ＝ 実装・探索・明示並列**: explorer/worker/reviewer の明示 spawn、`.codex/agents/*.toml` で役割固定、並列探索の統合、command hook で最低限の安全・ログ・品質ゲート。

## 7. 参照元

- runtime別のミクロ詳細: `claude-hooks.md`（Claude Code）／`codex-hooks.md`（Codex）。
- 公式: Claude Code Hooks / Subagents / .claude directory（code.claude.com/docs/en）。Codex Hooks / Subagents（developers.openai.com/codex）。
- 実例: session-board（`../events/` のイベント本体、`../shared/session-board/` のエンジン、Claudeの `~/.claude/settings.json` と `../codex/hooks.json` の登録表）。
- 元資料: GDrive `claude_codex_hooks_subagents_manual_v1.md`（v1.0）を検証のうえ取り込み。マニュアルの Claude イベント一覧は未確認分を含むため、確定分のみ `claude-hooks.md` へ反映。
- 人間向け表示: フォルダの説明書は対応する `AGENTS.html` に派生表示を置く。正本は常に `AGENTS.md` とこのmdで、HTMLから実行導線を作らない。
- 確認日: 2026-07-06
