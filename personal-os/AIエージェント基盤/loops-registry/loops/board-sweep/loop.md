---
稼働状態: 稼働中（2026-07-11 人間GOで --apply ロード・60分毎。判定モデル=gpt-5.6-luna（codex-cli 0.144.1で疎通確認）。安全弁=二重鍵＋SWEEP_APPLY_MAX 3件/回＋台帳ドラフト不流入。初回手動applyで not-done 2件を正しく残置と実測）
設計: ../../../../my-brain/areas/ai運用/plans/active/2026-07-09-デイリー運用刷新/plans/05-停止行自動判定sweep.md
二重鍵化: ../../../../my-brain/areas/ai運用/plans/active/2026-07-10-デイリーボード改善/plans/04-board-sweep二重鍵化とLLM接続.md
---

# board-sweep — ⏸停止行の自動判定sweep（dry-run既定・二重鍵）

## 目的

ボードの⏸（停止・確認待ち）行は「返答待ち」「セッション死亡」「one-shot完走」が混ざって堆積する
（07-09実測: codex行18本）。このloopは当日＋前日ボードの⏸行を定期的に弁別し、
**定型台帳一致** または **二重鍵（機械証跡 AND LLM判定done）** を確認できたものだけを
「終わったこと」へ流す（前日分も対象＝日付跨ぎの固着も解消）。
機械証跡（rollout末尾 `task_complete`＋沈黙）単独では流さない: `task_complete` は「最後のターンが
完走した」記録であり大目標達成の証明ではなく、沈黙2時間も「忘れてただけ」を含むため（2026-07-10ユーザー裁定）。
board-reconcile（5分毎・機械の生存照合・状態flipのみ）とは別本（こちらは意味判定・低頻度・finishまで行う）。

## 各回の実行

- launchd `com.kitamura.board-sweep`・`StartInterval 3600`（60分毎）。`RunAtLoad` なし。
- `scripts/sweep.sh` → `scripts/sweep.py` を1回（入口は薄い起動役・ロジックはPython＝フック言語規約）。
- パイプライン:
  1. ⏸列挙（当日＋前日ボード。`board.py` を import して `parse_line` 等を再利用・**board.py 本体は不可侵**）。
  2. 実体transcript照合（Claude: `~/.claude/projects/**.jsonl`／Codex: `~/.codex/sessions/**/rollout-*.jsonl`
     末尾の `task_complete`。探索根は `SESSION_BOARD_TX_ROOTS` で差替可）。
  3. 定型台帳マッチ（`hooks-registry/hooks/session-board/routine-ledger.md`）。
  4. headless LLM判定（台帳・対象外以外の残り行を**まとめて1回**・`SWEEP_LLM_CMD`。未設定なら unknown。
     機械証跡を持つ行もここへ入る＝二重鍵のLLM側）。
  5. dry-run（既定）: 判定（done/not-done/unknown＋根拠）をログへ書くだけ・ボード無変更。
     `--apply`: 適格行のみ `board.py finish` を subprocess で実行（行の属する日付の板へ閉じる）。

## LLM判定のコンテキスト（会話の積み重ね・2026-07-10ユーザー指定）

- 各行に付すのは ①**依頼の原点**（セッション最初のユーザープロンプト）②**目的への帰属**
  （ボード行の goal・種別・計画列＝デイリー上のどこに属すセッションか）③**会話ダイジェスト**
  （各ターンのユーザー発話とAIの応答・報告の連なり）＋機械証跡の有無。
- **ツール呼び出し・ツール結果・thinking は含めない**（重くなるため。必要が出たら後段で追加検討）。
- 抽出元は実体transcript（Claude jsonl / Codex rollout）。実フォーマットは 2026-07-10 に実ファイルで
  確認して実装（`sweep.py` の `claude_turns` / `codex_turns` に構造をコメント）。
