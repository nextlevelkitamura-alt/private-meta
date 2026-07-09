---
稼働状態: draft（未ロード・2026-07-09 新設。既定dry-run＝ボード無変更・判定ログのみ。有効化は人間ゲート・まずdry-run 1週間の実測から）
設計: ../../../../my-brain/areas/ai運用/plans/active/2026-07-09-デイリー運用刷新/plans/05-停止行自動判定sweep.md
---

# board-sweep — ⏸停止行の自動判定sweep（dry-run既定）

## 目的

ボードの⏸（停止・確認待ち）行は「返答待ち」「セッション死亡」「one-shot完走」が混ざって堆積する
（07-09実測: codex行18本）。このloopは当日＋前日ボードの⏸行を定期的に弁別し、
定型台帳一致または one-shot完走を機械確認できたものだけを「終わったこと」へ流す（前日分も対象＝日付跨ぎの固着も解消）。
board-reconcile（5分毎・機械の生存照合・状態flipのみ）とは別本（こちらは意味判定・低頻度・finishまで行う）。

## 各回の実行

- launchd `com.kitamura.board-sweep`・`StartInterval 3600`（60分毎）。`RunAtLoad` なし。
- `scripts/sweep.sh` → `scripts/sweep.py` を1回（入口は薄い起動役・ロジックはPython＝フック言語規約）。
- パイプライン:
  1. ⏸列挙（当日＋前日ボード。`board.py` を import して `parse_line` 等を再利用・**board.py 本体は不可侵**）。
  2. 実体transcript照合（Claude: `~/.claude/projects/**.jsonl`／Codex: `~/.codex/sessions/**/rollout-*.jsonl`
     末尾の `task_complete`。探索根は `SESSION_BOARD_TX_ROOTS` で差替可）。
  3. 定型台帳マッチ（`hooks-registry/hooks/session-board/routine-ledger.md`）。
  4. headless LLM判定（残り行を**まとめて1回**・`SWEEP_LLM_CMD`。未設定なら unknown）。
  5. dry-run（既定）: 判定（done/not-done/unknown＋根拠）をログへ書くだけ・ボード無変更。
     `--apply`: 適格行のみ `board.py finish` を subprocess で実行（行の属する日付の板へ閉じる）。

## 判定と安全弁

- 判定は3値（done / not-done / unknown）。**unknown は無変更**（行は1バイトも変えない）。
- 自動finishの適格条件は2つだけ:
  1. 定型台帳一致（`判定: done`・`確認` OK・非ドラフト・実体transcriptがあれば沈黙 `SWEEP_LEDGER_SILENCE_MIN`（既定30分）以上）。
  2. codex one-shot完走（rollout末尾 `task_complete`＋沈黙 `SWEEP_SILENCE_MIN`（既定120分）以上）。
- **LLM判定の done は流し込まない**（dry-run実測・分類ログ用。誤doneを流す経路を持たない）。
- 計画列が実参照（`?`/`なし` 以外）の行は自動対象外（人間の計画に紐づく行を機械で閉じない）。
- 自動finishは1sweepあたり `SWEEP_APPLY_MAX`（既定3件）まで。子entryは `[auto]` プレフィックス＋根拠
  （台帳名 or 証跡1行）必須（実装契約-第1波 §5 の語彙）。
- `AIJOBS_RUN=1` で起動（`sweep.sh` が export・`sweep.py` も setdefault）: 自分と子プロセス（headless LLM）が
  session-board に自己登録しない＝sweepがボードの行を増やさない。
- 失敗（LLM失敗・タイムアウト・台帳パース失敗・内部例外）は**すべて exit 0 でボード無変更**（エラーはloopログのみ）。
- 版管理系の操作（commit等）はコードパスごと持たない（`tests/test_sweep.py` がソースを機械検証）。
- 既知の割り切り: `repo` 列が `?` の行を finish すると「終わったこと」に `### ?` 見出しができる
  （実データでは focusmap リモートスレッド等。dry-run実測で運用を確認してから流す）。

## 定型台帳

- 正本: `../../../hooks-registry/hooks/session-board/routine-ledger.md`
  （1定型=1節・キー5つ: 一致/終わり/確認/記載/判定。書式の説明は台帳先頭）。
- 節内に「ドラフト」の語がある間は自動finishしない（dry-runログにのみ出る）。
  初期3件（朝架電J列・印刷更新・focusmapリモートスレッド）はドラフト・人間確認待ち。

## env（テスト/差し替え用）

- `GOAL_BASE` / `SESSION_BOARD_DATE` / `SESSION_BOARD_TX_ROOTS` / `SESSION_BOARD_NO_TURSO` … board.py と共通。
- `SWEEP_LEDGER`（台帳パス）/ `SWEEP_BOARD_DIR`（session-board 共有本体の場所）。
- `SWEEP_LLM_CMD`（headless LLM コマンド。stdin=プロンプト／stdout=JSON。未設定なら LLM 判定をスキップし unknown）
  / `SWEEP_LLM_TIMEOUT`（既定180秒）。
- `SWEEP_SILENCE_MIN`（one-shot完走の沈黙閾値・既定120分）/ `SWEEP_LEDGER_SILENCE_MIN`（台帳一致時の沈黙ガード・既定30分）
  / `SWEEP_APPLY_MAX`（1sweepの自動finish上限・既定3件）。

## テスト

- `tests/test_sweep.py`（envサンドボックス・fixtureボード・LLM stub・実ボード非接触）。
  pytest互換（導入済みなら `pytest tests/`）。pytest未導入でも `python3 tests/test_sweep.py` で全件実行できる。

## ログ先

- `output/logs/board-sweep.{out,err}.log`

## 導入順（dry-run → 有効化・人間ゲート）

1. 手動dry-run: `cd <このフォルダ> && python3 scripts/sweep.py`（ボード無変更・判定ログのみ）。
2. plistロード（**dry-runのまま**1週間実測。ロードは人間ゲート・symlink方式＝board-reconcile と同型）:

```sh
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/board-sweep/com.kitamura.board-sweep.plist' \
  ~/Library/LaunchAgents/com.kitamura.board-sweep.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.board-sweep.plist
launchctl enable gui/$(id -u)/com.kitamura.board-sweep
```

3. 誤判定率を人間が確認 → 台帳エントリのドラフト行を消す → plist の ProgramArguments 末尾を
   `scripts/sweep.sh --apply` に変えて再ロード（流し込み有効化・人間ゲート）。
4. 23:30 の節目で当日の `[auto]` 一覧を人間レビュー（Shutdown儀式に1項目・子03側の担当）。

停止: `launchctl bootout gui/$(id -u)/com.kitamura.board-sweep`
有効化・停止したら `../../実行一覧/personal-os.md` を同じ作業で更新する。
