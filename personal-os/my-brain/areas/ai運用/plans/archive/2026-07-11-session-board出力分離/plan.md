分類: hook ／ 種別: 既存改善 ／ 規模: フル
優先: ◎

# session-board出力責務をmd/tursoに分離

## 目的

稼働中の `session-board/board.py` に混在するMarkdown更新とTurso送信を、同じ `session-board/` 配下の `md/` と `turso/` へ責務分離する。hook・loopの発火点は増やさず、`board.py` は「MD確定→Tursoベストエフォート送信」を調停する入口にする。

## 現状

- 人間合意: `hooks-registry/hooks/session-board/{md,turso}/` に分ける。MD用hookとTurso用hookは別々に作らない。
- `board.py` は、MDのparse・描画・flock・原子置換、Turso SQL builder・HTTP送信・spool再送、CLI調停を1ファイルに持つ。
- Claude/Codex受け口は `common.py` 経由で `board.py` を呼ぶ。`board-reconcile` と `board-sweep` も `board.py` のCLI/公開関数を使う。
- 送信順は既にMD確定後のTurso送信。events/logsのみspoolし、MDの成功はTurso失敗で巻き戻さない。
- 本作業は稼働中hookの内部分離であり、行形式・CLI・Turso schema・runtime登録を変えない。

## 方針

### 目標構成

```text
hooks-registry/hooks/session-board/
├─ board.py             CLI・コマンド調停・互換re-export
├─ common.py            runtime共通受け口（原則不変）
├─ md/
│  ├─ AGENTS.md
│  ├─ CLAUDE.md -> AGENTS.md
│  ├─ __init__.py
│  └─ store.py        日付path・parse・描画・flock・原子書込
├─ turso/
│  ├─ AGENTS.md
│  ├─ CLAUDE.md -> AGENTS.md
│  ├─ __init__.py
│  ├─ store.py        token取得・SQL builder・HTTP送信・コマンド別sync
│  └─ spool.py        events/logsの失敗追記・再送・ロック
└─ tests/
```

### 実装契約

1. `board.py` のCLIと、既存外部がimportする名前（例: `parse_line` / `daily_path` / `_tx_roots`）を保つ。必要なものは明示re-exportにする。
2. 処理順は `md` の原子書込成功→flock解放→`turso` 送信のまま。Turso失敗をMDに伝播させない。
3. `add/update/flip/sub-start/sub-end/log/finish/reconcile/goal-add/check/show/goals` の入出力・冪等性・SQLバッチ内容を変えない。
4. `session_events` / `session_logs` だけをspool対象にする現契約、3秒timeout、最大50文再送、keychainからのsecret取得を保つ。
5. runtime受け口、`~/.claude` / `~/.codex` 露出、hooks.json/settings.json、launchd plist、Focusmap、Turso schemaは変更しない。
6. `session-board/AGENTS.md` と `README.md` の構成・責務説明だけを実装に追従させる。
7. 新規parity loopの実装・ロード、Turso schema追加、Focusmap UI改修はこの計画の対象外。

## 完了条件（レビュー項目）

- [x] `session-board/md/` がMD path・parse・描画・flock・原子書込を所有し、Turso/HTTP/keychainに依存しない。
- [x] `session-board/turso/` がSQL builder・HTTP送信・spool再送を所有し、デイリーMDを直接書き換えない。
- [x] `board.py` がCLI調停と互換re-exportに絞られ、処理順がMD確定→Tursoベストエフォートのままである。
- [x] `common.py`、Claude/Codex shim、`board-reconcile`、`board-sweep` からの呼び出しが無変更または互換層経由で解決し、runtime登録・plistにdiffがない。
- [x] `tests/test-session-board.sh`、`test-shims.sh`、`test_builders.py`、`test_common.py`、`test_events.py`、`test_events_sql.py`、`test_reconcile.py`、`test_spool.py` が全PASSする。
- [x] 互換テストが追加され、各CLIのMD差分とTurso statementが分離前契約と一致する。
- [x] `SESSION_BOARD_NO_TURSO=1` の全E2Eで外部DBへ送信せず、テストが本番MD・Turso・secretに触れない。
- [x] `session-board/{AGENTS.md,README.md}` の構成説明が `md/` / `turso/` 分離後の実体と一致し、secret・token・認証値の混入がない。

## 実装結果

- `sol` が本計画MDを正本に実装。`board.py` を222行のCLI調停＋互換re-exportへ縮小した。
- MD処理を `md/store.py`、Turso SQL/HTTPを `turso/store.py`、失敗再送を `turso/spool.py` へ分離した。
- 既存8テスト＋追加互換テストで263 PASS / 0 FAIL。独立subagentレビューも8/8 PASS。
- runtime shim、hooks.json/settings、launchd plist、Focusmap、Turso schema、外部DBは変更していない。commit / pushも未実施。

## レビュー方法

- 実装とは別のsubagentが上の項目順に採点し、メインが結果を `評価01.md` に記録する。
- FAILがあれば `修正01.md` を正本に1回だけ差し戻し、再評価する。
- 実装完了後も計画フォルダの移動、commit、push、hook/launchd再登録はメインの人間確認後だけ行う。