- 丸め（envで差替可・値の根拠は `sweep.py` の定数コメント）: 1発話 `SWEEP_DIGEST_MSG_MAX`（既定200字）・
  1セッション合計 `SWEEP_DIGEST_TOTAL_MAX`（既定2000字）・依頼の原点 `SWEEP_DIGEST_FIRST_MAX`（既定400字）。
  超過時は**初回プロンプト＋末尾ターン優先**で間を省略（「…中略N発話…」）。
  1回のLLM呼び出しに載せる行数は `SWEEP_LLM_ROWS_MAX`（既定40行）まで・超過分は次回sweepで再判定。
- 判定エージェントは **read-only**（`scripts/llm-judge.sh` が `--sandbox read-only --ephemeral` で起動・
  プロンプトも判定のみを指示しダイジェスト内の指示には従わせない。custom-agent-creator quality-gate 指針）。

## 判定と安全弁

- 判定は3値（done / not-done / unknown）。**unknown は無変更**（行は1バイトも変えない）。
- 自動finishの適格条件は2つだけ:
  1. 定型台帳一致（`判定: done`・`確認` OK・非ドラフト・沈黙ガード `SWEEP_LEDGER_SILENCE_MIN`（既定30分）以上。
     実体transcriptがあれば mtime 沈黙・**実体なしなら行の開始時刻からの経過**で測る）。
  2. **二重鍵**: codex one-shot完走の機械証跡（rollout末尾 `task_complete`＋沈黙 `SWEEP_SILENCE_MIN`
     （既定120分）以上）**AND** LLM判定 done。
- **どちらか単独では流さない**: 機械証跡のみ（LLMがdone以外・失敗・未接続）→不流入。
  LLM done のみ（機械証跡なし）→不流入（分類ログ用）。`SWEEP_LLM_CMD` 未設定の間は
  機械証跡があっても不適格＝**台帳ルートしか流れない**。
- 計画列が実参照（`?`/`なし` 以外）の行は自動対象外（人間の計画に紐づく行を機械で閉じない）。
- 自動finishは1sweepあたり `SWEEP_APPLY_MAX`（既定3件）まで。子entryは `[auto]` プレフィックス＋根拠
  （台帳名 or 証跡1行）必須（実装契約-第1波 §5 の語彙）。
- `AIJOBS_RUN=1` で起動（`sweep.sh` が export・`sweep.py` も setdefault）: 自分と子プロセス（headless LLM）が
  session-board に自己登録しない＝sweepがボードの行を増やさない。
- 失敗（LLM失敗・タイムアウト・台帳パース失敗・内部例外）は**すべて exit 0 でボード無変更**（エラーはloopログのみ）。
- 版管理系の操作（commit等）はコードパスごと持たない（`tests/test_sweep.py` がソースを機械検証）。
- 既知の割り切り: `repo` 列が `?` の行を finish すると「終わったこと」に `### ?` 見出しができる
  （実データでは focusmap リモートスレッド等。dry-run実測で運用を確認してから流す）。

## LLM接続（SWEEP_LLM_CMD＝scripts/llm-judge.sh）

- ラッパ `scripts/llm-judge.sh`: stdin=プロンプト → `codex exec --ephemeral --sandbox read-only` →
  stdout=JSONオブジェクト1個。進行ログは stderr。判定セッションは `--ephemeral` で残らず、
  `AIJOBS_RUN=1` でボードに自己登録しない。
- **モデルはハードコードしない**: 引数 `$1` ＞ 環境変数 `SWEEP_LLM_MODEL`。未指定なら exit 78 で降りる
  （sweep 側は全行 unknown・不流入＝無害）。**実名の確定は人間ゲート**（plist の `SWEEP_LLM_MODEL` に記入）。
- 2026-07-10 実測: `gpt-5.4-mini` 動作OK（ChatGPTサブスク認証）。`gpt-5.6-luna` はサーバ側に実在するが
  codex-cli 0.142.5 ではバージョンゲートで不可（`codex update` 後に利用可の見込み）。
  `gpt-5.4-nano`・`gpt-5.1-codex-mini` はAPIキー認証専用（サブスクでは400）。
- reasoning effort は既定 medium（`SWEEP_LLM_EFFORT` で差替可）。

## 定型台帳

