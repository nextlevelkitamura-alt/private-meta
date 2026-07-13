分類: 横断 ／ 種別: 既存改善 ／ 形態: program

# 計画運用の標準化とWIP制御

## 目的

program.md / plan.md の見え方を標準化し、①目的 ②並列化の有無 ③レビュー方式(都度/一括) ④進捗チェックボックス を計画に持たせる。あわせて active の同時実行数を制御(WIP)し、planning→active の昇格を機械化する。「見て進捗が分かる・active が溢れない・移動が手作業で漏れない」状態にする。ライト以上の新規計画は planning に起案し、指揮官が明示した昇格だけを bucketctl が active へ通す。

## 全体像

plan-ops(実装正本 `personal-os/AIエージェント基盤/skills/plan-ops/`)のテンプレ・スクリプト・lint と、規約正本(`areas/AGENTS.md` §3・`説明書/運用契約.md` §2)を横断で改定する。見え方(01)→機械追従(02)は直列、レビュー方式(03)・WIP＋昇格統制(04)は独立。この program.md 自身を新フォーマットの実例にし、子見出しのチェックボックスと段階状態の整合は program-lint で検証する。

## 子計画マップ   ※ 子の状態変更と同じコミットでここを更新

- [ ] 01  見え方標準化 … 実装
    並列: 可 ／ レビュー: 都度(02が依存)
    次: templates/{program,plan,子計画}.md と areas/AGENTS.md §3 に 目的・並列・レビュー方式・チェックボックス欄を定義
    場所: plans/01 ／ 依存: ―
- [ ] 02  チェックボックスとパーサ追従 … 実装
    並列: 不可 ／ レビュー: 都度(機械ツール＋テスト)
    次: _planops_map/progctl/lint を [ ]/[x] 対応にし、[x]⟺状態=完了 の整合を追加、テストと既存6 program を移行
    場所: plans/02 ／ 依存: 01
- [ ] 03  レビュー方式(都度/一括) … 実装
    並列: 可 ／ レビュー: 都度(契約=背骨)
    次: 運用契約.md §2 に「並列・独立=一括／直列・依存=都度」を追記
    場所: plans/03 ／ 依存: ―
- [ ] 04  WIP3とactive再定義(＋bucketctl昇格統制) … 実装
    並列: 可 ／ レビュー: 都度(移行32件＋script)
    次: plan-triageのplanning起案とbucketctlの仕様・テストを実装
    場所: plans/04 ／ 依存: ―

## 完了条件（レビュー項目）

- [ ] `templates/{program,plan,子計画}.md` に 目的・並列・レビュー方式・進捗チェックボックスの欄が入っている。
- [ ] `_planops_map.py` の HEADER_RE が `- [ ]`/`- [x]` プレフィックス付き見出しを解釈し、progctl と lint が誤動作しない(テストで担保)。
- [ ] `program_lint_core.py` が「`[x]` ⟺ 状態=完了」の不整合を検出する。
- [ ] 既存6 program の子計画マップが新フォーマットへ移行され、lint が0件検出の誤合格でなく実質的に通る。
- [ ] `運用契約.md` §2 に 都度/一括レビューの判定(並列・依存連動)が追記され、決定ログに1件ある。
- [ ] `areas/AGENTS.md` §3 に active=実行中のみ≤3・育成中→planning/paused が定義され、ai運用 active が3件以下になっている。
- [ ] ライト以上の起案先が planning であり、planning→active は指揮官が明示する `bucketctl promote` だけを入口にしている。上限超過時は昇格を弾く。
- [ ] 各正本改定に追従漏れ(契約§8 grep)が無く、secret混入なし。

## 関連

- plan-ops 実装正本: `personal-os/AIエージェント基盤/skills/plan-ops/`(templates・scripts・__tests__)
- 規約正本: `areas/AGENTS.md` §3(計画/program標準・バケット) ／ `説明書/運用契約.md` §2(段階・規模・レビュー方式)
- 併走(WIP枠を共有): `plans/active/2026-07-13-outputsを知識とexplainへ再編/`
