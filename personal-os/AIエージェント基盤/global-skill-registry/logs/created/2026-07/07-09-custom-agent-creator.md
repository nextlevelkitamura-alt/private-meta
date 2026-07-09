# custom-agent-creator

- 日付時刻: 2026-07-09 20:49 JST
- 正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/custom-agent-creator`
- 概要: Claude Code subagent / Codex custom agent / OpenCode primary・subagent の定義ファイルを作成・整理・レビューする支援Skill（meta）。permission/sandbox/approval・inline MCP・hooks・model routing・reviewer/quality-gate 設計を扱う。
- 構成: `SKILL.md`（router・59行）＋ `references/{claude-code.md, codex.md, opencode.md, checklist.md}` ＋ `SKILL.html`。workflows/ なし（単一フロー）。
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`（5窓・link-global-skill.sh）
- 備考: 出所=ユーザー設計書v0.4。設計書のフォルダ直下フラット5ファイル構成を、基盤ルール（create-rules §4：直下は SKILL.md/SKILL.html のみ）準拠で `references/` 配下へ翻訳（読み分け・必要分だけ読む意図は保存）。Claude Code subagent frontmatter は claude-code-guide で公式仕様（v2.1.200+）を確認し、設計書記載キー（background/isolation/mcpServers/permissionMode/hooks/skills 等）は全て有効と判明。plugin配布時に hooks/mcpServers/permissionMode が無視される制限を注記追加。OpenCode Go の model ID は実在未確認のため「例・実装時に要確認」とし断定しない。opencodeは専用skillディレクトリ（`~/.config/opencode/skills`）を持たず（opencode CLIはskill非対応・`opencode agent` のみ）、`~/.agents/skills`（`npx skills`/skills.sh 共通ハブ・`.skill-lock.json` の lastSelectedAgents にopencode登録）経由で露出＝2026-07-09 露出済み。露出先の役割は registry `AGENTS.md` §1 と `scripts/link-global-skill.sh` usage に記載。計画書=`my-brain/areas/ai運用/plans/active/2026-07-09-custom-agent-creator新設/plan.md`。
