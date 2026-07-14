分類: loop ／ 種別: 統合整理 ／ 形態: program ／ 規模: フル ／ 優先: ◎

# loopレジストリTurso正本化 program

## 目的

Macで動く自作loopの定義・内部処理・希望状態・実行履歴をTursoへ一元化し、Focusmapで
Personal OS / 仕事のloopを確認できるようにする。AIは型付きMCPから取得・更新し、一覧Markdownを
手編集しない。実装コードはGit、実機状態はlaunchd、secretはKeychainを正とし、同じ事実を二重管理しない。

## 現状

- 現役7loopの正本一覧は `AIエージェント基盤/loops-registry/実行loop一覧.md`、派生表示は同名HTML。
- global 4本は基盤repo、仕事3本は仕事repoが実装を所有する。launchdは全7本loaded。
- HTMLは内部処理55step、周期、失敗時、記録先、launchctl snapshotを表示できるが、状態は再生成時点。
- Focusmapには既存Turso監視層、agent token認証、差分cursor、Mac heartbeat、可視中pollingがある。
- Focusmap Agentは現状launchd常駐ではなくMacアプリの子process。Agent停止中はofflineと表示し、常時同期済みと仮定しない。
- Focusmap MCPは旧Supabase service-role直結構造のため、loop registryへ流用すると権限過大になる。
- Focusmap本体は現在 `temp-cleanup-branch` で未追跡差分があり、別worktreeに `feat/sessions-dashboard` が存在する。
  Turso client周辺の競合を避けるため、実装開始前にbaseと既存worktreeの統合順を人間が決める必要がある。

## 正本境界

1. Turso: loop定義、内部step、希望enabled/schedule、definition revision、実行履歴、audit、apply要求。
2. Git: script、plist生成器、テスト、API/MCP/UI実装。生成plistはTurso revision/hashを埋め込む。
3. macOS launchd: loaded / waiting / running / exit code / run countの実機事実。
4. ローカルまたは既存外部先: 生ログ。Tursoには短いsummary、error code、log参照だけを置く。
5. Keychain / 既存secret保管: token、credential。DB・MCP・Markdown・ログへ値を出さない。
6. `loops-registry/AGENTS.md`: 内容をコピーせず、MCP取得・更新・人間ゲート・障害時の禁止事項だけを持つ入口。

## 全体アーキテクチャ

```text
AI ──型付きMCP──> Focusmap v1 API ──> Turso loop registry
人間 ─Focusmap UI─┘                         │ desired revision / audit / outbox
                                             ↓
Focusmap Mac Agent <──agent API── claim / observation / run event
        │
        ├─ launchctlを観測
        ├─ 承認済みrevisionだけplistへ適用
        ├─ offline時はJSONL spool
        └─ script / plist / testsはGit側を参照
```

## 実装順と並列条件

1. 01でschema、状態語彙、API response、MCP引数、人間ゲート、fixtureを固定する。ここは全レーンの直列クリティカルパス。
2. 01の契約レビューPASS後、02 Mac同期と03 UIを別サブエージェントで並列実装する。共通型を各担当が再定義しない。
3. 02は最初に観測・shadow送信だけを行い、launchd設定は変えない。03はfixture/read APIでread-only UIを完成させる。
4. 04が7loop import、実データ照合、canary apply、全体cutover、旧一覧廃止を順番に行う。
5. 各実装担当とは別のreviewerが評価MDを作り、最大2回の差し戻し後に人間ゲートへ渡す。

## 子計画マップ

- [ ] 01 共通契約とDB・API・MCP … 実装（静的レビューPASS・実行検証待ち）
    次: 01契約commit f0361b0dを基準に02 Mac同期と03 UIを別worktreeで並列実装する
    参照: focusmap@f0361b0d
    場所: plans/01-共通契約とDB・API・MCP.md ／ 依存: ―
- [ ] 02 Mac同期と既存loop移行 … 実装（静的レビューPASS・実行検証待ち）
    次: 01〜03統合branchでMac Agent・API・import preflightの実行検証許可を待つ
    参照: focusmap@d281bec9
    場所: plans/02-Mac同期と既存loop移行.md ／ 依存: 01
- [ ] 03 Focusmap一覧UI … 実装（静的レビューPASS・実行検証待ち）
    次: 01〜03統合branchでtest・lint・build・Browser確認の人間許可を待つ
    参照: focusmap@837a9bdc
    場所: plans/03-Focusmap一覧UI.md ／ 依存: 01
