親計画: ../program.md ／ 分類: skill ／ 種別: 新規作成
並列: 不可 ／ レビュー: 都度

# plan-management Skillを新設

## 目的

「どこへ計画を置くか」「既存の計画へ合流するか」「子計画を作るか」「レビューへ進めるか」を、利用者が1つのSkillから扱えるようにする。経路判定とscriptを再実装せず、既存Skillの責務を呼び分ける。

## 現状

- `kickoff` は依頼をデイリーへ起票する入口、`plan-triage` は書き込まない経路解決、`plan-ops` は雛形・lint・昇格の手続きである。
- これらを順番に読む必要があり、計画そのものを管理したい利用者の入口がない。
- `plan-triage` はすでに短いrouterへ再編中であり、その未コミット変更に責務を足さない。

## 方針

1. `AIエージェント基盤/skills/plan-management/` にGlobal meta Skillを新設する。`SKILL.md` は60行以下を目標にし、目的、発火、workflow選択、絶対境界、`plan-registry/AGENTS.md` への直接参照だけを置く。
2. workflowは自然な利用目的が異なる3本に分ける。
   - `create-or-join.md`: `plan-triage` で既存plan/正しい箱を解決し、解決後だけ `plan-ops` で雛形を作成して内容を埋める。
   - `manage-program.md`: program化、子の追加、子計画マップ更新、依存・並列・レビューの記録を扱う。新規マップ行は人が判断して書き、既存行更新だけ `progctl` を使う。
   - `review-and-transition.md`: レビュー項目、評価/修正、done、人間確認、archiveの境界を扱う。移動・runtime変更は人間ゲートへ止める。
3. Skill自身にscript、template、規模基準、経路JSONを複製しない。`plan-triage` / `plan-ops` / `plan-registry` の正本を明示して委譲する。
4. `SKILL.html`、Global Skill作成ログ、catalog `meta.md` を同じ作業単位で更新する。runtime露出は差分確認後の人間承認まで保留し、ログには未露出バックログを記録する。

## 完了条件（レビュー項目）

- [x] `SKILL.md` が70行以内で、3 workflowとregistryを1ホップで参照できる。
- [x] 各workflowに、起動条件、入力、期待出力、失敗時の停止、人間ゲート、親Skillへの戻り先、完了確認が書かれている。
- [x] `kickoff`、`plan-triage`、`plan-ops`、`cockpit-supervisor` と発火条件・副作用・出力が重複していない。
- [x] 正本path、catalog、作成ログ、`SKILL.html` が一致し、runtime symlinkを未承認で作成していない。
- [x] `SKILL.html` が白背景で、入口Skill→既存Skill→計画文書の関係を説明できる。
