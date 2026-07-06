# B実装 レビュー項目 — session-board 再構築（2026-07-05）

サブエージェント（Opus）がこの実装を検証するためのチェックリスト。「やったか」でなく「こうなっていれば正しい」で書く。対象は `hooks/session-board/`。

## 命名・構造
1. 対のペアが同名（拡張子違いのみ）: `claude/session-start.py ↔ session-start.md`／`claude/session-end.py ↔ session-end.md`。
2. 受け口は全て `.py`（`session-start.py`／`session-end.py`／`prompt-register.py`）。`registered.sh` のみ `.sh`（中身が本物のbash＝launchctl/grep のため妥当）。
3. `board.py` は `#!/usr/bin/env python3` の単体スクリプト（`exec python3 - <<'PY'` の bash heredoc ラッパが無い）。
4. `codex/` フォルダが器として存在（P3用・READMEのみでも可）。
5. 旧ファイル（`board.sh`／`start-inject.sh`／`stop-guard.sh`／`prompt-register.sh`）が hooks/session-board 直下に残っていない（.bak 退避は可）。

## auto/claimed 廃止
6. `board.py`・受け口3本・全mdに `--auto`／`run-auto`／`wait-auto`／`claimed`／行末 `a -->` の残骸が無い。
7. `LINE_RE` に auto キャプチャ（`(?P<auto> a)?`）が無い。行末マーカーは `<!-- s:KEY -->` のみ。
8. `check` の出力は `missing`／`run`／`wait` の3値のみ（`-auto` が付かない）。

## 入れ子記録
9. `board.py log --key K --repo R --parent P --entry E` がある。「動いているエージェント」の自行は消さず🟢のまま、「終わったこと」の `### repo` > `- 親` の下に `  - HH:MM 子` を追記する。
10. `finish` は自行削除＋入れ子で子追記（親確定）。
11. 実測: `log`→`log`→`finish` で、1つの親の下に時刻付きの子が複数、入れ子で積まれる。親は重複しない。

## 節目確認（毎ターンブロック廃止）
12. `claude/session-end.py`（Stop受け口）は状態flipのみで、**`decision:block` を返さない**（毎ターンのブロックが無い）。
13. `claude/milestone.md`（prompt型判定文）が存在し、「大目標達成＋ユーザー満足の気配がある時だけ完了報告手順を注入・迷ったら素通し・1往復ごとの完了では止めない」方針。
14. `settings.json` の Stop に、command型（session-end.py）＋prompt型（milestone判定）の2本が登録されている。

## settings / skill / 露出
15. `settings.json`: SessionStart→`session-start.py`／UserPromptSubmit→`prompt-register.py`／Stop→`session-end.py`＋prompt型。他設定（model/statusLine/permissions/mcpServers/agentPushNotifEnabled）が無傷でJSON妥当。
16. `skills/session-board/` が削除され、露出symlink3本（`~/.claude`／`~/.codex`／`~/.agents/skills/session-board`）も削除。catalog `meta.md` から session-board 行が削除。
17. `daily-template.md` が hooks直下に移設され、`board.py` の既定テンプレパスがそこを指す（旧 skills/assets 参照が残っていない）。

## 動作・安全
18. 全コマンド（add/update/flip/finish/check/log）が動作。並行10書き込みで行の欠落なし（flock有効）。
19. 受け口の相対参照が正しい（`../board.py`／`../session-start.md`／`../session-end.md`）。フォルダ移動でパスが壊れていない。
20. secret/token/認証値の混入なし。ボード・md・スクリプトに機密が書かれていない。
21. ドキュメント（`hooks/AGENTS.md`／`hooks/session-board/README.md`／計画 plan.md／`GLOBAL_AGENTS.md` §6）が新構成（全py・節目確認・入れ子・skill廃止）に更新されている。
