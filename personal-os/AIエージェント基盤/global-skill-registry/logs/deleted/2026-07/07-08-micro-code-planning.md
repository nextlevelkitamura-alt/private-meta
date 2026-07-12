# micro-code-planning

- 日付時刻: 2026-07-08 14:08 JST
- 削除元: `/Users/kitamuranaohiro/.codex/skills/micro-code-planning`（codex実体・野良）
- 概要: 開発計画のミクロ（実装単位）観点を扱うCodex専用の単一ファイルskillだった（`SKILL.md`＋`agents/openai.yaml` のみ）。
- 削除理由: グローバル整理Box A。基盤の計画系スキル（`coding-task-orchestrator`＝9 workflow / `plan-triage` / `plan-ops` / `grill-me`）が全runtime露出済みで遥かに厚く、本skillの「実装計画の原則」は薄い重複＝冗長。
- 露出: codex単独実体のみ（窓なし）。撤去により全runtimeから消滅。
- 退避先: `~/.skills-trash/20260708-140817/codex/micro-code-planning`（復元可・README付き）。
- 検証: `grep` 参照ゼロ（skills/catalog/loops）、他runtime窓なしを確認のうえ撤去。撤去後codexに残存なし。
- 備考: created/migratedログは無し（野良のため引き継ぎ不要）。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
