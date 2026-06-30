分類: 横断
種別: 統合整理
形態: program

# 計画親子層の導入

## 目的
単発 plan.md の上に「複数の子計画を束ねて追跡する親層（program）」を入れる。
卒業で子が別repo/基盤へ散ってもドリフトしない追跡を効かせ、タスク実行は基盤の ai-jobs キューへ流す。

## 全体像
親（この program.md）＝索引。子は `plans/` の平置きファイル。整合は次の3点で担保する。
1. 子→親 `親計画:` backlink（子 frontmatter）。
2. 子の状態変更と同コミットで、下の子計画マップを更新。
3. ①②を plan-ops スキルで既定経路化（手で揃えない）。
タスクの実行は基盤 `ai-jobs/`（run-state＝フォルダ位置 ready/running/review/done/archive）。

## 子計画マップ
| NN | 子計画 | 状態 | 場所 | 依存 | 次の一手 |
|----|--------|------|------|------|----------|
| 01 | AGENTS規約追記＋ai-jobs雛形 | active | plans/01 | ― | 反映済・最終検証 |
| 02 | テンプレ確定 | planning | plans/02 | 01 | program.md/子/run-cardの3テンプレ |
| 03 | plan-opsスキル | planning | plans/03（→基盤卒業） | 01,02 | ゲート→workflows→references |
| 04 | 判断系スキル棚卸し | planning | plans/04（→基盤卒業） | 03 | mokuteki/orchestratorの重複整理 |
| 05 | 各repo標準展開 | planning | plans/05（→各repo） | 02 | ai-jobsで並列展開 |

## 完了条件
- areas/AGENTS.md に program層・判定基準・ai-jobs・backlink が記載済み（子01）。
- program.md / 子.md / run-card のテンプレが存在し本programが沿っている（子02）。
- plan-ops が scaffold〜親子集約〜run-card生成を実行できる（子03）。
- 本 program が運用され、子計画マップと実態のドリフトが 0。
- 判断系スキルの absorb/retire 結論がログ化（子04）。

## 関連
- Program B「AI自動実行基盤（Orca運用）」＝ `../2026-06-29-OrcaCLI複数エージェント運用/`。本program（A）に依存（A→B）。Bは ai-jobs を消費して回す。
- area＝傘。A と B は area 配下の焦点programであり、「基盤整備」大programは作らない。
