分類: skill ／ 種別: 新規作成 ／ 規模: フル ／ 優先: ◎
並列: 不可（契約確定→Skill実装→runtime露出の順） ／ レビュー: 都度

# Global Skill `loop-creator` 新規作成

## 目的

「朝に自動実行したい」「この処理をloopにしたい」という依頼から、loopの所有repo、正本、実装置き場、基盤からの発見導線、registry登録、実行前検証までを一貫して扱うGlobal Skill `loop-creator` を新設する。

人間が、実体は各repoにあり、基盤はdirectory symlinkとregistryで全体を把握する構造を理解できる状態にする。launchdの有効化・無効化・周期変更はSkillの自動判断で実行せず、必ず人間承認を通す。

## 現在の整理（2026-07-14）

- **完了**: Global Skill `loop-creator` の正本、作成・検証script、人間向けHTML、catalog/created log、5 runtimeへのdirect symlink、仕事repoの`loops/` rootと基盤directory symlink。自己テストと独立再監査はPASS。
- **完了（上位子計画）**: Focusmapの`loops/` rootと`implementation-links/Focusmap`も導入済み。既存実装の移動はしていない。
- **今回しない**: 新規個別loopの実装、launchdの登録・有効化・周期変更、既存loopの移設、Turso migration適用、Notion廃止。
- **履歴上の注意**: 初回実装前のlaunchd snapshotは遡及できない。以後のlaunchd変更では、対象labelとLaunchAgents symlinkの変更前後snapshotを比較する。

## 現状

- loopの正本契約は `AIエージェント基盤/loops-registry/AGENTS.md` にあり、global loopは基盤、repo固有loopは所有repoの `loops/<loop-id>/` に置く方針まで決まっている。
- 仕事repoには `loops/` rootと、基盤の `implementation-links/仕事` からroot全体を見る相対directory symlinkがある。既存の実装やlaunchdは移動していない。
- Focusmapへの同じroot導入、Global Skill `loop-creator` の正本化とruntime露出は完了している。
- 現行registryは `実行loop一覧.md` が中心で、Turso正本への移行は別の親計画で進行中である。移行前後の登録先をSkill内へ固定して二重管理してはいけない。
- `repo-create` はrepo整備、`plan-triage` は計画と担当repoの判定、`skill-creator-custom` はSkill自体のライフサイクルを担当する。どれもloop作成の全工程は所有していない。
- 全体展開とTurso移行は既存子計画「05 repo-local loop標準とLoop Creator」が所有している。本計画はそのうち **Global Skill本体だけ** を所有し、repo展開や既存loop移設を二重管理しない。
- 2026-07-14 16:57 JSTに人間が本計画内容での実装を承認した。`bucketctl` はactive上限3件のため専用計画の昇格を拒否したので、4件目を作らず、既にactiveの上位子計画05を実行容器として本計画を実装仕様に使う。

## 方針

### 1. Skillの責任範囲

`loop-creator` は `meta` 分類のGlobal Skillとし、次を一つの導線で行う。

1. 依頼がloopかを判定する。イベントhook、手動コマンド、一回限りのCodex automation、対話型agentはloopとして作らず、該当する導線へ返す。
2. `repo-registry` で所有repoを決め、対象repoの最寄り `AGENTS.md` と `loops/AGENTS.md` を読む。複数repoを横断する運用loopだけを基盤globalの候補にする。
3. repoが宣言した `loops/` rootが無い、候補が複数ある、正本が不明な場合は作成せず停止する。AI判断で別のloop置き場を増やさない。
4. `loops/<loop-id>/` には必須の `loop.md` だけを作る。実装が必要な時だけ `scripts/`、ファイルログが必要な時だけgitignoreされた `logs/`、launchdを使う時だけplistを追加する。`tests/`・`state/`・`output/` を定型として自動作成せず、既存ファイルも上書きしない。
5. 基盤の `implementation-links/<repo-id>` がrepoのloops root全体を指す相対directory symlinkか検証する。個別loopごとのsymlinkや実装コピーは作らない。
6. 登録時点の `loops-registry/AGENTS.md` が示す正本へdefinition/source referenceを登録する。Turso移行前後でmdとDBを同時正本にしない。
7. plist構文、必要なscript、symlinkの解決先、logsのgitignore、secret非混入、registry整合、対象diffを検証し、人間向けに正本・露出先・未実行事項を報告する。
8. launchdのbootstrap/bootout、enable/disable、周期変更、既存実装の移動は、人間が対象とrollbackを確認して明示承認した後だけ行う。

