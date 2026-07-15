---
name: inbox-triage
description: 人間が指定したデイリー依頼インボックス1行を、plan-triage.route/v1で既存plan合流・新規計画handoff・サクッと・停止へ分岐し、確認できた結果だけを元行へ記録する。起案調整までが仕事で、実装・自動巡回・active化はしない。Use when 「このインボックス行をトリアージして」とデイリーの絶対pathと対象行を指定された時。
---

# inbox-triage

指定された依頼インボックス1行だけを、安全な計画経路へ渡す。route判断を複製せず、対象repoへの直接writerにならない。

## 1. 必ず読む

1. `../plan-triage/references/route-contract.md`: action、停止、handoffの唯一の契約。
2. 規模判定時は `../plan-triage/workflows/triage.md` Step 2。
3. 雛形生成時だけ `../plan-ops/SKILL.md` §2.2。

## 2. 入力

1. 当日デイリーの絶対path。
2. 対象bulletの現在の完全な文字列。指定行以外を探索・処理しない。

## 3. routeとaction分岐

1. 対象行を `origin=private` として `plan-triage.route/v1` へ渡す。repo、領域、検索範囲、計画箱を本Skillで再判定しない。
2. `stop`: findingと人間が決める1点を返す。対象repo、デイリー、マーカーの書込みは全て0件。
3. `no_plan`: 実装せず、対象行へ `→サクッと判定(<1行理由>)` だけを付ける。
4. `join_existing`: canonical planの存在を確認し、対象行へ `→計画作成済み(<絶対path>)` だけを付ける。新規planは0件。
5. `create_new`: routeが返した解決済みpathだけを使う。root `plans/` やarea pathを推測・自動作成しない。
6. `handoff_required=true` なら6-field payloadを返し、新しい対象repo所有の可視sessionへ渡す。Private側はplanも成功マーカーも書かない。
7. 対象sessionのAGENTS読了、snapshot一致、`new-plan.sh --out <解決済みpath>` 成功、plan存在の報告後だけ、Private側を再開して成功マーカーを付ける。

## 4. planドラフト

1. 現在sessionがcanonical repoを所有しhandoff不要な時だけ、ライト以上を解決済みpathへ起案する。既存fileは上書きしない。
2. headerは分類・種別・規模、本文は目的・現状・方針・完了条件を持つ。現状に原文、デイリーpath、対象日を残す。
3. program化、active化、ops/code作成、commitは行わない。

## 5. 行マーカー

1. 入力文字列と完全一致する行1件だけを更新する。見つからなければ変更0件。
2. 旧 `→処理中(...)` は結果マーカーへ置換し、印なしは行末へ追記する。bullet本文と他行は変えない。
3. 新規付与は `→計画作成済み(` と `→サクッと判定(` だけ。着手・完了は実装担当が後で追記する。

## 6. 境界

通知、実装、外部API、secret、keychain、commit、push、削除、launchd、session ID移管を行わない。停止・handoff未完了を成功扱いしない。
