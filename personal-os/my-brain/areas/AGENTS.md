# My Brain Areas

このディレクトリは、work、ai運用、money、health などの継続領域を置く場所。
各areaは、考え、判断軸、計画を領域ごとに閉じて管理する。
personal-os の計画はここを単一正本にする。基盤・Skill・repo・loop計画は `ai運用/` が担当し、旧 `../../plans/` は廃止済み。
縦の目標ladder（3年→年間→デイリーの的と履歴）は隣の `../ゴール/`。ここ（areas）は横の領域別。全体の今は当日デイリーのsession-board区画（動いているエージェント/終わったこと）で見る。

計画は area で育て、成熟したら実行repoへ卒業させる（§5）。my-brain は計画を育てる工房であって、実行の現場ではない。

## 1. Area標準構成

新しいareaは、原則として次の形にする（2026-07-16、ai運用areaでのpilot結果を反映。§1.1参照）。

```text
areas/<area>/
  AGENTS.md   # 目的・判断基準・置くもの・置かないもの・計画ルーティングを持つ
  CLAUDE.md -> AGENTS.md
  plans/
```

1. `AGENTS.md`: そのareaでAIが作業するための入口ルール。目的、判断基準、置くもの、置かないもの、計画ルーティングを持つ（旧 `identity.md` の役割を統合済み。新規areaは最初から `identity.md` を作らない）。
2. `CLAUDE.md`: `AGENTS.md` への相対symlink。本文コピーは禁止。
3. `plans/`: 実行する計画（バケット管理）。計画に紐づく人間向けHTMLは各計画の `explain/` に置く。

考え・調査・仮説は独立フォルダにせず、`AGENTS.md` の「判断基準」か、育成中の計画の `plans/planning/<計画>/plan.md` の `方針`（未確定のまま育てる）に寄せる。`thinking/` は廃止した。完成した恒久・再利用可能な参照mdは、既定では計画の `references/`（特定計画専用）またはprogramの `references/`（複数子で共有）に置く。area直下 `知識/` は必須構成から外れ、§1.1の3条件を満たすものだけ例外的に残せる。

### 1.1 identity.md・知識/ の移行注記（pilot合格後に追従）

- 上記は2026-07-16時点の**新規area向け既定**であり、既存areaへの一括適用ではない。`identity.md`・`知識/` を持つ既存areaは、個別にpilotへ合格するまで現状の構成を維持する（強制移行・一括削除はしない）。
- **ai運用**は本programの子05でpilotを実施し、`identity.md` の全項目を `AGENTS.md`（目的・判断基準・置くもの・置かないもの・計画ルーティング）へ統合した（対応表: `plans/active/2026-07-15-計画立案実行完了基盤/references/2026-07-16-identity統合対応表.md`）。`identity.md` 自体の削除は人間承認待ち（承認セット）で、承認までは削除しない。`知識/` は既存2ファイルとも例外3条件を満たす恒久参照と判定し、当面維持する（分類根拠: 同program `references/2026-07-16-知識分類候補.md`）。
- **work・money・health は今回のpilot対象外**。既存の `identity.md`・`知識/`（該当areaにあれば）はそのまま使い続けてよい。各areaを個別に統合したい場合は、ai運用のpilot手順（identity.md全項目の対応表作成 → AGENTS.mdへ統合 → 知識/の1ファイルずつの分類 → 人間承認後に削除・移動）を踏襲し、一括では行わない。
- 例外3条件（`知識/` を area直下に残してよい場合、pilotでも既存areaでも共通）: (a) 2つ以上の計画で長期に再利用する、(b) 計画が終了してもAreaの判断基準として残る、(c) `AGENTS.md` へ入れるには詳細すぎる。すべて満たすものだけ残し、それ以外は計画/programの `references/` へ寄せる。

## 2. 全体俯瞰: 当日デイリーとactive計画

当日デイリー（`../ゴール/デイリー/<年>/<月>/<日>.md`）のsession-board区画（動いているエージェント/終わったこと）で、動いているAIセッションを見る。全area横断で「今activeな計画」を自動描画する仕組みは無い（旧レンダラは2026-07-04廃止・未再建。旧`../ダッシュボード.md`も同日撤去先を失い2026-07-08削除）。active計画を俯瞰するには各area `plans/active/` を確認するか、program.md子計画マップを読む。

