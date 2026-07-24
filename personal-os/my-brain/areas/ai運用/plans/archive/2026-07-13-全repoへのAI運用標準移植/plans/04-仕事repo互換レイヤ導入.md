親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル
並列: 可（中央/仕事を別worktree） ／ レビュー: Review 1へ集約

# 仕事repo二段ルーティング導入

## 目的

既存計画と索引を動かさず、Privateからの依頼を担当repoへ振り分け、仕事repo内では領域・プロジェクトに合う計画箱へ一意に向ける最小接続を入れる。計画索引とconsumer移行はChild 10が所有する。

## 現状

1. root `plans/planning|active|paused|done` と `領域/.../計画/plan.md` は用途が違うが、どの依頼をどちらへ置くかが明文化されていない。
2. Global `plan-triage` / `plan-ops` への薄い接続はあるが、pathと責務が曖昧である。
3. `task`、`eod`、`review`、`business-planning`、`repo-eval` 等が `計画一覧.md` を読み書きし、そこから領域planを解決する。legacy計画や一覧を即時一括移動・廃止すると業務Skillが壊れる。
4. Private workspaceで仕事repo配下を直接編集すると、仕事repoをsession rootにした時と同じrepo-local AGENTS・Skill・hookが適用される保証がない。

## 方針

1. Private入口では `repo-registry/repo概要.md` から担当repoだけを決める。仕事の領域表・プロジェクト表・計画状態はregistryへ複製しない。
2. 仕事repo内から始まった依頼はregistryを経由せず、最寄りの仕事 `AGENTS.md` から計画ルーティングを開始する。Privateから始まった依頼は、担当repo解決後に仕事repo所有のsession/worktreeへ引き継いでから書込みを行う。
3. 仕事root `AGENTS.md` に「計画ルーティング」と「Privateからの引継ぎ」節を置き、領域固有の依頼は `領域/{ドメイン}/{プロジェクト}/計画/plan.md`、複数領域・repo基盤の依頼はroot `plans/<bucket>/` と宣言する。
4. 作成前に対象repo内の既存planを目的・対象領域・関連pathで検索し、一致すれば既存planへ合流する。不一致または正本不明なら新規作成せず人間へ確認する。
5. `計画一覧.md` のparser・生成・writer切替はChild 10へ分離する。本Childは計画解決結果としてcanonical plan path、plan類型、停止理由だけを返し、一覧の実装を持たない。
6. Child 10とのinterfaceは、計画作成前の既存plan検索と解決済みplan pathだけに限定し、plan metadata parserを二重実装しない。
7. `plan-triage` は規模・実行経路・起動形・modelを判定し、`plan-ops` は解決済みの計画pathへ雛形生成・lintする。root plan専用のbucket操作を領域planへ誤適用しない。
8. hookは計画pathの解決・plan作成・一覧更新を担わない。対象repo contextでの安全な後処理とsession-board等の実行記録だけに限定し、Private側へ仕事hookをコピーしない。
9. `plan-triage`、`plan-ops`、session-boardはGlobal runtimeから使い、Skill本文・テンプレを仕事repoへコピーしない。
10. 候補者DB、外部送信、launchd、dispatcher、業務manual、既存 `領域/` とroot `plans/` の配置は変更しない。
11. 二段ルーティングと一覧互換レイヤをwave単位で戻せる差分に分け、適用前に対象pathだけのdiffを提示する。
12. Private→仕事repo引継ぎpayloadは、canonical repo path、対象plan、worktree cwd、許可path、禁止事項、開始時Git snapshotを必須にする。session IDの移管・既存行のreparentは行わない。
13. 新しい仕事repo sessionの登録とAGENTS読了を確認してからPrivate行をfinishする。Privateを調整役として残す時だけ、役割と終了責任を明示した2行併存を許す。
14. Global `plan-triage` のrepo-local作業をroot `plans/` 固定から二段ルーティングへ直し、既存Skill改善として構造・人間向けHTML・runtime露出を `skill-creator-custom` の手順で同じwaveに検証する。

## 実行パッケージ

1. **C01 route契約**: registry→repo AGENTS→既存plan→宣言箱、fail-closed条件、Child 10への出力schemaを固定する。
2. **C02 Global lane**: `AIエージェント基盤/skills/plan-triage/**` と承認されたSkill索引だけを所有し、root plans固定を撤去する。
3. **C02b Central caller lane**: `inbox-triage` が重複保持する旧root plans固定・曖昧時続行を撤去し、route判断を `plan-triage.route/v1` へ完全委譲する。Skill本文と白背景HTMLを同じ変更単位で更新する。
4. **C03 Work lane**: Gate 0 commit後の仕事 `AGENTS.md` 計画ルーティング節だけを所有し、領域固有/root横断/曖昧停止/session handoffを宣言する。
5. **C04 Integration**: 仕事領域plan、仕事root plan、focusmap宣言box、既存plan合流、箱不明停止のroute matrixとhandoff payload fixtureをIntegration担当が検証し、Review 1へ証拠を渡す。

## 許可path・テスト・rollback

