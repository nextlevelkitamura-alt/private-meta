# session-start — セッション開始の全体フロー

このフォルダは Claude/Codex 共通の `SessionStart` 実行本体を置く。開始時に実行されるのは
`reconcile-and-notify.py` だけで、設定が `--runtime claude` または `--runtime codex` を渡す。

## 実際に起きる順番

1. runtime が stdin JSON を渡して `reconcile-and-notify.py` を実行する。
2. `.py` が `shared/session-board/common.py` の `start_register()` を呼ぶ。
3. `start_register()` は、古い🟢/🔵行を生存照合して必要なら⏸へ直す。
4. この時点ではボード行を作らない。キーと「最初の意味あるプロンプトで登録する」という短い通知だけを返す。
5. 次の `UserPromptSubmit` で `../prompt-register/register-and-guide.py` が行を登録し、AIに開始ガイドを注入する。
6. AIは依頼を理解した後、注入された `board.py update` で目標・種別・今・計画・モデルを1回整える。

この分離は、プロンプトを持たない補助セッションを🟢の幽霊枠として残さないため。

## runtime ごとの差

| runtime | 実行コマンドの末尾 | stdout |
| --- | --- | --- |
| Claude | `--runtime claude` | plain text（開始通知） |
| Codex | `--runtime codex` | `hookSpecificOutput.additionalContext` のJSON |

機能の入出力・副作用・失敗時の扱いは [reconcile-and-notify.md](reconcile-and-notify.md) が正本。
開始後のボード操作の共通ルールは `../../shared/session-board/AGENTS.md`、終了は `../session-end/AGENTS.md` を読む。

## 登録と変更時

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` から、この `.py` を `--runtime` 付きで呼ぶ。repo内にClaude用の登録コピーは作らない。

- `.py` を変える前に同名 `.md` を更新・確認する。
- `--runtime` の分岐は出力形式だけに留める。セッション状態のロジックは `common.py` に置く。
- 登録を変えたら `../../shared/session-board/registered.sh` で窓を確認する。Codexは人間が `/hooks` で再trustする。