### 2. loop実体の最小構成

新規loopで必ず作るのは `loop.md` だけとする。定型フォルダを先に増やさず、必要性があるものだけを追加する。

```text
loops/<loop-id>/
├── loop.md                         # 必須: 目的・発火・runner・停止手順・状態/成果物の置き場
├── scripts/                         # 実行scriptが必要な時だけ
├── logs/                            # ファイルログが必要な時だけ。gitignore
└── *.plist                          # launchdを使う時だけ
```

- `tests/`: ロジックの複雑さ・失敗時の影響に応じて採用し、配置は対象repoの既存テスト規約に従う。定型作成しない。
- `state/`: 定型作成しない。lockは原則 `/tmp`、永続stateはそのloopが明示した既存の正本またはDBに置く。
- `output/`: 定型作成しない。成果物は対象repoの既存カテゴリ、dashboard、DBなど、そのloopの目的に合う正本へ置く。

### 3. launchdとscriptの実行モデル

launchdはmacOSの常駐実行係、plistはその予定表、scriptは実際の仕事をする実行者である。役割を混ぜない。

```text
loop.md                         人間/AI向けの定義。macOSは読まない
    └─ 参照する ───────────────┐
<launchd-label>.plist           いつ・何を起動するかをlaunchdへ渡す設定
    └─ symlinkで露出 ─→ ~/Library/LaunchAgents/<launchd-label>.plist
                                      └─ launchdが読み込む
                                          └─ scripts/<runner> を起動
                                                └─ 必要時だけ logs/ と成果物の正本へ出力
```

- `loop.md`: 目的、所有、発火意図、runner、停止手順、state/成果物の正本を説明する。実行されない。
- `*.plist`: label、絶対実行path、時刻または間隔、必要ならstdout/stderrの出力先を記す。macOSが読む設定であり、ソースコードではない。launchdを使わないloopには不要。
- `scripts/`: 実処理を行うsource code。手動実行・テスト・原因調査をscheduleから分離できる。実装が不要なrunnerには作らない。
- `~/Library/LaunchAgents/`: macOS runtimeへ露出する場所。正本ではなく、所有loopのplistへのsymlinkとする。
- `launchctl`: plistを読込・解除し、loaded状態や終了結果を確認する操作窓口。設定ファイルではない。

一つの共通plistで複数処理を起動する場合、それは複数loopではなく「dispatcherという一つのloop」である。個別の停止・周期変更・失敗観測を保つため、通常はloopごとに固有plistを持つ。共通化するのは雛形またはrunnerの共有部分までとする。

### 4. 最小のSkill構成案

正本は `AIエージェント基盤/skills/loop-creator/` に置く。初期構成は次を候補とし、計画レビューで過不足を確定する。

```text
skills/loop-creator/
├── SKILL.md                         # 70行以内の入口・発火条件・安全ゲート
├── SKILL.html                       # 人間向け白背景説明（正本はSKILL.md）
├── workflows/
│   └── create-or-update-loop.md     # 作成・変更・検証の詳細手順
└── scripts/
    ├── scaffold-loop.sh             # dry-run、非上書き、冪等の雛形生成
    └── test-scaffold-loop.sh        # 一時fixtureで安全条件を検証
```

`references/` と `assets/` は先に増やさない。契約は各repoと `loops-registry/AGENTS.md` を都度参照し、手順から独立して再利用する情報が実装中に判明した場合だけ追加する。

### 5. 既存Skillとの境界

- `skill-creator-custom`: 本計画の実装時に `loop-creator` 自体を作り、catalog・created log・runtime露出を整えるために使う。loop成果物は作らない。
- `plan-triage`: 対象repoと既存planを解決する入口として `loop-creator` から参照する。loopフォルダへは書き込まない。
- `repo-create`: repoに `loops/` root契約が無い時のrepo整備候補。個別loopは作らない。
- `loop-creator`: loop作成・変更の構造、registry登録、基盤directory symlink検証を所有する。Skill作成やrepo全般の標準化は所有しない。

### 6. 実装と露出の順序

