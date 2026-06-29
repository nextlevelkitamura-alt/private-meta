# My Brain

このディレクトリは、自分の考え、領域ごとの判断軸、調査、計画を置く場所。
実装repo、Skill正本、registry、履歴ログは置かない。

## 1. 役割

1. `areas/`: work、ai運用、money、health などの継続領域を置く。
2. 各areaでは、考えと実行計画を分けて管理する。
3. 領域の目的、判断基準、置くもの、置かないものは各areaの `identity.md` に置く。
4. 実行する計画は各areaの `plans/<バケット>/<計画名>/plan.md` を正本にする（状態はバケット）。
5. 計画はこの `areas/` を単一正本にする。基盤・Skill・repo・loop計画も `areas/ai運用/` に寄せる。

## 2. 境界

1. 実装repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
2. Global Skill正本、registry、runtime露出、履歴ログは `../AIエージェント基盤/` を正とする。
3. 旧 `../plans/` は廃止済み。基盤・Skill・repo・loop計画は `areas/ai運用/` に置く。移行状況は `areas/ai運用/plans/archive/2026-06-29-plans廃止とarea一本化/plan.md` を見る。
4. 同じ計画本文を `thinking/`、`plans/`、repo側にコピーしない。

## 3. 作業ルール

1. まず対象areaの `AGENTS.md` と `identity.md` を読む。
2. まだ考えを整理している段階なら `thinking/` に置く。
3. 実行する前提になったら `plans/active/<YYYY-MM-short-name>/plan.md` を作る。
4. 計画を作ったら `ops/` に種別5フォルダ（`.gitkeep`付き）を作る。作業は `ops/<種別>/<作業名>.md`、状態はファイル内 `状態:` 行（定義は `areas/AGENTS.md`）。
5. secret、token、credential、環境変数の値は表示・記録しない。
