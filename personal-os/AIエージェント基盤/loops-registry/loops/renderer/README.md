# renderer（統合デイリーレンダラ v1）

> **廃止（2026-07-06）**: 旧・日次自動ログ subsystem（session-daily-log / renderer / daily-digest）を session-board へ統一。以下は当時のロールアウトdraftの凍結記録で、参照する `hooks/session-daily-log/session-daily-log.sh` は削除済み。稼働状態は `loop.md` frontmatter を正とする。

当日デイリーの生成〜自動集計（`auto:goal` / `auto:tomorrow-carry`（前日「## 明日へ」の朝転記） /
`auto:log` バックフィル / `auto:done` / `auto:align`）を1本のスクリプト群に統合したもの。実行スペックは
`loop.md`、見出しテンプレ契約（末尾に人間手書き欄「## 明日へ」を含む）は `templates/デイリー.md` が正本。

- `scripts/render.sh [YYYY-MM-DD] [--final]` — エントリポイント。決定的・冪等・非AI。
- `scripts/carry-tomorrow.sh <daily> <YYYY-MM-DD>` — 前日デイリーの「## 明日へ」を当日の逆算直後
  （`## 今日のTODO` 直前）へ `auto:tomorrow-carry` 区画で冪等転記。前日が無い/空なら区画を作らず、
  既存の古い区画は除去する（空のauto区画を残さない）。マーカー外の人間行・他区画は不変。
- `scripts/render-debounced.sh [YYYY-MM-DD]` — hookから呼ぶ非同期debounceラッパ（呼び出し元を
  一切ブロックしない）。
- `scripts/tests/run-tests.sh` — テストスイート（fixtureベース・実デイリーには書き込まない）。

マーカー内側の読み書きは `../daily-digest/scripts/get-marker-block.sh` / `set-marker-block.sh` を
相対参照する（複製しない）。done カード収集は `../daily-digest/scripts/collect-done-cards.sh` を
同様に相対参照する。

## 現状（このworktree内での位置づけ）

このloopは **稼働状態: 停止（hook接続待ち・人間ゲート）**。`renderer-v1` worktree内でコードとテストは
完結している。**テンプレの既定参照先は repo 内蔵の `templates/デイリー.md`**（`render.sh` が自身の
`scripts/` ディレクトリからの相対パス `$SCRIPT_DIR/../templates/デイリー.md` で解決する。`GOAL_BASE`
側のテンプレは既定では一切見ない・`DAILY_TEMPLATE` 環境変数はテスト・特殊運用専用の上書き）。
これにより、my-brain側テンプレの差し替えを待たずに、renderer は常に新8見出しテンプレで当日ファイルを
生成する（t9で検証済み）。以下は一切適用していない（このworktree外への書き込み・push・main統合は
禁止のため）。

- `~/.claude/settings.json` への hook 登録
- `~/Private/personal-os/my-brain/ゴール/templates/デイリー.md` の1行ポインタ化（下記ロールアウト②）
- 本branchの基盤repo mainへのマージ

## 【ロールアウトdraft】人間ゲートで行う手順

適用は一切していない。以下は人間が判断・実行する手順のdraftのみ。

1. **このbranch（`nextlevelkitamura-alt/renderer-v1`）を基盤repo mainへマージする。**
   マージすると `loops-registry/loops/renderer/` 一式と、`hooks/session-daily-log/session-daily-log.sh`
   の変更、`loops-registry/loops/daily-digest/scripts/run.sh` の委譲変更が本番repoに入る。
   **この時点で renderer は既に新8見出しテンプレ（repo内蔵）で当日ファイルを生成するようになる**
   （旧my-brainテンプレの差し替えを待たない）。
