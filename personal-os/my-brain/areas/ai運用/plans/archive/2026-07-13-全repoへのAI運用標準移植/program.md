分類: repo ／ 種別: 統合整理 ／ 形態: program ／ 規模: フル ／ 優先: ○
次: Child 02はLINE token更新済み。Turso stagingへの実データ移行、D1/Supabaseの値非表示照合、Turso切替境界、staging専用importer、read-only export、staff-status／local runnerの安全停止型adapter、line-reader／staff-statusのread-only shadow、独立R1に加え、P2先行安全化とmock-only送信／read-only rollback契約の独立R2 precheckまでPASSした。canonical payload hash・Retry-Key・strict RFC3339・timeout/409/24時間期限を実送信なしで検証し、Worker／local mock wrapperは既定disabledかつtransportを持たないため、実LINE送信・DB実行へ転用できない。rollback演習時は旧schedulerを閉じたままにする。Tursoを唯一のDB正本とし、通常の業務自動化とローカルファイル／ログイン済みブラウザを要する処理はMac launchdを標準にする。Cloudflare Workerは常時公開が必要なLINE Webhookの受信口として残し、業務時間外にMac非依存で動かす必要がある予約送信・再試行・期限削除だけを担当する。Webhook受信は24時間でも、個別業務処理はlaunchdの業務時間へ渡す。ローカル資料をWorkerのcontextのためにuploadせず、TursoにはLINE／状態の最小DBだけを置き、schedulerや資料保管にしない。P2本体のprimary切替・0002 migration適用・deploy・launchd登録・LINE送信は未実施のまま保持する。
出所: `../../paused/2026-07-02-repo構造の標準化構想/plan.md` の後継

# 全repoへのAI運用標準移植

## 目的

Personal OSで整備した計画・実行・安全運用の型を、仕事repoを最初の実証先として各repoへ段階展開する。中央正本を複製せず、repo固有の構造と業務導線を壊さず、1波ずつ戻せる移行にする。

## 現状

1. Personal OS側には、作業規模・人間ゲートの `GLOBAL_AGENTS.md` §7、計画手続きの `plan-ops`、入口判断の `plan-triage`、repo改善の `repo-create` がある。
2. 仕事repoは業務ドメインの `領域/`、repo-local Skill、自動実行を既に持ち、root `plans/{planning,active,paused,done}` も作られている。一方、AGENTS上の計画正本は `領域/{ドメイン}/{プロジェクト}/計画/plan.md` と手書き `計画一覧.md` のままで、新旧導線が併存する。
3. 仕事repoのtracked HEADと履歴には平文credentialが残るが、2026-07-13のChild 02機械実装でworking treeのinline credentialと有効な `git add -A` / 自動commit経路は0件になった。2026-07-14にLINE tokenはroot非追跡 `.env` へ値非表示で更新・検証済みである。Supabaseはstaff-statusの2状態表だけを使う別系統で、endpointと既存credentialは現役だが、現在ログイン中のSupabase organizationにはprojectがない。staff-statusだけの復旧ならD1統合が最小変更である。LINE本線を含むDB整理が目的なら、Tursoを唯一のDBとし、通常の業務処理はlaunchd、WorkerはWebhook常時受付と業務時間外のMac非依存処理に限定する全体移行を別フル計画として扱う。ローカル資料をCloudflareやTursoへ文脈のために複製しない。いずれの人間判断も、明示path commit、fresh runtime検証までは安全化完了にしない。
4. 調査開始時点では仕事repoに別セッションの未コミット変更があり、調査中にもGit状態が変化した。移行実装は開始時snapshotと専用worktreeで並行作業から隔離する必要がある。
5. Personal OS側にも、存在しない節への参照、廃止済みの計画path・renderer・ops前提が残る。正本の矛盾を直さず横展開すると古い前提まで配ることになる。
6. 既存paused計画に今回の発案があるため、本programを現在の判断・状態の正本とする。旧計画は別セッションのstaged移動対象なので編集せず、後継ポインタの追記は既存差分解消後の人間ゲートに残す。
7. `repo-registry/repo概要.md` は担当repoを引く短い索引で、各repoの詳細・領域構造はそのrepoの `AGENTS.md` が正本である。一方、現行Global計画規約には全repoをroot `plans/`へ寄せる前提があり、仕事repoの `領域/{ドメイン}/{プロジェクト}/計画/plan.md` と矛盾する。本programで二段ルーティング契約へ修正する。
8. 2026-07-14の専用worktree再監査で、仕事repoにはcanonical候補15件（領域 `plan.md` 12件＋root planning 3件）があると確認した。領域の補助文書を含む計画folder、active consumer/reference 16path、逆向きAGENTS/CLAUDE 6階層、cross-repo Skill symlink 3件は、W01でsnapshot固定してfixture基準へ落とす。旧9子計画はこの量を大きな話題単位で束ね、実装単位・許可path・統合順を定義できていなかった。
9. 仕事repo `計画一覧.md` は2026-06-26時点の10件だけでroot planning 3件を含まず、plan header形式も複数ある。既存planを一括正規化してから生成するのではなく、metadata/alias契約とlegacy互換parserを先に作り、全writerを切り替え、shadow比較後にatomic生成へ移す必要がある。
10. focusmapは `temp-cleanup-branch` 上にあり、計7 worktree、regular `CLAUDE.md`、root `plans/`・`docs/ai/plans/`・`docs/plans/` の3候補が併存する。仕事PASS前に計画箱をroot plansへ決め打ちせず、read-only監査だけを先行し、人間がcanonical baseと計画箱を決めてからカナリアを開始する。
11. 現在確認できるactive実repoは仕事とfocusmapの2件である。`projects/active/focusmap-worktrees` はcontainerでrepoとして数えない。paused/archiveはローカル実体がなく、外部SSD未mountの対象を検証済み扱いにしない。active fleet完了と、未mountを含む全履歴repo完了を別マイルストーンにする。

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

