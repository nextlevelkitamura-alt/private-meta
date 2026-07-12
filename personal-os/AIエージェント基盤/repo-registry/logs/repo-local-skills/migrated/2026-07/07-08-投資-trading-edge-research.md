# trading-edge-research

- 日付時刻: 2026-07-08 14:17 JST
- repo-id: `投資`
- repo: `/Users/kitamuranaohiro/Private/projects/paused/投資`
- 旧正本: 両runtime野良実体 `~/.codex/skills/trading-edge-research`（採用）＋ `~/.claude/skills/trading-edge-research`（変体）
- 新正本: `.claude/skills/trading-edge-research`（投資repo-local）
- 削除元: 上記両runtime実体（撤去）
- 概要: 価格データ・MT5/Vantageデモ・複数時間足/複数根拠で、新しいトレーディング手法の発見・バックテスト・期待値計算・候補戦略保存・デモ発注支援を行うSkill。
- 移行理由: グローバル整理Box A。個人用途・orchestrator不要で、投資はpausedのためrepoと一緒に休眠させる。両runtimeの野良実体を撤去し、投資repo内をrepo-local正本にする（グローバル窓は張らず、使う時だけ有効化）。
- 正本選定: codex変体（2026-05-25・73行・Core Rules/Workflowが厚い・references4本＋`agents/openai.yaml`）を正本採用。claude変体（2026-05-24・53行）は固有の「副作用レベル L0-L3」框架を持つため破棄せず `~/.skills-trash/20260708-140817/claude/trading-edge-research` に温存（再稼働時に取り込み検討）。
- 検証: 両runtimeに実体が残っていないこと、park先に6ファイル（SKILL.md＋references4＋openai.yaml）が揃うこと、ビルド物/秘密混入なし（スキャン済み）を確認。
- 備考: グローバル露出なし（意図的・dormant）。副作用レベル框架の取り込みは投資再稼働時のfollow-up。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
