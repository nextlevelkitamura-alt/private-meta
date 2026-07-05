# agent-task-orchestrator（削除）

- 日付時刻: 2026-07-03 JST
- 削除正本: `skills/agent-task-orchestrator/`（SKILL.md＋references/7＋workflows/9＋templates/7・約100K）
- 承認: 2026-07-03 ユーザー承認（決定ログ#8。去就自体は#4で決定済み）
- 理由: Small/Medium/Large＋docs/tasks生態系前提の英語上位オーケストレーター。実運用実績なし・存在しないスキルへの参照多数・正本パス記述が旧所在（実害級の誤情報）。現行正本3点（契約§2＋program実行体制＋cockpit-supervisor）で置換済み。
- 吸収部品の移動先（詳細=同フォルダ `07-03-吸収候補調査-子08.md`）:
  - 破壊操作列挙の補完（本番データ・migration） → `説明書/運用契約.md` §2（人間承認済み）
  - 調査要否の入口基準 → `skills/plan-triage/SKILL.md` §4（3ペイン例外の典型例）
- runtime露出撤去: 5露出先のsymlinkを2026-07-03に削除（5露出先すべてに実在・計10本(2スキル×5)を撤去）
