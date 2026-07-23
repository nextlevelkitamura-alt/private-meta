# session-start — セッション開始の全体フロー

このフォルダは Claude/Codex 共通の `SessionStart` 実行本体を置く。開始時に実行されるのは
`reconcile-and-notify.py` だけで、設定が `--runtime claude` または `--runtime codex` を渡す。

## 実際に起きる順番

1. runtime が stdin JSON を渡して `reconcile-and-notify.py` を実行する。
2. `.py` が `shared/session-board/common.py` の `start_register()` を呼ぶ。
3. `start_register()` は、`routing.py`でrepo/worktree/branchを機械判定し、`board.py context-upsert`へbest-effort記録する。
4. 古い🟢/🔵行を生存照合して必要なら⏸へ直す。
5. この時点ではsession本体のボード行を作らない。キー通知と固定分類方針`../prompt-register/session-classification-policy.md`をそのSessionStartイベントで返す。resume/compactでも方針復元のため再注入される。
6. 次の `UserPromptSubmit` で `../prompt-register/register-and-guide.py` が行とturn pendingを登録し、AIに開始ガイドと短い動的候補を注入する。
7. AIは依頼を理解した後、注入された `board.py update`でsession行を整え、`route-propose`で対象turnの意味分類を提案する。

この分離は、開始時の実行場所だけを捕捉しつつ、プロンプトを持たない補助セッションを🟢の幽霊枠として残さないため。

## runtime ごとの差

| runtime | 実行コマンドの末尾 | stdout |
| --- | --- | --- |
| Claude | `--runtime claude` | plain text（開始通知） |
| Codex | `--runtime codex` | `hookSpecificOutput.additionalContext` のJSON |

機能の入出力・副作用・失敗時の扱いは [reconcile-and-notify.md](reconcile-and-notify.md) が正本。
開始後のボード操作の共通ルールは `../../shared/session-board/AGENTS.md`、終了は `../session-end/AGENTS.md` を読む。
`finish`はsession-board記録を閉じる操作だけで、計画のarchive承認・実行はしない。計画同期はplan-opsが所有する。

## 登録と変更時

Claudeは `~/.claude/settings.json` の `hooks` 項目、Codexは `../../codex/hooks.json` から、この `.py` を `--runtime` 付きで呼ぶ。repo内にClaude用の登録コピーは作らない。

- `.py` を変える前に同名 `.md` を更新・確認する。
- `--runtime` の分岐は出力形式だけに留める。セッション状態のロジックは `common.py` に置く。
- 登録を変えたら `../../shared/session-board/registered.sh` で窓を確認する。Codexは `../../codex/trust-current.py` で自動trustし、状態をreadbackする。
