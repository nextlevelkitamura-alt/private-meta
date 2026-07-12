# sns-post

- 日付時刻: 2026-07-08 14:06 JST
- 旧正本: `/Users/kitamuranaohiro/.claude/skills/sns-post`（claude実体・野良）
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/sns-post`
- 概要: SNSアカウント育成・投稿制作/編集・リサーチ・公開を、Googleスプレッドシート正本＋Buffer/Threads連携でmode別に回す業務オペ。
- 移行理由: グローバル整理Box A。claude単独の野良実体を正本＝基盤へ寄せ、グローバルはsymlink窓にする。ユーザーGO（2026-07-08）＝「本体のみ基盤へ・データ系は.gitignore」。
- 正本選定: 本体（SKILL.md＋mode-*.md＋references/＋sources/＋evals定義）を `skills/sns-post` へ移動。データ正本はGoogleスプレッドシート（アカウント管理・ネタ帳）＋各repoの `.claude/sns-config.json`・`scripts/`（repo-local・触らず残置）。
- 露出: **claudeのみ**（`~/.claude/skills/sns-post` → 新正本のsymlink窓）。業務用途でclaude起点のため、codex/gemini/.agentsへは意図的に露出しない（段階露出の未完ではなくスコープ判断）。link-global-skill.shは使わず単一窓を手動作成。
- git方針: 新正本直下に `.gitignore` を置き、`cache/`（TTL3分キャッシュ）と `insights/`（アカウント別設計変更ログ・半私的な業務状態）を追跡対象外に。`evals/evals.json`（eval定義）は追跡維持。`git check-ignore` で確認済み。トークン値（BUFFER_TOKEN/THREADS_ACCESS_TOKEN_*）は本文に無く、参照禁止の散文のみ。
- 検証: 旧位置が空（移動完了）、claude窓のreadlinkが新正本を指す、窓経由でSKILL.md読める、gitignoreがcache/insightsを無視しevalsを追跡することを確認。
- 備考: 構造は非準拠（mode-*.md/PROGRESS.mdがトップ、workflows/未整理）だが、ユーザー指示によりas-is移設。整形（mode-*.md→workflows/化・PROGRESS.md整理）は別作業のfollow-up。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
