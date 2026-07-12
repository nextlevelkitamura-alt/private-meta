# slide（統合・土台）

- 日付時刻: 2026-07-08 14:50 JST
- 旧正本: `~/.claude/skills/slide`（claude実体・野良／土台）＋ `project-slide-workflow`（基盤・5窓／案件型モードとして吸収）
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/slide`
- 概要: スライド・プレゼン資料を作る統合skill。A=ライト/B=しっかり/C=案件型（1枚ずつ壁打ち）の3モード。テンプレ庫・PPTアドイン/NotebookLMエンジン選択・副業/素材連携。
- 移行理由: グローバル整理Box A＋ユーザー決定「slide土台に統合」。slide（大・汎用/素材エコシステム）を基盤正本に据え、project-slide-workflow（小・案件型キャリア）の価値＝1枚ずつ壁打ちゲート・キャリア文体・Codex/Claude画像環境分岐を「モードC（案件型）」として吸収し1本化。
- 正本選定: slideを基盤へ移設。pjswのSKILL.md本文→`references/project-deck-mode.md`（モードC）、pjsw refs→`references/project-deck-templates.md`・`references/chat-prompt-template.md`。SKILL.mdのモード選択/分岐にC行を追加、frontmatter descriptionを3モードへ更新。
- 露出: 5runtime窓（link-global-skill.sh slide）。project-slide-workflowの5窓は撤去、基盤本体はtrashへ（吸収済）。
- git方針: `.gitignore` で `scripts/node_modules/`（28M・787f・npm再生成可）・`memory/`（デッキ記憶=state）・`ログ/*/`（案件ログ=state）・`テンプレ/ブランド/_last-used.txt`（state）を非追跡。テンプレ庫・`ログ/brief-template.yaml`・`テンプレ/ブランド/*/logo.jpg`（本体）は追跡。`git check-ignore` 確認済み。
- 検証: 5窓のreadlink一致・SKILL.md/モードC参照（`references/project-deck-mode.md`）が窓から見える、gitignoreが重量物/stateを除外し本体を追跡、pjsw 5窓＋基盤本体が撤去済みを確認。
- 備考: slideはグローバルのみ（repo窓なし）。pjswの名指し呼び出しは無し。**仕事repoに project-slide-workflow の同一コピー（repo-local実体）が残存**＝Box A外・follow-upで整理検討。外部結合（副業/素材・スライド管理スプシ・PowerPointアドイン・NotebookLM）は不変。SKILL.html未生成（follow-up）。台帳 `plans/active/2026-07-07-グローバルskill整理BoxA/plan.md`。
