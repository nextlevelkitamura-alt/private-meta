分類: 横断
種別: 既存改善
親計画: ../program.md

# AGENTS規約追記＋ai-jobs雛形

## 目的
program層（親子・判定基準・子計画マップ・references）、タスク実行の ai-jobs 化、子→親 backlink を governance に反映する。

## 方針
- areas/AGENTS.md: §3 に program層、§4 を「計画状態語彙＋ai-jobs」に再構成、§5 に子の個別卒業＋backlink。
- 基盤 AGENTS.md §1 に `ai-jobs/` を追加。基盤 `ai-jobs/AGENTS.md`（＋CLAUDE symlink）と `.gitignore` 除外を新設。
- 旧 `ops/` 5フォルダ構成は廃止。既存計画に残る `ops/` は legacy（新規には作らない・破壊しない）。

## 完了条件
- areas §3/§4/§5 と 基盤 §1 が更新済み。
- 基盤 `ai-jobs/{ready,running,review,done,archive}` ＋ `AGENTS.md`（＋CLAUDE symlink）＋ gitignore除外が存在。
- 既存 plan の `ops/` は未削除のまま。

## 結果
2026-06-30 着手・実施。上記 governance 反映と ai-jobs 雛形作成を本作業で実行（この子計画を実行した）。残: 反映の最終確認とコミット。
