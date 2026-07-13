親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: ライト
並列: 不可 ／ レビュー: 都度

# 仕事repo新規計画パイロット

## 目的

Privateから依頼する外部書込みのない整備系計画1件で、repo選択から仕事repo内の領域・プロジェクト・計画箱までが解決され、Claude/Codex・plan-ops・session-board・レビューを通して完了まで回ることを実証する。

## 現状

互換レイヤだけでは、runtimeごとのSkill発見、hook合成、計画昇格、レビュー文書、終了記録が実運用で1回ずつ動く保証にならない。

## 方針

1. 人間が、候補者データ、外部送信、DB、launchd、本番設定に触れない領域固有の文書整備依頼1件を選ぶ。既存plan・active owner・並行作業があれば新規作成せず合流または別候補にする。
2. 同じ依頼を、(A) 仕事repoをsession rootにした入口と、(B) Private入口→repo registry→仕事repo所有session/worktreeへの引継ぎ、の2経路でdry-runし、同じ既存planまたは作成予定pathを解決する。
3. 仕事 `AGENTS.md` で対象ドメイン・プロジェクト・`領域/{ドメイン}/{プロジェクト}/計画/plan.md` を解決する。
4. `plan-triage` で規模を判定し、`new-plan.sh` のdry-run後に解決済みpathへ起案する。領域planへroot専用 `bucketctl` を適用しない。
5. 既定2ペイン（実装/レビュー）で実行し、ライトの `評価01.md` を残す。
6. ClaudeとCodexの双方でroot AGENTS、repo-local Skill、Global Skillの発見先を確認する。
7. 正本plan更新後に `計画一覧.md` が再生成され、一覧から同じplanへ解決できることを確認する。
8. session-boardとrepo-local hookが対象repo contextで意図どおり各1回だけ動き、自動commitやplan path判定をしないことを確認する。
9. 完了後は仕事repoが定める領域planの完了表現に従い、対象commitのrevertで導線だけ戻せるrollback drillを行う。repo横断計画のroot bucket遷移は別の既存fixtureで回帰確認する。
10. (B)ではPrivate行のfinishまでをE2Eに含める。Privateを調整役として残す場合は2行の役割・終了責任を記録し、最後に両方を別々にfinishする。
11. canonical repo identityでmain repoとworktreeを同じrepoとして関連づけ、hook発火はrepo-local/global各1回、session-boardに孤児行0件を確認する。
12. session finish、領域planの完了表現、root planのdone遷移、成果物archiveを別イベントとして検証する。

## 完了条件（レビュー項目）

- [ ] パイロット依頼が、repo registry→仕事AGENTS→対象領域/プロジェクト→既存plan検索→領域plan正本の順に一意解決されている。
- [ ] 仕事repo内起点とPrivate起点が同じplan正本へ解決し、Private起点の書込みが仕事repo所有contextで行われている。
- [ ] `plan-triage`、`new-plan.sh`、ライトレビューが領域planに対してエラーなく実行され、root専用 `bucketctl` が誤適用されていない。
- [ ] repo横断plan fixtureでは `planning → active → done` の回帰がPASSし、領域planとroot planの正本が混ざらない。
- [ ] Claude/Codexの両方が同じAGENTS・repo-local Skill・Global Skill所有権を解釈する。
- [ ] session-boardとrepo-local hookに重複発火、旧rootエラー、無条件commitがない。
- [ ] canonical repo identityが一意で、Private/仕事sessionの孤児行が0件である。
- [ ] session finish、領域planの完了、root planのdone、成果物archiveを混同していない。
- [ ] plan更新後に生成された `計画一覧.md` から同じplanへ戻れ、一覧へ手動状態を書いていない。
- [ ] パイロット差分に外部サービス、DB、launchd、候補者情報、既存ユーザー変更が含まれない。
- [ ] `評価01.md` が全PASSで、人間が仕事repoでの使い勝手を確認している。
- [ ] rollback drill後にGit状態と計画導線が事前状態へ戻る。
