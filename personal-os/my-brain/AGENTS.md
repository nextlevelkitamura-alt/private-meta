# My Brain

このディレクトリは、自分の考え、領域ごとの判断軸、調査、計画を置く場所。
実装repo、Skill正本、registry、履歴ログは置かない。

計画は各areaで育て、成熟したら実行repoへ卒業させる。ここは計画を育てる工房であって、実行の現場ではない。育成→卒業の流れの正本は `areas/AGENTS.md` の §5。

## 1. 役割

1. `areas/`: work、ai運用、money、health などの継続領域（横の領域別）を置く。
2. `ゴール/`: 3年→年間→デイリーの縦ladder（的と履歴）。横の `areas/` と分け、全体の「今」（動いているエージェント／終わったこと）は board DB（Turso）が正本で focusmap がDBから描画する（2026-07-21 正本反転・案b＝デイリーmd 2節は廃止）。旧`ダッシュボード.md`（レンダラ自動描画前提）は2026-07-08削除（レンダラ廃止で空指しポインタ化していたため）。
3. 各areaでは、判断軸（`identity.md`）と実行計画（`plans/`）を分けて管理する。ただし `areas/ai運用/` はTheme専用構造であり、計画は各Themeの `plans/` に置く。
4. 領域の目的、判断基準、置くもの、置かないものは各areaの `identity.md` に置く。
5. 実行する計画は各areaの宣言済み計画箱を正本にする（状態はバケット）。`ai運用` では `themes/<Theme>/plans/<バケット>/<計画名>/plan-0.md` が親正本である。
6. 計画はこの `areas/` を単一正本にする。AI運用に属する構想とTheme固有計画は `areas/ai運用/themes/` に寄せ、Themeに属さない実装計画は所有repoへ置く。

## 2. 境界

1. 実装repo本体は `/Users/kitamuranaohiro/Private/projects/` に置く。
2. Global Skill正本、registry、runtime露出、履歴ログは `../AIエージェント基盤/` を正とする。
3. 旧 `../plans/` と `areas/ai運用/` 直下の `plans/` は廃止済み。AI運用の構想と計画は `areas/ai運用/themes/<Theme>/` に置く。
4. 同じ計画本文を `plans/` と repo側にコピーしない。

## 3. 作業ルール

1. まず対象areaの `AGENTS.md` と `identity.md` を読む。
2. まだ固まっていない構想は、`identity.md` か育成中の計画の方針に置く。`ai運用` ではThemeの `concepts/` に置く。`thinking/` は廃止した。
3. 新規計画は各areaまたはrepoが宣言する `planning/` バケットに作る。`ai運用` ではTheme配下の `plans/planning/<YYYY-MM-DD-日本語企画名>/plan-0.md` に作る。
4. 旧 `ops/` 5フォルダ構成は廃止（既存計画に残るものはlegacy・新規に作らない）。計画から派生する作業は `areas/AGENTS.md` §4.2 に従う。
5. secret、token、credential、環境変数の値は表示・記録しない。
