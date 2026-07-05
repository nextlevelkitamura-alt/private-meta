# create-new

新規Skill作成、既存手順のSkill化、既存Skillへのworkflow追加判断を行うワークフロー。判断基準は `references/create-rules.md`。既存Skillの修正が答えになったら `review-skill.md` へ渡す。

## 手順

### Step 1: 依頼内容を確認する

1. 何をするSkillか / どんな発話で呼ばれたいか / 入力 / 出力。
2. 書き込み・送信・削除・金銭処理などの副作用があるか。
3. 依存するCLI・MCP・API・script・外部サービスがあるか。
4. Global Skill候補か、repo-local候補か。

曖昧なままディレクトリを作らない。足りない情報は短く確認する。

### Step 2: create-rules で判断する

`references/create-rules.md` を読み、以下を確認する。

1. §1「作る前の判断」: 近い既存Skill、作る/直すの境界（既存なら `review-skill.md` へ）、既存への吸収で足りないか。
2. §2「矛盾チェック」: 責務・発火条件・安全方針が矛盾しないか。矛盾候補があれば方針を決めるまで作成に進まない。
3. §3「分類と配置」: `meta`/`applied` と Global/repo-local のscopeが妥当か。

近いSkillがあれば中身を読み、Skillごとに次をリストで出す（表は使わない）。

- 既存Skill名 / 近い点 / 違う点 / 矛盾候補（無ければ「なし」）/ 提案（新Skill化 / 既存workflow追加 / repo-local化 / 現状維持 ＋理由1行）。

### Step 3: 方針を提示する

`references/create-rules.md` §11「作成・修正前に提示するもの」に沿って提示する。方針は 新Skill / 既存workflow追加 / repo-local化 / docs・一回作業 / 矛盾解消後に再判断 から選ぶ。

Medium/Large・複数ターン・方針未確定なら §10「記録と計画」に従い計画書を作る（Globalは `ai運用/plans/active/<YYYY-MM-DD-対象>/plan.md` に `分類: skill`・`種別: 新規作成`。既存workflow追加で足りるなら `種別: 既存改善` にして `review-skill.md` へ接続。統合が主目的なら `統合整理` の別計画に切り出す）。

### Step 4: 最小構成で作る

`references/create-rules.md` §4「構成の絶対ルール」に従い、§4.2「フォルダ別作り込み基準」を上から順に自問する。作らないのがデフォルト。

1. まず単一 `SKILL.md`（`assets/skill-template.md` を骨組みに）で足りるか。単一の自然なフローで150行以内なら `workflows/` を作らない。
2. `workflows/` は要るか（§4.1 の分割判断に合致する時だけ。合致するなら親workflowに呼び出し条件・入力・期待出力・失敗時対応・戻り先・完了確認を書く）。
3. `references/` は要るか（複数箇所から使う判断基準だけ）。
4. `assets/` は要るか（コピーして使う雛形だけ。md雛形とhtml雛形は同名ペア）。
5. `scripts/` は要るか（決定的で反復される処理だけ）。
6. applied系なら §8「出力先」で出力先を明記したか。
7. `description` は §6 に従い what と when と日本語トリガー語を入れ、主要ユースケースを先頭に置く。副作用があるなら §7 の frontmatter拡張（`disable-model-invocation` 等）を検討する。
8. `AGENTS.md` を作成・同梱した場合は、同階層に `CLAUDE.md -> AGENTS.md` の相対symlinkを作る（既存の非symlink `CLAUDE.md` は上書きせず方針確認）。

### Step 5: 構成ゲートとSKILL.html

1. `references/create-rules.md` §4.4 の構成ゲートを通す。
2. 完了条件として `<skill>/SKILL.html` を生成する（§9、骨組みは `assets/skill-template.html`）。

### Step 6: logs/catalog/所有repo側導線を更新する

新規Skillを作成した場合は、完了前に行う（別workflowに逃がさず、この作成workflowの完了条件とする）。書式・バケット語彙は該当registryの `logs/AGENTS.md`・`catalog/AGENTS.md` に従う。

1. Global新規は `global-skill-registry/logs/created/YYYY-MM/MM-DD-<skill>.md` に作成ログを書き、`global-skill-registry/catalog/`（`meta.md` または `applied.md`）へ1 block追加する。
2. repo-local新規は `repo-registry/logs/repo-local-skills/created/YYYY-MM/MM-DD-<repo-id>-<skill>.md` に作成ログを書き、所有repo側の現在導線更新要否を確認する。
3. 既存Skillへのworkflow追加だけで新Skillを作らない場合は、更新不要の理由を報告に入れる。
4. 段階runtime露出（一部runtimeだけ先に露出）にする場合は、残りを作成ログの `未露出バックログ:` 行へ列挙する（書式・追跡は `global-skill-registry/logs/AGENTS.md` §2/§6。`grep -r '未露出バックログ' global-skill-registry/logs/created/` で機械追跡）。

### Step 7: 報告する

1. 作成または更新したSkill名 / 正本path / 変更したファイル。
2. 既存Skillとの関係、矛盾候補と解消方針。
3. runtime露出の有無。
4. logs更新先、Global catalog更新先または所有repo側導線更新先、あるいは更新不要の理由。
5. 出力先（applied系のみ）。
6. `SKILL.html` 生成の結果。
7. plans更新先・種別、または更新不要の理由。
8. `AGENTS.md` を作成・同梱した場合の `CLAUDE.md` symlink確認結果。
9. workflowを増やした場合の分割理由と親workflowに残した完了条件。
10. 構成ゲートの確認結果。

## 禁止事項

1. 近い既存Skillを見ずに新Skillを作らない。矛盾候補を放置して作成しない。
2. 既存Skillの修正が答えなのに `review-skill.md` へ渡さず新規で作らない。
3. runtime露出先を長期正本にしない。repo-local Skillを無理にGlobal化しない。
4. 一回限りの検証scriptや仮テストscriptをrepoに残さない。
5. `SKILL.html` の生成を完了条件から外さない。
