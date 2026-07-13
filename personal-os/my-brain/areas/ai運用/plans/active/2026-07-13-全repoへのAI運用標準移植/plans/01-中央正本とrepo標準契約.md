親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 可 ／ レビュー: 都度

# 中央正本とrepo標準契約

## 目的

全repoへ配る前に、Personal OS側の古い参照と語彙矛盾を解消し、「何を中央に置き、何を各repoが持つか」を1本の契約として固定する。

## 現状

1. `my-brain/areas/ai運用/AGENTS.md` に repo-local Skill計画を `plans/skills/` とする古い記述があり、Global規約は全repoを `<repo>/plans/planning|active|paused|done/` へ寄せる。一方、仕事repoは `領域/{ドメイン}/{プロジェクト}/計画/plan.md` を正本としており、repo類型を無視したpath競合がある。
2. `my-brain/areas/AGENTS.md` と `ai運用/AGENTS.md` が、現行の基盤 `AGENTS.md` に存在しない節を参照する。
3. areas側には、廃止済みrendererの自動反映、旧 `ops/`、active直置きなどの古い前提が点在する。
4. 仕事repoの薄い接続が、`plan-ops` の実体と異なるpathに読める。
5. `repo-create` はrepo種別を持つが、repoごとの計画箱宣言と二段ルーティングの生成・監査責務は未定義である。
6. repo registryは担当repoの索引だが、現行 `plan-triage` は対象repoを決めた後もroot `plans/` を一律作成先として扱う。
7. session-boardの注入文と実装が `<repo>/plans` を前提にしており、repo `AGENTS.md` が宣言する計画箱と競合する可能性がある。

## 方針

1. 共通契約、安全、人間ゲート、Global Skill/hook/runtime露出はPersonal OS側を正本とする。
2. repo registryは担当repoだけを解決し、領域表・計画本文・状態を持たない。各repoの詳細と計画箱はrepo固有 `AGENTS.md` を正本とする。
3. 仕事repoは、領域固有計画を `領域/{ドメイン}/{プロジェクト}/計画/plan.md`、複数領域・repo基盤計画をroot `plans/<bucket>/` に置く。coding repoはroot `plans/<bucket>/` を既定とする。
4. `plan-triage` は規模・経路・起動形・modelを判定するが、物理pathは対象repo `AGENTS.md` の宣言から解決する。`plan-ops` は解決済みpathへ雛形生成・lintを行う。このSkill実装は仕事repoの導線と同じ波で検証するため、子04が所有する。
5. 同一repo内の互換symlinkだけを許し、cross-repo symlinkは標準にしない。
6. Global規約とrepo-local適用の責務境界は新しい野良契約を増やさず、横展開時に `repo-create` の既存criteriaへ統合する。実装・Skill評価は子08が所有する。
7. 規約変更は人間承認と `ai運用/決定ログ.md` 追記を同じ変更単位にする。
8. session-boardの正本である `hooks/session-board/session-start.md`、`common.py`、`README.md` を同じ契約へ揃え、session状態・Daily実行ログとplan本文・plan状態の責務を分ける。
9. 本programを横断移植の唯一の計画正本とし、仕事repoへ同じ移植計画を複製しない。移植後のrepo固有計画だけを所有repoの計画箱へ作る。

## 完了条件（レビュー項目）

- [ ] `GLOBAL_AGENTS.md`、`説明書/運用契約.md`、`my-brain/areas/AGENTS.md`、`my-brain/areas/ai運用/AGENTS.md` のrepo計画pathと状態語彙が一致する。
- [ ] Global契約から「全repoは必ずroot plans」という前提が外れ、repo `AGENTS.md` が計画箱を宣言する二段ルーティングが定義されている。
- [ ] repo registry→対象repo AGENTS→既存計画検索→計画箱、の責務と失敗時の停止条件を人間が追える。
- [ ] `rg` で、存在しない基盤AGENTS節、`plans/skills/`、廃止済みrenderer自動反映、旧 `ops/` 必須化のactiveな指示が0件である。
- [ ] `plan-triage` のSkill実装は子04、`repo-create` のcriteria・監査実装は子08が所有すると一意に切り分けられ、子01に同じ手順を複製していない。
- [ ] session-boardの注入文・実装・READMEにroot `plans/` 固定がなく、repo `AGENTS.md` が解決したplan参照を表示できる。
- [ ] session-boardがsession状態とDaily実行ログを所有し、plan本文・plan状態を所有しないことが正本と実装で一致する。
- [ ] `ai運用/決定ログ.md` に、標準契約・棄却した代替案・影響先が1件記録されている。
- [ ] secret、repo-local Skill本文、hook本文を中央契約へコピーしていない。
