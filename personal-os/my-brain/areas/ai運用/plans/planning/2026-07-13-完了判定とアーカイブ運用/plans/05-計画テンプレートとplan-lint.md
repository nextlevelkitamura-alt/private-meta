親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 都度
人間ゲート: なし

# 計画テンプレートとplan lint

## 目的

plan/program/子計画テンプレートを、そのまま実装担当へ渡せる「実行契約」を持つ形へ拡張し、静的なplan lintで必須項目・placeholder残存・backlink不整合を機械検出できるようにする。本programの全子が依存する共通契約を最初に固定する。

## 非対象

- bucketctl・遷移機構（01）、planctl（07）、triage/handoff側の参照更新（06）
- 既存計画の一括テンプレ移行（代表計画の移行は11のpilotで行う）
- Area標準構成（identity.md・知識/）の規約変更（11がpilot結果と同時に行う）

## 現状

現行テンプレは plan.md・program.md・子計画.md・評価.md・修正.md の5枚（`skills/plan-ops/templates/`）。plan/子計画は 目的/現状/方針/完了条件 が核で、実装担当へ渡すための 非対象・対象repo・読む順番・変更可能/禁止範囲・依存成果・検証・停止条件・完了時に返す情報 を持たない。lintは program-lint（子計画マップ検査）だけで、単発plan・子計画本文の静的検査は無い。このため計画をworkerへ渡すたびに、指揮官が実行契約を口頭・チャットで補っており、指示が丸まって劣化する。

## 実行契約

- 対象repo: `~/Private`（private-meta）
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/skills/plan-ops/SKILL.md`・`references/script-map.md`
  2. `../program.md`（親・正本境界と人間ゲート）
  3. この計画
  4. `../references/2026-07-15-計画実行基盤/02_Codex実装指示書_計画実行基盤.md` §7-8・§12（テンプレ変更・plan lint・result packet書式）
  5. `../references/2026-07-15-計画実行基盤/01_計画実行基盤_現状調査と再設計.md` §7-8（テンプレ全文の設計意図）
- 依存成果: ―（本programの共通契約の起点）
- 変更可能範囲: `skills/plan-ops/templates/`、`skills/plan-ops/scripts/`（plan-lint新設・new-plan.sh/new-child.shの雛形追従）、`skills/plan-ops/__tests__/`、`skills/plan-ops/SKILL.md`・`references/script-map.md` の該当節、`my-brain/areas/AGENTS.md` の「plan.md 統一テンプレ」「プログラム計画」節
- 変更禁止範囲: progctl/bucketctl/program-lint の既存挙動、既存計画本文、`hooks-registry/`、`agents-registry/`
- 維持する契約: 既存5テンプレのファイル名／program-lint互換（既存fixtureが通り続ける）／状態はバケットで持ち `状態:` フィールドを作らない
- 検証: `skills/plan-ops/__tests__/run.sh` 全緑＋plan-lint正常系・異常系テスト
- 停止・エスカレーション条件: program-lint既存fixtureとの互換が保てない／実行結果.jsonのschemaが07・08の要求と矛盾する
- 完了時に返す情報: 02指示書§24の完了報告形式（status・base/result commit・変更ファイル・テスト・リスク・人間判断事項）

## 方針

1. plan.md・子計画.md へ `規模`、`形態判定`（単発/Program子＋理由1行）、`非対象`、`実行契約`（対象repo・最初に読む順番・依存成果・変更可能範囲・変更禁止範囲・維持する契約・検証・停止/エスカレーション条件・完了時に返す情報）を追加する。`実装結果` は実装後にplanctlが追記、`終了記録` はarchive時に追記する旨の注記だけを置き、実行前には節を作らない。
2. program.md テンプレへ `非対象`、`正本境界`、`全体像・実行Wave`、`人間ゲート`、`終了記録` を追加し、子マップ行へ `役割`・`対象repo`・`参照` を加える。モデルID・worktree・branch・session IDはどのテンプレにも入れない。
3. 新規テンプレ3枚を作る。`実行指示.md`（Task Packet。03資料の起動時割当＋共通プロンプト＋役割別追加指示の構成）、`実行結果.json`（result packet。有効なJSON）、`終了記録.md`（01が定める必須項目）。
4. plan-lint を新設する。検査対象: 必須セクション、placeholder残存、子の親backlink、実行契約の必須項目、完了条件1件以上、変更可能/禁止範囲が空でない（または理由明記）、対象repoがある（または `repo無し` と明記）、programマップの必須行、マップと子frontmatterの矛盾。program-lintは互換維持する。
5. 雛形生成（new-plan.sh／new-child.sh）を新テンプレへ追従させ、`areas/AGENTS.md` のテンプレ記述箇所（必須セクションの定義）を新構造と矛盾しない形へ同期する。

## 完了条件（レビュー項目）

- [ ] `templates/` に plan.md・program.md・子計画.md の拡張版と、実行指示.md・実行結果.json・終了記録.md が存在し、実行結果.json が有効なJSONである。
- [ ] どのテンプレにもモデルID・worktree path・branch・session IDのフィールドが無い。
- [ ] plan-lint が、正常planの通過／必須節欠落／placeholder残存／実行契約欠落／子backlink不正／programマップ必須行欠落 をfixtureで検出し、テストが通る。
- [ ] 既存program-lintの全fixture・plan-opsの全テストが変更後も通る。
- [ ] new-plan.sh／new-child.sh が新テンプレで雛形を生成し、生成直後の雛形がplan-lintを（placeholder検査を除き）通る。
- [ ] `areas/AGENTS.md` のテンプレ節が新テンプレ構造と一致し、`状態:` フィールド禁止・バケット正本の原則を変えていない。