1. 本計画を人間がレビューする。active上限に空きがあれば昇格し、上位active子計画が実行を所有する場合は4件目を作らず、その子計画へ進捗を集約する。
2. `skill-creator-custom` に従い、近接Skillとの差分、名称、発火条件、negative trigger、安全ゲートを再確認する。
3. `SKILL.md`、詳細workflow、scaffold/test script、`SKILL.html` を正本側へ実装する。
4. 一時fixtureで、dry-run、必須以外の定型フォルダを作らないこと、既存ファイル非上書き、未宣言rootでの停止、相対directory symlink検証を実行する。実在loopやlaunchdは試験用に変更しない。
5. 人間がruntime露出を承認した後、`global-skill-registry/scripts/link-global-skill.sh` のdry-runと本実行で5 runtimeへ直接symlinkを露出する。
6. `global-skill-registry/catalog/meta.md` と `logs/created/2026-07/07-14-loop-creator.md` を更新し、正本と露出先を記録する。
7. `skill-creator-custom` の完了チェックと独立レビューを通し、既存loop・launchdに差分が無いことを報告する。

### 7. 人間ゲート

次は計画承認とは別に、実行直前の明示承認が必要である。

- Global Skillを各runtimeへsymlink露出すること。
- launchdの登録解除、再登録、有効化、無効化、周期変更をすること。
- 既存loop実装を移動・改名・削除すること。
- Tursoへのmigration適用、本番definitionの一括変更をすること。
- commit、push、main反映をすること。

## 関連計画と所有境界

- 上位の全体展開: [05 repo-local loop標準とLoop Creator](../../active/2026-07-12-loopレジストリTurso移行/plans/05-repo-local-loop標準とLoop Creator.md)
- 本計画: Global Skill `loop-creator` の設計、実装、検証、catalog/log、runtime露出だけを所有する。
- 上位子計画: 仕事・Focusmapへのloop root展開、基盤のimplementation link、Turso移行との順序を所有する。

## 完了条件（レビュー項目）

- [x] `skills/loop-creator/SKILL.md` が70行以内の入口になり、自然文の発火条件、loopではない依頼、所有repo判定、fail-closed条件、人間ゲートを明記している。
- [x] 詳細workflowが、repo-registry→最寄りAGENTS→宣言済みloops root→必要最小限のloop.mdと条件付き構成→root directory symlink→登録時点のregistry正本→検証の順を一意に示す。
- [x] scaffold scriptがdry-run可能で、必須の`loop.md`以外の定型フォルダを作らず、既存ファイル非上書き、同一入力で冪等、宣言外pathでは停止となり、一時fixtureのtestで再現できる。
- [x] `loop.md`・script・plist・`~/Library/LaunchAgents/`・launchd・`launchctl` の役割と、正本/露出先/実行時状態の違いがSkillと人間向けHTMLで一致している。
- [x] Skillが個別loop symlink、基盤への実装コピー、mdとTursoの二重正本、secret記録、無承認launchd変更を禁止している。
- [x] `SKILL.html` が `SKILL.md` の人間向け説明であり、白背景・ライト単色・固定ライト表示で、正本、各repo、基盤link、registry、runtimeの関係を図示している。
- [x] `global-skill-registry/catalog/meta.md` とcreated logが、Skill名、正本path、役割、作成理由、runtime露出を記録している。
- [x] 人間承認後、5 runtimeの `skills/loop-creator` が正本への直接symlinkであり、本文コピーやsymlink chainになっていない。
- [x] Skill validator、script test、symlink realpath、対象diff、既存loop/launchdのread-only確認を通し、既存実行状態に変更が無い。
- [x] 独立レビューで上位子計画との責任重複がなく、Focusmap展開へ進める入力条件が明確だと確認できる。

## 実装レビュー（2026-07-14）

- 初回の独立監査で、未宣言rootを祖先の`AGENTS.md`だけで受理する点、同一applyの非成功終了、directory linkの機械検証不足、`SKILL.html`の関係図不足を検出した。
- 修正後は、repo-localをroot直下の`loops/AGENTS.md`、globalを`loops-registry/loops/`のcanonical pathに限定した。既存で同じ所有・scope・runnerの`loop.md`はno-op成功にし、相対directory symlinkを検証するscriptを追加した。
- `test-scaffold-loop.sh`、global/仕事rootのdry-run、仕事のimplementation link、`loops-registry/verify.py`を通過し、独立再監査はPASSだった。launchd登録・周期変更・既存loop移動は行っていない。
- 初回実装時のlaunchd事前snapshotは後から再構成できない。以後のlaunchd変更では、最初の変更前と変更後に対象labelの`launchctl print`とLaunchAgents symlinkを比較することをworkflowへ追加した。
- Focusmapのroot展開とlink作成は上位子計画で完了した。launchd有効化は本計画の対象外であり、別の人間承認済み作業でのみ扱う。