1. 優先マーク（◎/○）は各 plan.md / program.md 冒頭の `優先:` 行に書く。
2. 「次の一手」は plan.md / program.md 子計画マップの `次:` 行が正本。
3. `paused`/`done`/`archive` は横断俯瞰に含まれない（履歴は各 `plans/` とログ）。

## 3. Plan標準構成

計画は `plans/` 直下のライフサイクルバケットに置く。状態はフォルダで持ち、plan.md に状態フィールドは書かない。

```text
plans/
  planning/  <YYYY-MM-DD-日本語企画名>/plan.md（方針検討中・未着手）
  active/    <YYYY-MM-DD-日本語企画名>/plan.md
  paused/    .gitkeep
  done/      .gitkeep
  archive/   .gitkeep
  移行済み/   YYYY-MM/MM-DD-<計画名>.md   （卒業ログ。初回卒業時に作る）
```

0. 計画フォルダ名は `YYYY-MM-DD-日本語企画名`。日付は**最新の大幅更新日**（目的・子構成を作り直した日。日常の進捗更新は含まない）であり、更新は plan-ops の `rename` サブコマンドで行う。固有名詞（Orca, skill-creator-custom 等）は識別子として残し、企画名は日本語で簡潔に（15〜20字目安）。
1. バケットが計画の状態の正本。意味は次の通り（area 内計画の状態）。
   - `planning`: 方針検討中・未着手（2026-07-04追加。repo-local `plans/` 規約と同語彙）。
   - `active`: 実装・修正・AIレビュー中の計画。各 `plans/` root あたり最大3件。
   - `paused`: 一時停止。再開予定あり。
   - `done`: 実装済みかつ最終評価md全PASS。人間のクローズ判断待ち。
   - `archive`: 人間が閉じると明示確認し、終了記録を残した参照専用の計画。成功だけを意味しない。
   - `移行済み/`: repoへ卒業した計画のログ置き場（状態バケットではなく履歴。詳細は §5）。
2. plan.md に `状態:` フィールドは書かない（フォルダが正本）。`分類:`（skill/repo/loop）と `種別:`（新規作成/既存改善/統合整理）は計画の分類なので plan.md 冒頭に書く。
3. 状態が変わったら `git mv` でバケット間を移す。
   - 新規 → `planning/`。実行を決めた指揮官が plan-ops の `bucketctl` で上限を確認してから `active/` へ昇格する（直行しない）。
   - 一時停止、未完の軽微作業、保留 → `paused/`。理由と再開条件は各計画に残す。
   - `active → done` は最終評価md全PASS後だけ。問題があれば `done → active` へ戻す。
   - `done → archive` は人間確認と終了記録後だけ。`planning/active/paused → archive` は `superseded/merged/conflict/cancelled` の終了記録と人間確認がある時だけ。
   - repoへ卒業 → バケット移動ではなく §5 の卒業手順で repo へ移す。
   - 終了区分は `completed`／`superseded`／`merged`／`conflict`／`cancelled`。`completed` は全完了条件・最終評価全PASS（Programは全子完了）を要し、その他は理由・人間確認・未完了事項、さらに `superseded/merged/conflict` は後継・統合先を要する。移動は `bucketctl` を使い、上限は active=3・paused=3・done=8（planning/archiveは無制限）とする。
4. 空の `planning/` `paused/` `done/` `archive/` は `.gitkeep` を置く。`移行済み/` は空フォルダを先に作らず、初回卒業時に作る。
5. `plan.md` を計画本文の正本にする。追加ファイルは分離した方が読みやすい時だけ作る。実行結果・評価からの同期は `planctl`、終了記録の検証を含む遷移は `bucketctl` が担当する。

### plan.md 統一テンプレ

