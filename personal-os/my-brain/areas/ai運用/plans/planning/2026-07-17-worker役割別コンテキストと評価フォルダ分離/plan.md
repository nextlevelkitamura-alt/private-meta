# 計画: worker役割別コンテキストと評価フォルダ分離

- 状態: planning（activeが5/3で満杯超過中のため、承認②の排水後に昇格して実装開始）
- 規模: ライト（実装 → 実装レビュー1パス・差し戻し上限1 → 事後報告）
- 起点: 2026-07-17 人間要望「実装者とレビュアーで読むコンテキストを分けたい」「plans内の子計画と評価をフォルダ分けして見やすくしたい」
- 設計合意: 人間向け図解（Artifact）で2026-07-17に合意済み
  - 設計本文: https://claude.ai/code/artifact/0632ee90-8f4d-47e7-8e49-caef90b3109b （v2: 評価フォルダ分離を含む）
- 調査根拠: Exploreサブエージェントによる配線調査（2026-07-17・本計画起票の直前）。要点: worker読み順の組み立ては delegate.py render_task_packet の1箇所に集約・role差は末尾1行のみ・program_run の implement/review は program_path=None で親programを渡していない。
- 人間ゲート: 標準テンプレ変更（新フォルダ 実装/・レビュー/・評価/ の追加）は2026-07-17の対話で承認済み。hook増設なし。pushは別途明示依頼時のみ。

## 方針

1. programフォルダに役割別コンテキストを標準装備する: `実装/共通.md`（実装担当の共通規約）と `レビュー/共通.md`（レビュアーが気をつけること）。program.mdは「何をするか（流れ）」、共通.mdは「その役割がどう振る舞うか」だけを書き、相互コピーしない。
2. 委譲パケットの「最初に読む順番」を役割分岐にする: 実装= 最寄りAGENTS → program.md → 実装/共通.md → 自分の子計画 → references。レビュー= 最寄りAGENTS → program.md → レビュー/共通.md → 対象子の完了条件 → 実装diff。実装にはレビュー/共通.mdを載せず、レビューには実装/共通.mdを載せない。
3. program_run の implement/review が program_path を実際に渡す（現状Noneの欠落修正）。共通ファイルと評価フォルダのpathはprogramフォルダから機械導出し、manifestへ新フィールドは追加しない（schema・validate群4箇所の同時改修を避ける）。
4. programの評価NN.md・修正NN.mdの置き場を `plans/` 隣接から `評価/` へ分離する（ファイル名規約 `NN-〈子名〉-評価NN.md` は不変）。単発planは従来どおり plan.md 隣接。既存programは旧配置のまま読める両対応（評価/優先→plans/隣接フォールバック）とし、既存計画の移動はしない。
5. hookは増設しない。roles定義（implementer.md / reviewer.md）には「役割別共通ファイルを読む」の一文のみ追加し、パス直書きはしない。

## 変更対象（見込み）

- agents-registry/harness/delegate.py（読み順の役割分岐・共通ファイル/評価pathの導出）
- agents-registry/harness/program_run.py（program_path受け渡し・評価保存先の切替）
- skills/plan-ops/templates/program.md・実行指示.md・子計画.md（役割別コンテキスト欄と読み順）
- skills/plan-ops/scripts/planctl.py・plan-lint.sh（評価path両対応・programの共通ファイル存在チェック）
- skills/plan-create-review/workflows/create-or-join.md・review-and-transition.md（生成物と読み物の明文化）
- agents-registry/roles/implementer.md・reviewer.md（一文追加）
- 上記のテスト追従（harness・plan-ops・必要ならplan-closeout）

## 完了条件（レビュー項目）

- [ ] programテンプレ一式から新規programを生成すると、実装/共通.md・レビュー/共通.md・評価/ が生まれる（雛形scriptの機械実行で確認）
- [ ] implementer向けパケットの読み順が「AGENTS → program.md → 実装/共通.md → 子計画 → references」の順で出力され、レビュー/共通.md を含まない（テストで固定）
- [ ] reviewer向けパケットの読み順が「AGENTS → program.md → レビュー/共通.md → 対象子の完了条件 → diff」で出力され、実装/共通.md を含まない（テストで固定）
- [ ] program_run の implement/review が program_path を渡し、パケットの「親program」が実pathになる（None欠落の解消をテストで固定）
- [ ] programの評価・修正の新規保存先が 評価/ になり、planctl・program-lint・閉鎖ゲートが「評価/優先→plans/隣接フォールバック」の両対応で旧programも全PASS判定できる
- [ ] manifest schema・manifest.py・planctl MANIFEST_TYPES・plan-closeout MANIFEST_REQUIRED に差分がない（新フィールド不追加の確認）
- [ ] hooks登録（~/.claude/settings.json・hooks-registry/codex/hooks.json）に差分がない
- [ ] 既存テスト（harness・plan-ops・plan-closeout・session-board）が全緑＋新分岐のテストが追加されている

## 実装結果

実装後に追記する。実行前は記入しない。
