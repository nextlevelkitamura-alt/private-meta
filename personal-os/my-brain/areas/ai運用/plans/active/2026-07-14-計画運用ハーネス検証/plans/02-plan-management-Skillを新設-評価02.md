親計画: ../program.md ／ 対象計画: `plans/02-plan-management-Skillを新設.md` ／ ラウンド: 02 ／ 規模: フル ／ 評価者: repair_plan_registry（独立レビュー担当）
diff範囲: `AIエージェント基盤/skills/plan-management/`、`plan-registry/`、`global-skill-registry/catalog/meta.md`、`global-skill-registry/logs/created/2026-07/07-14-plan-management.md`、親program

# 評価02: plan-management Skillを新設

## 項目別採点   ※ 子計画の完了条件と同順

- [PASS] `SKILL.md` が70行以内で、3 workflowとregistryを1ホップで参照できる。
  根拠: `SKILL.md` は36行で、registryと3 workflowを直接案内する。`new-child.sh`、`progctl.sh`、`check-section.sh` はすべて実在する `plan-ops/scripts/` 配下を指し、旧pathはSkill配下に0件である。
- [PASS] 各workflowに、起動条件、入力、期待出力、失敗時の停止、人間ゲート、親Skillへの戻り先、完了確認が書かれている。
  根拠: 3 workflowすべてに「起動条件・入力・期待出力」と「人間ゲート・失敗時・戻り先・完了確認」がある。
- [PASS] `kickoff`、`plan-triage`、`plan-ops`、`cockpit-supervisor` と発火条件・副作用・出力が重複していない。
  根拠: 起票、書込みなしroute、固定script、実行レーン監督、実行記録を明示して委譲し、このSkillはそれらを再実装しない。
- [PASS] 正本path、catalog、作成ログ、`SKILL.html` が一致し、runtime symlinkを未承認で作成していない。
  根拠: catalog・created log・Skillの正本pathが一致し、5 runtime候補とCodex/Claude hook登録に `plan-management` は存在しない。
- [PASS] `SKILL.html` が白背景で、入口Skill→既存Skill→計画文書の関係を説明できる。
  根拠: `SKILL.html` とregistryの `AGENTS.html` は `color-scheme: light` と白背景を固定し、dark切替・外部資源・JSなしで責務フローを説明する。ローカル `file://` は既知のURLポリシーで開けないため静的確認までとした。

## 総合判定

全PASS。子02はフル計画の人間確認へ進める。runtime露出、hook接続、既存計画の移動は、この判定に含めず未実施のままとする。
