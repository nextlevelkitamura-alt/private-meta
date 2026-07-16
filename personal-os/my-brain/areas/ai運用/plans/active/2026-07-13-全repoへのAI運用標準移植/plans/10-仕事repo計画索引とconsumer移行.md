親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル
並列: 可（consumer 4レーン） ／ レビュー: Review 1へ集約

# 仕事repo計画索引とconsumer移行

## 目的

不統一な既存planを一括移動せずに読み取り、`計画一覧.md` を手書き状態正本から決定的なread-only索引へ切り替え、全active writerを正本plan更新へ向ける。

## 現状

1. 2026-07-14の専用worktree再監査時点のcanonical候補は領域 `*/計画/plan.md` 12件とroot `plans/planning/*/plan.md` 3件の計15件だが、header形式と状態表現が統一されていない。W01はこのsnapshotをfixture基準として固定し、以後の増減を暗黙に混ぜない。
2. `計画一覧.md` は2026-06-26時点の10件だけで、root 3件と停止・新規計画を反映していない。
3. `task`、`eod`、`review`、`business-planning`、`repo-eval` が一覧へ直接書く。generatorを先に本番化すると、旧writerとの二重書込みになる。

## 実行パッケージ

1. **W01 metadata/parser契約**: interface version、安定plan ID schema、metadata alias、領域/root類型、状態の取得元、parser input/output、欠損・重複・broken link時のfail-closedを固定する。
2. **W02 shadow generator**: 新規 `scripts/plan-index/` だけを所有し、`check` はread-only、`render --write` は明示実行、parse失敗時は出力を更新しない。
3. **W03A consumer lane A**: `task` と `eod` を「正本plan更新→index再生成」へ変更する。
4. **W03B consumer lane B**: `review` と `business-planning` を同契約へ変更する。
5. **W03C consumer lane C**: `repo-eval/**` の本体・template・rubricを同契約へ変更する。
6. **W03D policy lane D**: `方針/介入レベル.md` と `領域/整備/リポ評価/計画/plan.md` に残る一覧直接更新指示を、正本plan更新→生成へ揃える。履歴文書は編集しない。
7. **W04 atomic integration**: 4laneのtest-author証拠を統合し、shadow出力と旧一覧の差を人間確認してから `計画一覧.md` の単独ownerが生成版へ切り替える。

## 許可pathと競合境界

- W01は仕事repoを編集しない。安定plan ID、metadata alias、状態取得元、fail-closed条件を人間が選び、承認結果を本Childの `実装記録` にIntegration担当が記録する。これがW02/W03のimmutable inputになる。
- W02: `scripts/plan-index/**` のみ。既存planと `計画一覧.md` へ書かない。
- W03A: `.agents/skills/task/**` と `.agents/skills/eod/**` だけ。W03B: `.agents/skills/review/**` と `.agents/skills/business-planning/**` だけ。W03C: `.agents/skills/repo-eval/**` だけ。別laneのSkillと一覧へ書かない。
- W03D: `方針/介入レベル.md` と `領域/整備/リポ評価/計画/plan.md` だけ。履歴の `scripts/worker-search/HANDOFF.md` と `領域/整備/リポ評価/履歴/**` はfreezeし、active指示と混ぜない。
- W04: 承認済みunionと `計画一覧.md`。root `AGENTS.md` はChild 04だけが所有する。
- 仕事repoのGate 0安全化10pathがcommitされるまで、追加writerは起動しない。
- 依存は `W01 → W02 → W03A/W03B/W03C/W03D（並列） → W04` で固定する。各laneのtest-author結果をIntegration担当が本Childの `実装記録` へ集約し、正式採点はReview 1の1回だけにする。

## テスト・レビュー・rollback

1. 現存する複数header形式、root plan形式、metadata欠損、同名/同ID、broken link、補助文書除外をfixture化する。
2. 2回生成がbyte-identical、全link実在、root状態はbucket由来、source plan書込み0を確認する。
3. 5 writerの `計画一覧.md` 直接更新指示が0件で、外部サービス呼出0の隔離テストを通す。
4. test-authorは実装者と別、Integration担当が全lane証拠をまとめる。Review 1 reviewerは両者と別系統にする。
5. lane単位commitで戻し、W04は統合commit一括revertで旧一覧へ戻す。旧writerと生成writerを同時稼働させない。

## 人間ゲート

plan ID/metadata契約、shadow差分、生成版へのatomic切替、W04の明示path commit。pushは別判断。

## 完了条件（レビュー項目）

- [ ] snapshotで固定したcanonical候補15件と補助文書の区別がfixtureと台帳で一致する。
- [ ] parse不能・ID重複・broken linkが1件でもあれば非0終了し、既存indexがbyte不変である。
- [ ] `計画一覧.md` が決定的な派生索引で、plan本文・状態の第2正本になっていない。
- [ ] active writer全件が正本plan更新後にgeneratorを呼び、一覧を直接編集しない。
- [ ] 4 consumer laneとIntegrationの実行証拠がReview 1で全PASSし、統合commitのrevert drillがPASSする。
