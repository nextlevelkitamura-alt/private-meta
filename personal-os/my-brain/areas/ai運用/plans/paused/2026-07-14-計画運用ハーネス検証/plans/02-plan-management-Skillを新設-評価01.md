親計画: ../program.md ／ 対象計画: `plans/02-plan-management-Skillを新設.md` ／ ラウンド: 01 ／ 規模: フル ／ 評価者: repair_plan_registry（独立レビュー担当）
diff範囲: `AIエージェント基盤/skills/plan-management/`、`plan-registry/`、`global-skill-registry/catalog/meta.md`、`global-skill-registry/logs/created/2026-07/07-14-plan-management.md`、親program

# 評価01: plan-management Skillを新設

## 項目別採点   ※ 子計画の完了条件と同順

- [FAIL] `SKILL.md` が70行以内で、3 workflowとregistryを1ホップで参照できる。
  根拠: `SKILL.md` は36行でregistryと3 workflowを直接示すが、`manage-program.md` と `review-and-transition.md` に実在しない `plan-ops/<script>.sh` が3箇所あり、workflowを実行すると正しいscriptへ到達できない。
- [PASS] 各workflowに、起動条件、入力、期待出力、失敗時の停止、人間ゲート、親Skillへの戻り先、完了確認が書かれている。
  根拠: 3 workflowすべてに「起動条件・入力・期待出力」と「人間ゲート・失敗時・戻り先・完了確認」がある。
- [PASS] `kickoff`、`plan-triage`、`plan-ops`、`cockpit-supervisor` と発火条件・副作用・出力が重複していない。
  根拠: `SKILL.md` §委譲と境界が起票、書込みなしroute、固定script、実行レーン監督をそれぞれ委譲し、hook/session-boardを記録だけに限定している。
- [PASS] 正本path、catalog、作成ログ、`SKILL.html` が一致し、runtime symlinkを未承認で作成していない。
  根拠: catalogと作成ログは同じ正本pathを示し、5 runtime候補とhook登録に `plan-management` は存在しない。
- [PASS] `SKILL.html` が白背景で、入口Skill→既存Skill→計画文書の関係を説明できる。
  根拠: `color-scheme: light` と白背景を固定し、暗色切替・外部資源・JSはなく、registry→management→triage→ops→レビューの流れを示す。ローカル `file://` は既知のURLポリシーで開けないため静的確認までとした。

## 総合判定

FAILあり。`修正01.md` で3本のscript参照を `plan-ops/scripts/` 配下の実体へ直し、評価02で再確認する。

## 修正指示ドラフト

`manage-program.md` の `new-child.sh` と `progctl.sh`、`review-and-transition.md` の `check-section.sh` を、実体の `plan-ops/scripts/` を含むpathへ最小修正する。責務境界、HTML、runtime露出、hookは変更しない。
