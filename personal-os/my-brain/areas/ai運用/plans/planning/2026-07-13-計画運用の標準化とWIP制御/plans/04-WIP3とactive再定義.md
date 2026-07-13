親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善

# WIP3とactive再定義(＋bucketctl昇格自動化)

## 目的

active の同時実行数を制御し、育成中と実行中の混在で膨れた active を「今動かす ≤3」に絞る。あわせて planning→active の昇格を機械化し、上限超過を弾く(「実装前にちゃんと active へ移す」を手作業の漏れ無しにする)。

## 現状

`areas/AGENTS.md` §3 は active を「育成中、**または** area 内で実行中」と定義 → 温めているだけの計画も active に溜まり、ai運用 active=**32件**。WIP を制限する規約もチェックも無い。バケット遷移は `plan-ops` SKILL.md §3 が「active↔paused↔done↔archive は `git mv` で手動」と明記し、昇格・WIP確認の自動化は無い(progctl はマップ書換のみ)。

## 方針

1. active の定義を「**実行中(今週着手・進行中)のみ・≤3**」へ。育成中で今動かさないものは既存の `planning/`(方針検討中)か `paused/`(一時停止)へ。新バケットは作らない。
2. active から外す経路: **重要**=レビューして実装確認の上 archive、**軽微**=理由タグ付きで archive 直行 or paused。`archive=評価済みOK` の不変条件は「理由: 評価済み / 軽微棚上げ」の1語タグで両立させる。
3. ai運用 active 32件を上記でトリアージ(→3件)。移行は `git mv`、**削除はしない**(削除は人間承認・§5)。
4. **昇格の機械化**: `scripts/bucketctl.sh` を新設。`promote <計画パス> --to active` で `git mv`、active 数が上限超過なら**弾いて現 active 一覧を表示**(何を外すかの選択は人間=**追い出しは自動化しない**)。既定 dry-run・`--commit` で定型コミット(progctl と同じ流儀)。削除・卒業は扱わない(§5 の人間ゲート維持)。kickoff/plan-triage の実装開始フローから呼び「実装前に planning→active 昇格」を導線化。`__tests__` を追加し、SKILL.md §3 の「手動」記述を追従。

## 完了条件（レビュー項目）

- [ ] §3 に active=実行中のみ≤3・育成中→planning/paused が定義されている。
- [ ] active 除外の経路(重要=レビュー後 archive／軽微=理由タグ付きで棚上げ)が §3 にあり、`archive=評価済みOK` の既存不変条件と矛盾しない。
- [ ] ai運用 active が3件以下になり、外した計画が planning/paused/archive に理由付きで配置されている(削除は `git mv` のみ・していない)。
- [ ] `bucketctl.sh promote --to active` が `git mv` を行い、上限超過時は弾いて active 一覧を表示する(追い出しは自動化しない・既定 dry-run・`--commit` 対応)。
- [ ] kickoff もしくは plan-triage から昇格が呼ばれる導線があり、SKILL.md §3 の「手動」記述が追従されている。
- [ ] `__tests__` に bucketctl のテストがあり `run.sh` が緑。決定ログに1件。
