# pre-tool-use — 計画運用のPreToolUseガード

`PreToolUse` 入力を読むhookを2つ持つ。コマンド/実装の判定は各 `.py` に置き、計画やバケットは編集しない。

1. `guard-plan-bucket-move.py`（Bash入力）: `mv` / `git mv` が `plans/planning|active|paused|done|archive` を
   対象にする時だけ deny し `bucketctl` を案内する。通常コマンドと `bucketctl` 自身は通す。
2. `guard-plan-gate.py`（Edit/Write/MultiEdit入力）: 計画に紐づかないコード実装らしき時だけ1セッション1回、
   警告のみ注入する（deny も ask もしない・exit0）。免除（.md・plans/references/評価/scratchpad・active計画あり・
   session1回）と設計根拠は同名 `guard-plan-gate.md`（program「計画立案システム刷新」子04 §3.2）。

登録状態: `guard-plan-gate` は **Claude=登録済み**（`settings.json` の `PreToolUse` matcher
`^(Edit|Write|MultiEdit)$`）／**Codex=未登録**（必要性をAIが評価し、登録する場合はJSON検証・自動trust・readbackまで行う）。`guard-plan-bucket-move` は
Claude/Codex とも登録済み。各runtimeの実登録は `~/.claude/settings.json` と `codex/hooks.json` を正とする。

`CLAUDE.md` はこのファイルへの相対symlink。
