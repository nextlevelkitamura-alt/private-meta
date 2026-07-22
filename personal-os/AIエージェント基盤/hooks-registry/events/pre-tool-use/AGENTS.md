# pre-tool-use — 計画運用のPreToolUseガード

`PreToolUse` 入力を読むhookを2つ持つ。コマンド/実装の判定は各 `.py` に置き、計画やバケットは編集しない。

1. `guard-plan-bucket-move.py`（Bash入力）: `mv` / `git mv` が `plans/planning|active|paused|done|archive` を
   対象にする時だけ deny し `bucketctl` を案内する。通常コマンドと `bucketctl` 自身は通す。
2. `guard-plan-gate.py`（Edit/Write/MultiEdit入力）: 計画に紐づかないコード実装らしき時だけ1セッション1回、
   警告のみ注入する（deny も ask もしない・exit0）。免除（.md・plans/references/評価/scratchpad・active計画あり・
   session1回）と設計根拠は同名 `guard-plan-gate.md`（program「計画立案システム刷新」子04 §3.2）。

登録状態: `guard-plan-gate` は**未登録**（settings.json / codex hooks.json に無い＝本体に作用しない・登録は
GLOBAL_AGENTS.md §7 の人間ゲート）。`guard-plan-bucket-move` の実登録状態は上位 `hooks-registry/AGENTS.md` の
登録表と各runtime設定を正とする（本フォルダ旧記述「承認セットまで未適用」の実態追従は別作業＝説明書ドリフト整合で扱う）。

`CLAUDE.md` はこのファイルへの相対symlink。
