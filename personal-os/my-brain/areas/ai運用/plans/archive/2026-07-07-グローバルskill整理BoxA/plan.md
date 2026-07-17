# グローバルskill整理 Box A — 移設台帳

グローバル（`~/.claude` / `~/.codex`）に居座る野良skillを、正本＝基盤へ寄せて symlink 窓化する作業の実行台帳。
この md がコンパクト後も残る**実行用の正本**。表示用Artifact（box-a-plan / box-a-classify）は派生物で、正本はここ。

## 状態（2026-07-08 実行中）
- **④削除：完了**（8個を復元可トラッシュ `20260707-212747` へ退避）。※`logs/deleted/` への正式記録は未（follow-up）。
- **①移設：完了**：ui-ux-pro-max・handoff-plan-supervisor（as-is・5窓・catalog(meta)・log）＋ **sns-post（本体のみ基盤へ・claude窓のみ・`cache/`＋`insights/`をgitignore・evals定義は追跡・catalog(applied)・log）＝完了**。
- **撤去：完了**：macro/micro-code-planning を復元可トラッシュ `20260708-140817` へ（削除ログ済）。
- **③repo送り**：trading-edge-research→投資 repo-local＝**完了**（codex変体採用/claude変体は温存/両runtime撤去/repo-local移行log）。nextlevel-app-calendar-links＝**保留**（所属先 `nextlevel-career-site` repoがローカル未発見・SSD未マウントで排除できず／要確認）。
- **設定吸収：完了**：settings設計知識4点を ui-ux-pro-max（`references/settings/`＋`assets/settings/`＋SKILL.md節）へ吸収、orchestrationは落として本体trash・削除ログ・catalog更新。
- **画像統合：完了**：images-generate＝2分岐1本（router40行＋workflows/general-image・mockup）。5窓＋仕事窓を基盤へ張替、imagegen-mockup吸収trash、catalog(applied)・移行ログ。名前維持で `/generate-images` 呼び出し疎通OK。
- **スライド統合：完了**（slide土台）：slideを基盤正本に、pjswを「モードC（案件型）＝references/project-deck-mode.md」として吸収。5窓＋グローバルpjsw5窓撤去＋pjsw本体trash。node_modules(28M)/memory/ログはgitignore。catalog(pjsw→slide差替)・移行log・削除log。**Box A本体＝完了。残：保留2件＋follow-up。**
- **実行方式**：`skill-creator-custom` 経由。露出機械部は `global-skill-registry/scripts/link-global-skill.sh <skill>`。

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

## 決定・要確認（2026-07-08 更新）

### settings-ui-architect → **ui-ux-pro-maxへ吸収（決定 2026-07-08）**
ui-ux移設は完了済み。吸収は追加作業として、設定/管理画面の設計モジュールを ui-ux-pro-max に取り込む。

### macro/micro-code-planning → **trash方向（調査で冗長を確認・最終GO待ち）**
調査: 両者とも `SKILL.md`＋`agents/openai.yaml` のみの**単一ファイルskill**（references/workflows/scripts無し＝原則1枚）。基盤の計画系＝coding-task-orchestrator（9 workflow）/ plan-triage / plan-ops / grill-me が遥かに厚く、全runtime（codex含む）露出済み。macro/microの「設計内容の原則」は薄い重複＝**冗長**。Codex専用。→ trash 妥当（ユーザー最終GO待ち）。

### sns-post → **「本体は基盤へ・データ系は.gitignore」で移設可（GO待ち）**
Q1調査結果（2026-07-08）:
- 種別: グローバルclaude skill。実体は**薄いオーケストレーション層**で、依存はrepo/外部にある。
- **データ正本＝Googleスプレッドシート**（アカウント管理＋ネタ帳＋投稿管理）。ローカル `cache/` は TTL3分の写し。
- config/scripts は**repo-local**: 本業=`~/Private/仕事/.claude/sns-config.json`＋`scripts/buffer`、副業=`~/Private/副業/.claude/sns-config.json`＋`scripts/sns-post`。
- 外部: Buffer（BUFFER_TOKEN）/ Threads（THREADS_ACCESS_TOKEN_*）。**トークンの値はskill本文に無い**（参照＆ログ禁止の明記のみ）。secretスキャンのヒットは全て散文。
- 構成: SKILL.md＋mode-*.md（9）＋references/＋sources/（=本体）／cache(4f20K)・insights(1f4K)・evals(1f4K)（=再生成/派生）。
- **移設方式**: 本体を `基盤/skills/sns-post` へ、`cache/`（＋要判断で insights/evals）を `.gitignore`、catalog=applied.md。config/scripts は repo 側に残置（触らない）。

---

## authoring 3統合の実装前調査（2026-07-08・LIVE skillにつき方向は要決定）

いずれも実際に仕事/副業で使われている稼働skillで、plan一行仕様より中身が大きい/前提とズレる。方向を確定してから統合する。

**方向決定（2026-07-08・ユーザー）**：
- 画像＝**基盤で1本化**（2分岐・仕事symlink窓を新正本へ張替）。
- スライド＝**slide土台に統合**（slideを基盤正本に／pjswの壁打ちゲート・キャリア文体・環境分岐をモード吸収／node_modules・memory・ログはgit非追跡）。
- 設定＝**設計知識だけ吸収**（settings設計知識をui-ux-pro-maxへ／汎用orchestrationは落とす＝既存メタskillが担当）。

