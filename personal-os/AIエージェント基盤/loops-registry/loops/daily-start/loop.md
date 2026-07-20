---
稼働状態: 未ロード（実装完了・launchd load は人間ゲート＝指揮官が実施予定。2026-07-20 実装）
設計: ../../../../my-brain/areas/ai運用/plans/planning/2026-07-09-デイリー運用刷新/plans/03-儀式の自動実行.md
---

# daily-start — 朝10:03の「デイリースタート」儀式を起動する loop（runner=ai）

## 目的

毎朝 10:03（JST）に「デイリースタート」を1回起動し、月週目標・前日の引き継ぎ・繰越しを読んで、
今日の大課題（themes）と今日やること（todos）を確定起票させる。人間の承認バーは置かない。
このloopは **起動だけ** を自動化する。themes/todos の起票・判断・question 発行・実行ログ書き込みは、
起動された AI（`skills/daily-start/` の無人モード）が行う。手動で「デイリースタート」を実行した日は、
実行ログ（`state/done-<日付>`）を見て 10:03 の定期起動をスキップする。

## runner=ai の位置づけ（無人headless連続実行ではない）

- runner は `ai`（無人 AI runtime を起動する）。ただし **自動化するのは「起動」だけ**で、実行体は
  既定で **Orca の可視1ペイン**（人が監督・介入できる）を優先する。Orca が応答しない時だけ
  `claude -p` の **headless にフォールバック**する。
- これは「無人 headless を連続実行し続ける loop」ではない。1日1回の calendar 起動（10:03）で、
  可視ペイン優先・headless は退避経路。人間の方向修正が入り得る儀式なので、まず可視ペインで安定させる
  （loops-registry AGENTS.md「runner=ai は…まずペイン実行で安定させる」に沿う）。

## 各回の実行

- launchd `com.kitamura.daily-start`・`StartCalendarInterval` 10:03 JST（Hour=10 Minute=3）。`RunAtLoad` なし。
- `scripts/run.sh`（薄い起動役）を1回。判断・起票は起動された AI が持つ（run.sh は判断を持たない）。

## 内部処理（run.sh の順番）

1. 多重起動防止ロック（`/tmp/daily-start.lock`・mkdir ベース・stale 3600秒で自己修復）。
   macOS に `flock` が無いため、既存 loop（board-sweep 系と同じ流儀）の mkdir ロック方式を採る。
2. 当日の冪等ガード: `state/done-<YYYY-MM-DD(JST)>` があれば「skip: already done」をログに残して exit 0。
   done マーカーは run.sh は書かない（起動された AI＝スキルが finish 時に書く）。ここでは読むだけ。
3. Orca 応答確認（`orca worktree ps --json` が exit 0 か）→ 可なら `cockpit.sh spawn` で可視1ペインを起動。
4. Orca 不可、または spawn 失敗なら `claude -p` で headless 起動（同じプロンプト `scripts/prompt.md`）。
5. ③④どちらも起動に失敗したら output ログにエラーを残し exit 1（リトライは今回入れない＝次の 10:03 発火に任せる）。

## モデル選定（AIモデル一覧.md のレーン規約に従う）

- モデルは `../../../AIモデル一覧.md` のレーン規約に従い、実装機構としては env `DAILY_START_MODEL` で保持する。
- 既定 = `claude-sonnet-5`（cockpit spawn の既定 `DEF_MODEL_CLAUDE` と揃える）。デイリースタートは
  判断（月週目標→themes/todos の確定）を含むため、AIモデル一覧の役割では「指揮・通常の対話作業＝opus4.8」に
  近い。判断を重くしたい場合は人間が plist env `DAILY_START_MODEL=opus4.8` 等へ差し替える（一覧の掲載モデルに限る）。
- 起動機構はこの一覧に従うモデルID／effort だけを引数に持ち、別の役割既定を作らない。

## permission と無人実行（人間ゲートの判断ポイント）

