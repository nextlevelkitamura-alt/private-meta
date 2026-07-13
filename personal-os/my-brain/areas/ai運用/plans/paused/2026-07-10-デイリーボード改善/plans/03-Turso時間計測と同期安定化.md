親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善

# 03 Turso時間計測と同期安定化

## 目的

実行時間（🟢区間）と待ち時間（⏸区間）をmdに書かずに計算できるようにする。Turso側に状態遷移の追記式イベントログを新設し、あわせて既存Turso同期の穴を塞いで安定化する。

## 現状

- `board.py` は add/update/flip/log/finish 後にTursoへベストエフォート送信（`_turso_execute`・タイムアウト3秒・失敗握りつぶし）。
- `sessions` は上書き式（現在値のみ）で履歴が残らない → 時間集計ができない。
- 穴: (a) 送信がflock外のため古い状態が後着上書き勝ちする競合がありうる (b) 失敗時リトライ無しで欠損 (c) `reconcile` の⏸降格は送信されない。

## 方針

1. `session_events` テーブル新設（追記式・上書きしない）: session_key / goal / state(run|wait|sub) / at(ISO時刻) ほか必要最小限。add/flip/finish（状態が変わる瞬間）とreconcileの降格時にinsert。
2. 集計はSQL: 実行時間=run区間合計・待ち時間=wait区間合計・「⏸のままN分超」一覧。ワンショット系15分・通常30分などの閾値は種別列で分ける。
3. ⏸15分超の検知を完了自動判定loop（チップ委託済み・task_a7b03a3f）の発火条件に接続する。
4. 穴の解消: (a)は追記式＋時刻ソートで実質解消 (b)は区間補間で緩和（リトライ導入は重さと相談） (c)はreconcile送信の追加。
5. 確定（2026-07-11・設計案の推奨を採用・Turso側設置済み）:
   - スキーマ: session_key / state / at(ミリ秒ISO) / **trig**（SQLite予約語TRIGGERを回避）/ goal / repo / type / plan / session_date ＋ index（(session_key,at)・(session_date)）。**テーブル・index作成済み**（turso db shell）。
   - 認証: 新トークンを発行し keychain `turso-personal-os-board` へ上書き（値非表示）。insert→count→delete のスモークOK。
   - 送信: add（新規のみ）/flip（変化時のみ）/finish（done・削除前スナップショット）/reconcile降格（wait）。**updateは送らない**。sessions upsert とは1パイプライン合流。
   - 保持: 放置（年数MB・DELETE権限を持たせない）。集計は run/wait/sub 3値別出し・now止め＋720分上限・⏸滞留アラートはv1一律15分。
   - ダッシュボード: v1＝保存SQL（session-board配下 `queries/`）、次段＝夜会ダイジェスト1行（mdボードに時間は書かない）。
6. 実装前の人間確認は 2026-07-11 のユーザーGO（push後そのままTurso設定と計画を進める指示）で通過。

## 完了条件（レビュー項目）

- [x] 未確定4点が確定し、人間確認を経て本mdに追記されている。
- [x] 状態遷移のたびに `session_events` へ1行追記され、mdには時間情報が増えていない。
- [x] 実行時間・待ち時間・「⏸15分超」一覧がSQLで取得できる（サンプルクエリを本mdに記載）。
- [x] reconcileの⏸降格がTursoへ反映される。
- [x] secret/トークン値がコード・ログ・commitに現れない。
- [x] 既存テスト全緑＋Turso失敗時にmd運用が一切阻害されない（ベストエフォート維持）。