### 実行DAG（再設計版）

```text
P0 計画整合（この再計画）
  01 中央契約の証拠整合・11子計画と原子パッケージを確定
        ↓
P1 先行並列
  ├─ 02 S01〜S05: credential人間ゲート → 安全化10path commit → fresh runtime
  ├─ 03 A01〜A05: plan / consumer / path / 副作用のread-only台帳
  ├─ 07 O01/O02: AGENTS・Skill・hook・loop所有権のread-only台帳
  ├─ 08 K01: repo-createの出力契約・fixture設計だけ先行
  └─ 09 F01: focusmapの計画箱・branch/worktreeをread-only監査
        ↓ Gate A: 同じsnapshotで台帳統合・移動候補/非対象を人間確認
P2 制御面と仕事基礎を並列
  ├─ 04 C01〜C04: plan-triage + 仕事AGENTS + handoff verifier
  └─ 10 W01〜W04: metadata/parser → generator → consumer 4レーン → atomic index
        ↓ Gate B: route/index統合検証
P3 仕事カナリア（直列）
  05 E01〜E03: route matrix → 新規plan 1件 → rollback
        ↓
P4 仕事repo完成（部分並列）
  ├─ 06 L01〜L03: 既存plan 1件の正本整理・rollback
  ├─ 07 O03〜O07: 6階層AGENTS/CLAUDE・Skill・hook・旧path所有権
  ├─ 08 K02/K03: repo-create audit/inventory（06/07と非重複pathで並列）
  └─ 08 K04/K05: 06/07完了後にscaffold/audit-allと統合review
        ↓ Gate C: 仕事新規/既存/runtime/rollback/fixture全PASS
        ↓ Review 1: 仕事repoカナリアを独立reviewerが一括評価
P5 実装系カナリア（直列）
  09 F02〜F05: base/計画箱人間決定 → focusmap契約 → E2E → rollback
        ↓ Gate D: coding repoカナリアPASS
P6 fleet
  11 R01〜R03: active実repo監査 → 未mount分類 → Review 2独立最終評価/人間完了
```

### Turso完了後の実装順（Gate T）

Child 02のP1（実データのstaging移行・read-only shadow・R1を含む）はPASSしているが、Tursoを本番経路へ切り替えた状態ではない。したがって、仕事repoの計画導線へ書き込む起点を次の `Gate T` に固定する。D1/Supabaseは切替後もread-only rollback targetとして保持し、削除・停止・本番送信・launchd登録・Worker公開はP2/R2の完了まで行わない。

