# ai運用 Area

このareaは、personal-os 基盤、Global Skill、repo、loop、CLI（Orca など）の運営に関する考えと計画を置く場所。
実装の正本は置かない。実装正本は `../../../AIエージェント基盤/`。

## 1. 目的

personal-os 基盤、Global Skill、repo、loop、CLI（Orca など）の運営に関する考えと計画を整理する。
このareaは「考え・計画」を持つ。実装の正本は持たない。

### 実装正本との違い（混同しない）

1. このarea（`my-brain/areas/ai運用/`）: 基盤をどう運営するかの考えと計画。
2. 実装正本（`personal-os/AIエージェント基盤/`）: Skill本文、registry、logs、runtime露出の正本。
3. 名前が似ているが別物。計画はこのarea、実装はAIエージェント基盤に置く。

## 2. 判断基準

1. 具体的な実行に進む前に、目的、前提、完了条件を明確にする。
2. 人間が判断すること、AIに任せること、repoやSkillやloopに落とすことを分ける。
3. 横断計画本文は `plans/<バケット>/<計画名>/plan.md` を正本にする。Theme固有計画は各Theme最寄り `AGENTS.md` が宣言する `themes/<Theme>/plans/<バケット>/<計画名>/plan.md` を正本にする（状態はバケットで持つ）。
4. 実装正本（Skill本文、registry、logs）はこのarea内に増やさない。

## 3. 置くもの

1. 基盤の運営方針・判断軸は、この `AGENTS.md` の「目的」「判断基準」に置く（旧 `identity.md` はここへ統合済み。全項目の対応表は `plans/active/2026-07-15-計画立案実行完了基盤/references/2026-07-16-identity統合対応表.md`。`identity.md` 自体の削除は承認セット待ち）。
2. 完成した恒久・再利用可能な参照mdは `知識/` に置く。未確定の構想はこの `AGENTS.md` の「判断基準」か計画の `方針`、特定計画だけの資料は計画内 `references/` に置く。`知識/` を考えや調査の置き場にしない。
3. 横断計画は `plans/planning/<YYYY-MM-DD-日本語企画名>/plan.md` に作る。Theme固有計画はTheme最寄り `AGENTS.md` が宣言する `themes/<Theme>/plans/` に作る。状態遷移は `../AGENTS.md` の規約、結果同期は `planctl` を使う。計画に紐づく人間向けHTMLは各計画の `explain/` に置く。repo実行が要る計画は成熟後に実行repoへ卒業させる。規約・卒業手順は `../AGENTS.md`。
4. 計画から派生する作業は `../AGENTS.md` §4.2 に従う（旧 `ops/` 5フォルダ構成は廃止・既存はlegacy）。規模、レビュー、人間ゲート、各Skill・hookの責務は `../../../AIエージェント基盤/plan-registry/AGENTS.md` を正とし、このareaには再定義しない。
5. Personal OS自体の構造・運用ルールの検討、Global Skill・repo・loop・CLI（Orca など）の企画・計画、旧計画ディレクトリから移行済みの基盤・横断計画は、このareaを正本にする。

## 4. 置かないもの

1. Skill本文、registry、logs。これらは `../../../AIエージェント基盤/` が正本。
2. 実装repo本体。必要なら `/Users/kitamuranaohiro/Private/projects/` に置く。
3. secret、token、credential、環境変数の値。

## 5. 計画ルーティング（このarea固有の計画配置）

1. 横断計画は `plans/planning/<YYYY-MM-DD-日本語企画名>/plan.md` に作る。Theme固有計画は、Theme最寄り `AGENTS.md` が宣言するTheme配下の計画箱を先に検索してから置く。すべてのバケット遷移は宣言済みの規約に従い、`bucketctl` を使う対象では既定dry-runから `--apply`/`--commit` を明示する。
2. `plan.md` 冒頭に `分類:`、`種別:` を書く。状態はフォルダ（バケット）で持ち、`状態:` フィールドは書かない。
3. `分類:` は `skill`、`repo`、`loop` を使う。Personal OS基盤や横断運用は、主対象に最も近い分類で扱う。
4. `種別:` の定義と、バケット（状態）の規約・移動方法は `../AGENTS.md` を正とする。計画の規模・レビュー・人間ゲートは `../../../AIエージェント基盤/plan-registry/AGENTS.md` を見る。
5. Global Skill / loop 計画はこのareaで育成する。Global Skill計画の卒業可否と箱は `../../../AIエージェント基盤/global-skill-registry/AGENTS.md`、loopの計画と実装の境界は `../../../AIエージェント基盤/loops-registry/AGENTS.md` を正とし、存在しない節や `loops-registry/plans/loop/` を推定しない。repo-local Skill計画は `repo-registry/repo概要.md` で所有repoを決め、所有repo `AGENTS.md` が宣言する計画箱を正本にする。`plans/skills/` を共通pathとして自動作成しない。
6. repo-local Skillの所属repoが未確定なら、所有repoを決める計画としてこのareaに `分類: repo` で置く。
7. repo-local SkillをGlobal化する判断が主目的なら、このareaに `分類: skill` で置く。
8. 旧計画ディレクトリは廃止済み。移行状況は `plans/archive/2026-06-29-plans廃止とarea一本化/plan.md` を見る。
9. 全repo横断の移植計画はこのareaのprogramを唯一の計画正本にし、移植先repoへ同じprogram・子計画・状態表を複製しない。移植後にrepo固有で発生した依頼だけを、そのrepoの計画箱で別計画として扱う。
10. 容量は各 `plans/` root で planning=5・active=6・paused=3・done=8（archiveは無制限。2026-07-24 planning 無制限→5）。満杯時も自動退避・`--force` は使わず、人間が整理先を選ぶ。planning 満杯時は未成熟な構想を themes/（`../AGENTS.md` §1.2）へ差し戻す。

## 6. 作業ルール

1. 新しい計画を作る前に、対象がTheme固有ならそのTheme配下の `plans/`、横断ならarea直下の `plans/` を確認する。
2. まず `plan.md` に目的、対象、判断、実行順、完了条件を書く。
3. 旧 `ops/` 5フォルダは作らない（廃止済み）。派生作業の扱いは `../AGENTS.md` §4.2。
4. 完了済み計画には、結果と反映先だけを短く追記する。

## 7. 書かないもの

1. Skill本文のコピー。
2. registry、logs、catalog、repo profileのコピー。
3. 実行済み履歴として該当registryの `logs/` に書くべき内容。
4. コマンド生ログ、diff全文、secret、token、credential、環境変数の値。
5. `identity.md` への新規の判断基準追記（統合後は本 `AGENTS.md` の「目的」「判断基準」へ書く。`identity.md` は削除承認待ちの凍結状態）。

## 8. 完了条件

1. 横断計画はこのareaの `plans/<バケット>/<YYYY-MM-DD-日本語企画名>/plan.md`、Theme固有計画はTheme配下の宣言済み計画箱に配置されている。
2. `分類:`、`種別:` が本文冒頭にある（状態はバケットで持ち、`状態:` 行は書かない）。
3. 計画、現在状態、履歴、実装正本が混ざっていない。
4. repo-local Skill計画をPersonal OS側へコピーしていない。
5. 不要な二重管理を増やしていない。
6. `identity.md` は内容を追記されず、統合対応表と整合したまま削除承認を待っている。
