# Orca エージェントフック / サブエージェント 実務メモ

Orca（Stably AI の ADE）が **Claude Code のフックにどう相乗りし、設定をどう継承し、サブエージェント/Remote Control とどう関わるか** を、cockpit 運用者向けに1枚に固定する。Claude/Codex 汎用のフック仕様は複製せず、`../../../hooks-registry/references/claude-hooks.md` を参照する。ここは **Orca 固有部分だけ** を書く。

> 対象範囲: 2026-07-08 時点。Orca v1.4.123（`com.stablyai.orca`）＋ 公式ソース `github.com/stablyai/orca` ＋ ローカル `~/.orca/` ＋ Claude Code 公式 docs を突き合わせて確認。Orca は変化が速いので、実装前に実機・公式で再確認する。確定/未確認を各節で明示。

## 目次
- 0. 要点（先に結論）
- 1. Orca とは（最小）
- 2. フックの仕組み（Orca固有＝ブリッジ）
- 3. 設定の継承（Remote Control を含む）
- 4. サブエージェント / Agent Teams
- 5. Remote Control × Orca の注意
- 6. cockpit 運用への含意
- 7. 未確認（実装前に確認する）
- 8. 参照

## 0. 要点（先に結論）

- Orca は **独自のフックDSLを持たない**。実体は「Claude Code 純正の hooks に、Orca 管理のコマンドを"追記登録"するブリッジ」。
- 登録先は標準の `~/.claude/settings.json`。**`hooks` キーだけを浅くマージ**し、`remoteControlAtStartup` など他のトップレベルキーには一切触れない。
- だから **Remote Control も設定も `~/.claude/settings.json` に書けば、Orca 配下の全ペインが継承**する。**Orca 側に追加設定は不要**。
- Orca に「サブエージェント」概念は無い。あるのは他CLIの subagent の"観測"と、Claude 公式 **Agent Teams** の統合（**現行 cockpit は未使用**）。
- cockpit の見張り番（`watch.sh`）が読む `orca worktree ps --json` の状態は、**このフックブリッジが集めたデータが出典**。＝ Orca の agent-hooks が未インストールだと監督が機能しない。

## 1. Orca とは（最小）

- **開発元/実体**: Stably AI の ADE（Agent Development Environment）。Electron アプリ＋CLI。`/Applications/Orca.app`、CLI は `~/.local/bin/orca`（App バンドル内 `Contents/Resources/bin/orca` への symlink）。
- **役割**: claude / codex / cursor / gemini / copilot / opencode ほか30種超の CLI コーディングエージェントを、**git worktree 単位で分割ペイン実行**する。
- **公式**: `github.com/stablyai/orca`（public・TSソースが読める）／ `onorca.dev`／ README 日本語版 `docs/readme/README.ja.md`。
- **cockpit との接点**: `orca terminal ...`（ペイン起動）、`orca worktree ps --json`（`watch.sh` / renderer が毎tick読む監視源）。

## 2. フックの仕組み（Orca固有＝ブリッジ）

Orca のフックは「Orca 独自機構」ではなく、**Claude 純正 hooks への相乗り**である。

- **登録処理（`ClaudeHookService.install()`）**: `~/.claude/settings.json` を読み、下記7イベントに Orca 管理コマンド1行を追記する。既存の同一スクリプトパスの古い行だけを検出・置換し、**ユーザー独自エントリ（session-board 等）は温存**。`.bak` バックアップ付きのアトミック書き込みで保存。
- **登録される7イベント**: `UserPromptSubmit` / `Stop` / `StopFailure` / `PreToolUse`(matcher `*`) / `PostToolUse`(matcher `*`) / `PostToolUseFailure`(matcher `*`) / `PermissionRequest`(matcher `*`)。**`SessionStart` は対象外**。
- **`claude-hook.sh` の中身**: stdin の hook ペイロードを読み、`ORCA_AGENT_HOOK_PORT` / `ORCA_AGENT_HOOK_TOKEN` / `ORCA_PANE_KEY`（env・名前のみ）が揃う時だけ `http://127.0.0.1:${PORT}/hook/claude` へ POST する薄いプロキシ。揃っていなければ即 `exit 0`（非ブロッキング）。
- **受け手**: Orca デーモンのローカル HTTP リスナーがイベント（ツール名・入力プレビュー・最後の assistant 発話・waiting 状態など）を正規化し、ペインの **idle / working / waiting / error** 表示に変換する。
- **12エージェント分が同型**: `~/.orca/agent-hooks/` に `claude` `codex` `gemini` `copilot` `cursor` `antigravity` `droid` `devin` `grok` `kimi` `openclaude` `command-code` のプロキシが1本ずつ。CLI ごとに `*HookService` が対応。
- **設定方法**: Orca の **Settings UI**（IPC 経由 install / remove / getStatus、状態は `installed` / `partial` / `not_installed` / `error`）。**CLI サブコマンドは非公開**（`orca agent-hooks ...` は "Unknown command"）。＝スクリプトから叩けない、GUI 管理。
- **session-board との共存**: 同じ `~/.claude/settings.json` 内で、personal-os の session-board フックと Orca の `claude-hook.sh` は、matcher の異なる別行として独立共存する（実物で確認済み）。互いに上書きしない。

## 3. 設定の継承（Remote Control を含む）

**結論（1文）**: Orca は通常ペインで `claude` を素の設定で起動するため、`remoteControlAtStartup: true` を `~/.claude/settings.json` に1回書けば **Orca 配下のどのペインでも継承**され、**Orca 側の追加設定は一切不要**。