- 儀式は `board.py`（Bash）で themes/todos を書き込む。既定は安全側の permission にしている:
  可視ペイン `DAILY_START_PERM=acceptEdits` / headless `DAILY_START_HEADLESS_ARGS=--permission-mode acceptEdits`。
- acceptEdits では Bash（board.py 実行）が自動承認されないため、**完全無人での書き込みには不足**する
  （可視ペインは人が承認、headless は非対話でツールが拒否され得る）。完全無人で書き込ませたい場合は、
  人間が plist env を `DAILY_START_PERM=bypassPermissions`・`DAILY_START_HEADLESS_ARGS=--dangerously-skip-permissions`
  に設定する。これは無人 AI に無制限のツール実行を与える判断なので **人間が明示的に決める**（実装では既定にしない）。
- **現在の設定**: 2026-07-20夜の人間明示承認（「デンジャラスモードでいい」）により、**現plistは危険側
  （bypassPermissions / --dangerously-skip-permissions）を設定済み**。run.sh 側の既定は安全側のまま。
  安全側へ戻すには plist の当該2 envを削除する（評価01の文書整合指摘への追記）。

## env（差し替え・テスト用。既定は run.sh 冒頭）

- `DAILY_START_STATE_DIR` / `DAILY_START_OUTPUT_DIR` / `DAILY_START_LOG_FILE` … state・ログの置き場。
- `DAILY_START_LOCK_DIR`（既定 `/tmp/daily-start.lock`）/ `DAILY_START_LOCK_STALE_SECONDS`（既定 3600）。
- `DAILY_START_DATE`（既定=今日 JST。冪等ガードの日付。テストで固定するのに使う）。
- `DAILY_START_MODEL` / `DAILY_START_WT`（spawn の worktree selector・既定 `name:Private`）/ `DAILY_START_PERM`。
- `DAILY_START_HEADLESS_ARGS`（headless の tool 許可・既定 `--permission-mode acceptEdits`）。
- `DAILY_START_PROMPT_FILE`（既定 `scripts/prompt.md`）/ `DAILY_START_OWNER`。
- `DAILY_START_COCKPIT` / `DAILY_START_ORCA_BIN` / `DAILY_START_CLAUDE_BIN`（起動コマンドのフルパス。テストで stub に差し替える）。

## ログ先・state

- ログ: `output/logs/daily-start.log`（run.sh 自身）＋ `output/logs/daily-start.{out,err}.log`（launchd）。gitignore。
- state: `state/done-<YYYY-MM-DD>`（起動された AI が書く冪等マーカー）。gitignore（`../../../.gitignore` にネスト登録）。

## テスト

- `tests/test_run.sh`: run.sh の分岐を実 AI 起動なしで検査する（起動コマンドを stub に差し替える）。
  - done マーカーがある日は「起動せず exit 0」（skip 分岐）。
  - Orca 応答ありなら可視ペイン stub が呼ばれる。
  - Orca 応答なしなら headless stub が呼ばれる（フォールバック）。
  - 両方失敗なら exit 1。
- plist lint: `plutil -lint com.kitamura.daily-start.plist` が OK（`tests/test_run.sh` 内でも検査）。

## 導入順（実装完了 → 人間GO → launchd load・人間ゲート）

1. 手動起動確認: `cd <このフォルダ> && scripts/run.sh`（Orca 稼働時は可視ペインが立つ）。
2. plist load（symlink 方式・既存 loop と同型・人間ゲート）:

```sh
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/daily-start/com.kitamura.daily-start.plist' \
  ~/Library/LaunchAgents/com.kitamura.daily-start.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.daily-start.plist
launchctl enable gui/$(id -u)/com.kitamura.daily-start
```

3. 有効化・停止したら `../../実行loop一覧.md` を同じ作業で更新する（本コミットで追加済み）。

停止: `launchctl bootout gui/$(id -u)/com.kitamura.daily-start`
