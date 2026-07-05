# review-skill

既存Skillを直す・軽くする・description改善・レビューするワークフロー。レビューだけで終わるか、人間承認を得て修正実行まで進むかを同じworkflow内で分岐する。判断基準は `references/review-rules.md` と `references/create-rules.md`。

## 手順

### Step 1: 対象を読む

1. `<skill>/SKILL.md`
2. `<skill>/workflows/*.md`（必要な範囲）
3. `<skill>/references/*.md`（必要な範囲）
4. `<skill>/assets/*`（テンプレや素材の用途確認だけ）
5. `<skill>/scripts/*`（存在と用途の確認。全文は必要な場合だけ）

### Step 2: 観点でレビューする

`references/review-rules.md` の観点カタログ（A発火精度 / B構造 / C重複・矛盾 / D安全 / E保守 / F実測評価）で見る。今回の変更規模に応じて頻度3段階（毎回 / 大きな変更時 / 年次棚卸し）のどこまで見るかを決める。

矛盾候補を見つけたら、すぐ断定せず対象範囲・時間軸・優先順位・Global/repo-localの違いで説明できるか確認する。統合・吸収・workflow追加・repo-local化で迷う場合は `references/create-rules.md` §1（吸収判断）を読む。

### Step 3: 改善案を提示する

`references/review-rules.md`「改善提案の出し方」に従い、結論（現状維持 / 軽量化 / 統合 / 一部削除 / 削除候補）・残す核・削る候補・寄せ先・最小修正案・優先順位を出す。

**ここで一旦停止する。** 明示依頼または次のStepの承認がない限り、ファイルを変更しない。移行・改名・削除が必要なら Step 4以降に進まず `migrate-skill.md` / `skill-delete` へ渡す。

### Step 4: 修正規模を判定し、必要なら計画化する

1. `references/create-rules.md` §10 で修正規模を判定する。Tiny/Smallな修正はその場で実行してよい。
2. Medium/Large（複数ターン・構造再編・複数Skillにまたがる）は、修正実行の前に計画書を作る。Globalは `ai運用/plans/active/<YYYY-MM-DD-対象Skill名>/plan.md` に `分類: skill`・`種別: 既存改善`（統合・改名・移行が主目的なら `統合整理`）。repo-localは所有repo内の `plans/skills/既存改善/<状態>/`。ファイル名は `YYYY-MM-DD-<対象Skill名>-日本語改善内容.md`。

### Step 5: 人間承認（修正実行ゲート）

1. 提示した最小修正案に対する人間の明示依頼または承認があるか確認する。
2. 承認がなければ Step 3 の提示で完了とし、修正へ進まない。
3. 削除・改名・移行・symlink変更・logs/catalog更新を含む場合は、その危険操作を個別に承認確認する。

### Step 6: 修正を実行する

1. 承認された範囲だけを編集する。承認外の変更を混ぜない。
2. `references/create-rules.md` §4（構成の絶対ルール）・§5（書き方）・§6（description設計）に従う。
3. 既存の未コミット変更や、指定外のファイルを巻き戻さない。
4. 一回限りの検証scriptや仮ファイルを残さない。

### Step 7: 構成ゲートとSKILL.html

1. `references/create-rules.md` §4.4 の構成ゲートを通す（直下md・workflow分割・references・完了条件の置き場・`rg` で旧参照残り）。
2. 編集した作業単位の完了条件として、`<skill>/SKILL.html` を再生成する（`references/create-rules.md` §9、骨組みは `assets/skill-template.html`）。

### Step 8: 外部整合を確認する

軽量化・移行・改名・削除を伴った場合だけ確認する。

1. 他Skillが対象Skill名や `SKILL.md L123` のような行番号を参照していないか。行番号参照はworkflow名+Step名へ置き換える。
2. descriptionを変えた場合は catalog（`global-skill-registry/catalog/`）の該当エントリの更新要否を確認する。
3. logs/catalog/所有repo側導線の更新要否を確認する（書式は該当registryの `logs/AGENTS.md`・`catalog/AGENTS.md`）。

### Step 9: 報告する

1. 結論と、実際に修正したか（Step 3で停止か / Step 6まで実行か）。
2. 変更したファイル。
3. 残した核と削った内容。
4. description変更があれば、拾う発話 / 拾わない発話 / 近接Skillの誤爆リスク。
5. workflow分割を変えた場合は理由と親workflowに残した完了条件。
6. `SKILL.html` 再生成の結果。
7. plans更新先・種別、または更新不要の理由。
8. logs/catalog/所有repo側導線の更新先、または更新不要の理由。
9. 構成ゲートの確認結果と、残った未対応。

## 禁止事項

1. Step 3 の提示で止めるべきところを、承認なしに Step 6（修正実行）へ進めない。
2. 削除・移動・改名・symlink変更・logs/catalog更新を暗黙に実行しない。
3. repo-local Skillを配置理由なしにGlobal化しない。
4. 正本ルールをSkill側へ長くコピーしない。
5. `SKILL.html` の再生成を完了条件から外さない。
