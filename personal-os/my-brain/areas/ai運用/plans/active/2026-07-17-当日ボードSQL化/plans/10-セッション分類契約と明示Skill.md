親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
テンプレ: v2
規模: フル
形態判定: Program子 ／ 理由: session-board・Focusmap・Global Skillの共通分類契約を先行確定する
並列: 不可 ／ 差し戻し上限: フル=2
自律実行: Global Skill新設・runtime露出・readback

# セッション分類契約と明示Skill

## 目的

Hookが毎promptで使う短い分類方針と、人間が未分類をまとめて再評価するGlobal Skillを分離し、Codex / Claude / Focusmapで同じ分類語彙を使える状態にする。

## 非対象

- HookからSkillを直接起動すること
- Theme・Planを意味類似だけで自動確定すること
- Focusmap UIと本番DB migrationの適用

## 現状

現行UserPromptSubmitは初回ガイドとsessionミラーを注入するが、Theme内単発・新Plan候補・新Theme候補の構造化判断契約がない。Skill全文の強制注入はSkill invocationではないため採用しない。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤
- 実行形: direct
- 最初に読む順番:
  1. AIエージェント基盤/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この計画
  5. harness-registry/focusmap-daily.md・global-skill-registry/AGENTS.md
- 依存成果: 子09のTheme階層とsession所属契約
- 変更可能範囲: AIエージェント基盤/skills/session-routing/、global-skill-registry/、harness-registry/focusmap-daily.*
- 変更禁止範囲: 既存Skill本文、runtime露出先の本文コピー、Focusmap実装
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 毎prompt必須の方針はHook専用policy、Skillは明示再分類だけ。Plan本文はrepo Markdown正本。
- 検証: Skill quick_validate、SKILL.html描画、catalog/log整合、policyとの語彙一致
- 停止・エスカレーション条件: 近接Skillと発火条件が競合する、Skillが自動DB書込みを所有する
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

分類語彙を `plan`・`theme_work`・`plan_candidate`・`theme_candidate`・`unclassified` の5種に固定する。自動Hookのpolicyは短い固定方針、人間が明示するSkillは再評価・付け替え・Plan化handoffだけを扱う。

## 工程

<!-- 1行1工程。NNは連番、種別は 実装|レビュー|修正、評価は 都度|まとめ。まとめ評価が既定。 -->
- [x] 01 実装: 近接Skillと正本境界を確認する  評価: まとめ
- [x] 02 実装: session-routing Skillと人間向けSKILL.htmlを作る  評価: まとめ
- [x] 03 実装: policyの分類語彙とstructured output契約を正本化する  評価: まとめ
- [x] 04 実装: catalog・created log・harness説明を同期する  評価: まとめ

## 完了条件

- [x] Hook policyとSkillが同じ分類語彙を使い、同じ本文を二重管理していない
- [x] Skillは70行以内のrouterで、自動Hookの副作用を所有しない
- [x] Codex / Claudeのどちらからも1つの正本へ露出される
- [x] SKILL.html、catalog、created log、harness説明が更新されている

## 実装結果

`skills/session-routing/`、`events/prompt-register/session-classification-policy.md`、catalog・created log・`harness-registry/focusmap-daily.*`を同期した。Skillは61行、`quick_validate.py` PASS。HookはSkillを自動起動せず、固定policyと明示再分類Skillを分離した。子14の統合評価待ち。

## 終了記録

archive時に必須。実行中は記入しない。