```text
Gate T（直列・人間承認）
  Turso R2 PASS
  ├─ contacts/messages統合規則と業務時間を決定
  ├─ staging import → shadow read → rollback演習
  ├─ Turso唯一DB／launchd業務時間／Worker時間外Webhookの境界を確認
  └─ D1/Supabase read-only保管・復旧手順を確認
        ↓
Wave A（path分離で並列）
  ├─ C03: 仕事repo AGENTSの二段route + handoff verifier
  ├─ W01: plan metadata/parser契約と同一snapshot台帳
  └─ G0: scripts/shared の Playwright依存を正規化（symlink削除を伴うため別承認）
        ↓ Gate A1: route fixture / parser fixture / dependency test PASS
Wave B（path分離で並列）
  ├─ C04: 仕事repoへのroute統合とPrivate→repo session handoff
  └─ W02: 計画一覧generatorのshadow生成
        ↓ Gate B1: duplicate・broken link・旧path参照が0、atomic切替準備完了
Wave C（W02後に4レーン並列）
  └─ W03A〜W03D: 既存consumerを担当pathごとに移行
        ↓
Wave D（直列）
  W04 atomic index → E01 route matrix → E02 新規plan 1件 → E03 rollback
        ↓ Gate C: 仕事repoの新規/既存/索引/runtime/rollbackを一括確認
        ↓ Review 1（全repo移植・仕事カナリア）
Wave E（条件付き並列）
  ├─ O03〜O06: ownership整理（path別）
  ├─ K02/K03: repo-create audit/inventory（非重複path）
  └─ L01〜L03: 既存plan 1件の正本整理（E03後のみ直列）
        ↓ Gate D: 仕事pilot完了後に人間がlaunchd/hook変更を個別承認
P5/P6
  F02〜F05（focusmap） → R01〜R03（active fleet） → Review 2
```

各waveの完了条件は、(1)開始snapshotと許可path、(2)対象repo最寄りAGENTSの読込証跡、(3)自動テストとfixture結果、(4)rollback手順、(5)未push・未反映状態の5点を揃えることとする。どれか1点でも欠けたら次waveをreadyにしない。Turso R2、Review 1、Review 2は別の評価であり、Turso R2が通っても仕事repoのReview 1を省略しない。

#### Gate Tで人間が決めること

1. contactsは `updated_at` 最新、同時刻はD1優先とするか、messagesはsourceを保持したunionとするかを確定する。
2. 業務時間（暫定案は平日09:00〜18:00 JST）を確定する。確定まではlocal runnerのclaimをdry-runに留める。
3. staging実データimport、shadow read、短期二重書込み、切替、rollback演習を段階ごとに許可する。
4. `scripts/shared/node_modules` の追跡symlink整理、launchd登録、Worker secret設定、LINE送信経路の変更を個別に許可する。

各担当agentは、最初に本program、その後に担当子計画と対象repoの最寄り `AGENTS.md` だけを読む。共通契約を個別promptへ全文コピーせず、「唯一の正本・許可path・人間ゲート・完了条件」を短く渡す。

### 並列化の契約

1. read-only監査は同じsnapshot IDを入力にし、workerは正本を編集しない。統合担当だけが中央referenceへ書く。
2. writerは `1 agent = 1 worktree = 1 allowed-path集合` とし、同一pathを2workerへ渡さない。共有する `program.md`、`計画一覧.md`、各repo root `AGENTS.md` はIntegration担当だけが最終更新する。
3. 依存契約が確定する前に実装を並列化しない。特にplan metadata/parser interfaceはconsumer 4レーンより先に固定する。
4. 各原子パッケージは、実装者とは別のtest-authorが先に受入項目を作る。package中はIntegration担当が証拠を確認し、正式な独立reviewer採点はReview 1とReview 2の2回だけに集約する。reviewerは採点だけを行い、自分で修正しない。
5. package完了報告には、開始snapshot、allowed paths、変更path、test結果、rollback手順、commit hash、未push/未反映状態を含める。証拠が1つ欠ければ次の依存taskをreadyにしない。
6. Private指揮官は横断調整と中央正本だけを所有する。仕事/focusmapへの書込みは、それぞれをrootとする新しい可視sessionへhandoffする。
7. package証拠は各子計画の `実装記録` にIntegration担当だけが追記する。正式評価は `plans/レビュー1-仕事repoカナリア-評価NN.md` と `plans/レビュー2-全体完了-評価NN.md` の2系列だけとし、FAIL時の修正指示も同basenameの `-修正NN.md` にする。同じ評価fileへ複数reviewerが書かない。

