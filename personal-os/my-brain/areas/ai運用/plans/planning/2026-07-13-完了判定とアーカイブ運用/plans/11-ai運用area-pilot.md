親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
並列: 不可 ／ レビュー: 都度
人間ゲート: `identity.md` の削除・`知識/` 配下の移動は候補一覧の提示後に個別承認

# ai運用area pilot

## 目的

新しいArea標準（AGENTS.md＋plans/ を核とし、identity.md と area直下 `知識/` を必須構成から外す）を、ai運用areaだけでpilot適用する。計画固有資料は各計画の `references/` を既定の置き場にする。pilot合格までwork/money/healthへ波及させない。

## 非対象

- work・money・health areaへの適用（pilot合格後の別作業）
- 既存計画の状態・バケットの是正（03が所有）
- `知識/`・`identity.md` の一括移動・一括削除（1ファイルずつ判定し、実行は人間承認後）

## 現状

各areaは AGENTS.md・CLAUDE.md・identity.md・知識/・plans/ を標準構成とする（`areas/AGENTS.md` §1）。identity.md の内容（目的・判断基準・置くもの・置かないもの）は AGENTS.md と責務が重なり、area直下 `知識/` は「どの計画のための資料か」が切れやすい（references/2026-07-15-計画実行基盤/01 §2.6・§4）。ai運用の実態として、計画中の調査資料が `知識/` と計画フォルダに分散している。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `my-brain/areas/AGENTS.md` §1（Area標準構成の正本）・`my-brain/areas/ai運用/AGENTS.md`・`identity.md`
  2. `../program.md`・この計画
  3. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §20（pilot手順）
  4. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §4（推奨Area構成・知識/の例外3条件）
- 依存成果: 05の新テンプレ（代表計画の移行先書式）
- 変更可能範囲: `my-brain/areas/ai運用/AGENTS.md`・`identity.md`（統合後の削除は人間承認後）・`知識/`（移動は人間承認後）、`my-brain/areas/AGENTS.md` §1（Area標準構成の規約。pilot結果と同じ作業単位で更新）、pilot対象に選んだ代表計画のフォルダ
- 変更禁止範囲: work・money・health など他のarea、`AIエージェント基盤/` 配下（参照の張り替えを除く）、既存計画のバケット位置
- 維持する契約: 正本は一つ（identity内容をAGENTSへ統合したら旧文は残さない）／`知識/` の各ファイルは所有先判定が済むまで削除しない／CLAUDE.md→AGENTS.md symlinkの維持
- 検証: 統合後AGENTS.mdの網羅照合（identity.mdの全項目に統合先がある）＋旧pathへの参照grep（切れ参照ゼロ）
- 停止・エスカレーション条件: `identity.md` または `知識/` に別のconsumer（Skill・hook・他計画からの参照）があり移動で壊れる場合は、その参照の一覧を添えて停止
- 完了時に返す情報: 02指示書§24の完了報告形式（移動候補一覧と人間判断待ち項目を必須で含む）

## 方針

1. `ai運用/identity.md` の内容を `ai運用/AGENTS.md` の 目的／判断基準／置くもの／置かないもの／計画ルーティング へ統合する。統合の網羅を示してから、identity.md の削除を人間承認へ提示する（承認まで削除しない）。
2. `知識/` の各ファイルを1つずつ読み、(a) 特定計画の `references/` へ、(b) Program共有 `references/` へ、(c) AGENTSへ統合すべき短い判断基準、(d) 例外3条件（2計画以上で長期再利用・計画終了後もareaの判断基準として残る・AGENTSに入れるには詳細すぎる）を満たすarea共通参照、へ分類する。移動候補一覧を先に提示し、人間承認後に対象限定で移動する。
3. 代表の単発plan 1件とprogram 1件を新テンプレ（05）へ移行し、書式が実運用に耐えるかを確認する（全計画の一括移行はしない）。
4. pilot結果を反映して `areas/AGENTS.md` §1 のArea標準構成を更新する（identity.md・知識/ を必須から外し、既存areaは「pilot合格後に追従」の移行注記を付ける）。
5. 先行資料 `2026-07-08-並列実装フロー` の内容が本programへ吸収済みであることを確認し、`merged` close の候補理由を03へ引き継ぐ。

## 完了条件（レビュー項目）

- [ ] `ai運用/AGENTS.md` に identity.md の全項目の統合先があり、対応表で網羅を確認できる。identity.md の削除は承認待ち一覧に載っており、承認前に削除されていない。
- [ ] `知識/` の全ファイルに所有先判定（4分類のいずれか）が付き、移動候補一覧が提示されている。承認なしの移動・削除が無い。
- [ ] 移動を実施した場合、旧pathを参照する箇所がgrepでゼロである（実施前なら対象参照の一覧がある）。
- [ ] 代表の単発plan 1件・program 1件が新テンプレへ移行され、plan-lint・program-lintが通る。
- [ ] `areas/AGENTS.md` §1 が新Area標準を示し、他areaへの適用が「pilot合格後」と明記されている。work/money/healthは変更されていない。
- [ ] 並列実装フローの吸収確認と `merged` close 候補理由が03へ引き継がれている。
