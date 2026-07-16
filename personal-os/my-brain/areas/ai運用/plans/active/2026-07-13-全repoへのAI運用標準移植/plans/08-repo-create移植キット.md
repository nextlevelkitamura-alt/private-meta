親計画: ../program.md ／ 分類: skill ／ 種別: 既存改善 ／ 規模: フル
並列: 可（K01は依存01、K02/K03は依存05、K04/K05は依存06/07） ／ レビュー: Review 1へ集約

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

## 実行パッケージ

1. **K01 出力契約/fixture**: Child 02と並行し、仕事/focusmapの既知差分、worktree container、未mountを入力fixtureとして設計する。まだ実repoへapplyしない。
2. **K02 audit-repo**: AGENTS/CLAUDE、計画箱、既存plan、dirty/worktree、危険hook、handoff契約を値なしで監査する。
3. **K03 inventory-legacy-plans**: 領域/root/仕様/履歴を分類し、移動判断は出力しない。
4. **K04 scaffold-repo**: dry-run既定、既存上書き0、2回目apply変更0、削除/移動/commit/push/登録0を保証する。
5. **K05 audit-all/Skill review**: canonical repo identityでcontainer重複と未mountを区別し、skill-creator-customの評価・修正サイクルを通す。

## 実装順・rollback

K01だけChild 01後に先行可。Child 05 PASS後、K02とK03は非重複pathで並列可。K04/K05はChild 06/07完了後に直列実行する。各package commitをrevertし、実repo applyはChild 09/11の人間gateまで行わない。

## 実装記録

### K01 出力契約 / fixture（2026-07-13）

- Terra実装者は `repo-create` 内の許可3pathだけを編集し、Integration担当が対になる白背景 `SKILL.html` を追加した。stage・commit・実repo applyは0件。
- `references/migration-contract.md` にcanonical identity、linked worktree dedupe、worktree container、未mount、計画箱fail-closed、決定的JSON envelope、exit優先 `4 > 3 > 2 > 0`、secret値出力0を固定した。
- `scripts/fixtures/migration-cases.json` に仕事Gate 0前後、focusmap、worktree重複、未mount、計画箱未宣言/曖昧、legacy分類、CLAUDE形状、secret redaction、scaffold冪等を含む合成fixture 15件を作った。実credential値・実repo snapshot本文は含めていない。
- 機械検証はJSON parse、15 ID一意、全case `secret_values_emitted=0`、配列sort、contract相対path、exit `0/2/3` とguard `4`、SKILL 59行、diff-checkをPASSした。
- K01は後続K02〜K05の入力契約として利用可能。Child 08全体と正式採点は未完で、Review 1へ集約する。

## 許可path manifest

- 共通root: `personal-os/AIエージェント基盤/skills/repo-create/`。この外へ書かない。
- K01: `references/migration-contract.md`、`scripts/fixtures/**`、参照導線のための `SKILL.md`、人間説明の `SKILL.html`。既存workflow・実行scriptは編集しない。
- K02: `scripts/audit-repo*`、`scripts/tests/audit-repo/**`。
- K03: `scripts/inventory-legacy-plans*`、`scripts/tests/inventory-legacy-plans/**`。
- K04: `scripts/scaffold-repo*`、`scripts/tests/scaffold-repo/**`。
- K05: `scripts/audit-all*`、`scripts/tests/integration/**`、`SKILL.md`、`SKILL.html`、`agents/openai.yaml`、承認された `workflows/**` と `references/**`。K01〜K04の実装pathはIntegration修正時だけ触る。
- package証拠は本Childの `実装記録` にIntegration担当が集約し、Skill rootへ計画状態を複製しない。正式採点と修正指示はReview 1の1系列だけに置く。

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
- [ ] skill-creator-customの構成ゲート・SKILL.html・runtime露出確認を通り、Review 1で全PASSである。
