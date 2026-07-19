---
name: plan-create-review
description: 計画を作る・既存計画へ合流する・programの子計画を管理する・評価と遷移を進める・終了を伝えてdone/archiveへ閉じる時に、plan-registryと既存のplan-triage/plan-opsへ正しくつなぐ利用者向け入口Skill。Use when「この仕事の計画を作って」「既存計画に入れたい」「子計画を追加したい」「計画を評価して」「この計画は終了・archiveへ」。作業の起票、route基準の定義、scriptの再実装、実装レーンの監督には使わない。
---

# plan-create-review

計画ライフサイクルを扱う人間・AI向けの一本入口（create=作る・evaluate=評価する。終了→archiveまで受ける）。経路判断・script・評価合否を自分で再実装せず、既存の正本へつなぐ。

## まず読む正本

1. `../../plan-registry/AGENTS.md`: 規模・段階・責務・人間ゲートの基準。
2. `../../../my-brain/areas/AGENTS.md`: area計画の物理バケット、評価文書、卒業手順。
3. 対象repoの最寄り `AGENTS.md`: repo固有の計画箱とローカル規約。

## Workflow振り分け

1. `workflows/create-or-join.md`: 「計画を作る」「既存計画へ入れる」。routeを解決してから合流または起案する。
2. `workflows/manage-program.md`: 「子計画を足す」「programの状態を更新する」。親子と子計画マップを管理する。
3. `workflows/evaluate-and-transition.md`: 「評価する」「完了・archiveへ進める」「終了を伝えられた（done→終了記録→archive）」。通常のprogram子は完了条件の評価で閉じ、親だけを最終人間確認へ送る。危険操作は該当子で実行前に止める。

## 委譲と境界

1. `plan-triage` は基準を依頼へ適用して書込みなしrouteを返す。このSkillはroute JSONや置き場判断を再実装しない。
2. `plan-ops` は雛形、既存子計画マップ更新、静的lint、planning→active昇格の固定scriptを持つ。このSkillはscriptを複製しない。
3. `kickoff` はデイリーへの起票ゲート、`cockpit-supervisor` は実行中レーンの監督。どちらの本文・状態も所有しない。
4. hook / session-boardに計画本文・状態・repo・評価合否を決めさせない。

## 絶対ルール

1. サクッと3条件が全YESでない、または不明なら、実装前にこのSkillから計画経路を解決する。
2. 置き場不明、既存plan競合、未承認の移動・削除・runtime変更は停止し、人間へ戻す。
3. 計画本文と子計画マップを正本とし、第2の状態台帳を作らない。secret・token・認証値を記録しない。
4. runtimeへのsymlink露出はこのSkillの作成とは別の人間承認ゲートである。

人間向けの構造説明は `SKILL.html`。正本はこの `SKILL.md` と3つのworkflowである。
