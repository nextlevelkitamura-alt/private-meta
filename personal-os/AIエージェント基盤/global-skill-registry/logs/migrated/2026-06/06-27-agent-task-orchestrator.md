# agent-task-orchestrator

- 日付時刻: 2026-06-27 20:51 JST
- 旧正本: `/Users/kitamuranaohiro/Private/起業スキル/skills/agent-task-orchestrator`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/agent-task-orchestrator`
- 概要: AI作業依頼の初回理解確認、Domain/Size/Research/Docs判定、専門Skill routing、戻り報告評価、closeout判断を行う上位オーケストレーター。
- 移行理由: 複数repo・複数runtimeで使うメタSkillであり、起業スキルrepo配下ではなくAIエージェント基盤のGlobal Skill正本に集約するため。
- 正本選定: 旧実体 `/Users/kitamuranaohiro/Private/起業スキル/skills/agent-task-orchestrator` を採用。runtime 3箇所はこの旧実体へのdirect symlinkで、Gemini系2箇所は未露出だった。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証: `quick_validate` 成功、5 runtime direct symlink/readlink確認済み、runtime経由の `SKILL.md` 読み込み確認済み。
- 備考: 旧実体は新正本へ移動済み。移行後は各runtime入口から新正本へのdirect symlinkに統一。
