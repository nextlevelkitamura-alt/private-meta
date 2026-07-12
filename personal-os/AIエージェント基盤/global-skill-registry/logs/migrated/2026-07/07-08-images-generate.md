# images-generate（統合）

- 日付時刻: 2026-07-08 14:44 JST
- 旧正本: `~/.claude/skills/images-generate`（claude実体・野良／A分岐の母体）＋ `~/.codex/skills/imagegen-mockup`（codex実体・野良／B分岐として吸収）
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/images-generate`
- 概要: 画像生成の統合窓口。2分岐（A=一般/プロモ画像、B=開発/モックアップ）で判定し、どちらも system `imagegen` の built-in image_gen で生成。
- 移行理由: グローバル整理Box A＋ユーザー決定「基盤で1本化」。runtime分裂していた2つの画像skill（claudeの一般画像／codexのmockup）を、2分岐1本の統合skillへ。名前は `images-generate` を維持（仕事repoの多数skillが `/generate-images` を名指しで呼ぶため疎通保持）。
- 正本選定: images-generate（母体）を基盤へ移しSKILL.mdをrouter化（40行）。旧フローは `workflows/general-image.md`（A分岐）へ、imagegen-mockupのSKILL.md本文は `workflows/mockup.md`（B分岐）へ、recipesは `references/mockup-prompt-recipes.md`、codex agentは `agents/openai.yaml` を統合skill名へ更新。
- 露出: 5runtime窓（link-global-skill.sh）。加えて 仕事repoの `.agents/skills/images-generate` を旧 `~/.claude実体` から新正本（基盤）へ直接張替（`.claude/skills` は `.agents/skills` へのsymlinkのため実体窓は1本）。
- 検証: 5窓のreadlink一致・SKILL.md読める、分岐workflow（general-image.md/mockup.md）が窓から見える、仕事窓経由でSKILL.md読める、codexに imagegen-mockup 残存なしを確認。
- 備考: `disable-model-invocation: true` は母体の設定を維持（仕事の呼び出しフローを乱さないため）。mockupの自動起動が要るなら別途フラグ判断（follow-up）。キャラ参照画像 `assets/characters/*.png`（計4.2M）はgit追跡（本体アセット）。SKILL.html未生成（follow-up）。imagegen-mockupは `~/.skills-trash/20260708-140817/codex/imagegen-mockup` に温存。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
