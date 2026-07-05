# hooks — runtime フック本体

各 AI ランタイム（Claude Code 等）の **hook script の正本**を置く場所。
hook は「**イベント直後に軽い決まった処理を挟む**」もの（記録・通知など。判断不要・高速・非ブロッキング）。実行方式の位置づけは `../loops-registry/references/loop-types.md` の ③hook。

## 現在の hook

- `session-daily-log/` ── Claude Code の `Stop` イベント → 当日デイリー `## ログ(自動)`（`auto:log`）にセッションのポインタ＋git事実（cwd/repo/branch/dirty/commit short-sha/session/transcript）を upsert。commit は sha ポインタのみ（件名は `../loops-registry/loops/renderer/` が git 解決）。末尾で renderer（`render-debounced.sh`）を非同期debounce起動する（Stopを絶対ブロックしない。当日デイリーが無くても起動だけは行う）。詳細・登録スニペットは `session-daily-log/README.md`。状態: **停止**（2026-07-04 に `~/.claude/settings.json` から除去。デイリーの91%が機械生成になり見直しへ。関連loop（lanes-sync/daily-digest等）も同日全停止＝`../loops-registry/実行一覧/personal-os.md`。本文は残置・再登録は人間ゲート）。

- `session-board/` ── セッション宣言型ボードの機構（2026-07-05 再構築・**skill廃止**・全py統一）。機構=Python（`board.py` エンジン＋`claude/` 受け口3本）／手順=md（`session-start.md`・`session-end.md`）／対は同名・拡張子違い。受け口: SessionStart=`claude/session-start.py`（手順注入）／UserPromptSubmit=`claude/prompt-register.py`（機械登録・🟢復帰）／Stop=`claude/session-end.py`（🟢→⏸の機械flipのみ・**ブロックしない**）＋prompt型（`claude/milestone.md`）が節目のみ完了確認を注入。**毎ターン確認は廃止**（節目だけ・2026-07-05）。入れ子記録（`log`）で「終わったこと」を親＋時刻付き子に。状態は🟢動作中/⏸停止・確認待ち/🔵サブ稼働中の3値。バックグラウンドのサブ実行中は各セッションが自分で `flip --state sub`→完了で `--state run` と**自己申告**して🔵にし、Stop（session-end.py）でも次プロンプト（prompt-register.py）でも維持される（中央検知は無し・フックは自分のセッションでしか走らないため）。状態: **登録済み**（`~/.claude/settings.json` SessionStart+UserPromptSubmit+Stop×2）。詳細・登録スニペット・制約は `session-board/README.md`、現況は `session-board/registered.sh`。Codex接続は `codex/`＝P3未実装。

## 補助フォルダ

- `research/YYYY-MM-DD/` ── hook / runtime hook / agent登録まわりの調査メモ。hook本体や登録スニペットの正本ではない。
- `references/` ── runtime別hookの恒久リファレンス（例: `codex-hooks.md`＝Codex hooksの実務マニュアル）。日付なし・更新して使う。

## 規律

- **本文はここが正本**。各 runtime への**登録**（例 `~/.claude/settings.json`）は露出＝人間ゲート（全セッションに効くため、AI が勝手に登録しない）。**例外**: session-board の hook 登録・更新は**包括承認済み**（2026-07-05・承認ルールB）。ただし session-board 以外の hook 追加・削除は従来どおり人間ゲート。
- hook は**非ブロッキング**（内部失敗でも本体セッションを止めない）。secret/token/値を書かない（ポインタのみ）。session-board は**非ブロッキングに移行**（2026-07-05・`claude/session-end.py` は状態flipのみ）。完了確認は Stop の**prompt型フック**（`claude/milestone.md`）が節目のみ注入する（`{"ok":false,"reason":…}`＝完了手順を実行させる／`{"ok":true}`＝通常停止。毎ターンではない。prompt型は`ok`形式が正で`decision`形式ではない）。
- 記録の住み分け: **dispatch されたジョブセッションは記録しない**（カードが記録する）／拾うのは ad-hoc な対話だけ。dispatcher が spawn 時に `AIJOBS_RUN=1` を付与し、hook はそれを見て抑止する。
- `CLAUDE.md` は `AGENTS.md` への相対symlink。
