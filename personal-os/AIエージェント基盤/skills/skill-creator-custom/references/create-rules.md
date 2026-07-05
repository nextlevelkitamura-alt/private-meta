# Create Rules

新規Skill作成、既存Skillの修正・workflow追加、吸収・移行相談で使う**判断基準の唯一の正**。`create-new.md` と `review-skill.md` の両方がここを読む。同じ基準を他ファイルへコピーしない。

正本の入口: 配置とruntime露出は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`。Global Skillのlogs/catalogは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/`。repo-local Skillの履歴は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/logs/`。repo-local Skillの現在導線と計画書は所有repo側。Global Skillや横断判断の計画書は `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/`。バケット語彙・種別語彙・logs書式はこれらの正本に従い、ここに列挙しない。

## 1. 作る前の判断

1. ユーザーが新Skill作成を求めたら、原則として作成に進める。ただし「作らない」選択肢（既存への吸収・workflow追加・repo-local化・docs化）も提示する。
2. **作る / 直す の境界**: 対象Skillが既に存在するなら `review-skill.md`（直す）へ渡す。存在しない、または新規責務なら `create-new.md`（作る）で進める。
3. 作成前に近い既存Skillを見る: `AIエージェント基盤/skills/*/SKILL.md`、`global-skill-registry/catalog/`（`meta.md`/`applied.md`）、必要なら `global-skill-registry/logs/{created,migrated,deleted}/`、repo-local候補なら所有repoのAGENTSと既存Skill。
4. 確認すること: 似た発火条件のSkillがないか／似た目的・出力のSkillがないか／既存Skillのworkflow追加で足りないか／責務・発火条件・安全方針が矛盾しないか／過去に削除された類似Skillなら削除理由の再発がないか。
5. **吸収判断**（既存へ吸収 / 新規 / repo-local の分かれ目）:
   - 似ているだけでは吸収しない。同じ発火条件・入力・出力・副作用なら吸収候補。
   - 既存Skillの1 workflowで自然に表現できるなら、新Skill化よりworkflow追加を優先する。
   - repo固有script・固有データ・固有サービスに依存するものはrepo-localに残す。
   - 複数repoで同じmeta系目的に使われるものはGlobal化候補にする。

## 2. 矛盾チェック

矛盾候補があれば、作成前に方針を決める。

1. 同じ自然言語で複数Skillが起動しそう／同じ作業を別名Skillで持とうとしている。
2. 既存Skillは事前確認必須なのに新Skillは自動実行にしている（安全方針のずれ）。
3. repo-localで扱うべき業務をGlobalにしようとしている。
4. `meta` / `applied` の分類が既存Skillの役割と矛盾している。
5. 表面上の違いをすぐ矛盾扱いしない。対象範囲・時間軸・優先順位・Global/repo-localの違いで説明できるか確認する。

## 3. 分類と配置

1. `meta`: AIの進め方、判断、調査、レビュー、オーケストレーション、Skill運用、repo運用、runtime運用、技術運用を扱うSkill。技術運用Skillも独立分類にせずまず `meta` に含める。
2. `applied`: 資料、字幕、返信文、要約、提案、投稿、リストなど業務成果物を直接作るSkill。
3. 汎用メタSkill・planning・review・handoff・governance はGlobal候補。特定repoの業務・固有scripts・固有データ・外部サービス運用に密結合するものはrepo-local候補。迷ったらrepo-local。
4. plugin/system/cache配下のSkillは、明示依頼なしに移行しない。

## 4. 構成の絶対ルール

1. まず単一 `SKILL.md` で足りるか確認する。フォルダは `SKILL.md` ＋ `workflows/` `references/` `assets/` `scripts/` 以外を作らない（`evals/` は公式評価ツール実行時のみ例外。`SKILL.html` は人間向けの唯一の例外ファイル）。
2. `SKILL.md` はrouterに徹し70行以内。目的・発火・Workflow振り分け・中核安全方針だけを書く。判断基準は `references/`、手順は `workflows/` へ。
3. 単一の自然な作業フローで150行程度に収まるなら `workflows/` を作らず `SKILL.md` に手順を残す。これがworkflow分割の主トリガー。
4. 参照は `SKILL.md` から1階層まで。`SKILL.md`→workflow→referenceのように多段ネストさせず、`SKILL.md` からworkflowとreferenceを直接指名する（多段だと部分読みで情報が欠落する）。100行超のreferenceは冒頭に目次を置く。
5. `SKILL.md` 直下に実行workflow相当のmdを残さない。

### 4.1 workflow分割判断（唯一の置き場・review-rulesはここを参照する）

別workflowにしてよい条件:

1. それ単体でユーザー発話の目的になる。
2. それ単体で成果物・判断・実装計画まで出せる。
3. 親workflowから呼ぶ場合の入力・期待出力・戻り先・失敗時対応を明示できる。
4. 手順が長い、または分岐が多い。
5. 副作用や承認ゲートが親workflowと独立している。
6. 複数workflowから再利用される。
7. 実行タイミングが任意、または条件付きである。

別workflowにしない条件:

1. 親作業の完了条件そのもの。
2. 毎回必ず実行する。
3. 手順が数行で済む。
4. 見落とすと正本・logs・catalog・runtime露出の整合性が崩れる。
5. 別ファイルを読む形にすると実行漏れが起きやすい。
6. 実行順が親workflowの途中に埋め込まれている。
7. 前のworkflowの結果を受け取って実行するだけの後続Stepである。
8. 2つ以上のworkflowを順番に実行しないと1目的が完了しないのに、親workflowに入力・期待出力・戻り先・完了確認が書かれていない。
9. 親workflowを読んでも作業全体の完了条件が分からない。

### 4.2 フォルダ別の作り込み基準

作成時は上から順に「作る条件」を自問し、合致した時だけ作る。作らないのがデフォルト。

1. `workflows/`: 作る=上の 4.1「してよい条件」に合致する時。書き方=1本1発話目的（端から端まで）。完了条件・毎回必須の処理は自分のStepに持ち、ルールは書かず本referenceを参照。作らない=ただのStep分割・数行の手順・前工程の結果を受けるだけの後続処理。単一フロー150行以内。
2. `references/`: 作る=複数workflowや複数判断から再利用する基準がある時。書き方=1ファイル1テーマ、記述的なファイル名、100行超は目次、`SKILL.md` から1階層。作らない=20行前後の教訓補足（→既存workflowのStepに1〜3行で組み込む）、正本ドキュメントのコピー。
3. `assets/`: 作る=コピーして使う雛形・テンプレ・設定断片がある時。書き方=mdの雛形とhtmlの雛形は同名ペア、テンプレに判断基準の文章を書かず本referenceへのポインタ1行にする。作らない=README・CHANGELOG・背景資料などSkill実行に使わないファイル（`SKILL.html` だけが例外）。
4. `scripts/`: 作る=毎回同じコードを書く決定的・反復処理がある時。書き方=「実行する/参照として読む」を `SKILL.md`・workflow側に明示、定数に根拠コメント（根拠なき定数を残さない）。作らない=一回限りの検証script・仮テスト（作業後に残さない）。
5. 出力先（outputs）: applied系（成果物を作るSkill）は §7 に従い出力先を必ず明記する。

### 4.3 構成サイズ目安

1. Tiny: `SKILL.md` だけ。
2. Small: `SKILL.md`（＋必要なら `agents/openai.yaml`）。
3. Medium: `SKILL.md` に1つの `workflows/` または `references/`。
4. Large: 複数workflow。明確なモード分岐・別々の副作用・別々の読み込み条件がある時だけ。
5. 迷う場合は小さい構成を選び、実運用で読みにくさが出てから分割する。

### 4.4 構成ゲート（create-newとreview-skill共通の完了基準）

完了前に確認する。

1. `<skill>/` 直下のmdは `SKILL.md` と必要な補足だけで、実行手順は `workflows/` にある。
2. `workflows/` はユーザー発話の目的ごとに分かれている。
3. `references/` は複数箇所から使う判断基準だけを置いている。
4. 親workflowの完了条件・安全ゲートを `references/` へ逃がしていない。
5. `rg` で旧path・旧Skill名・移動前ファイル名の参照残りを確認する。
6. `SKILL.html` を再生成した（§8）。

## 5. 書き方

1. 日本語で書く。frontmatter key・path・コマンド・固有名詞以外の英語説明を増やさない。
2. 数字付き箇条書きを基本にし、1項目に1判断だけ書く。
3. フォルダや正本場所は初出で絶対pathを書く。repoが明示済みなら以後はrepo-relative pathでよい。
4. 「何をするか」「いつ読むか」「どこへ逃がすか」を明確に書く。長い説明より判断できる短いルールを優先する。
5. 時限情報（「2026年8月以降は…」等）を本文に直書きしない。古い手順は隔離するか消す。
6. 同じ概念を2つ以上の言葉で呼ばない（用語を統一する）。
7. 古いPhase・成功事例・作業ログ・TODOをSkill本文に残さない。

## 6. description設計

1. 第三人称で書く（システムプロンプトに注入されるため）。「何をするか」＋「いつ使うか（ユーザーが実際に打つ語彙・日本語トリガー語）」の両方を含める。最大1024文字。
2. 主要ユースケースを先頭150〜200字に置く（多スキル環境ではdescriptionが切り詰められ後半が消えるため）。
3. 誤爆しやすい近接Skillへの否定トリガー（「〜には使わない」）を必要なら入れる。
4. `削除`・`移動`・`改名`・`登録`・`初期設定` などの汎用動詞を単体で使わず、`Skill削除`・`リポジトリ移動` のように対象名とセットにする。
5. descriptionにworkflowの手順要約を書かない（本文を読まずdescriptionだけで従う挙動を避ける）。
6. 抽象論から作らず、代表的なユーザー発話と期待出力から設計する。

## 7. frontmatter拡張（2026・Claude Code）

1. 副作用のあるSkill（削除・外部送信・デプロイ・課金・不可逆変更）は `disable-model-invocation: true` を検討し、人間だけが `/name` で起動できるようにする（ただしユーザーもスラッシュ起動できなくなる既知の挙動差があるため、導入時に挙動を確認する）。
2. `allowed-tools` はコマンド単位まで絞って最小限にする（`Bash` 全体のような過剰な免除にしない）。
3. 探索・分析が長いSkillは `context: fork` でサブエージェント分離を検討する（メイン会話のトークンを汚さない）。
4. `paths` はDiscoveryを壊す既知バグがあるため当面使わない。

## 8. 出力先（outputs）

1. applied系Skillは、生成物の置き場を所属repoのoutputs規約準拠で必ず明記する。
2. outputs規約の正本は `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/GLOBAL_AGENTS.md`（`outputs/<用途>/YYYY-MM/`。最終成果物はgit追跡・中間生成物は `.gitignore`）。このSkillに規約本文をコピーしない。
3. Skillごとに独自の出力先をハードコードしない（repo横断で置き場がばらつくため）。

## 9. SKILL.html（人間向け説明書）

1. 命名ルール（人間向けHTMLは対になるmdと同じベース名。`SKILL.md`→`SKILL.html`）の正本は `GLOBAL_AGENTS.md`。ここでは義務と型だけを定める。
2. Skillを編集した作業単位の完了条件として `<skill>/SKILL.html` を再生成する（同一作業で複数ファイルを直しても再生成は最後に1回）。
3. 固定6節: ①何をするSkillか（1行） ②いつ発火するか（発話例） ③構造図 ④各workflowの中身（何をするか・Step構造・完了条件） ⑤referencesの中身（各判断基準が持つ節構成と、いつ読むか） ⑥絶対ルール・安全方針＋更新日。単一 `SKILL.md` 構成で `workflows/`・`references/` が無いSkillは④⑤を省く。骨組みは `assets/skill-template.html`。
4. ④⑤は人間がmdを開かずに「各ファイルの中に何がどう書いてあるか」を掴める粒度にする。workflowはStepの流れと各Stepの要点、referenceは節見出しと役割を書く。ただしmd本文の逐語コピーはしない（概観に徹する）。
5. `SKILL.html` を `SKILL.md`・workflow・referenceから参照しない（AIの実行コンテキストに載せない人間専用ファイル）。正本は常にmd側。
6. `SKILL.html` は `assets/` を増やさない唯一の例外としてフォルダ直下に置く。

## 10. 記録と計画

1. logs・catalog・所有repo側導線の更新要否は、作成・移行・削除・改名の完了条件として確認する。書式・バケット語彙は該当registryの `logs/AGENTS.md`・`catalog/AGENTS.md` に従い、ここに列挙しない。
2. Global Skillの正本は `AIエージェント基盤/skills/<skill>/`。runtime露出は正本への direct symlink を標準にし、copy-syncしない。
3. **修正の規模判定**: Tiny/Smallな修正はその場で完結してよい。Medium/Large（複数ターン・構造再編・複数Skillにまたがる）は着手前に計画書を作る。Globalは `ai運用/plans/active/<YYYY-MM-DD-対象>/plan.md` に `分類: skill`・`種別:` を書き、状態はバケットで持つ（`状態:` フィールドは書かない）。repo-localは所有repo内の `plans/skills/<種別>/<状態>/`。所属repo未確定なら ai運用側に `分類: repo` で置く。
4. `種別:` は 新規作成 / 既存改善 / 統合整理 から選ぶ（定義とバケット規約は `ai運用/AGENTS.md` が正本）。
5. `AGENTS.md` を作成または同梱する場合は、同階層の `CLAUDE.md` を `AGENTS.md` への相対symlinkにする。

## 11. 作成・修正前に提示するもの

1. 新Skill名（新規時）または対象Skill名（修正時）。
2. 近い既存Skillと矛盾候補。
3. 新Skill化 / 既存workflow追加 / repo-local化 / 現状維持 の選択肢。
4. 正本path。
5. runtime露出要否。
6. logs更新要否、Global catalog更新要否または所有repo側導線更新要否。
7. plans更新要否（既存改善なら対象Skill名を含むファイル名）。
8. 出力先（applied系のみ）。
9. `SKILL.html` 再生成の要否。
10. `AGENTS.md` を作成・同梱する場合の `CLAUDE.md` symlink要否。
11. workflowを増やす場合の分割理由と、親workflowに残す完了条件。
