分類: repo ／ 種別: 統合整理 ／ 形態: program ／ 規模: フル ／ 優先: ○
次: Wave 0として中央契約と仕事repoの無条件Stop commit停止を並列実装し、統合レビューする
出所: `../../paused/2026-07-02-repo構造の標準化構想/plan.md` の後継

# 全repoへのAI運用標準移植

## 目的

Personal OSで整備した計画・実行・安全運用の型を、仕事repoを最初の実証先として各repoへ段階展開する。中央正本を複製せず、repo固有の構造と業務導線を壊さず、1波ずつ戻せる移行にする。

## 現状

1. Personal OS側には、作業規模・人間ゲートの `運用契約.md`、計画手続きの `plan-ops`、入口判断の `plan-triage`、repo改善の `repo-create` がある。
2. 仕事repoは業務ドメインの `領域/`、repo-local Skill、自動実行を既に持ち、root `plans/{planning,active,paused,done}` も作られている。一方、AGENTS上の計画正本は `領域/{ドメイン}/{プロジェクト}/計画/plan.md` と手書き `計画一覧.md` のままで、新旧導線が併存する。
3. 仕事repoのtracked設定に平文credentialがあり、履歴にも残る。値は本計画・HTML・ログに記載しない。加えて、有効なStop hookが `git add -A` と自動commitを実行し、既存未コミット変更を巻き込む危険がある。
4. 調査開始時点では仕事repoに別セッションの未コミット変更があり、調査中にもGit状態が変化した。移行実装は開始時snapshotと専用worktreeで並行作業から隔離する必要がある。
5. Personal OS側にも、存在しない節への参照、廃止済みの計画path・renderer・ops前提が残る。正本の矛盾を直さず横展開すると古い前提まで配ることになる。
6. 既存paused計画に今回の発案があるため、本programを現在の判断・状態の正本とする。旧計画は別セッションのstaged移動対象なので編集せず、後継ポインタの追記は既存差分解消後の人間ゲートに残す。
7. `repo-registry/repo概要.md` は担当repoを引く短い索引で、各repoの詳細・領域構造はそのrepoの `AGENTS.md` が正本である。一方、現行Global計画規約には全repoをroot `plans/`へ寄せる前提があり、仕事repoの `領域/{ドメイン}/{プロジェクト}/計画/plan.md` と矛盾する。本programで二段ルーティング契約へ修正する。

## 全体像

```text
Privateから依頼
  ↓
repo-registry/repo概要.md
  └─ 担当repoだけを解決（領域表や計画本文は持たない）
       ↓
<担当repo>/AGENTS.md
  └─ repo種別・領域・プロジェクト・計画箱を解決
       ↓
既存計画を検索 ── あり → 既存計画へ合流
       └──────── なし → repo内の正しい箱へ新規作成
                              ↓
                    plan-triage / plan-ops
                    （規模・実行形・雛形・lint）
                              ↓
                    対象repo所有のsession/worktreeで実行
                    （対象repoのAGENTS・Skill・hookを適用）

仕事repoの計画箱
├─ 領域固有: 領域/{ドメイン}/{プロジェクト}/計画/plan.md
└─ repo横断: plans/{planning,active,paused,done}/<企画>/
```

共通化するのは制御面とルーティング手続きだけとする。`repo-registry` は担当repo、対象repoの `AGENTS.md` は領域と計画箱、各planは本文と状態を所有する。session-boardはsession状態とDailyの実行ログを所有するが、plan本文・plan状態は所有しない。仕事repoでは業務領域に閉じる計画を `領域/.../計画/` に置き、repo横断・複数領域・基盤移行だけをroot `plans/` に置く。Private起点でも実装時は対象repo所有のsession/worktreeへ切り替え、仕事repoのAGENTS・repo-local Skill・安全化済みhookを適用する。全repoへ同じ物理pathやhook本文を強制しない。

### 今回の正本と実装記録

- 本program一式を「全repo移植」の唯一の計画正本とする。仕事repoへ同じ移植計画・子計画・状態表をコピーしない。
- 仕事repoには承認済みの実装差分・テスト・必要最小限のrepo-local説明だけを置く。中央programは各waveの順序・合否・参照commitだけを持ち、仕事repoの設定本文やテスト結果を複製しない。
- 移植後に仕事固有の新規依頼を起案する時は、仕事repo `AGENTS.md` が解決した計画箱のplanだけを正本にする。本programにはそのplanへの参照とパイロット合否だけを残す。
- session-boardとDailyは実行中session・時刻付き進捗の表示であり、計画正本の代替にしない。

### Privateから仕事repoへのsession引継ぎ

1. Private sessionは、担当repo判定・既存plan検索・計画案・人間承認・引継ぎ情報の作成までを所有する。
2. 書込み前に、canonical repo path、plan参照、worktree cwd、許可path、禁止事項、開始時Git snapshotを渡して、仕事repoをrootとする新しい可視sessionを起動する。session IDの付け替え・既存行のreparentは行わない。
3. 新sessionがsession-boardへ登録され、仕事 `AGENTS.md` を読んだことを確認後、Private sessionは引継ぎ完了として自分の行をfinishする。
4. Private sessionを横断調整役として残す場合だけ2行併存を許し、両行の役割と終了責任を明記して、それぞれを別にfinishする。

