分類: 横断 ／ 種別: 統合整理

# ai-jobs縮小（run-cardキューの整理）

## 目的

機能していない ai-jobs（run-card キュー）を安全に縮小し、実行の主経路を
session-board＋対話ワーカー並列（並列実装フロー）へ一本化する。

## 現状

- ready / running / review すべて空・done 1件（exec-audit-20260702.md）のみ・archive 空（2026-07-08 確認）。
- `review` と `reviewing` の重複フォルダが放置されている。
- 規約参照: `areas/AGENTS.md` §4.2（計画から派生する作業は ai-jobs へ）ほか my-brain 系 AGENTS.md 数箇所。
- `common.py` の `AIJOBS_RUN` ガード（headless をボードに載せない）はキューと独立に有効。
- 縮小方向はユーザー裁定済み（2026-07-08・`../2026-07-08-並列実装フロー/plan.md` 裁定ブロック）。

## 方針（未確定・種まき）

1. `AIJOBS_RUN` ガードは残す（名前もそのまま。将来の Orca 等自動実行でも使う）。
2. done の1件は archive へ移し、`reviewing` 重複フォルダを解消する（移動・削除は人間承認の上）。
3. `areas/AGENTS.md` §4.2 と関連 AGENTS.md の「ai-jobs へ出す」導線を、並列実装フロー参照へ書き換える。
4. ai-jobs フォルダ自体の扱い（archive 化 or 空のまま残置）は実行時に裁定する。
5. 規約変更を伴うため、決定ログに縮小の決定を1件残す（運用契約 §8）。

## 完了条件（レビュー項目）

- [ ] `AIJOBS_RUN` ガードが common.py に残り、session-board テストが緑のまま
- [ ] `areas/AGENTS.md` §4.2 に ai-jobs への新規投入導線が無い（並列実装フロー参照へ置換済み）
- [ ] ai-jobs 配下に未処理カードが無く、`reviewing` 重複が解消されている
- [ ] 決定ログに縮小の1件が記録されている

## 関連

- 裁定元: `../2026-07-08-並列実装フロー/plan.md`
- 対象: `AIエージェント基盤/loops-registry/ai-jobs/`／`areas/AGENTS.md` §4.2
