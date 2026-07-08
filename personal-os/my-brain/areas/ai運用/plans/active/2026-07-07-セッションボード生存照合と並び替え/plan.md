# セッションボード 生存照合と並び替え

状態: 実装・検証・実適用まで完了。Claude側は稼働確認済み。残＝Codex側の実測（再trust後）と日付跨ぎの恒久対応（別課題）。

## 背景（問題）

ボードは純粋なイベント駆動で、状態を抜けるのに「閉じる合図」が要る（🟢→⏸は Stop、🔵→🟢は手動戻し）。
その合図は **中断（Esc）・ウィンドウを閉じる・クラッシュ・戻し忘れ** では鳴らず、行が永久固着する。
実測（2026-07-06 23:48）: 🟢動作中8行のうち4つは4〜10時間前が最後の死体、🔵1つも4時間前の残骸。IDは全て正しく取れており、原因は識別不能ではなく**生存確認レイヤの不在**。

## 決定（設計）

- **生存シグナル＝実体トランスクリプトの mtime**。ツール実行のたび追記されるので、長い1ターン中でも更新され続け誤判定しにくい（board更新時刻だと長い自律ターンで誤検知する）。
- **`reconcile`**: 🟢/🔵の各行の実体（Claude=`~/.claude/projects`、Codex=`~/.codex/sessions` の `.jsonl`）を照合し、`STALE_MIN`（既定10分）超の沈黙は**⏸へ降格**。実体が見つからない行は判定不能として触らない。**状態は3値のまま**（新状態を作らない）。
- **並び替え `sort_agents`**: どの書き込み後も「動いているエージェント」節を **🟢→🔵→⏸**（`STATE_RANK`）、各群内は**時刻昇順**に整列。死体は自動で下段へ沈み、上段＝生きているセッションになる。
- **発火＝各hook相乗り（インフラ0）**: `common.stop_flip`（Stop＝ターン終了）と `common.start_lines`（SessionStart）から `board_reconcile()`。**UserPromptSubmit（＝開始）には乗せない**＝開始レイテンシを守る。
- 却下: サブエージェント委託（調査結論＝技術的に不可〔Codexはprompt/agent/async全skip・Claudeもdispatch不可 issue#64898〕・逆効果・世界も決定論一択）。速くしたい場合の正解は記録hookの非同期化（Phase2・今回未実施）。

## 実装（このcommit）

- `hooks/session-board/board.py`: `reconcile` コマンド＋`reconcile_rows`／`sort_agents`／`_list_transcripts`／`_newest_for`／`_tx_roots`、定数 `STATE_RANK`・`STALE_MIN`。全書き込み後に `sort_agents`。`--key` は reconcile では不要。行フォーマット（`LINE_RE`）は不変。
- `hooks/session-board/common.py`: `board_reconcile()` 追加、`stop_flip`＋`start_lines` から相乗り呼び出し。
- 受け口（claude/・codex/ の各.py）は**不可触**（薄いシムのまま）。共有本体2ファイルだけで両runtimeに効く。
- doc: `README.md`（コマンド・「生存照合と並び替え」節・既知の制約更新）、`AGENTS.md`（common関数・規律）。
- 探索根は `SESSION_BOARD_TX_ROOTS`（:区切り）で差し替え可（テスト・移設用）。

## 検証

- 隔離テスト（`scratchpad/test_reconcile.py`）: 死んだ🟢/🔵→⏸、生存🟢/🔵維持、実体なし維持、並び順 🟢→🔵→⏸・時刻昇順、空ボードでファイル非生成 — 全PASS。
- 実データ ドライラン（実07-06の複製・本物のトランスクリプト）: 死体7行を⏸へ、🟢維持は生きている2つ（`9b4dfa42`・`73feaa82`）＝体感「2つだけ」と一致。
- 実適用: 実 2026-07-06 ボードへ `SESSION_BOARD_DATE=2026-07-06 board.py reconcile` を1回適用。集計 `{🟢:2, ⏸:23}`・状態順整列を確認。

## 残・既知課題

- **日付跨ぎ（midnight carryover）＝未解決**: `reconcile` は当日ボード対象。前日ボードの固着や、深夜跨ぎで生きているセッションの行（前日側に残る）は自動掃除されない。当面は `SESSION_BOARD_DATE=… board.py reconcile` を手動。恒久対応（前日も掃く／生存行を当日へ転記／表示は最新n日を横断 等）は別途検討。
- **Codex側 reconcile の実測**: 受け口再編（2026-07-06）で `/hooks` 再trust待ち。再trust後、Codexで開始🟢/Stop⏸に加え reconcile 相乗りが効くか実測。
- Phase2（記録hookの非同期化 `async`/detach）は今回スコープ外。開始が遅いと感じたら着手。

## 完了条件

- [x] reconcile＋sort 実装（board.py・common.py）
- [x] 隔離テスト・実データ検証PASS
- [x] 実07-06ボードへ適用し「上=生きてるだけ」を確認
- [x] doc（README・AGENTS）更新
- [x] commit＋push（人間ゲート）
- [ ] Codex再trust後に Codex側 reconcile 実測
- [ ] 日付跨ぎの恒久対応を判断（別課題として起票可）