- 正本: `../../../hooks-registry/hooks/session-board/routine-ledger.md`
  （1定型=1節・キー5つ: 一致/終わり/確認/記載/判定。書式の説明は台帳先頭）。
- 節内に「ドラフト」の語がある間は自動finishしない（dry-runログにのみ出る）。
  初期3件（架電・印刷・focusmap定期）はドラフト・人間確認待ち。
- 一致条件は負条件 `goal除外=`（いずれか含めば不一致）も使える（2026-07-10 実装。
  「朝架電J列**の再発防止整理**」型の誤マッチを塞ぐ・ドラフト解除ゲート条件）。

## env（テスト/差し替え用）

- `GOAL_BASE` / `SESSION_BOARD_DATE` / `SESSION_BOARD_TX_ROOTS` / `SESSION_BOARD_NO_TURSO` … board.py と共通。
- `SWEEP_LEDGER`（台帳パス）/ `SWEEP_BOARD_DIR`（session-board 共有本体の場所）。
- `SWEEP_LLM_CMD`（headless LLM コマンド。stdin=プロンプト／stdout=JSON。未設定なら LLM 判定をスキップし
  unknown＝二重鍵不成立・台帳ルートのみ）/ `SWEEP_LLM_TIMEOUT`（既定180秒）/
  `SWEEP_LLM_MODEL`・`SWEEP_LLM_EFFORT`（llm-judge.sh 用）。
- `SWEEP_SILENCE_MIN`（機械証跡の沈黙閾値・既定120分）/ `SWEEP_LEDGER_SILENCE_MIN`（台帳一致時の沈黙ガード・既定30分）
  / `SWEEP_APPLY_MAX`（1sweepの自動finish上限・既定3件）。
- `SWEEP_DIGEST_MSG_MAX`（既定200字）/ `SWEEP_DIGEST_TOTAL_MAX`（既定2000字）/ `SWEEP_DIGEST_FIRST_MAX`（既定400字）
  / `SWEEP_LLM_ROWS_MAX`（既定40行）… 会話ダイジェストの丸め。

## テスト

- `tests/test_sweep.py`（envサンドボックス・fixtureボード・LLM stub・実ボード非接触。
  二重鍵3態〔機械のみ／LLMのみ／両方〕と会話ダイジェスト抽出〔Claude/Codex実フォーマットfixture〕を含む）。
  pytest互換（導入済みなら `pytest tests/`）。pytest未導入でも `python3 tests/test_sweep.py` で全件実行できる。

## ログ先

- `output/logs/board-sweep.{out,err}.log`

## 導入順（dry-run実測 → 人間GO → --apply・人間ゲート）

1. モデル実名を人間が確定 → plist の `SWEEP_LLM_MODEL` に記入（空の間はLLM判定なし＝台帳ルートのみ）。
2. 手動dry-run: `cd <このフォルダ> && python3 scripts/sweep.py`（ボード無変更・判定ログのみ）。
   LLM込みは `SWEEP_LLM_CMD=scripts/llm-judge.sh SWEEP_LLM_MODEL=<実名> python3 scripts/sweep.py`。
3. plistロード（**dry-runのまま**1週間実測。ロードは人間ゲート・symlink方式＝board-reconcile と同型）:

```sh
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/board-sweep/com.kitamura.board-sweep.plist' \
  ~/Library/LaunchAgents/com.kitamura.board-sweep.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.board-sweep.plist
launchctl enable gui/$(id -u)/com.kitamura.board-sweep
```

4. 二重鍵の判定ログ（◎の内訳・誤done率）を人間が確認（**人間GO**）→ 台帳エントリのドラフト行を消す →
   plist の ProgramArguments 末尾を `scripts/sweep.sh --apply` に変えて再ロード（流し込み有効化・人間ゲート）。
5. 23:30 の節目で当日の `[auto]` 一覧を人間レビュー（Shutdown儀式に1項目・子03側の担当）。

停止: `launchctl bootout gui/$(id -u)/com.kitamura.board-sweep`
有効化・停止したら `../../実行loop一覧.md` を同じ作業で更新する。
