# グローバルskill整理 Box A — 移設台帳

グローバル（`~/.claude` / `~/.codex`）に居座る野良skillを、正本＝基盤へ寄せて symlink 窓化する作業の実行台帳。
この md がコンパクト後も残る**実行用の正本**。表示用Artifact（box-a-plan / box-a-classify）は派生物で、正本はここ。

## 状態（2026-07-07 時点）
- **④削除：完了**（8個を復元可トラッシュへ退避）。
- **①移設**：ui-ux-pro-max・handoff-plan-supervisor＝**完了（2026-07-08）**（基盤/skills＋5runtime窓＋catalog(meta)＋移行log）。sns-post＝**保留**（構造非準拠＋`cache/`/`sources/`/`insights/` のデータをgit追跡する懸念・要方針）。
- **②統合・③repo送り：未実行**。
- **実行方式**：`skill-creator-custom` 経由。移設の機械部分は `global-skill-registry/scripts/link-global-skill.sh <skill>`（5runtime窓を自動生成）。

## モデル（前提）
- 正本＝基盤 `personal-os/AIエージェント基盤/skills/`、グローバル＝symlink窓。特定repo依存＝`projects/<repo>/`（repo-local）。
- 基盤AGENTS.md：複数repo/runtime横断＝基盤へ登録／特定repo依存＝projects/<repo>。

---

## 確定した決定（ユーザー指示 2026-07-07）

### ① そのまま移設（基盤へ・中身変更なし）
- **ui-ux-pro-max**（codex実体）→ 基盤/skills/ へ **as-is**（行動計画・中身そのまま）。窓を `~/.codex`（＋必要なら `~/.claude`）へ。※settings統合は「移行後の追加作業」（要決定2）。
- **handoff-plan-supervisor**（codex実体）→ 基盤/skills/。
- **sns-post**（claude実体）→ 基盤/skills/。※移設時にスプシconfig（アカウント管理／ネタ帳）の生存を確認。

### ② 統合（skill-creator-custom で1本化）
- **画像：images-generate ＋ imagegen-mockup → 1本に統合**。中で **2分岐を判定テキストで持たせる**：
  - プロモ／一般の画像制作 → **単純に画像生成**（imagegen 直行）
  - 開発／Webサイト／アプリの **モックアップ** → モックアップとして生成
  - **肝：どちらも最終的に `imagegen`（system skill）を使う**。分岐の入口トリガー文をSKILL.md/参照に明記。
  - 正本を基盤/skills/ に1本、両runtimeへ窓。
- **スライド：slide ＋ project-slide-workflow → 1本に統合**。pjsw を土台に、slide側の「PPTアドイン／NotebookLMエンジン選択」「テンプレ」「`副業/素材` 連携」を取り込む。全体像を見ながら skill-creator-custom で。

### ③ repo送り（特定repo専用・基盤に置かない）
- **nextlevel-app-calendar-links**（codex実体）→ `projects/active/仕事/` の repo-local（`.claude/skills/`）。
- **trading-edge-research**（両runtime実体）→ `projects/paused/投資/` の repo-local。個人用途・orchestrator不要・投資はpausedなのでrepoと一緒に休眠。両runtime実体は撤去（窓は張らず、使う時だけ）。

---

## 要決定（コンパクト後にユーザーへ再確認）※AskUserQuestionは一旦denyされた
1. **macro/micro-code-planning**：ユーザーは「基盤の新計画方式（coding-task-orchestrator/plan-triage/plan-ops）に寄せるべき・良し悪し判断できない・グローバルでAIに探させる必要ない」＝**外す寄り**。
   - (a) trash退避【推奨】 / (b) 非表示保持（disable-model-invocation） / (c) 基盤移設。**未確定**。
2. **settings-ui-architect**：今回言及なし。
   - (a) ui-ux-pro-maxへ吸収【推奨・移行後の追加作業】 / (b) 単独移設 / (c) trash。**未確定**。

---

## follow-up（別レイヤ・本筋外）
- **task-router の参照更新**：`kimi-webbridge` / `playwright-scout` を名指し（`skills/task-router/SKILL.md:87,123`、`workflows/heavy-flow.md:145`）。削除で宙に浮く → `claude-in-chrome` / `computer-use` MCP へ差し替え。task-router 自体の棚卸し時にまとめてもよい。
- **起業スキル5本**（ai-news-short-video / kaihatsu-kanri / note-create / research-planning-skill / short-video-create）：symlink正本が `~/Private/起業スキル/`。ただし `projects/paused/起業スキル` も存在 → 窓が壊れていないか要確認。Private構造整理として別途。

---

## 実行手順（1個あたり・skill-creator-custom経由）
1. `skill-creator-custom` を起動（新規／統合／移行の窓口）。
2. 対象の中身を読み、**統合**なら正本1本へマージ（②）／**as-is**なら移動（①）／**repo-local**は projects/<repo>/ へ（③）。
3. 基盤/skills/ に正本を置き、`~/.claude`・`~/.codex` に symlink 窓（対象runtime分）。
4. `global-skill-registry/catalog` に登録。runtime露出を確認。
5. 撤去後の実体は「窓 or repo-local」だけ残る。trashは不要確認後に完全削除。
6. 各節目で `board.py log`。

---

## 済み（2026-07-07）
- **④削除8個** → `~/.skills-trash/20260707-212747/`（復元可・README付き）
  - claude: sleep / kimi-webbridge / mcp / playwright-scout
  - codex: screenshot / playwright / sora / notion-spec-to-implementation
  - 撤去理由：現ハーネスに上位互換（claude-in-chrome/computer-use MCP）or 更新が古く役目終了。
- 表示用Artifact：box-a-plan（全体計画）／ box-a-classify（②③詳細＋フォルダ構成）。

## 現状の分類サマリ（野良19個）
- ①移設：ui-ux-pro-max, handoff-plan-supervisor, sns-post
- ②統合：画像(images-generate＋imagegen-mockup) / スライド(slide→pjsw)
- ②要決定：macro-code-planning, micro-code-planning, settings-ui-architect
- ③repo送り：nextlevel-app-calendar-links(仕事), trading-edge-research(投資)
- ④削除済：sleep, kimi-webbridge, mcp, playwright-scout, screenshot, playwright, sora, notion-spec-to-implementation
