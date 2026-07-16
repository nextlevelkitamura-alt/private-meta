# shared/session-board — session-board の共通エンジン

当日デイリーの「動いているエージェント」を管理するruntime非依存の共通エンジン。実行イベント本体は `../../events/`、登録表はClaudeの `~/.claude/settings.json` とCodexの `../../codex/hooks.json` に分かれる。

## このフォルダにあるもの

| ファイル・フォルダ | 役割 |
| --- | --- |
| `board.py` | CLI調停。Markdown確定後にTursoへベストエフォート送信 |
| `common.py` | 全イベント本体が使う共通ロジック・注入文生成 |
| `md/` | デイリーのMarkdown永続化、ロック、原子的置換 |
| `turso/` | DBミラー送信と失敗時spool |
| `session-end.md` | 節目の完了・git仕上げ手順 |
| `daily-template.md` | デイリー雛形 |
| `registered.sh` | 登録とsymlinkの読み取り専用診断 |
| `tests/` | 単体・E2Eテスト |

状態は 🟢動作中 / ⏸停止・確認待ち / 🔵サブ稼働中 の3値。新しい状態は作らない。

## 境界

- `common.py` に状態遷移を集める。`events/` の `.py` は入力を受け、runtime別の出力形式だけを選ぶ。`.py` と対になるイベント説明は `../../events/<イベント>/` にある。
- SessionStart は生存照合とキー通知だけ。最初の UserPromptSubmit が行を登録する。全体フローは `../../events/session-start/AGENTS.md`。
- subagent/headless（`AIJOBS_RUN=1`）は独立行を登録しない。
- 永続化失敗は本体を止めない。secret/tokenの値を書かない。

## 変更時

`md/store.py` の行形式と3状態を壊さない。変更後は `tests/`、`registered.sh`、各runtimeの登録表を確認する。Claudeは設定ファイルの `hooks` 項目を直接確認し、Codexは `/hooks` の再trustが必要になる。
`CLAUDE.md` は `AGENTS.md` への相対symlink。README は置かない。
