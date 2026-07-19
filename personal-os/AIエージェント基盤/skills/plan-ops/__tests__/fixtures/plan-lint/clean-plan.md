分類: skill ／ 種別: 既存改善
規模: ライト
形態判定: 単発 ／ 理由: 同じrepo内で一つのrollback単位に閉じる
並列: 不可

# 合成正常plan

## 目的

plan-lintの正常fixture。

## 非対象

- runtime設定

## 現状

静的検査が必要。

## 実行契約

- 対象repo: repo無し
- 実行形: delegated-single
- 最初に読む順番:
  1. AGENTS.md
  2. この計画
- 依存成果: なし
- 変更可能範囲: docs/
- 変更禁止範囲: runtime/
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 既存lint互換
- 検証: bash __tests__/run.sh
- 停止・エスカレーション条件: 既存fixtureが壊れた時
- 完了時に返す情報: result packet

## 方針

最小変更で検査する。

## 完了条件

- [ ] clean-plan.mdがlintを通る

## 実装結果

実行後に追記する。

## 終了記録

archive時に追記する。
