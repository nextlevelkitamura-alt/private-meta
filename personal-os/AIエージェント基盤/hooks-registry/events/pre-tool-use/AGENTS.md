# pre-tool-use — 計画バケットへの生移動を拒否する

`PreToolUse`のBash入力だけを読む。`guard-plan-bucket-move.py`は`mv` / `git mv`が
`plans/planning|active|paused|done|archive`を対象にする時だけdenyし、`bucketctl`を案内する。
通常コマンドと`bucketctl`自身は通す。コマンド判定はこの`guard-plan-bucket-move.py`に置き、計画やバケットは編集しない。

Claude/Codexの登録は承認セットまで未適用。`CLAUDE.md`はこのファイルへの相対symlink。