### 作業量と暦時間

- Gate 0の人間作業: 1〜2時間。credentialは旧値へ戻さず、問題時は再発行する。
- Gate 0後に仕事repoの新基準が最初に使えるまで: 2〜3稼働日。
- Child 02〜08/10をReview 1・rollback込みで閉じるまで: 4〜7稼働日。
- active 2repo（仕事＋focusmap）を閉じるまで: 6〜9稼働日。ただしfocusmapのcanonical base/worktree整理待ちは暦時間へ別加算する。
- 未mountのpaused/archive: mount後、1repoあたり0.5〜1日を個別加算する。未mountのまま「全履歴repo完了」とは宣言しない。

## 移植原則

1. **中央正本**: 共通契約、Global Skill、Global hook、テンプレはPersonal OS / AIエージェント基盤を正本とし、各repoへ本文コピーしない。
2. **二段ルーティング**: Privateからの依頼は、repo registryで担当repoを決め、次に対象repoの `AGENTS.md` で領域・プロジェクト・計画箱を決める。registryへ領域表を複製しない。
3. **実行contextの切替**: 仕事repo内から始めた依頼はそのまま仕事AGENTSへ従う。Privateから担当repoを解決した依頼は、計画・実装の書込み前に対象repo所有のsession/worktreeへ切り替える。Private側からrepo-local hookの代替実行や本文コピーをしない。
4. **repo-local所有**: 業務領域、コード、manual、repo-local Skill、repo固有hook/loopの実装は所有repoに残す。hookは計画pathを決めず、イベント後処理・安全確認・実行記録だけを担う。
5. **cross-repo symlink禁止**: clone、worktree、別PC、外部SSDで壊れるため、repo境界をまたぐsymlinkは標準にしない。Global Skillの発見はruntime露出へ任せる。
6. **repo固有の計画箱**: 計画pathは常に対象repoの `AGENTS.md` 宣言を正とする。仕事の領域固有計画は `領域/.../計画/`、repo横断計画はroot `plans/`。coding repoもroot `plans/` を自動前提にせず、focusmapのように候補が複数なら人間決定まで停止する。
7. **既存計画優先**: 新規作成前に同じ目的のplanを検索し、存在すれば合流する。日付違い・path違いの重複planを自動生成しない。
8. **strangler移行**: 新しいルーティング入口を先に整え、既存計画は正本性を台帳で判定してから1件ずつconsumerと同じ波で整理する。一括移動・一括改名をしない。
9. **1計画1正本**: registry、一覧、session-boardへ本文や状態を複製しない。`計画一覧.md` はlegacy互換parserで各plan header/bucketから生成するread-only索引とし、Skillは正本plan更新後に再生成するだけにする。parse不能・plan ID重複・broken linkが1件でもあれば部分indexを書かずfail-closedにする。
10. **安全優先**: secret、危険hook、dirty worktree、旧絶対pathを第0ゲートで処理し、PASSまで仕事repoで実装ペインを起動しない。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [x] 01 中央正本とrepo標準契約 … 完了
    並列: 可 ／ レビュー: 既存評価済み（今回の2回には含めない）
    次: 子02の巻込みauto-commitとcredential人間ゲートを解消する
    場所: `plans/01-中央正本とrepo標準契約.md` ／ 依存: ―
- [ ] 02 仕事repo緊急安全化 … 実装中（P1/R1 PASS・P2 mock-only/R2 precheck PASS）
    並列: 可 ／ レビュー: Review 1へ集約
    次: P2 mock-only送信・read-only rollback契約はPASS。実DBへの0002 migration適用、Worker／runner接続、primary切替、Cloudflare deploy、launchd登録、LINE送信は未実施のまま保持し、Gate Tと実環境R2後にのみ仕事repo本番pathへ統合する
    場所: `plans/02-仕事repo緊急安全化.md` ／ 依存: ―