- [ ] 04 統合・切替・旧一覧廃止 … 実装（統合・専用検証PASS・Browser確認待ち）
    次: 3001のPersonal OS説明サーバーを止める人間承認後にFocusmap UIをBrowser確認し、その後Turso migrationのdry-run判断へ進む
    参照: focusmap@d3f29a5c
    場所: plans/04-統合・切替・旧一覧廃止.md ／ 依存: 01,02,03
- [ ] 05 repo-local loop標準とLoop Creator … 実装（repo-local標準・Skill導入完了／Turso連携は04へ）
    次: 2026-07-14のread-only baselineを参照し、Turso source reference・7loop import・切替は04の人間ゲート後に進める
    場所: plans/05-repo-local-loop標準とLoop Creator.md ／ 依存: 01,02

## 人間ゲート

1. このprogramと共通契約の承認。
2. Focusmap実装branch/baseと既存 `feat/sessions-dashboard` worktreeの統合順。
3. Focusmap AGENTSが通常禁止しているtest/lint/build/Browser確認を、このprogramの検証時に実行してよいか。
4. Turso migration適用と現行7loop初期import。
5. 定義更新APIのwrite有効化。
6. canary 1本のlaunchd適用、続いて残り6本の適用。
7. push / Cloud Run本番反映。
8. 旧 `実行loop一覧.md` / HTML / verify.py / 個別定義Markdownの削除。

## 完了条件（レビュー項目）

- [ ] `plans/01` のschemaで7loopが一意に表現でき、内部55step・interval/calendar・RunAtLoad・KeepAlive・retryを欠落なく持てる。
- [ ] Focusmap APIだけがTursoへ書き、MCP・ブラウザ・Mac AgentへTurso tokenやservice roleを露出しない。
- [ ] stale revisionは409、mutation/event再送は冪等で、definition・audit・outboxが中途半端に分離しない。
- [ ] Mac offlineまたはTurso障害でも現行launchdは停止せず、復旧後にrun/observationが再送される。
- [ ] Focusmap Agentが停止している間はoffline/staleと表示され、古い観測値を「現在正常」と誤表示しない。
- [ ] Focusmap `/dashboard/settings/loops` でPersonal OS 4本・仕事3本を表示し、待機中を停止と誤判定しない。
- [ ] 内部処理、周期、retry、記録先、latest run、definition/applied revision、drift、Mac接続をPCとモバイルで確認できる。
- [ ] AIが `get_contract` を先に読み、list/get/runs/drift/update/request_applyを型付きMCP経由で実行できる。
- [ ] 周期変更・停止・再開はMCP単独でapproveできず、人間承認済みoutboxだけをMac Agentがclaimできる。
- [ ] 現行7loopをrevision=1へimportし、MD・plist・launchctlと件数、label、schedule、step順、実装参照が一致する。
- [ ] canaryとrollbackを実証後に全7本が同期済みとなり、旧一覧を削除してもFocusmap/MCPから同じ情報を取得できる。
- [ ] secret、token、credential、生ログ、候補者などの個人情報がTurso・MCP response・Git差分へ入らない。
- [ ] `docs/CONTEXT.md` と `loops-registry/AGENTS.md` が最終境界を示し、同じ契約本文をコピーしていない。
- [ ] 各子計画の最終評価MDが全PASSで、人間が旧一覧廃止と本番反映を承認している。

## 構成カード

- 規模: フル。複数repo、DB migration、API/MCP、Mac Agent、UI、launchd、人間ゲートを含む。
- 指揮: このprogramの単一指揮官が共通契約・依存・評価を管理する。
- 実装担当: 01 DB/API/MCP、02 Mac同期、03 UI、04 Integrationを分離する。
- レビュー: 各担当と異なるCodex xhigh系reviewer。最大2回。
- 起動形: 計画レビュー中は計画・監督を含む3役。契約確定後の各子は実装＋レビューの2役。
- モデル: 実装は既定sonnet5。01と04は他レーンが待つクリティカルパスのためopus4.8 fast候補。レビューはcodex xhighから下げない。
- 実装開始: このprogramを人間が承認するまで未起動。

## 関連

- 先行計画: `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-12-loopレジストリ統治設計/plan.md`
- 現行registry: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/`
- Focusmap: `/Users/kitamuranaohiro/Private/projects/active/focusmap/`
- 仕事repo: `/Users/kitamuranaohiro/Private/projects/active/仕事/`
