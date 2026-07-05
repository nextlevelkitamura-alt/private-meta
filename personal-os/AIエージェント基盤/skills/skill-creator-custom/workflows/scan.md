# scan

Skillを横断スキャンし、重複・矛盾・統合候補・導線のずれを洗い出すワークフロー。対象がGlobal Skillか repo-local Skillかで一部Stepが分岐する。読み取り専用で、削除・改名・移行・symlink変更は候補提示のみとし自動実行しない。判断基準は `references/create-rules.md`。

## 手順

### Step 1: 対象とスキャン範囲を決める

1. **対象の分岐**: `Global`（`AIエージェント基盤/skills/` のGlobal Skill同士）か `repo-local`（`/Users/kitamuranaohiro/Private/projects/` 配下のrepo-local Skill）かを決める。両方なら順に2周する。
2. 全件か、指定Skill群 / 指定repoか、指定件数かを確認する。
3. 出力が棚卸し・矛盾候補・統合候補・description改善・所有repo側導線確認のどれかを確認する。
4. repo-localの探索は `/Users/kitamuranaohiro/Private/projects/active/` のrepo実体を優先し、指定がある場合だけ `projects/paused/`・`projects/archive/` へ広げる（repo配置の正本は `/Users/kitamuranaohiro/Private/AGENTS.md`。plansの状態バケットとは別の体系）。
5. 読み取りレビューだけなら logs/catalog/runtime露出を変更しない。危険操作が必要になりそうなら候補として報告する。

### Step 2: 索引を読む（対象で分岐）

**Global の場合**:

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/catalog/meta.md` と `applied.md` を読み、`概要`・`近接・注意` から近いSkill名・責務・分類を抜く。catalogは索引であり正本でないため、catalogだけで矛盾を断定しない。
2. **三点照合**: `skills/` の実体（`ls skills/`）・catalog記載（`meta.md`＋`applied.md`）・`logs/deleted/` を突き合わせ、(a) `skills/` にあるがcatalog未記載、(b) catalog記載だが `skills/` に無い、(c) `logs/deleted/` に削除済みなのにcatalog残存、の3不整合を検出する。件数（skills実体数 ＝ meta＋applied記載数）も確認する。

**repo-local の場合**:

1. `/Users/kitamuranaohiro/Private/AGENTS.md` を読み `projects/` の配置ルールを確認する。
2. 対象repoの `AGENTS.md` があれば読む。repo-local Skill候補は対象repo内の `.agents/skills/`・`.claude/skills/`・`skills/` を探索する。`CLAUDE.md` だけがある場合はsymlinkか本文かを確認する。
3. Global Skillとの近さを見る場合は `global-skill-registry/catalog/meta.md`・`applied.md` も読む。

### Step 3: 軽量indexを作る

1. Globalは各 `SKILL.md` のfrontmatter `name`・`description` を見る。repo-localはrepo名・repo path・Skill名・正本path・概要・用途を抜く。
2. この段階で全workflow・references・assets・scriptsを全読みしない。runtime露出先（`~/.codex/skills` 等）は正本でないため本文確認に使わない。
3. Skillごとに発火条件・主な責務・対象scope・出力・副作用・近接Skillを短く整理する。repo-local本文をこのrepoへコピーしない。

### Step 4: 重複・矛盾候補を探す

1. 同じ自然言語の依頼で複数Skillが起動しそうなもの。
2. 同じ成果物・判断を別名Skillで持っているもの。
3. 安全方針がずれているもの（片方は事前確認必須・片方は自動実行）。
4. Globalに置く理由が弱くrepo-localの業務知識・固有scriptに寄っているもの（Global対象時）／複数repoで同じmeta系目的に使われGlobal化候補になるもの（repo-local対象時）。
5. `meta`/`applied` の分類と実際の責務がずれているもの。
6. 正本・logs・catalog・runtime露出の運用ルールを本文に重複して抱えているもの。
7. **description総量**: descriptionが長いSkillが多いと一覧予算で切り詰められ発火漏れが起きる。長大なdescriptionや重複トリガーを候補にする。切り詰め状況は `/doctor` で確認できる。
8. **SKILL.html突合**: `SKILL.html` の更新日と `SKILL.md` 群の更新日を突き合わせ、更新漏れ（`skill-creator-custom` を経由せず編集された跡）を候補にする。
9. 表面上似ていても、対象範囲・時間軸・優先順位・Global/repo-localの違いで説明できる場合は矛盾と断定しない。

### Step 5: 怪しい候補だけ正本を読む

1. 候補になったSkillだけ、正本 `SKILL.md` を読む（repo-localは所有repo内、GlobalはGlobal Skillとの重複候補で両方の `SKILL.md`）。
2. `SKILL.md` だけで判断できない場合に限り `workflows/*.md`、判断基準が別ファイルに出ている場合に限り `references/*.md` を読む。`assets/`・`scripts/` は用途確認だけ。
3. 候補が多い場合は重要度順に上位だけ正本を読み、残りは未確認候補として分ける。全件精読が必要なら、このworkflow内で抱えずスキャン範囲と分担方針を提示する。

### Step 6: 方針を分類する

このworkflow内で分類と報告を完結させる。統合候補・workflow追加候補・repo-local化候補・Global化候補がある場合は `references/create-rules.md` §1（吸収判断）を読んでから分類する。

1. `現状維持`: 近いが責務・scopeが分かれている。
2. `description改善`: 発火条件・区別が曖昧だが責務は分けられる。
3. `workflow追加`: 新Skillでなく既存Skillの1 workflowで足りる。
4. `統合候補`: 2つ以上のSkillが同じ責務を持つ。
5. `repo-local化候補` / `Global化候補`: Global↔repo-localの寄せ替え。
6. `移行・改名候補`: 正本名・runtime露出・catalog導線の整理が必要。
7. `所有repo側導線修正候補`: 正本path・概要・用途が古い / 不足（repo-local対象時）。
8. `削除候補`: 明示承認が必要なため、このworkflowでは実行せず `skill-delete` へ渡す。

### Step 7: 報告する

1. 対象（Global / repo-local）とスキャン範囲。
2. 読んだcatalog / repo / 正本。
3. 三点照合の結果（Global時）。
4. 矛盾候補・統合候補・description改善候補の一覧。
5. repo-local化 / Global化 / 所有repo側導線修正の候補。
6. description総量・SKILL.html更新漏れの指摘。
7. 断定できず保留した候補と、追加で読むべき正本。
8. 実装する場合の最小修正案または計画化案。
9. 明示承認が必要な危険操作。
10. logs/catalog/plans更新が必要か、または更新不要の理由。

## 禁止事項

1. catalogだけで矛盾を断定しない。runtime露出先を正本として読まない。
2. 削除・改名・移行・symlink変更を暗黙に実行しない。
3. repo-localに残す理由があるものを無理にGlobal統合しない。repo-local本文をAIエージェント基盤repoへコピーしない。
4. 一回限りのスキャン結果をSkill本文やcatalogに溜め込まない。
5. 任意の次工程は出してよいが、別workflowの必須実行でスキャン目的が完了する形にしない。