2. **my-brainテンプレを1行ポインタ化する（内容の差し替えではない）。**
   テンプレの正本は基盤repo側（`loops-registry/loops/renderer/templates/デイリー.md`）に一本化した。
   `~/Private/personal-os/my-brain/ゴール/templates/デイリー.md` の中身をコピーで置き換えるのではなく、
   「正本はこちら」を示す1行ポインタ（例: `正本: ../../AIエージェント基盤/loops-registry/loops/renderer/templates/デイリー.md（直接編集しない）`）
   に差し替える（二重管理禁止）。renderer 自体はこのファイルを既定では参照しないため、このポインタ化は
   renderer の動作に影響しない人間向けの道しるべ作業（未実施でも renderer は正しく動く）。
3. **hook登録は変更不要。**
   `hooks/session-daily-log/session-daily-log.sh` 自体のファイルパスは不変（README.md 記載の登録
   スニペットのコマンドパスも不変）。中身の変更（末尾で `render-debounced.sh` を非同期起動する処理の
   追加）は、mainマージにより登録済みの `~/.claude/settings.json` から呼ばれるファイルの中身が
   自動的に更新される。**まだ未登録なら**、`hooks/session-daily-log/README.md` の登録スニペット手順で
   `~/.claude/settings.json` の `hooks.Stop` に追記する（このloopの新規スコープではなく、
   session-daily-log自体が元々未登録だったため）。
4. **launchd plistも変更不要。**
   `com.kitamura.daily-digest` の plist（コマンドパス・スケジュールとも）はそのまま。
   `loops-registry/loops/daily-digest/scripts/run.sh` が内部で
   `loops-registry/loops/renderer/scripts/render.sh --final` へ委譲するよう変更したため、
   plist側の変更は不要（マージだけで23:30の締めレンダがrendererへ切り替わる）。

## daily-digest との統合・置換についての推奨

`daily-digest`（夜loopのauto:done/align生成）と`session-daily-log`（hookのauto:logupsert）は
このloopに**吸収**した（run.shは薄い委譲ラッパへ、hookは末尾でrendererを非同期起動するだけに変更）。
名前・plist・hook登録はどちらも変更していないため、ロールアウト後も既存の運用導線（`実行一覧/`の
ジョブ一覧、launchd登録手順）をそのまま使い続けられる。

中期的には `daily-digest/` フォルダ自体を廃止し、`renderer/` 1本に統合することを推奨する
（現状は `run.sh` の委譲・`collect-done-cards.sh`/`get-marker-block.sh`/`set-marker-block.sh` の
相対参照という形で二重管理を避けているが、フォルダが2つ残っている状態は将来の読み手に
「どちらが正本か」を毎回考えさせるコストがある）。ただしこの統合（plist・frontmatterの`loop名`変更を
伴う）は人間ゲート（launchd再登録が絡むため）で別途判断する。

## TODO（将来最適化・軽微）

- `codex-pull.sh` は当日分の各セッションごとに rollout ファイルを `glob.glob(recursive=True)` で
  都度探索している。対象日1000件×rollout1000個という極端なケースの実測で2.47秒（通常の実環境
  規模＝当日数件では1〜2秒以内）。sessions_base 配下の rollout 一覧を1回だけ走査してid→pathの
  索引を先に作る実装に変えれば、この極端ケースも短縮できる。現状のスケール（個人の1日あたりの
  Codexセッション数）では未着手のままで実用上問題ない。
- 子04a（`auto:board-now`/`auto:board-wait`/`auto:board-plans`）の既知スコープ簡略化:
  - 「着手可能」は program.md 子計画マップの状態が完全一致で「計画」の子のみを対象にする
    （単発 plan.md は対象外。子計画のNN番号と「実装未着手」というvocabulary前提に依存）。
  - 「未紐付けレーン」判定は displayName に「子NN」パターンがあるかどうかの表層一致のみ
    （その番号が実在する子計画かどうかは plan-scan.sh の結果とクロスチェックしない）。
  - 「未紐付けコミット」は auto:log（Claudeセッション経由でpull済みのcommits）のみを対象にし、
    Codexセッションのcommitや、Claude/Codexいずれのセッションも介さない手動commitは拾わない。
  現状の運用規模（cockpitレーン数・active計画数が個人運用の範囲）では実用上問題ないが、
  精度を上げる場合はこの3点が拡張ポイント。
