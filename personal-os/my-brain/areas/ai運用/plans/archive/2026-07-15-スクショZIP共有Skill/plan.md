分類: skill ／ 種別: 新規作成
規模: ライト
並列: 不可 ／ レビュー: 都度

# スクショZIP共有Skill
## 目的

Finderやコンソールのスクリーンショットを、元ファイルを変えずに共有用ZIPへまとめ、デスクトップにはZIPだけを出すGlobal Skillを作る。

## 現状

1. 既存Global Skillに、ローカルファイルを共有用ZIPにする同一責務のSkillはない。
2. 正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/share-as-zip/` に置く。
3. `ai運用/plans/active/` は例外込みで4件が稼働中だが、2026-07-15に人間から本計画を1件だけ例外としてactiveに入れる明示承認を得た。既存計画は移動しない。本計画は評価PASS後にarchiveへ移す。

## 方針

1. `share-as-zip` はappliedのGlobal Skillとし、単一フローの `SKILL.md` のみを実行導線にする。workflow、reference、scriptは作らない。
2. 入力はローカルで読めるスクリーンショット等のファイルパスと任意の補足文。ZIP内の元ファイル名は維持し、補足文があれば `補足.txt` を加える。同名ファイルが重複する時は自動改名せず確認する。
3. 出力は `~/Desktop/<先頭の元ファイル名>-YYYY-MM-DD-HHmm.zip` のみとする。ZIP名が既にある時は末尾へ連番を付け、元ファイル・デスクトップ上の個別コピー・一時ファイルは残さない。
4. 人間向けの `SKILL.html`、applied catalog、作成ログを同じ作業で追加する。2026-07-15に受けた承認に基づき、5つのruntimeへ正本のdirect symlinkを露出する。

## 完了条件（レビュー項目）

- [x] `skills/share-as-zip/SKILL.md` が70行以内の単一フローで、入力・ZIP名・補足文・重複時・後始末の扱いを定義している。
- [x] `skills/share-as-zip/SKILL.html` が白基調で、実行用正本を複製せずに内容を説明している。
- [x] `global-skill-registry/catalog/applied.md` と `logs/created/2026-07/07-15-share-as-zip.md` に新規Skillとして正しく記録されている。
- [x] `~/.agents/skills`、`~/.codex/skills`、`~/.claude/skills`、`~/.gemini/config/skills`、`~/.gemini/antigravity-cli/skills` の各 `share-as-zip` が正本を指すdirect symlinkである。
- [x] 新規Skillと計画に関係しない既存変更には手を加えていない。

## 結果

2026-07-15に `share-as-zip` を作成し、5 runtimeへ露出した。`評価01.md` のreviewer subagent評価は全PASS。
