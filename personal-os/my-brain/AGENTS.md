# My Brain

このディレクトリは、自分の考え、領域ごとの判断軸、調査、計画を置く場所。
実装repo、Skill正本、registry、履歴ログは置かない。

計画は各areaで育て、成熟したら実行repoへ卒業させる。ここは計画を育てる工房であって、実行の現場ではない。育成→卒業の流れの正本は `areas/AGENTS.md` の §5。

## 1. 役割

1. `areas/`: work、ai運用、money、health などの継続領域（横の領域別）を置く。
2. `ゴール/`: 3年→年間→デイリーの縦ladder（的と履歴）。横の `areas/` と分け、全体の「今」は当日デイリーの自動区画（今やっていること/待ち/計画ボード。レンダラが描画）で見る。`ダッシュボード.md` はポインタのみ。
3. 各areaでは、判断軸（`identity.md`）と実行計画（`plans/`）を分けて管理する。
4. 領域の目的、判断基準、置くもの、置かないものは各areaの `identity.md` に置く。
5. 実行する計画は各areaの `plans/<バケット>/<計画名>/plan.md` を正本にする（状態はバケット）。
6. 計画はこの `areas/` を単一正本にする。基盤・Skill・repo・loop計画も `areas/ai運用/` に寄せる。

## 2. 境界

1. 実装repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
2. Global Skill正本、registry、runtime露出、履歴ログは `../AIエージェント基盤/` を正とする。
3. 旧 `../plans/` は廃止済み。基盤・Skill・repo・loop計画は `areas/ai運用/` に置く。移行状況は `areas/ai運用/plans/archive/2026-06-29-plans廃止とarea一本化/plan.md` を見る。
4. 同じ計画本文を `plans/` と repo側にコピーしない。

## 3. 作業ルール

1. まず対象areaの `AGENTS.md` と `identity.md` を読む。
2. まだ固まっていない構想は、`identity.md` か、育成中の計画の `plans/active/<計画>/plan.md` の `方針`（未確定のまま）に置く。`thinking/` は廃止した。
3. 実行する前提になったら `plans/active/<YYYY-MM-DD-日本語企画名>/plan.md` を作る。
4. 旧 `ops/` 5フォルダ構成は廃止（既存計画に残るものはlegacy・新規に作らない）。計画から派生する作業は `areas/AGENTS.md` §4.2 に従う。
5. secret、token、credential、環境変数の値は表示・記録しない。