- [x] 03 仕事repo移植台帳 … 完了
    並列: 可（A01〜A04 read-only） ／ レビュー: Review 1へ集約
    次: Gate 0後、Child 04/10のimmutable inputとして台帳を使う
    場所: `plans/03-仕事repo移植台帳.md` ／ 依存: 01
- [ ] 04 仕事repo二段ルーティング導入 … 実装中（C01/C02/C02b/C03 PASS・C04待ち）
    並列: 可（中央/仕事を別worktree） ／ レビュー: Review 1へ集約
    次: C03は専用worktreeで仕事root AGENTSに実装し、独立レビューPASS。Turso Gate T後に、未コミット差分を人間確認して統合し、C04の実AGENTS入力route matrixとhandoff fixtureを実行してReview 1へ証拠を渡す
    場所: `plans/04-仕事repo互換レイヤ導入.md` ／ 依存: 01, 02, 03
- [ ] 10 仕事repo計画索引とconsumer移行 … 実装中（W01/W02 PASS・W03/W04待ち）
    並列: 可（consumer 4レーン） ／ レビュー: Review 1へ集約
    次: W01契約とW02 shadow-only generatorは専用worktreeで独立レビューPASS。manifestの15候補・stable ID・KPI例外・root bucket状態を人間がimmutable inputとして確認後、W03A〜Dをpath別に並列実装し、W04はshadow差分の人間確認後に単独ownerが行う
    場所: `plans/10-仕事repo計画索引とconsumer移行.md` ／ 依存: 02, 03
- [ ] 05 仕事repo新規計画パイロット … 計画
    並列: 不可 ／ レビュー: Review 1へ集約
    次: Wave DでW04 atomic index後にroute matrix→新規plan 1件→rollbackを直列実施し、Gate CとReview 1の証拠を揃える
    場所: `plans/05-仕事repo新規計画パイロット.md` ／ 依存: 04, 10
- [ ] 06 仕事repo既存計画の正本整理 … 計画
    並列: 不可 ／ レビュー: Review 1へ集約
    次: 人間が選んだ既存計画1件の正本・consumer・索引を同時整理する
    場所: `plans/06-仕事repo旧計画段階移行.md` ／ 依存: 05
- [ ] 07 仕事repo導線所有権整理 … 計画
    並列: 可（監査先行、書込みはpath別） ／ レビュー: Review 1へ集約
    次: Child 02と並行してread-only監査し、仕事pilot後にsymlink/hook/pathを1単位ずつ整える
    場所: `plans/07-仕事repo導線所有権整理.md` ／ 依存: 01（監査）, 02, 05（書込み）
- [ ] 08 repo-create移植キット … 実装中（K01完了）
    並列: 可（仕様設計を先行） ／ レビュー: Review 1へ集約
    次: K01契約/15 fixtureを凍結し、仕事pilot後にK02 audit-repoとK03 inventoryを非重複pathで実装する
    場所: `plans/08-repo-create移植キット.md` ／ 依存: 01（K01）, 05（K02/K03）, 06/07（K04/K05）
- [ ] 09 実装系カナリア … 計画
    並列: 可（F01 read-onlyのみ） ／ レビュー: Review 2へ集約
    次: focusmapのcanonical baseと計画箱を人間決定後、coding repoカナリアを実行する
    場所: `plans/09-実装系カナリアと全repo展開.md` ／ 依存: 01（F01）, 08（F02〜F05）
- [ ] 11 全repo監査と段階展開 … 計画
    並列: 可（repo単位・人間承認後） ／ レビュー: Review 2
    次: active実repoを監査し、未mount/paused/archiveを別マイルストーンで分類する
    場所: `plans/11-全repo監査と段階展開.md` ／ 依存: 09

## 人間ゲート