1. 冒頭に `分類:`（skill/repo/loop/横断）、`種別:`（新規作成/既存改善/統合整理）。任意で `規模:`（フル/ライト。省略時フル）と `優先:`（◎/○）を足す。規模、段階語彙、レビュー、人間ゲートの正本入口は `../../AIエージェント基盤/plan-registry/AGENTS.md`（runtime最小ゲートは同階層の `GLOBAL_AGENTS.md` §7）。
2. 必須セクション: `目的` / `非対象` / `現状` / `実行契約` / `方針` / `完了条件（レビュー項目）`。実行契約の正本テンプレはplan-opsに置き、モデルID・作業場所・branch・session IDを計画本文へ固定しない。
3. `完了条件` は検証可能な**レビュー項目**で書く（下の「レビュー項目と実行ゲート」）。未確定なら「未確定」と明記。`方針` も固まる前は「未確定」と書いて育てる。
4. 「背景: 未記入」のような空欄テンプレは禁止。書けない欄は消すか「未確定」と書く。

### レビュー項目と実行ゲート

計画は「完了条件＝レビュー項目（検証可能なチェック）」を実行前に定義する。レビューの規模別方式・人間ゲート・差し戻し上限は `../../AIエージェント基盤/plan-registry/AGENTS.md` を正とし、ここはareaでの文書配置と状態遷移だけを持つ。

1. **実行ゲート**: フル計画は `explain/` の図解HTMLを最新化して人間へ提示し、理解に相違がない明示を得てからactive昇格・実行開始する。並列宣言の子はレーン別のファイル担当を計画へ記載後にだけ走らせる。area計画は指揮官がペインへ配って実行する（§4.2）。
2. **done ゲート**: 実行後、選んだレビュー方式の完了条件を満たせば done。満たさなければ差し戻す。
3. レビュー項目は「やったか」でなく「**こうなっていれば正しい**」を書く（例: 「テーブル行が残っていない」「リンクが全て解決する」「secret混入なし」）。
4. 各項目は**対象（ファイル/セクション）を明示**する（例: 「3年計画.md の領域別4行すべてにヒントが付く」）。範囲を絞らないと機械チェックが誤判定する。

### 評価・修正文書（レビューサイクルのMD駆動・2026-07-11追加）

ライト以上の実装は、採点結果と差し戻し指示もMD文書にする（口頭・チャット要約で渡すと指示が丸まって劣化するため）。書式の雛形は plan-ops `templates/評価.md`・`templates/修正.md`（本文をここに複製しない）。

1. **命名（接尾辞方式・計画と同じ場所）**: 単発は plan.md と同フォルダに `評価01.md` → `修正01.md` → `評価02.md` …。program の子は `plans/NN-子名-評価01.md` のように子と同じ接頭NNを付けて並べる。
2. **ラウンド番号＝差し戻し回数**。上限と書き手の責務は `../../AIエージェント基盤/plan-registry/AGENTS.md` に従い、上限超過は人間へエスカレーションする。
3. **doneゲートとの接続**: 最終ラウンドの評価mdが全PASSであることを done 移動の条件にする（§3「レビュー項目と実行ゲート」2の具体化）。サクッと（判定はplan-registry）では評価・修正mdを作らない。
4. 実装担当への差し戻しは「修正NN.mdを読め」で渡す（resume等の引数に要約を書いて済ませない）。

### プログラム計画（親子層）

複数の子計画を束ねる必要が出たら、単発 plan.md の上に「プログラム（program）」を被せる。

program化の判定と子計画のレビュー方式は `../../AIエージェント基盤/plan-registry/AGENTS.md` を正とする。ここではprogramの物理構成だけを定める。

```text
plans/active/<YYYY-MM-DD-日本語企画名>/   # programフォルダ（自身の状態はこのareaバケット）
  program.md            # 親＝索引（目的・全体像・子計画マップ・完了条件）
  plans/                # 子計画群（平置きファイル）
    NN-<子計画名>.md     # 子＝plan.md 相当。frontmatter に 親計画: backlink
  references/           # 任意・遅延：参照資料（完成した材料。考え・未確定は方針/identity.md）
```

