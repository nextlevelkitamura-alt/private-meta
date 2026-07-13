親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル
並列: 不可 ／ レビュー: 都度

# 仕事repo二段ルーティング導入

## 目的

既存計画を動かさず、Privateからの依頼を担当repoへ振り分け、仕事repo内では領域・プロジェクトに合う計画箱へ一意に向ける最小接続を入れる。

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
5. `計画一覧.md` はpathを維持したまま、領域planとroot planのheaderから作る生成・read-only索引へ降格する。各行は正本planへのlinkを持ち、一覧自体へ状態を書かない。
6. 一覧を読む既存Skillは互換維持しつつ、書込み側を「正本plan更新→一覧再生成」へ同一waveで切り替える。全writer切替前は一覧を廃盤化せず、旧手動運用と生成運用を同時に走らせない。
7. `plan-triage` は規模・実行経路・起動形・modelを判定し、`plan-ops` は解決済みの計画pathへ雛形生成・lintする。root plan専用のbucket操作を領域planへ誤適用しない。
8. hookは計画pathの解決・plan作成・一覧更新を担わない。対象repo contextでの安全な後処理とsession-board等の実行記録だけに限定し、Private側へ仕事hookをコピーしない。
9. `plan-triage`、`plan-ops`、session-boardはGlobal runtimeから使い、Skill本文・テンプレを仕事repoへコピーしない。
10. 候補者DB、外部送信、launchd、dispatcher、業務manual、既存 `領域/` とroot `plans/` の配置は変更しない。
11. 二段ルーティングと一覧互換レイヤをwave単位で戻せる差分に分け、適用前に対象pathだけのdiffを提示する。
12. Private→仕事repo引継ぎpayloadは、canonical repo path、対象plan、worktree cwd、許可path、禁止事項、開始時Git snapshotを必須にする。session IDの移管・既存行のreparentは行わない。
13. 新しい仕事repo sessionの登録とAGENTS読了を確認してからPrivate行をfinishする。Privateを調整役として残す時だけ、役割と終了責任を明示した2行併存を許す。
14. Global `plan-triage` のrepo-local作業をroot `plans/` 固定から二段ルーティングへ直し、既存Skill改善として構造・人間向けHTML・runtime露出を `skill-creator-custom` の手順で同じwaveに検証する。

## 完了条件（レビュー項目）

- [ ] Privateでの依頼から、repo registry→仕事 `AGENTS.md`→既存plan検索→計画箱の順を再現できる。
- [ ] 仕事repo内起点はregistryを迂回し、Private起点は仕事repo所有のsession/worktreeへ切り替わり、両方が同じplan正本へ合流する。
- [ ] 仕事 `AGENTS.md` だけで、領域固有計画とrepo横断計画の作成先・正本・停止条件を判断できる。
- [ ] 領域固有の新規計画が `領域/{ドメイン}/{プロジェクト}/計画/plan.md` に作られ、root plansへ重複生成されない。
- [ ] repo横断の新規計画だけがroot `plans/<bucket>/` に作られ、`領域/` 内へ重複生成されない。
- [ ] `計画一覧.md` のpathは維持され、全行が正本planへのlinkを持つ生成・read-only索引になっている。
- [ ] `task`・`eod`・`review`・`business-planning`・`repo-eval` は一覧へ書かず、「plan更新→一覧再生成」を実行する。
- [ ] 旧手動一覧と生成一覧が同時運用されず、生成器停止時もplan正本が失われない。
- [ ] `new-plan.sh` が明示された計画pathへdry-runでき、`bucketctl.sh` はroot planにだけ適用される。
- [ ] `plan-triage` がrepo-local計画をroot `plans/` へ固定せず、対象repo `AGENTS.md` が宣言する箱と既存plan検索を使う。
- [ ] Private側のhookに仕事repo固有処理がコピーされず、仕事repo側のhookも計画ルーティングを行わない。
- [ ] 引継ぎpayloadのcanonical repo・plan参照・worktree cwd・許可path・開始時snapshotが一意である。
- [ ] 新しい仕事repo sessionの開始確認後にPrivate行がfinishされ、意図しない2行併存や孤児行がない。
- [ ] 外部サービス、DB、launchd、稼働loop、業務manualのdiffが0である。
- [ ] 対象commitのrevertで互換レイヤだけを元に戻せる。
