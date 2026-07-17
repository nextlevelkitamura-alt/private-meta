分類: loop ／ 種別: 新規作成 ／ 優先: ○ ／ 規模: フル
次: focusmap側でTurso `personal-os-board` を読むUIを新設する判断（focusmap repo側のplansで別途起票するか、personal-os側で完結させるか）。

# デイリー状態のTurso表反映（session-board源・board.py統合）

## 目的

当日デイリーの「動いているエージェント」「終わったこと」を、personal-os専用のTurso DBへ送り、将来focusmap UIで「今日の目標」と「AIの実際の動き」を1画面で俯瞰できるようにする。正本は常にローカルMD（デイリー）。Tursoは表示専用のミラー。2026-07-08のHTML設計書（AI運用2軸統合設計）の軸2に対応する実装計画。設計書: https://claude.ai/code/artifact/ce9fa3fc-eb6e-4650-baf8-c0a14a7eb8fb

## 現状（2026-07-08 実装完了）

- デイリーは session-board（`hooks/session-board/board.py`）がイベント駆動・flock排他で2節を書く（`## 動いているエージェント`／`## 終わったこと`）。同じ源データから Notion 連携（`../2026-07-06-デイリーNotion表反映/plan.md`・実装未着手）が並行進行中。両計画は送信先が別（Notion API／Turso）なので独立に進める。
- **Turso DB新規作成**: `personal-os-board`（focusmapの`focusmap-codex-monitoring`とは別・独立DB。無料枠のDB数上限100に対し2/100で余裕。focusmap側の将来変更に巻き込まれないための分離）。テーブル: `sessions`（層1・今動いてる行）／`session_logs`（層2・終わったこと）。
- **board.py本体にTurso送信を統合済み**: `add`/`update`/`flip`→`sessions`へupsert、`log`/`finish`→`session_logs`へinsert（`finish`は同時に`sessions`から自行削除）。3本目のhookや非同期loopは新設せず、既存コマンドがそのまま両方やる設計に変更（当初案からの軌道修正・下記「経緯」）。
- **限定トークンをkeychain保管**（`turso-personal-os-board`）。`sessions`/`session_logs`テーブルのみ読み書き可能（`--permissions`でテーブル単位に絞り込み。Codex監視データには一切触れない）。
- **実機テスト全PASS**: add/update/log/finishの4パターンをTurso実データで確認。既存のPython単体テスト10本＋シェル統合テスト87本も回帰確認済み（`SESSION_BOARD_NO_TURSO=1`ガードでテスト実行時はTurso送信をスキップし、本番データに混ざらないようにした）。
- **無料枠は問題なし**: Starterプラン書き込み上限は月1000万行、現在の想定利用は月数千行程度（0.1%未満）。超過時も課金でなく単にブロックされるだけ（Overages disabled）。

## 経緯（設計変更の理由）

当初は「機械送信=同期(3本目のUserPromptSubmit hook新設)・要約送信=非同期(daily-notion-sync同型loop新設・LLM API要約)」の2層構成で計画したが、ユーザーからの指摘で以下に変更した:
1. **「終わったこと」のentry自体が、AIが既に人間向けに要約済みの1行**（`board.py log --entry "..."`はAIが手で書く）。追加のLLM APIで再要約する意味がなく、そのままTursoへ送ればよい。
2. よって層2は「非同期loop」でなく「`board.py log`実行時にそのまま送る」で足りる。これなら層1・層2とも**board.py本体への統合**で完結し、新規hookも非同期loopも不要になった。
3. DB配置は当初「focusmap-codex-monitoringに相乗り」を検討したが、①今後のfocusmap開発に巻き込まれるリスク、②テーブル名の分かりやすさ、の2点から独立DB `personal-os-board` に変更（無料枠のDB数枠は100あり相乗りの必要性がそもそも無かった）。

## 未確定 / 運用で決める

- **focusmap UI側の接続**: 現状Tursoにはデータが流れているが、focusmapのNext.jsアプリからこの`personal-os-board`を読む実装はまだ無い（既存`/dashboard/ai-todos`はSupabase読み取りのため直結しない）。新規ページ/APIをfocusmap側に作るか、personal-os側で完結させる（HTML等で都度可視化）かは未定。focusmap側の作業になる場合、あちらのrepoの`plans/`で別途計画する。
- **`reconcile`コマンドはTurso同期の対象外**: 沈黙行の⏸降格・幽霊枠掃除はTursoへ反映されない（現状割り切り。実害は「Turso側のstateが実態よりrunのまま残る」程度で、次のadd/update/flip呼び出しで自然に上書きされる）。

## 完了条件（レビュー項目）

- [x] Turso接続情報とスキーマが用意され、personal-os側から書き込み可能な認証経路（keychain）が用意されている。
- [x] `board.py` の `add`/`update`/`flip` 実行時、flock解放後にTursoへ機械送信される（実機確認・Turso側`sessions`テーブルに反映）。
- [x] `board.py` の `log`/`finish` 実行時、entryがそのまま`session_logs`へ送信される（追加LLM API呼び出し不要と判明・実機確認）。
- [x] `finish`実行時、`sessions`から自行が削除される（実機確認）。
- [ ] focusmapのUIで、personal-os発のデータが表示される（未着手・次の一手）。
- [x] token・認証値がrepo・ログ・デイリーのどこにも出ない（1度出力事故があったが即検知しDB作り直しで無害化・以後は生成→keychain直格納のみで運用）。
- [x] Turso障害時にローカルMD運用が一切影響を受けない（`_turso_execute`は例外を握りつぶす設計・タイムアウト3秒）。
- [x] テスト実行時に本番Tursoへデータが漏れない（`SESSION_BOARD_NO_TURSO=1`ガードを追加・既存テスト87本+10本を回帰確認）。