### 実行wave

```text
Wave 0（並列）  01 中央契約 ─┐
                02 緊急安全化 ├→ 統合レビュー・人間ゲート
                              ┘
Wave 1（直列）  03 移植台帳
Wave 2（直列）  04 二段ルーティングとsession引継ぎ
Wave 3（直列）  05 新規計画E2Eパイロット
Wave 4（直列）  06 既存計画1件の整理 → 07 runtime所有権整理
Wave 5（直列）  08 repo-create移植キット → 09 focusmap・全repo展開
```

各担当agentは、最初に本program、その後に担当子計画と対象repoの最寄り `AGENTS.md` だけを読む。共通契約を個別promptへ全文コピーせず、「唯一の正本・許可path・人間ゲート・完了条件」を短く渡す。

## 移植原則

1. **中央正本**: 共通契約、Global Skill、Global hook、テンプレはPersonal OS / AIエージェント基盤を正本とし、各repoへ本文コピーしない。
2. **二段ルーティング**: Privateからの依頼は、repo registryで担当repoを決め、次に対象repoの `AGENTS.md` で領域・プロジェクト・計画箱を決める。registryへ領域表を複製しない。
3. **実行contextの切替**: 仕事repo内から始めた依頼はそのまま仕事AGENTSへ従う。Privateから担当repoを解決した依頼は、計画・実装の書込み前に対象repo所有のsession/worktreeへ切り替える。Private側からrepo-local hookの代替実行や本文コピーをしない。
4. **repo-local所有**: 業務領域、コード、manual、repo-local Skill、repo固有hook/loopの実装は所有repoに残す。hookは計画pathを決めず、イベント後処理・安全確認・実行記録だけを担う。
5. **cross-repo symlink禁止**: clone、worktree、別PC、外部SSDで壊れるため、repo境界をまたぐsymlinkは標準にしない。Global Skillの発見はruntime露出へ任せる。
6. **repo固有の計画箱**: 計画pathは対象repoの `AGENTS.md` が宣言する。仕事の領域固有計画は `領域/.../計画/`、repo横断計画はroot `plans/`、coding repoは原則root `plans/` とする。
7. **既存計画優先**: 新規作成前に同じ目的のplanを検索し、存在すれば合流する。日付違い・path違いの重複planを自動生成しない。
8. **strangler移行**: 新しいルーティング入口を先に整え、既存計画は正本性を台帳で判定してから1件ずつconsumerと同じ波で整理する。一括移動・一括改名をしない。
9. **1計画1正本**: registry、一覧、session-boardへ本文や状態を複製しない。`計画一覧.md` は各plan headerから生成するread-only索引とし、Skillはplan更新後に再生成するだけにする。
10. **安全優先**: secret、危険hook、dirty worktree、旧絶対pathを第0ゲートで処理し、PASSまで仕事repoで実装ペインを起動しない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01 中央正本とrepo標準契約 … 完了
    並列: 可 ／ レビュー: 都度
    次: 子02の巻込みauto-commitとcredential人間ゲートを解消する
    場所: `plans/01-中央正本とrepo標準契約.md` ／ 依存: ―
- [ ] 02 仕事repo緊急安全化 … 計画
    並列: 可 ／ レビュー: 都度
    次: 旧hook保持sessionを終了し、auto-commit 2件の分離とcredential gateを人間承認する
    場所: `plans/02-仕事repo緊急安全化.md` ／ 依存: ―
- [ ] 03 仕事repo移植台帳 … 計画
    並列: 不可 ／ レビュー: 都度
    次: legacy計画・consumer・旧絶対pathのread-only対応表を作る
    場所: `plans/03-仕事repo移植台帳.md` ／ 依存: 01, 02
- [ ] 04 仕事repo二段ルーティング導入 … 計画
    並列: 不可 ／ レビュー: 都度
    次: Private→registry→仕事AGENTS→repo実行contextと、plan→生成一覧の互換導線を実装する
    場所: `plans/04-仕事repo互換レイヤ導入.md` ／ 依存: 01, 02, 03
- [ ] 05 仕事repo新規計画パイロット … 計画
    並列: 不可 ／ レビュー: 都度
    次: 外部書込みのない領域固有計画1件で二段ルートとrollbackを実証する
    場所: `plans/05-仕事repo新規計画パイロット.md` ／ 依存: 04
- [ ] 06 仕事repo既存計画の正本整理 … 計画
    並列: 不可 ／ レビュー: 都度
    次: 人間が選んだ既存計画1件の正本・consumer・索引を同時整理する
    場所: `plans/06-仕事repo旧計画段階移行.md` ／ 依存: 05
