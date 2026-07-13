親計画: ../program.md ／ 分類: skill ／ 種別: 既存改善 ／ 規模: フル
並列: 不可 ／ レビュー: 都度

# repo-create移植キット

## 目的

仕事repoで実証した移植判断を `repo-create` の既存改善workflowへ落とし、次repoからread-only監査と最小scaffoldを反復可能にする。

## 現状

`repo-create` は既存repo改善、AGENTS/CLAUDE、Git安全、repo種別を扱うが、repo種別ごとの計画箱宣言、既存計画、中央参照、program lint、横断auditはまだ扱わない。

## 方針

1. 新しいGlobal Skillを増やさず、`repo-create` のcriteria・workflow・scriptsへ統合する。
2. `audit-repo` はAGENTS/CLAUDE、計画箱宣言、Privateからの引継ぎ、必要なroot bucket、中央参照、既存計画候補、program lint、dirty/worktree、cross-repo symlink、危険hook、session-board/runtime登録をread-only検査する。文書だけで稼働状態を判定しない。
3. `inventory-legacy-plans` は計画とconsumer候補を領域固有/repo横断に分類するが、移行判断・移動を自動化しない。
4. `scaffold-repo --dry-run|--apply` はrepo種別に応じて、欠けた計画箱、必要なbucket・`.gitkeep`、薄いAGENTSの計画ルーティング導線だけを作る。既定はdry-run。
5. `audit-all` はrepo registryから担当repo候補を引き、各repo `AGENTS.md` の計画箱宣言と `projects/{active,paused,archive}` の実体を突き合わせる。registryへ領域表を複製せず、worktree重複と未mountのpaused repoを区別する。
6. plan/programの生成・lintは既存 `plan-ops` を明示pathで呼ぶ。`bucketctl` はroot bucket計画に限定し、領域planの状態操作は仕事repo契約へ従う。別parserを作らない。
7. secret検出は値を出力せず、件数・path・判定だけを返す。
8. applyでも既存ファイル上書き、legacy移動、削除、commit、push、hook/launchd登録をしない。

## 完了条件（レビュー項目）

- [ ] `repo-create` の既存改善workflowから `audit-repo`、`inventory-legacy-plans`、`scaffold-repo` へ迷わず到達できる。
- [ ] `audit-repo` がAGENTS/CLAUDE、計画箱宣言、必要bucket、中央参照、program lint、dirty/worktree、危険hookを値なしで報告する。
- [ ] `audit-repo` が、Private起点の書込み前に対象repo contextへ切り替える契約と、hookが計画ルーティングを持たないことを検査する。
- [ ] `scaffold-repo` は既定dry-runで、2回目のapplyが変更0件となる。
- [ ] 既存ファイル上書き、legacy移動、削除、commit、push、hook/launchd登録を行うコードpathがない。
- [ ] plan/program解析が `plan-ops` を再利用し、root bucketと領域planの操作境界を別実装で重複させていない。
- [ ] Private依頼のfixtureで、registry→repo AGENTS→既存plan検索→計画箱の順が再現され、registryに領域表が複製されない。
- [ ] 仕事repofixtureで既知の競合を検出し、安全化後はPASSする回帰テストがある。
- [ ] secret fixtureの値が標準出力・ログ・評価mdに現れない。
- [ ] `audit-all` が未mount repoをdeferred、worktreeを重複なしで扱う。
- [ ] skill-creator-customの評価・修正サイクルを通り、最終評価が全PASSである。
