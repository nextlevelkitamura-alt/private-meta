# ai運用 Area

このareaは、personal-os 基盤、Global Skill、repo、loop、CLI（Orca など）の運営に関する考えと計画を置く場所。
実装の正本は置かない。実装正本は `../../../AIエージェント基盤/`。

## 1. 置くもの

1. 基盤の運営方針・判断軸は `identity.md` に置く。
2. 固まっていない構想は `identity.md` か、育成中の計画の `plan.md` の `方針`（未確定のまま）に置く。`thinking/` は廃止した。
3. 実行する計画は `plans/active/<YYYY-MM-DD-日本語企画名>/plan.md` に作り、状態に応じてバケット（active/paused/done/archive）間を移す。repo実行が要る計画は成熟後に実行repoへ卒業させる。規約・卒業手順は `../AGENTS.md`。
4. 計画から派生する作業は `../AGENTS.md` §4.2 に従う（旧 `ops/` 5フォルダ構成は廃止・既存はlegacy）。
5. Personal OS基盤・横断repo・Global Skill・repo・loopの計画は、このareaを正本にする。

## 2. 置かないもの

1. Skill本文、registry、logs。これらは `../../../AIエージェント基盤/` が正本。
2. 実装repo本体。必要なら `/Users/kitamuranaohiro/Private/projects/` に置く。
3. secret、token、credential、環境変数の値。

## 3. 計画ルーティング

1. 1計画は `plans/active/<YYYY-MM-DD-日本語企画名>/plan.md` に作り、状態に応じてバケット（active/paused/done/archive）間を `git mv` で移す。
2. `plan.md` 冒頭に `分類:`、`種別:` を書く。状態はフォルダ（バケット）で持ち、`状態:` フィールドは書かない。
3. `分類:` は `skill`、`repo`、`loop` を使う。Personal OS基盤や横断運用は、主対象に最も近い分類で扱う。
4. `種別:` の定義と、バケット（状態）の規約・移動方法は `../AGENTS.md` を正とする。
5. Global Skill / loop 計画はこのareaで育成し、成熟したら基盤の卒業先（skill＝`../../../AIエージェント基盤/global-skill-registry/plans/`、loop＝`../../../AIエージェント基盤/loops-registry/plans/loop/`）へ卒業させる（卒業手順は `../AGENTS.md` §5、卒業先構成は基盤 `AGENTS.md` §1.1）。repo-local Skill計画は所有repo内の `plans/skills/` を正本にする。
6. repo-local Skillの所属repoが未確定なら、所有repoを決める計画としてこのareaに `分類: repo` で置く。
7. repo-local SkillをGlobal化する判断が主目的なら、このareaに `分類: skill` で置く。
8. 旧計画ディレクトリは廃止済み。移行状況は `plans/archive/2026-06-29-plans廃止とarea一本化/plan.md` を見る。

## 4. 作業ルール

1. 新しい計画を作る前に、既存の `plans/` を確認する。
2. まず `plan.md` に目的、対象、判断、実行順、完了条件を書く。
3. 旧 `ops/` 5フォルダは作らない（廃止済み）。派生作業の扱いは `../AGENTS.md` §4.2。
4. 完了済み計画には、結果と反映先だけを短く追記する。

## 5. 書かないもの

1. Skill本文のコピー。
2. registry、logs、catalog、repo profileのコピー。
3. 実行済み履歴として該当registryの `logs/` に書くべき内容。
4. コマンド生ログ、diff全文、secret、token、credential、環境変数の値。

## 6. 完了条件

1. 計画がこのareaの `plans/<バケット>/<YYYY-MM-DD-日本語企画名>/plan.md` に配置されている。
2. `分類:`、`種別:` が本文冒頭にある（状態はバケットで持ち、`状態:` 行は書かない）。
3. 計画、現在状態、履歴、実装正本が混ざっていない。
4. repo-local Skill計画をPersonal OS側へコピーしていない。
5. 不要な二重管理を増やしていない。
