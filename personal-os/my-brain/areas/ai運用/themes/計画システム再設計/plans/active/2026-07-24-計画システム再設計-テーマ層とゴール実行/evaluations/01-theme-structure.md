# 評価01

対象: Theme構造移行（`goal.md`、`concepts/`、`plans/`、最寄り規約、参照更新）
範囲: 実行ライン04bのみ。計画全体のdone判定ではない。

## 結果

- [PASS] Theme直下は管理ファイルを除き `goal.md`、`concepts/`、`plans/` のみであり、旧 `topics/`、`references/`、`壁打ち/` は残っていない。
- [PASS] 構想は `concepts/topics/`、`concepts/research/`、`concepts/discussion-logs/` にあり、Theme固有active計画は `plans/active/` へ移動している。親正本は `plan-0.md`、評価は `evaluations/`、調査資料は `concepts/research/` に分離している。
- [PASS] Theme最寄り `AGENTS.md`、ai運用area、areas、plan-registry、triageがAI運用の計画箱をTheme配下だけに限定し、Theme外の実装計画を所有repoへ解決する。
- [PASS] `plan-lint.sh`、相対リンク検査、`git diff --check`、`CLAUDE.md -> AGENTS.md` を検証する。

## 判定

PASS。Theme構造移行の受入条件は満たす。Goal/Tursoのフィールド境界、Focusmap UI、schema、同期はこの評価の対象外であり、既存計画の未完了条件は維持する。
