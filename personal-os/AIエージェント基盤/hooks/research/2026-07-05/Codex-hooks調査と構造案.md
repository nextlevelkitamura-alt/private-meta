# Codex hooks 調査と session-board 正本構造案（2026-07-05）

Codex（この環境＝Codex.app / `codex-cli 0.142.5` / model gpt-5.5）に session-board を載せるための調査。
リサーチ・サブエージェント委任は2回とも0ツール実行で失敗したため、直接調査した。

## 環境の実体

- バイナリ: `~/.npm-global/bin/codex`（`codex-cli 0.142.5`）／デスクトップ本体 `/Applications/Codex.app`。
- 純正ミニマルCLIではなく、plugins/marketplace・MCP・computer-use・browser・goals 等を持つ2026年版。
- `~/.codex/config.toml`: `notify = ["…SkyComputerUseClient","turn-ended"]`（Computer Useが専有）、`[hooks.state]`（空＝2026-07-04のhook撤去跡）、`[mcp_servers.*]` あり。
- 撤去前 `config.toml.bak-hook-cleanup-20260704-103813`: `notify` に `--previous-notify ["~/.agi-tools/codex-notify.sh"]` のチェーン痕、`[hooks.state."…/.codex/hooks.json:pre_tool_use:0:0"]` の trust ハッシュ。旧 `codex-notify.sh` と旧 hooks.json は撤去済みで実体は残っていない。
- skill は `~/.codex/skills/`（html・naiyou-suriawase 等、Claudeと同名＝共有運用）。commands/prompts/rules も別途あり。

## Codex hooks（公式: developers.openai.com/codex/hooks）

イベント（Claude Codeとほぼ同一）:
SessionStart / UserPromptSubmit / Stop / SubagentStart / SubagentStop / PreToolUse / PostToolUse / PermissionRequest / PreCompact / PostCompact。

command hook の契約:
- 入力 = **stdin の JSON**（cwd=セッションcwd）。共通フィールド `session_id` `transcript_path` `cwd` `hook_event_name` `model` `permission_mode`。
- イベント固有: SessionStart=`source(startup|resume|clear|compact)` / UserPromptSubmit=`turn_id,prompt` / Stop=`turn_id,stop_hook_active,last_assistant_message` / SubagentStart=`turn_id,agent_id,agent_type` / SubagentStop=`+agent_transcript_path,last_assistant_message`。
- `type` は **command のみ**（`prompt`/`agent` はパースされるが**skip**）。
- 出力（stdout JSON）: 注入=`hookSpecificOutput.additionalContext` または `systemMessage`／ブロック=`{"continue":false,"stopReason":…}` か `{"decision":"block","reason":…}`（legacy）か exit 2＋stderr。
- 対応表の要点: SessionStart は additionalContext/systemMessage/continue 全可。UserPromptSubmit は additionalContext と continue 可・systemMessage不可。Stop は continue/decision:block 可・**additionalContext/systemMessage 不可**（＝Stopでの文脈注入は reason 経由のみ）。

配置と優先: `~/.codex/hooks.json`（user）→ `~/.codex/config.toml [hooks]` → `<repo>/.codex/hooks.json` → `<repo>/.codex/config.toml [hooks]` → plugin。上位層は下位を置換せず全マッチが走る。inline `[[hooks.<Event>]]` TOML でも同義。

有効化と信頼: `[features] hooks`（既定 true）。**非managed hook は実行前に trust が必要**（`/hooks` でレビュー→hash記録。変更で再trust）。`--dangerously-bypass-hook-trust` で一時回避。managed（requirements.toml/MDM）は自動trust。

notify（hooksと別系統）: `agent-turn-complete` のみ発火。JSON は **argv[1]** で渡る（`type,thread-id,turn-id,cwd,input-messages,last-assistant-message`）。今は Computer Use が専有。→ **board は Stop hook を使い notify は触らない**（衝突回避）。

## Claude の3受け口 → Codex 対応

- SessionStart（手順注入）: **clean**。Codexも SessionStart で `additionalContext` 注入可。
- UserPromptSubmit（登録/🟢復帰）: **clean**。`prompt`/`session_id`/`cwd` 同型、副作用として board.py を叩くだけ。
- Stop 機械flip（🟢→⏸）: **clean**。command hook で board.py flip。
- Stop の節目確認（Claudeは prompt型＝モデル判定）: **gap**。Codexに prompt型は無い→ command が自前判定（ヒューリスティック）か、無条件に `decision:block`+reason で手順を促すかの代替。
- 🔵サブ: **Codexが有利**。SubagentStart→🔵 / SubagentStop→🟢 を**自動flip**でき、Claudeの自己申告より堅い（将来Claudeにも SubagentStop 転用余地）。

## 構造の結論

- エンジン `board.py`＋手順md（session-start/session-end）＋README＋template は **runtime非依存＝共有（唯一の正本）**。
- 受け口だけ `claude/` と `codex/` に**分離**（登録先・guard・milestone・subagentの差があるため）。二重管理する正本はゼロ。
- 登録露出: Claude=`~/.claude/settings.json`／Codex=`~/.codex/hooks.json`（＋`/hooks` trust）。どちらも露出先で正本にしない。人間ゲート。

## 出典

- https://developers.openai.com/codex/hooks
- https://developers.openai.com/codex/config-advanced
- ローカル: `~/.codex/config.toml`・`config.toml.bak-hook-cleanup-20260704-103813`・`codex --help`・`codex-cli 0.142.5`
