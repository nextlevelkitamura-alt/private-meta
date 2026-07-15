親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
並列: 不可 ／ レビュー: 一括（Wave 6のE2E・統合評価と合わせて実施）
人間ゲート: 既存計画のバケット移動・identity.md削除・知識/移動は実行せず、候補一覧を承認セットへ記録（承認後に対象限定で適用）

# 既存計画とarea標準の適用（Wave 5）

## 目的

新しい規約を既存の実データへ安全に当てる作業を1子でまとめる。(a) 既存計画の整合監査 — 新遷移規約・終了区分・容量（active≤3/paused≤3/done≤8）で全バケットを点検し、移動候補を一覧化する。(b) ai運用areaのpilot — identity.mdをAGENTS.mdへ統合し、`知識/` の各ファイルの所有先を判定し、代表計画を新テンプレへ移行する。**実行（移動・削除）はせず、候補一覧の提示までが完走ライン。**

## 非対象

- work・money・health areaへの適用（pilot合格後の別作業）
- 承認前の一括移動・一括削除・履歴改変
- 遷移・終了記録の機構そのもの（02が所有。ここは02の手順を使う側）

## 現状

ai運用には active、paused、done、archive の各バケットに複数の計画があり、過去の規約では done と archive の意味が現在提案と異なる。2026-07-13時点で paused=24（新上限3）、done=18（新上限8）と即時超過状態。archive化されたprogramに子計画マップが `実装`・未チェックのまま残る例があり、バケットだけでは完了根拠を追えない。

Area標準は AGENTS.md・CLAUDE.md・identity.md・知識/・plans/ の5点構成（`areas/AGENTS.md` §1）だが、identity.mdはAGENTS.mdと責務が重なり、area直下 `知識/` は「どの計画のための資料か」が切れやすい（references/2026-07-15-計画実行基盤/01 §2.6・§4）。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `my-brain/areas/AGENTS.md` §1・§3-4（Area標準・バケット規約の正本）・`my-brain/areas/ai運用/AGENTS.md`・`identity.md`
  2. `../program.md`（完走スキーム・承認セット）・この計画
  3. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §20（pilot手順）
  4. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §4（推奨Area構成・知識/の例外3条件）・§9（終了区分での監査観点）
- 依存成果: 02の遷移・終了区分・`bucketctl check`・archive lint、01の新テンプレ（代表計画の移行先書式）
- 変更可能範囲: 監査一覧・移動候補・統合ドラフトの出力（この計画の `../references/` 配下）、`my-brain/areas/ai運用/AGENTS.md`（identity統合の本文追加）、`my-brain/areas/AGENTS.md` §1（Area標準の規約更新・pilot結果と同時）、代表計画として選んだ1単発plan＋1program（新テンプレへの移行）、承認セットへの候補記録
- 変更禁止範囲: 承認前のバケット移動・identity.md削除・知識/移動、work/money/health area、`AIエージェント基盤/` 配下（参照の張り替えを除く）、既存計画本文（監査は読み取り専用・移行は代表2件のみ）
- 維持する契約: 監査は読み取り専用（正本の計画本文をコピーしない・一覧は元ファイルへのパスを持つ）／正本は一つ（identity統合後の重複本文を残さない）／CLAUDE.md→AGENTS.md symlink維持
- 検証: 監査一覧の網羅（全バケット・全計画）＋統合後AGENTS.mdの対応表（identity.md全項目に統合先）＋旧path参照grep＋代表計画のplan-lint/program-lint通過
- 停止・エスカレーション条件: `identity.md`・`知識/` に別のconsumer（Skill・hook・他計画からの参照）があり移動で壊れる場合は参照一覧を添えて停止
- 完了時に返す情報: result packet＋承認セットへ記録した候補件数（維持/移動/削除の内訳）

## 方針

### A. 既存計画の整合監査

1. active/paused/done/archive の全計画を読み取り専用で走査し、(a) 実装根拠、(b) 最終評価md、(c) 人間確認記録、(d) programの子マップ状態とチェックボックス、(e) バケット件数と上限超過、(f) archive配下の終了記録・終了区分の有無を一覧化する。出力は `../references/` に置く。
2. 一覧から「現規約ならdone候補」「archiveだが確認根拠・終了記録不足」「子マップとバケットが矛盾」「paused/doneの上限超過」を抽出する（02のarchive lint・`bucketctl check` を使う）。機械検出は候補提示に限り、状態の断定・移動を自動化しない。
3. 候補ごとに `維持 / planningへ戻す / activeへ戻す / doneへ戻す / archiveを承認（終了区分を記録） / pausedへ戻す` の推奨を付けて**承認セットへ記録**する。先行資料 `2026-07-08-並列実装フロー` の `merged` close候補もここに含める。承認後の適用は02の遷移手順で行い、マップ・終了記録を同じコミットで更新する。

### B. ai運用area pilot

4. `identity.md` の内容を `ai運用/AGENTS.md` の 目的/判断基準/置くもの/置かないもの/計画ルーティング へ統合し、全項目の対応表を作る。identity.mdの削除は承認セットへ（承認まで削除しない）。
5. `知識/` の各ファイルを1つずつ読み、(a) 特定計画の `references/` へ、(b) Program共有 `references/` へ、(c) AGENTSへ統合すべき短い判断基準、(d) 例外3条件（2計画以上で長期再利用・計画終了後も判断基準として残る・AGENTSに入れるには詳細すぎる）を満たすarea共通参照、に分類し、移動候補一覧を承認セットへ記録する。
6. 代表の単発plan 1件とprogram 1件を新テンプレ（01）へ移行し、書式が実運用に耐えるかを確認する（一括移行はしない）。
7. pilot結果を反映して `areas/AGENTS.md` §1 のArea標準構成を更新する（identity.md・知識/ を必須から外し、既存areaは「pilot合格後に追従」の移行注記を付ける）。

## 完了条件（レビュー項目）

- [ ] 監査一覧が全バケット・全計画を対象に、件数/上限・実装根拠・最終評価・人間確認・program子状態・終了記録の有無を含み、各行が元ファイルへのパスを持つ。
- [ ] 監査結果が「確定事実」と「人間判断が必要な候補」を分け、承認なしに計画をarchive/done/pausedへ移していない。候補（並列実装フローのmerged closeを含む）が推奨付きで承認セットに記録されている。
- [ ] `ai運用/AGENTS.md` にidentity.md全項目の統合先があり対応表で網羅を確認できる。identity.md削除・知識/全ファイルの分類が承認セットに載っており、承認前の削除・移動が無い。
- [ ] 代表の単発plan 1件・program 1件が新テンプレへ移行され、plan-lint・program-lintが通る。
- [ ] `areas/AGENTS.md` §1 が新Area標準を示し、他areaへの適用が「pilot合格後」と明記され、work/money/healthに変更が無い。
- [ ] 旧pathを参照する箇所のgrep結果（移動実施前なら対象参照の一覧）が承認セットに添付されている。