1. **親はフォルダ、親ドキュメントは直下 `program.md`。** 子は `plans/` に平置き。
2. **子の状態は program.md の子計画マップが持つ**（リスト形式: 「`- [ ] NN 子計画名 … 状態`」＋ `役割:`／`対象repo:`／`並列:`／`レビュー:`／`人間ゲート:`／`次:`／`場所:/依存:`／`参照:`。表は使わない）。見出し左のチェックボックスは完了だけ `[x]`、それ以外は `[ ]` とし、plan-opsが状態との不整合を検出する。`レビュー:` は `都度` または `一括（束ね先）` と書く。一括は直接依存のない子を3子程度で束ね、共通契約を変える修正が必要なら即差し戻し・都度化する。子に状態バケットは作らない。段階語彙、programの最終一括確認、危険操作の個別承認は `../../AIエージェント基盤/plan-registry/AGENTS.md` に従う。§4.1の英語バケット語彙はフォルダ用で、マップには使わない（plan-ops `program-lint.sh` が機械チェックする。2026-07-08 決定ログ#12）。
3. `program.md` frontmatter に `形態: program` を書く（単発 plan.md と区別）。
4. 子が並列実行で複数作業に割れる時だけ、その子をフォルダにする。実行の配り方は §4.2。
5. 子が卒業しても program.md は索引として残り、マップの「場所」を更新する（§5）。

### コピペ用テンプレ（正本は基盤 plan-ops・本文複製禁止）

テンプレ本文の正本は `../../AIエージェント基盤/skills/plan-ops/templates/`（plan/program/子計画/評価/修正に加え、`実行指示.md`・`実行結果.json`・`終了記録.md`）。本節にテンプレ本文を複製しない。規模・レビューの規約は `../../AIエージェント基盤/plan-registry/AGENTS.md`、雛形の生成は `skills/plan-ops/scripts/new-plan.sh` / `new-child.sh`（使い方は plan-ops SKILL.md）。

単発 plan.md は `並列:`／`レビュー:` と `目的/現状/方針/完了条件（レビュー項目）` を持ち、`形態: program` と子計画マップだけ持たない。program.md は `人間確認方針:`、子計画.md は親計画backlinkに加えて `並列:`／`レビュー:`／`人間ゲート:` を持つ。

## 4. 計画状態語彙 と タスク実行

### 4.1 計画状態語彙（バケットの正本）

計画 / program のライフサイクル状態。バケット（フォルダ）で持つ。area・基盤で使う語彙の正本はここ。

1. `planning`: 方針検討中、未着手、判断未確定。（基盤・areaとも使用。2026-07-04 repo-local `plans/` 規約と統一）
2. `ready`: 計画済みで着手可能。（基盤plansで loop が拾う印）
3. `active`: 実装・修正・AIレビュー中の実行計画（各 `plans/` root あたり最大3件）。
4. `paused`: 一時停止。
5. `done`: 最終評価md全PASS済みで、人間のクローズ判断待ち。
6. `archive`: 人間確認と終了記録を残した閉じた参照専用計画。

area の plan バケットは `planning/active/paused/done/archive`（§3）。卒業先の物理構成は所有repoの最寄り `AGENTS.md` を正とし、ここから存在しない節や計画箱を推定しない。

### 4.2 計画から派生する作業の実行

計画から派生する「実行する作業」は、area 内にフォルダを作らず、指揮官（orca-cockpit）が実装/レビューのペインへ直接配って実行する。

1. 実行の状態はテキスト（当日デイリー行注記＋Notion盤面）で持つ。フォルダキューは使わない（旧 ai-jobs は 2026-07-11 廃止＝決定ログ#14）。
2. **human 作業は実行レーンに入れない。** 人間のやることは program.md マップの「次の一手」か 子.md に書く。
3. 完了したら plan-ops が出所の計画（program.md マップ／子.md）を更新する（ジョブ→計画へ集約。コピーしない）。
4. 旧 `ops/` 5フォルダ構成は廃止。既存計画に残る `ops/` は legacy（新規には作らない・破壊しない）。

## 5. 計画ライフサイクル: 育成 → 卒業

計画は area で生まれ育て、成熟したら実行先へ「卒業」させる。

