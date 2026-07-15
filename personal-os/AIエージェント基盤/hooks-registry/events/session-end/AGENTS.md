# session-end — セッションを停止確認待ちにする

runtime の `Stop` で `mark-wait.py` を実行する。🟢の行だけを⏸へ変え、全体の生存照合も行う。完了を判定したり、セッションを止めたりはしない。

詳細は [mark-wait.md](mark-wait.md)。完了・git仕上げの人間向け手順は `../../shared/session-board/session-end.md`。

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` からこの `.py` を呼ぶ。`.py` を変える前に同名 `.md` を更新し、状態遷移は `common.py` に置く。
