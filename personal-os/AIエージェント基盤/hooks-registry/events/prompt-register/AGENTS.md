# prompt-register — 最初の入力を登録して開始ガイドを渡す

runtime の `UserPromptSubmit` で `register-and-guide.py --runtime <claude|codex>` を実行する。
未登録ならボード行を作り、⏸なら🟢へ戻し、「今」が空なら入力冒頭を仮置きする。目標未記入なら詳細ガイド、記入済みなら短い状態ミラーを注入する。

`.py` の入出力・副作用は [register-and-guide.md](register-and-guide.md) を読む。状態ロジックは `../../shared/session-board/common.py` が正本で、このフォルダには置かない。

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` から、この `.py` を `--runtime` 付きで呼ぶ。`.py` を変える前に同名 `.md` を更新し、runtime別の実装コピーは作らない。