1. credentialの失効・再発行、Git履歴対応方針。LINE tokenはroot非追跡 `.env` の `LINE_CHANNEL_ACCESS_TOKEN` 1値を正とし、2026-07-14に値非表示で更新・検証済みである。Claude公式MCP起動時だけ別名へaliasする。DB統一・local-firstの方針はTursoを唯一の正本とすることで確定した。通常業務はlaunchd、WorkerはWebhook常時受付と業務時間外のMac非依存処理へ限定し、ローカル資料を外部へuploadする設計は採用しない。contacts/messagesの統合規則とstaging実データimport／shadow readはP1で確定・PASSした。残るDB判断はP2の業務時間明示値、primary切替、実行経路の有効化、R2とrollback確認である。Supabase access回復を選ぶ場合だけ、新Secret key移行を別scopeで扱う。
2. tracked設定・hook・launchd登録の変更。
3. 旧計画の移動・改名・旧pathポインタ化。
4. `CLAUDE.md` / `AGENTS.md` のsymlink向き変更。
5. `planning → active` 昇格、明示pathだけのcheckpoint commit、main反映、push。
6. 仕事repoパイロットの合否と、focusmap以降へ進む判断。
7. Globalの「全repo root plans」前提を、repo `AGENTS.md` が計画箱を宣言する契約へ変更する判断。
8. Private sessionから対象repo sessionへの引継ぎ完了と、調整役を残す場合の2行併存。
9. sessionのfinish、planのdone、成果物archiveを別判断として実行すること。
10. 旧Stop hookが作成した `f4b78f49`・`fb6f5047` は後続の正当な仕事commitとともに既に `origin/master` の祖先である。reset/rewriteは既定にせず、credential失効後に履歴保持を推奨案として人間判断を記録する。変更前から開いている仕事sessionは終了・再起動し、旧hookの再発火を防ぐ。
11. plan metadata/安定ID、生成 `計画一覧.md` へのatomic切替、focusmapのcanonical baseと計画箱。
12. focusmapで実行するtest/lint/build/diff/browserコマンド。同repoのAGENTSが自動検証を禁止しているため、許可されたコマンドだけを実行する。
13. Child01評価ファイル `評価01.md` を規約名へ改名するか。renameは明示承認まで行わず、現行ファイルを唯一の評価証拠として扱う。

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
- [ ] plan-indexが複数header形式、root bucket、欠損metadata、plan ID重複、broken linkをfixtureで扱い、失敗時に部分indexを書かず、2回生成がbyte-identicalである。
- [ ] hookは担当repo・計画pathを決めず、対象repo contextで安全な後処理・実行記録だけを行う。
- [ ] 仕事repoで領域固有の新規計画1件と既存計画1件が、Claude/Codex・plan-ops・session-boardを通して完了し、repo-local/global hookが各1回だけ発火し、wave単位のrollbackを確認している。
- [ ] sessionのfinish、root planのdone、領域planの完了表現、成果物archiveが混同されていない。
- [ ] 仕事repoの `領域/`、業務manual、repo-local Skill、稼働中loopが不要に移動・複製されていない。
- [ ] `repo-create` の監査・scaffoldが既定dry-run、secret値非表示、冪等、既存ファイル非上書きである。
- [ ] focusmapのcanonical base・計画箱・許可testが人間決定され、実装系カナリアがrollback込みでPASSしている。
- [ ] active実repoは導入済み・保留・対象外、未mount/paused/archiveは別マイルストーンとして理由と再開条件が一意に記録されている。
- [ ] Review 1とReview 2の最終評価mdが全PASSし、人間がactive fleet完了と全履歴repo完了を別々に確認している。

## 関連

- 仕事repo移植台帳: `references/仕事repo移植台帳.md`
- 統合レビュー仕様: `references/統合レビュー仕様.md`
- Review 1統合テストパック: `references/レビュー1統合テストパック.md`
- Review 2統合テストパック: `references/レビュー2統合テストパック.md`
- 仕事repo handoff payload: `references/仕事repo-handoff-payload.yaml`
- 先行発案: `../../paused/2026-07-02-repo構造の標準化構想/plan.md`
- 先行手順: `../../paused/2026-07-08-計画実行フロー統一/plans/02-計画置き場の全リポ統一.md`
- 共通契約: `../../../../../../AIエージェント基盤/GLOBAL_AGENTS.md` §6-7
- 計画規約: `../../../../AGENTS.md`
- repo索引: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/repo概要.md`
- 仕事repo: `/Users/kitamuranaohiro/Private/projects/active/仕事`
- 第2カナリア候補: `/Users/kitamuranaohiro/Private/projects/active/focusmap`
