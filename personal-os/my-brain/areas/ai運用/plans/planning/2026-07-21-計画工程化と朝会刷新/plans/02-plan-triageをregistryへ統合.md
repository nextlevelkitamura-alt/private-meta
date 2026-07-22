親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
規模: フル
形態判定: Program子 ／ 理由: skill削除を伴う構造統合を独立子として承認・追跡する
並列: 可 ／ 差し戻し上限: フル=2
人間ゲート: skill削除（plan-triage）はskill-delete承認・catalog更新

# 子02: plan-triage を plan-registry へ統合

## 目的

露出されない軽い決定手続き（triage.md 93行＋検証テスト）を plan-registry へ吸収し、
規約(89行)と決定手続きが同じ基準を二重に持つ状態を解消して、plan-registry を実体ある正本にする。
2026-07-22 人間決定「triageは決定手続き＝registryへ／opsは本物のツール＝skillのまま」。

## 非対象

- plan-ops（bucketctl/planctl/plan-lint/plansync＝15スクリプト）の移設（skillのまま）。
- triageの判定ロジック自体の仕様変更（移設のみ・振る舞いは不変）。

## 現状

- skills/plan-triage/ に SKILL.md・workflows/triage.md（93行）・scripts/validate-*.mjs＋fixtures。
- exposure-manifest に plan-triage は無い（runtime非露出）。利用者コマンドでもない。
- 「skill plan-triage」を参照するのは9箇所: kickoff・plan-create-review・morning-routine・inbox-triage・orca-cockpit・loop-creator・repo-create・custom-agent-creator（＋plan-ops）。
- plan-registry/AGENTS.md は既にtriageを参照（§1・表・図の4箇所）＝関係は成立、実体だけがskill側にある。

## 実行契約

- 対象repo: ~/Private（personal-os/AIエージェント基盤/plan-registry・skills/plan-triage・global-skill-registry・上記9参照skill）
- 実行形: delegated-single
- 最初に読む順番:
  1. plan-registry/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この計画
  5. skills/plan-triage/workflows/triage.md（移設元）・skill-delete SKILL.md
- 依存成果: なし（子01と独立）
- 変更可能範囲: plan-registry/AGENTS.md・plan-registry/scripts/・9参照の各SKILL.md・global-skill-registry catalog・skills/plan-triage（削除）
- 変更禁止範囲: triageの判定基準（規模3条件・route）の意味・plan-opsツール
- 維持する契約: triageの判定挙動を移設前後で不変に保つ（検証テストで担保）
- 検証: 移設テスト（validate-route-cases.mjs等）をplan-registry配下で全PASS。「skill plan-triage」残参照をgrepで0件確認
- 停止・エスカレーション条件: triage手続きがregistryに収まらない複雑さと判明したら移設せず「registryが参照」で確定し人間へ報告
- 完了時に返す情報: result packet（status / changed_paths / tests / blockers / remaining_risks）

## 方針

1. triage.md（決定手続き）と検証テスト（validate-route-cases.mjs/validate-inbox-contract.mjs/fixtures）を plan-registry 配下へ移す（本文はAGENTS.mdへ節として、テストはplan-registry/scripts/へ）。
2. plan-registry/AGENTS.md がtriage決定手続きを吸収し「基準＋当て方＋検証」を持つ正本になる。
3. 9参照の「skill plan-triage」を plan-registry 参照へ更新（意味は不変・呼び先の名だけ変わる）。
4. skill-delete で skills/plan-triage を閉じ、global-skill-registry catalog を更新。

## 完了条件

- [ ] triage手続き・テストが plan-registry 配下にある（対象: plan-registry/AGENTS.md・scripts/）
- [ ] skills/plan-triage が閉じ（skill-delete承認・deletedログ）、catalogから除かれている（対象: skills/・global-skill-registry）
- [ ] 9参照すべてが plan-registry を指し、「skill plan-triage」の残参照が0（対象: 各SKILL.md・grep）
- [ ] triageの判定挙動が移設前後で不変（検証テストがplan-registry配下で全PASS）（対象: 移設テスト）

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