- C02とC03は別repo・別session・別worktree。`program.md` はIntegration担当だけが更新する。
- C02の許可pathは `personal-os/AIエージェント基盤/skills/plan-triage/**` とGlobal Skill catalogの `plan-triage` blockだけ。C02bは `personal-os/AIエージェント基盤/skills/inbox-triage/SKILL.md`、同階層 `SKILL.html`、Global Skill catalogの `inbox-triage` blockだけ。C03は仕事repo root `AGENTS.md` だけを所有する。
- C04はproduction writerを持たず、C02配下の `tests/**` と使い捨てfixture repoでroute matrixを実行する。結果は本Childの `実装記録` にIntegration担当だけが追記し、Review 1の入力にする。
- session-board正本はChild 01で契約実装済みのため、現行差分監査→不足fixture追加を既定とし、本文再実装はしない。
- Global Skill sourceのmain反映はruntimeへ即影響し得るため、人間gate後にmergeし、fresh sessionで検証する。各repoのcommit revertで個別に戻す。

## 完了条件（レビュー項目）

- [ ] Privateでの依頼から、repo registry→仕事 `AGENTS.md`→既存plan検索→計画箱の順を再現できる。
- [ ] 仕事repo内起点はregistryを迂回し、Private起点は仕事repo所有のsession/worktreeへ切り替わり、両方が同じplan正本へ合流する。
- [ ] 仕事 `AGENTS.md` だけで、領域固有計画とrepo横断計画の作成先・正本・停止条件を判断できる。
- [ ] 領域固有の新規計画が `領域/{ドメイン}/{プロジェクト}/計画/plan.md` に作られ、root plansへ重複生成されない。
- [ ] repo横断の新規計画だけがroot `plans/<bucket>/` に作られ、`領域/` 内へ重複生成されない。
- [ ] route出力がChild 10のparserを再実装せず、canonical plan path・plan類型・停止理由だけを一意に返す。
- [ ] `new-plan.sh` が解決済みの計画pathへdry-runでき、`bucketctl.sh` はroot planにだけ適用される。
- [ ] `plan-triage` がrepo-local計画をroot `plans/` へ固定せず、対象repo `AGENTS.md` が宣言する箱と既存plan検索を使う。
- [ ] Private側のhookに仕事repo固有処理がコピーされず、仕事repo側のhookも計画ルーティングを行わない。
- [ ] 引継ぎpayloadのcanonical repo・plan参照・worktree cwd・許可path・開始時snapshotが一意である。
- [ ] 新しい仕事repo sessionの開始確認後にPrivate行がfinishされ、意図しない2行併存や孤児行がない。
- [ ] 外部サービス、DB、launchd、稼働loop、業務manualのdiffが0である。
- [ ] 対象commitのrevertで互換レイヤだけを元に戻せる。

## 実装記録

### 2026-07-14 C01/C02

1. `plan-triage` を46行のrouterへ縮退し、実行手順を `workflows/triage.md`、唯一のroute契約を `references/route-contract.md` へ分離した。
2. repo内起点はregistryを読まず、Private/headless起点だけがregistryで担当repoを決める。以後は最寄りAGENTS→既存plan→宣言箱の順とし、未宣言・同順位複数・正本不明はexit 3、書込み0件にした。
3. `plan-triage.route/v1` とhandoff必須6fieldを固定し、linked worktreeはcanonical repoと同じGit common-dirを持つ場合だけ許可した。Child 10のheader・状態・ID・alias parserは再実装していない。
4. work既存plan、Private→work領域plan、work root plan、focusmap宣言box、箱欠損、箱競合、既存plan競合の7 fixtureを追加した。handoffは正常1件と必須6field各欠損・別Git common-dir・snapshot不一致の8変異テストを実行した。
5. `SKILL.html` を固定ライト配色で追加し、Global Skill catalogを更新した。`~/.codex`、`~/.claude`、`~/.agents` の3露出は同じ中央正本へのdirect symlinkであることを確認した。
6. Terra test-authorがPTI-01〜15を作成し、Integration担当がroute fixture、JSON構文、SKILL行数、相対参照、白背景静的検査、runtime露出、`git diff --check` を実行してPASSした。これは正式Review 1には数えない。
7. ローカル `file://` の実画面確認はin-app BrowserのURL安全ポリシーで拒否された。別ブラウザで迂回せず、白背景固定・dark切替0の静的検査を証拠とした。
8. C02後の横断scanで `inbox-triage` が旧root plans自動作成と曖昧時続行を独自保持していることを検出した。新契約と矛盾するため、Gate B前のC02bへ追加し、解消前はChild 04完了にしない。

### 2026-07-14 C02b

1. Terra read-only監査で、旧Skillのroot plans自動作成、曖昧時続行、Private側直接writer、dark固定HTMLを行番号付きで確定した。これは正式Review 1には数えない。
2. `inbox-triage` を45行のrouterへ縮退し、repo・領域・検索範囲・計画箱の判断を `plan-triage.route/v1` へ完全委譲した。
3. `stop` はplan・デイリー・マーカーを含む書込み0件、`join_existing` は新規作成0件、`create_new + handoff_required` は新しい対象repo所有sessionの完了報告までplan・成功マーカー0件とした。
4. 白背景固定の `SKILL.html` へ再生成し、暗色切替0、SKILL行数上限、旧hard-coded path 0、7 route fixture、handoff異常8変異、`git diff --check` をIntegration検査でPASSした。
