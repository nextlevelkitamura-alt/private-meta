# settings-ui-architect

- 日付時刻: 2026-07-08 14:36 JST
- 削除元: `/Users/kitamuranaohiro/.codex/skills/settings-ui-architect`（codex実体・野良）
- 概要: 設定/管理/課金/セキュリティ等のUI設計・評価・改善・モック・実装分割を扱うCodex専用の本格orchestration skillだった（12 workflow＋4 refs＋4 templates）。
- 削除理由: グローバル整理Box A。設計知識（taxonomy/rubric/benchmark/acceptance）は `ui-ux-pro-max` へ吸収（`references/settings/`＋`assets/settings/`）。汎用の受け渡しorchestration（two-chat runbook/worker分割/integration/timeline gates/handoff）は `coding-task-orchestrator`＋`handoff-plan-supervisor` と重複するため意図的に落とした（ユーザー決定「設計知識だけ吸収」）。単独skillとしては不要化。
- 露出: codex単独実体のみ（窓なし）。撤去により全runtimeから消滅。設定設計知識は ui-ux-pro-max（全5runtime露出）から使える。
- 退避先: `~/.skills-trash/20260708-140817/codex/settings-ui-architect`（復元可・落としたorchestration含む全体を温存）。
- 検証: ui-ux-pro-max に4ファイル（settings-taxonomy/ui-quality-rubric/benchmark-targets/ui-acceptance-template）がコピーされ、SKILL.mdに「Settings / Admin / Preferences UI Design」参照セクション追加、codexに残存なしを確認。
- 備考: 吸収は設計知識のみ。落としたorchestrationが必要なら trashから復元、または `coding-task-orchestrator` 併用。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