- [ ] 07 仕事repo導線所有権整理 … 計画
    並列: 不可 ／ レビュー: 都度
    次: AGENTS/CLAUDE・Skill・hook・loopの所有権を実測後に整える
    場所: `plans/07-仕事repo導線所有権整理.md` ／ 依存: 02, 03, 05
- [ ] 08 repo-create移植キット … 計画
    並列: 不可 ／ レビュー: 都度
    次: repo種別ごとの計画箱宣言と二段ルートをdry-run監査・scaffoldへ落とす
    場所: `plans/08-repo-create移植キット.md` ／ 依存: 05, 06, 07
- [ ] 09 実装系カナリアと全repo展開 … 計画
    並列: 不可 ／ レビュー: 都度
    次: focusmapを第2カナリアとして類型差を検証する
    場所: `plans/09-実装系カナリアと全repo展開.md` ／ 依存: 08

## 人間ゲート

1. credentialの失効・再発行、Git履歴対応方針。
2. tracked設定・hook・launchd登録の変更。
3. 旧計画の移動・改名・旧pathポインタ化。
4. `CLAUDE.md` / `AGENTS.md` のsymlink向き変更。
5. `planning → active` 昇格、明示pathだけのcheckpoint commit、main反映、push。
6. 仕事repoパイロットの合否と、focusmap以降へ進む判断。
7. Globalの「全repo root plans」前提を、repo `AGENTS.md` が計画箱を宣言する契約へ変更する判断。
8. Private sessionから対象repo sessionへの引継ぎ完了と、調整役を残す場合の2行併存。
9. sessionのfinish、planのdone、成果物archiveを別判断として実行すること。
10. 旧Stop hookが作成した未push commit `f4b78f49`・`fb6f5047` の扱い。安全化2ファイルと別sessionの新規planを分離し、plan本文を失わない回復手順は実行前に人間承認を得る。変更前から開いている仕事sessionを先に終了・再起動し、旧hookの再発火を防ぐ。

## 完了条件（レビュー項目）

- [ ] `personal-os` のGlobal/area/基盤入口で、repo計画のbucket・正本path・廃止済み参照に矛盾がない。
- [ ] 仕事repoでtracked secretが0件となり、漏えいcredentialが失効・再発行済みで、履歴対応の人間判断が記録されている。
- [ ] 仕事repoの有効hookに `git add -A` 自動commitと存在しない旧root参照が残っていない。
- [ ] Privateからの依頼で、repo registry→担当repo `AGENTS.md`→既存計画検索→計画箱の順に、担当repo・領域・プロジェクト・plan正本を一意に解決できる。
- [ ] 仕事repo内起点とPrivate起点が同じplan正本へ合流し、Private起点の実装は仕事repo所有のsession/worktreeで行われる。
- [ ] Private→仕事repo引継ぎでcanonical repo、plan参照、worktree cwd、開始時snapshotが一意で、新旧sessionに孤児行がない。
- [ ] 仕事repoの領域固有計画は `領域/{ドメイン}/{プロジェクト}/計画/plan.md`、repo横断計画はroot `plans/<bucket>/` に作られ、各planの本文・状態正本が1箇所である。
- [ ] repo registryに仕事の領域表や計画状態を複製せず、仕事 `AGENTS.md` だけで領域・プロジェクト・計画箱を判定できる。
- [ ] `計画一覧.md` は領域planとroot planのheaderから生成するread-only索引に降格し、`task`・`eod`・`review`・`business-planning`・`repo-eval` が計画状態の手書き複製を要求しない。
- [ ] hookは担当repo・計画pathを決めず、対象repo contextで安全な後処理・実行記録だけを行う。
- [ ] 仕事repoで領域固有の新規計画1件と既存計画1件が、Claude/Codex・plan-ops・session-boardを通して完了し、repo-local/global hookが各1回だけ発火し、wave単位のrollbackを確認している。
- [ ] sessionのfinish、root planのdone、領域planの完了表現、成果物archiveが混同されていない。
- [ ] 仕事repoの `領域/`、業務manual、repo-local Skill、稼働中loopが不要に移動・複製されていない。
- [ ] `repo-create` の監査・scaffoldが既定dry-run、secret値非表示、冪等、既存ファイル非上書きである。
- [ ] focusmapの実装系カナリアがPASSし、管理対象repoごとに導入済み・保留・対象外と理由が一意に記録されている。
- [ ] 各子計画の最終 `評価NN.md` が全PASSで、人間が全repo展開可を確認している。

## 関連

- 先行発案: `../../paused/2026-07-02-repo構造の標準化構想/plan.md`
- 先行手順: `../../paused/2026-07-08-計画実行フロー統一/plans/02-計画置き場の全リポ統一.md`
- 共通契約: `../../../../../../説明書/運用契約.md`
- 計画規約: `../../../../AGENTS.md`
- repo索引: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/repo概要.md`
- 仕事repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 第2カナリア候補: `/Users/kitamuranaohiro/Private/projects/active/focusmap`