### 画像（images-generate＋imagegen-mockup）
- images-generate（claude実体）は **仕事repoから symlink参照される LIVE skill**（`仕事/.claude/skills/images-generate` → `~/.claude/skills/images-generate`）。job-createスクリプト（`~/Private/仕事/scripts/job-create/`）にパス直結・キャラプリセット・Drive連携あり。
- imagegen-mockup（codex実体）はmockup特化の薄い計画層。両者とも最終は system `imagegen`（`~/.codex/skills/.system/imagegen`）へ委譲。
- 2分岐1本化（一般→imagegen直行／モックアップ→mockup）は可能。ただし正本を基盤へ動かすなら仕事のsymlink窓を新正本へ張替が必要。job-create結合は当面維持→follow-up整理。

### スライド（slide → pjsw）
- **slide が pjsw より遥かに大きい**。slide＝light/full・テンプレ庫（構成7/レイアウト8/差別化/ブランド）・PPTアドイン/NotebookLMエンジン選択・`~/Private/副業/素材/`結合・スライド管理スプシ・memory/ログ（state）・**scriptsにnode_modules同梱**。pjsw＝案件型で1枚ずつ壁打ち・キャリア文体・Codex/Claude環境分岐の軽量skill。
- 「pjswへ吸収」は方向が逆。実際は slideが土台で、pjswの壁打ちゲート/キャリア文体/環境分岐をモードとして取り込むのが自然。
- node_modules・memory・ログ は git非追跡が必須（素材/スプシは外部正本）。

### 設定（settings-ui-architect → ui-ux吸収）
- 「設定モジュール」ではなく **12 workflow＋4 refs＋4 templates の本格orchestration skill**。設定UI設計知識（taxonomy/rubric/benchmark/acceptance）＋汎用受け渡し（two-chat/split/integrate/gates）を含む。
- 汎用受け渡しは coding-task-orchestrator / handoff-plan-supervisor と重複 → 吸収の粒度（知識だけ／全部／単独移設）を決める必要。

---

## follow-up（別レイヤ・本筋外）
- **④削除の `logs/deleted/` 補記**：2026-07-07 の④削除8個（sleep/kimi-webbridge/mcp/playwright-scout/screenshot/playwright/sora/notion-spec-to-implementation）は台帳とトラッシュREADMEにはあるが、`global-skill-registry/logs/deleted/2026-07/` への正式ログが無い。規約上は必要 → 遡って8本の削除ログを補記する。
- **calendar-links の所属確認**：skill本文が `nextlevel-career-site` repo専用と明記。だが同repoは `projects/` 配下にも 仕事(=nextlevel-work) 内にも無く、PortableSSD未マウントで排除できず。→ (a) career-site repoのローカル位置を確認して送る／(b) 当面 仕事(nextlevel-work) の repo-local に置き将来移す、のどちらかをユーザーに確認してから実行。codex実体は保留中。
- **task-router の参照更新**：`kimi-webbridge` / `playwright-scout` を名指し（`skills/task-router/SKILL.md:87,123`、`workflows/heavy-flow.md:145`）。削除で宙に浮く → `claude-in-chrome` / `computer-use` MCP へ差し替え。task-router 自体の棚卸し時にまとめてもよい。
- **起業スキル5本の壊れた窓（診断済 2026-07-08）**（ai-news-short-video / kaihatsu-kanri / note-create / research-planning-skill / short-video-create）：`~/.agents`・`~/.codex`・`~/.claude` の窓（計15本）が旧パス `~/Private/起業スキル/skills/` を指したまま **dangling**。正本はPrivate整理で `projects/paused/起業スキル/skills/`（paused project・実在確認済）へ移動済。Box A作業とは無関係の既存破損。→ 判断: (a)新パスへ窓を張替＝グローバル維持／**(b)pausedにつき窓を撤去しrepo-local化（trading→投資と同方針・推奨）**。ユーザー確認後に実施。

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
- **①移設 完了（2026-07-08）**：ui-ux-pro-max・handoff-plan-supervisor を codex実体→基盤/skills・5runtime窓・catalog(meta)・移行log（`logs/migrated/2026-07/07-08-*.md`）。窓経由でスキル一覧に出現確認。
- 表示用Artifact：box-a-plan（全体計画）／ box-a-classify（②③詳細＋フォルダ構成）。

## 現状の分類サマリ（2026-07-08 完了時点）
- ①移設：ui-ux-pro-max ✅ / handoff-plan-supervisor ✅ / sns-post ✅（本体のみ基盤・claude窓・cache+insights gitignore）
- ②統合：画像 images-generate ✅（2分岐1本・5窓・仕事窓張替） / スライド slide ✅（slide土台・pjsw吸収=モードC・5窓・node_modules等gitignore）
- 設定：settings-ui-architect ✅（設計知識をui-uxへ吸収・orchestrationは落とす・本体trash）
- ③repo送り：trading-edge-research ✅（投資repo-local）／ nextlevel-app-calendar-links ⏸保留（所属 nextlevel-career-site repo未特定・要確認）
- 撤去：macro/micro-code-planning ✅（trash）／ imagegen-mockup ✅（画像へ吸収trash）／ project-slide-workflow ✅（slideへ吸収trash・グローバル5窓撤去）
- ④削除済（07-07）：sleep, kimi-webbridge, mcp, playwright-scout, screenshot, playwright, sora, notion-spec-to-implementation
- **残タスク**：①calendar-links所属確認 ②起業スキル5窓dangling処理 ③④削除の正式deletedログ補記 ④SKILL.html再生成(images-generate・slide・ui-ux)
