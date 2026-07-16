# plan-create-review 移行（plan-managementから改名）

- 日付時刻: 2026-07-16 19:53 JST
- 旧正本: `personal-os/AIエージェント基盤/skills/plan-management/`
- 新正本: `personal-os/AIエージェント基盤/skills/plan-create-review/`
- 概要: 計画の作成・既存plan合流・program管理・評価（レビュー）・終了（done→終了記録→archive）を既存正本（plan-registry / plan-triage / plan-ops）へつなぐ利用者向けの一本入口Skill。
- 移行理由: 利用者が打つ計画コマンドを1本にし、名前を意図（create=作る・review=評価）で読めるようにする人間裁定（2026-07-16チャットで一本化・改名・露出を承認、名称は選択式で確定）。plan-triage / plan-ops は内部道具として存置。
- 正本選定: `git mv` による改名で履歴を維持。SKILL.md・SKILL.html・workflows 3本は同一実体のまま名称と受け口記述だけ追従。
- 検証: session-boardテスト全緑（builders 14・common 13・events 43・events_sql 26・output_layers 7・reconcile 16・spool 16）。旧名の残参照は過去記録（plans/配下・logs/created/）のみをgrepで確認。
- runtime露出結果: `scripts/link-global-skill.sh plan-create-review` で `~/.agents/skills`・`~/.codex/skills`・`~/.claude/skills`・`~/.gemini/config/skills`・`~/.gemini/antigravity-cli/skills` の5箇所へsymlink作成・verify通過。旧名はどのruntimeにも未露出だったため置換・削除なし（未露出欠陥の同時解消）。
- 備考: 旧名の作成履歴 `created/2026-07/07-14-plan-management.md` は温存。計画書は `my-brain/areas/ai運用/plans/active/2026-07-16-計画入口一本化/plan.md`。
