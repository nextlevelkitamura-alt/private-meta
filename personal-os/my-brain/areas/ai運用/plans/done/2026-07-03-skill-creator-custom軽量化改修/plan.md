分類: skill
種別: 既存改善
優先: ◎

# skill-creator-custom 軽量化改修

## 目的

Skill作成・改善の窓口 `skill-creator-custom` を、人間の5原則（SKILL.md=router／workflowは切りのいい単位で細分化しない／規定フォルダ以外を増やさない／同じことを2回言わない／生成物の置き場を規約化）に適合させる。あわせて「既存Skillを直す」動線の欠落と、人間向け説明HTML（SKILL.html）の運用を新設する。

正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-creator-custom/`

## 現状

- SKILL.md が109行で、§3〜§6が振り分けでなくルール本文。references と重複（router原則違反）。
- workflow分割判断16項目が create-rules §9 と review-rules §6 にほぼ一字一句重複。構成ルールが SKILL.md §5 / create-rules §7 / create-new Step6 に三重。
- plans運用細則を7ファイルにコピーした結果、正本 `ai運用/AGENTS.md` にある `paused` バケットが skill 側の全記述で欠落（複製劣化の実害）。
- workflows/ が5本。うち global-scan.md と repo-index-scan.md は対象（Global/repo-local）が違うだけで骨格が重複。assets が skill-template.md と hub-skill-template.md で約8割同一。
- **review-skill.md は「レビューのみ・ファイル変更禁止」で、既存Skillを実際に修正する手順がどこにも無い**（動線の穴）。
- 生成物（outputs）の置き場規約が空白。仕事repoでは `output/` と `outputs/` が併存。
- 人間向けの構造説明が無い（AI向けmdのみ）。

## 方針

1. SKILL.md を約45行の router（絶対ルール5＋Workflow振り分け4＋委譲＋迷ったら）に削る。ルール本文は全て references / 正本参照へ。
2. create-rules.md を「作る/直すの判断基準の唯一の正」に再編。absorb-rules.md の固有4項目を吸収し廃止。フォルダ別作り込み基準・SKILL.html規約・outputs・frontmatter拡張・description設計・作る/直す境界を追加。plansバケット語彙の列挙は撤去し正本参照1行に。
3. review-rules.md を観点カタログ（A発火精度 / B構造 / C重複矛盾 / D安全 / E保守 / F実測評価）＋頻度3段階に全面書き直し。
4. review-skill.md に「レビュー→人間承認→修正実行→構成ゲート→SKILL.html再生成→報告」を追加し、修正実行の動線を完成させる。
5. workflows を4本にする。global-scan.md と repo-index-scan.md を scan.md に統合（対象で分岐）。description総量チェックとSKILL.html更新日突合を scan に追加。
6. assets を skill-template.md（hub統合・作り込み強化）＋ skill-template.html（新規）に再編。hub-skill-template.md は廃止。
7. 人間向けHTML命名ルール（対になるmdと同じベース名。SKILL.md→SKILL.html）を GLOBAL_AGENTS.md に1行で置く。outputs規約（`outputs/<用途>/YYYY-MM/`・最終成果物はgit追跡・中間は.gitignore）も GLOBAL_AGENTS.md に置き、skill 側は参照のみ。
8. skill-creator-custom 自身の SKILL.html を固定5節で生成（新ルールの自己適用）。
9. 削除（absorb-rules.md / global-scan.md / repo-index-scan.md / hub-skill-template.md）は人間承認済み（本計画）。commit/push はしない。

## 完了条件（レビュー項目）

実装後、以下を「こうなっていれば正しい」で検証する。★=最重要。

1. ★**重複ゼロ**: skill配下の全mdで、workflow分割判断の条件リストは create-rules 1箇所のみ（review-rules は参照1行）。正本パス案内の段落は SKILL.md 1箇所のみ。「repo-localを無理にGlobal化しない」等の定型句は各観点で最大1回。（対象: SKILL.md / references/*.md / workflows/*.md）
2. ★**SKILL.md router化**: SKILL.md が70行以内。内容は frontmatter・絶対ルール・Workflow振り分け・委譲・迷ったらのみ。構成ルール／plans細則／書き方の本文が無い。（対象: SKILL.md）
3. ★**正本コピー撤去（paused欠落の恒久解消）**: plansのバケット語彙（active/paused/done/archive）と種別語彙の列挙が skill配下のどのmdにも無く、「ai運用/AGENTS.md のバケットに従う」等の参照1行になっている。（対象: skill配下全md）
4. ★**「直す」動線の完成**: review-skill.md が レビュー→人間承認→修正実行→構成ゲート→SKILL.html再生成→報告 の順を持ち、修正実行のStepと完了条件を自分で持つ。承認なしに修正へ進まない禁止事項が残っている。（対象: workflows/review-skill.md）
5. **workflow 4本と存在理由**: workflows/ が create-new.md / review-skill.md / scan.md / migrate-skill.md の4本。global-scan.md と repo-index-scan.md が存在しない。scan.md が対象（Global / repo-local）で分岐する。（対象: workflows/）
6. **SKILL.html規約と実体**: create-rules に「人間向けHTMLは対になるmdと同名」「Skill編集の完了条件＝SKILL.html再生成」「AIから参照しない」「唯一の例外ファイル」が1箇所。`skill-creator-custom/SKILL.html` が存在し固定5節（①何をする ②いつ発火 ③構造図 ④workflow一覧 ⑤絶対ルール・安全＋更新日）。GLOBAL_AGENTS.md に命名ルール1行。（対象: SKILL.html / create-rules / GLOBAL_AGENTS.md）
7. **フォルダ別作り込み基準**: create-rules に workflows/references/assets/scripts/outputs それぞれの「作る条件・書き方・作らない条件」があり、create-new.md の最小構成Stepがこれを上から自問する形になっている。（対象: create-rules / workflows/create-new.md）
8. **outputs規約**: create-rules にapplied系の出力先明記ルールがあり、規約の正本は GLOBAL_AGENTS.md に1箇所（`outputs/<用途>/YYYY-MM/`・git追跡方針）。skill側にコピーしていない。（対象: create-rules / GLOBAL_AGENTS.md）
9. **frontmatter拡張の反映**: create-rules に disable-model-invocation / allowed-tools / context:fork の採否基準と、paths は当面使わない旨がある。（対象: create-rules）
10. **フォルダ整合と参照残りゼロ**: assets が skill-template.md と skill-template.html の2本。hub-skill-template.md / absorb-rules.md が存在しない。`rg` で旧ファイル名（global-scan / repo-index-scan / hub-skill-template / absorb-rules）への参照残りがゼロ。CLAUDE.md->AGENTS.md symlink維持。（対象: skill配下全体）
11. **安全性**: secret・token混入なし。削除は本計画で承認された4ファイルのみ。commit / push していない。（対象: 作業全体）

## 結果

実装完了（2026-07-03・未評価）。Opus 4.8 highのレビュー後にdone判定。

- md合計 1,150行 → 655行。SKILL.md 109→34行（router化・70行以内クリア）。
- 削除4本: absorb-rules.md / global-scan.md / repo-index-scan.md / hub-skill-template.md（承認済み・commitはしていない）。
- 新規3本: workflows/scan.md（global+repo統合）/ assets/skill-template.html / SKILL.html。
- create-rules.md を判断基準の唯一の正に再編（workflow分割判断はここ1箇所、absorb固有4項目を吸収、フォルダ別作り込み基準・SKILL.html規約・outputs・frontmatter拡張・description設計・作る/直す境界を追加、plansバケット列挙は撤去し参照1行に）。
- review-rules.md を観点カタログA〜F＋頻度3段階に全面書き直し。
- review-skill.md に修正実行動線（レビュー→承認→修正実行→構成ゲート→SKILL.html再生成→報告）を追加し「直す」動線の穴を解消。
- GLOBAL_AGENTS.md に命名ルール（対md同名HTML）とoutputs規約を追加（正本を1箇所に）。
- 検証: 基盤本体に旧参照残りゼロ（ヒットは plans履歴と本plan.mdのみ）。symlink健全。secret無し。catalogは概要が有効なため更新不要。
- 既知メモ: GLOBAL_AGENTS.md は基盤repoで未追跡（`??`）だった。改修以前からの既存状態。

### レビュー（Opus 4.8 high・独立実測・2026-07-03）

- 判定: 条件付きdone → 指摘対応後 done。11項目中 ★1★2★4 と 5〜11 は「満たす」、★3のみ「一部」（scan.md:12 に `active/→paused/→archive/` の語彙列挙が残存）。
- 指摘1対応済み: scan.md:12 は実際は `projects/` のrepo配置（plansバケットではない）だったが、同語で紛らわしいため `projects/active/` 優先＋配置正本参照＋「plansの状態バケットとは別の体系」の注記に修正。
- 指摘2（AGENTS.mdのスコープ外変更混入）: 基盤 `AGENTS.md` の未コミット変更は本改修以前からのユーザー作業であり、本改修では触れていない。コミット時はパス指定で本改修分（skills/skill-creator-custom/・GLOBAL_AGENTS.md）と分離すること。
- 追加確認: description 286字・第三人称・近接Skill分離OK／SKILL.htmlは人間専用が成立／references 1階層／catalog更新不要は妥当／三点照合・repo探索の価値は scan.md に保持。
- SKILL.html: scan.md修正は構造・ルール・workflow一覧に影響しないため、同一作業単位内で生成済みの内容が有効（再生成しても同一）。