1. 育成: `planning/` で `plan.md` を育てる。実行を決めたら指揮官が `bucketctl promote` で `active/` へ昇格する。成熟マーカーは持たない（成熟＝即卒業なので状態化しない）。
2. 卒業の引き金: 当面は人間が判断する。評価軸が固まったらAIとのハイブリッドへ。評価軸は実運用の中で固める。
3. 卒業先の判断:
   - 単一repoに属す作業 → `repo-registry/repo概要.md` で担当repoを確定し、対象repo `AGENTS.md` が宣言する領域・プロジェクト・計画箱。先に既存planを検索し、箱が曖昧なら卒業せず人間に確認する。
   - personal-os構造・横断・repo無し → 卒業せず area 内で実行（human作業は program.md マップ／子.md、AI実行は §4.2）。
   - global skill → 卒業可否と箱は `AIエージェント基盤/global-skill-registry/AGENTS.md` に従う。loopの構想・draftは ai運用areaのplanに残し、実装だけを `AIエージェント基盤/loops-registry/AGENTS.md` のゲート後に `loops/` へ反映する。存在しない `loops-registry/plans/loop/` は作らない。

### 卒業手順（repoへ移す場合）

1. 人間が「卒業」と判断。
2. 移行先を決める（既存repo＝対象repo `AGENTS.md` の計画箱 / 新規repo＝repo-createでrepoと計画箱を先に宣言 / Global Skill＝`global-skill-registry/AGENTS.md` に従う / loop＝planはareaに残し実装のみ `loops-registry/AGENTS.md` に従う）。
3. 移行先repoに `plan.md`（＋要れば子計画）を作成 → そのrepoで commit。
4. area の元 plan フォルダを削除し、`移行済み/YYYY-MM/MM-DD-<計画名>.md` に移行ログを追記 → ~/Private で commit。
5. programの子なら、plan-opsで program.md マップの「場所」を移行先に更新する。廃止済みrendererの自動反映は前提にしない。session-boardは実行sessionとDailyログを所有するだけで、計画の移行先・本文・状態を書き換えない。
6. 確認: secret無し / 移行先パスが計画文書（program.md マップ・plan.md）と移行ログで一致。
   ※ 卒業は ~/Private と移行先repoの2repoをまたぐ。`git mv` できないので「移行先で作成commit → area側で削除＋ログcommit」の2コミットになる。

### プログラムの子計画の卒業

プログラム配下の子は、個別に卒業する。親 program.md は索引として area に残る。

1. 子の本体を卒業先へ（上の通常手順）。子 frontmatter の `親計画:` backlink は、卒業後は**絶対パス**にする（cross-repo になるため）。
2. program.md の子計画マップの「場所」列を卒業先に更新（状態は active のまま、実行先が変わっただけ）。
3. 親 program.md は動かさない（全体の地図として工房に残る）。

### 移行ログの書式

`<area>/plans/移行済み/YYYY-MM/MM-DD-<計画名>.md`、1卒業＝1ファイル（並列書き込み衝突なし・既存 logs 規約と同形）。本体は移行先repoが持つのでここには置かない。

```text
移行日時: YYYY-MM-DD HH:mm JST
元計画: <area側の計画フォルダ名>
移行先: <repo名>
移行先パス: <repo内の plan.md / SKILL.md 等>
要約: <1行>
```

### area内実行のコミット

1. area内実行が生むのはドキュメント・意思決定・human行動の記録のみ → ~/Private にコミットしてよい（local-only・非コード）。
2. コードや成果物ファイルが出る瞬間に卒業対象。~/Private にコードを置かない。
3. 使い捨て実行は scratchpad、コミットしない。

## 6. 配置判断

1. 領域内のライト以上の新規計画は `plans/planning/<計画名>/plan.md` に作る。実行を決めた指揮官だけが `bucketctl promote` で `active/` へ昇格し、状態に応じてバケット間を移す。考え・調査は独立させず `identity.md` か plan.md の `方針` に寄せる。
2. その計画から派生する実行作業は、指揮官がペインへ配って実行する（§4.2）。program化の判断は `../../AIエージェント基盤/plan-registry/AGENTS.md` に従う。
3. 成熟した計画は §5 の卒業手順で実行repoへ移す。area には移行ログが残る。計画索引・programマップの追従は各所有機構で明示的に行い、廃止済みrendererを前提にしない。
4. repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
5. Skill正本、registry、logsは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/` を正とする。
6. 計画本文を複数箇所にコピーしない。必要なら相対パスで参照する。