- **起動コマンド**: cockpit は `claude [--model M] [--permission-mode P] [--strict-mcp-config --mcp-config <empty.json>]` を組み立てるだけ（`scripts/cockpit.sh` の `cmd_agent()`）。**`--settings` 差し替えも HOME 上書きもしない**。Orca 本体側も通常ペイン経路で HOME / `CLAUDE_CONFIG_DIR` を書き換えない。
- **例外は非適用**: `CLAUDE_CONFIG_DIR` を触るのは Orca 内部のヘッドレス用途2箇所（AIコミットメッセージ生成・裏の利用量チェック）だけで、**ユーザーが見るペインの claude には適用されない**。
- **Orca は RC キーを関知しない**: Orca ソース全文検索で `remoteControlAtStartup` は0件。Orca が触るのは `hooks` キーのみ（浅いマージ）で、他のトップレベルキーは素通し。
- **注意**: 自動接続が毎回効くかは **Claude Code 本体の既知不具合**（`anthropics/claude-code#54527`・`#29929`）次第で、**Orca 起因ではない**。確実性を求めるなら `/config` トグル or `claude --remote-control` 明示起動（§5）。

## 4. サブエージェント / Agent Teams

- **Orca 独自のサブエージェント概念は無い**。cockpit の「ペイン / ワーカー」= worktree 内の terminal であって、Orca のサブエージェントではない。
- **観測するだけ**: Claude の Task tool が生む subagent は `SubagentStart` / `SubagentStop`（Claude 純正イベント）で発火する。Orca はそれを受けて UI の権限確認表示が混線しないよう `toolUseId` / `agentId` で名寄せする配線を持つのみ。※この2イベントは **現状 `~/.claude/settings.json` に未登録**（Orca が登録するのは§2の7イベント）。
- Codex の `/subagents` は **Codex 純正コマンド**を Orca のコマンドパレットに列挙しているだけ。Orca の機能ではない。
- **Claude 公式 "Agent Teams"（実験的・`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`）** は Orca が「Claude Agent Teams」エージェント種別として統合済み（偽 tmux ブリッジで teammate を Orca ネイティブペインに描画）。**ただし `cockpit.sh` の `cmd_agent()` は `claude|codex|opencode` の3種のみ対応で Agent Teams 分岐は無い ＝ 現行 cockpit 運用では未使用**。

## 5. Remote Control × Orca の注意

RC（Claude 純正の Remote Control）は「ローカルの claude プロセスに Web/モバイルから接続する」機構で、通信は outbound HTTPS のみ。pty / tmux / 素ターミナルの別を問わず動く。cockpit で使うなら次を前提にする。

- **1インタラクティブプロセス＝1 RCセッション**: cockpit の各ペインは別プロセスなので、ペインごとに **別々の RC セッション**が claude.ai/code・モバイルに並ぶ（ペイン間で共有されない）。
- **プロセスが生きている間だけ**: `cockpit.sh down` / `orca terminal stop` でペインの claude を落とすと、そのペインの RC セッションはその場で終了する。
- **Ultraplan は RC を切断**: 同じ claude.ai/code の1枠を取り合うため、ペイン内で Ultraplan を使うとそのペインの RC が切れる。
- **用語の混同に注意**: Orca 自身の「モバイルから遠隔操作」（`orca serve --mobile-pairing` / `orca environment add --pairing-code` 等）は **Orca アプリを遠隔操作する別物**で、Claude 純正 RC とは無関係。マニュアル・会話で混ぜない。

## 6. cockpit 運用への含意

- **監督はフック依存**: 見張り番 `watch.sh` の監視源 `orca worktree ps --json` の `agents[].state` / `lastAssistantMessage` は、§2のフックブリッジが集めたデータ。**Orca の agent-hooks が未インストール（Settings で `installed` でない）だと、監督（idle/working/waiting 検知）が機能しない**。
- **RC を cockpit で使うなら**: 「ペイン数だけ RC セッションが立つ」前提で。スマホからは各ペインを個別セッションとして見る形になる。

## 7. 未確認（実装前に確認する）

- Orca Settings の「Agent Hooks」パネルの正式表示名、初回インストールのトリガー（手動クリック or 起動時プロンプト）。
- 生 JSON の `remoteControlAtStartup` と `/config` の "Enable Remote Control for all sessions" トグルが同一経路か別経路か。
- cockpit 2ペイン構成で、実際に RC セッションが2つ立つかの実機検証。
- Orca の pty hibernate / デーモン再起動が、稼働中の RC セッションを切断するか。

## 8. 参照

- **Orca**: `github.com/stablyai/orca` ／ `onorca.dev` ／ `docs/readme/README.ja.md`
- **Claude Remote Control**: `code.claude.com/docs/en/remote-control`
- **Claude Agent Teams**: `code.claude.com/docs/en/agent-teams`
- **RC 既知不具合**: `anthropics/claude-code#54527`（settings で自動接続しない）・`#29929`（`/config` トグルが永続化されない）
- **汎用フック仕様（複製しない・リンクで参照）**: `../../../hooks-registry/references/claude-hooks.md`
- **実体**: `~/.orca/agent-hooks/claude-hook.sh`、`scripts/cockpit.sh`（`cmd_agent()`）、`scripts/watch.sh`
- **調査経緯**: 2026-07-08 の会話（Sonnet 5 サブエージェント2体・ローカル＋公式ソース突き合わせ）。この md が Orca フック/サブエージェントの現時点の集約点。
