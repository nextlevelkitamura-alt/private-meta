# mokuteki-jisso（削除）

- 日付時刻: 2026-07-03 JST
- 削除正本: `skills/mokuteki-jisso/`（SKILL.md＋references/7＋agents/openai.yaml・約44K）
- 承認: 2026-07-03 ユーザー承認（決定ログ#8。去就自体は#4で決定済み）
- 理由: S/M/L規模語彙・他チャット引き継ぎ監督の旧入口。契約§2＋plan-triage＋cockpit-supervisorで置換済み。「M以上はユーザー確認なしに始めない」が契約§2と正面衝突。references7枚は本文未参照の孤児。
- 吸収部品の移動先（詳細=同フォルダ `07-03-吸収候補調査-子08.md`）:
  - 指示スペック定型 → `skills/orca-cockpit/references/role-prompts.md` §3b
  - レビュー観点3点（範囲逸脱・検証虚偽・失敗ログ省略） → 同 §4
  - 分割前readonly衝突調査 → `skills/cockpit-supervisor/SKILL.md` §3-5
  - 差し戻しsendの型 → 同 §2-5
  - naiyou-suriawase→plan-triage連携 → `skills/plan-triage/SKILL.md` §1
- runtime露出撤去: 5露出先のsymlinkを2026-07-03に削除（5露出先すべてに実在・計10本(2スキル×5)を撤去）
