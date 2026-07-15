---
name: plan-triage
description: 「やりたいこと」1件を受け、規模・対象repo・計画箱・実行形・モデルを決める入口Skill。Private起点ではrepo-registryで担当repoだけを選び、対象repoの最寄りAGENTS.md→既存plan検索→宣言済み計画箱の順に二段ルーティングする。repo内起点、計画の置き場、構成カード、既存plan合流を判断したい時に使う。実装中の監督、単なる要約、Skill作成には使わない。
---

# plan-triage

「やりたいこと」1件を、実行前に安全な計画経路とruntime非依存の実行構成カードへ変換する。判断までが仕事で、repoへの書込み・レーン起動は行わない。

## 1. 必ず読む

1. `workflows/triage.md`: 規模・経路・実行形・モデルを順番に判断する実行手順。
2. `references/route-contract.md`: 二段ルーティング、fail-closed、出力JSON、handoffの唯一の契約。
3. route変更時は `scripts/fixtures/route-cases.json`、`scripts/validate-route-cases.mjs`、caller変更時は `scripts/validate-inbox-contract.mjs` を使う。

## 2. 規模と入力

1. やりたいこと1行。
2. 起点pathまたは起点種別（repo内 / Private / headless）。
3. 対象repo見当。不明でよい。
4. 影響範囲と戻しやすさ。不明な時だけ追加質問は最大2問。
5. 1〜2ファイル・1手で戻せる・人間ゲートなしなら `サクッと`、1レーン完結なら `ライト`、独立子計画2本以上・複数レーン・複数ゲートなら `フル`。詳細はworkflow Step 2。

## 3. 経路の不変条件

1. repo内起点は最寄り `AGENTS.md` から始め、repo-registryを読まない。
2. Private起点はrepo-registryで担当repoだけを決め、領域・project・計画箱は対象repoの最寄り `AGENTS.md` から決める。
3. 宣言範囲で既存planを先に検索し、一意なら合流する。新規作成は一致0件かつ宣言箱が一意な時だけ提案する。
4. 計画箱未宣言、同順位複数、既存plan競合、正本不明はexit 3で停止する。root `plans/` を推測・自動作成しない。
5. Private起点で対象repoへ書く前は、新しい対象repo所有sessionへのhandoffを必須にする。既存session IDを移管・reparentしない。
6. plan header・状態・ID・alias解析は所有repoのindex契約へ委譲し、このSkillで再実装しない。
7. hookはrepo・領域・計画pathを決めない。

## 4. 出力

1. `plan-triage.route/v1` JSON。
2. 実行形・必要役割・write lane数・worktree・レビュー・人間ゲート・判定理由を含む構成カード。モデル選択は `AIモデル一覧.md` を参照するが、計画本文には固定しない。
3. ライト以上は解決済みpathを渡す計画スケルトン案。
4. 停止時はfinding code、人間が決める事項、書込み0件を返す。

## 5. 境界

1. 実行中の監督は `cockpit-supervisor`。
2. 雛形生成・lint・root bucket操作は `plan-ops`。`bucketctl` を領域planへ使わない。
3. repo新規作成・整備は `repo-create`。
4. 削除、push、main反映、hook/launchd登録、外部書込みは人間承認なしに行わない。
