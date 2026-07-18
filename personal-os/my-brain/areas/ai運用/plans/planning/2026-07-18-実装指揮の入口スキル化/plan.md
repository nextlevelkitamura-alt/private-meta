分類: skill ／ 種別: 新規作成
規模: ライト
形態判定: 単発 ／ 理由: 薄いSkill1本＋hook注入文1行＋相互参照のみで、独立卒業する子は不要
並列: 不可 ／ レビュー: 都度 ／ 差し戻し上限: 1（ライト）
人間ゲート: hook注入文（session-board common.py）の変更・Global Skill新設のruntime露出

# 実装指揮の入口スキル化

## 目的

計画（plan.md / program.md）が完成して実装フェーズに入った瞬間に、対話型の指揮官（メインセッション）が開く「束ねた入口」を1枚作る。指揮官がサブエージェントへ並列委任する際の、(a)必読コンテキストの順序（対象repoのAGENTS.md → 親program.md → 実装/共通.md → 子計画md）、(b)並列レーンの組み方（並列宣言・ファイル交差・レーン上限3）、(c)人間ゲートで止めさせる委任プロンプトの書き方、(d)result packet回収→都度/一括レビュー接続、を成文化し、実装開始時に確実に参照される導線を付ける。

## 非対象

- delegate.py・program_run.py・roles等の既存機構の改修（参照するだけ。本文コピーしない）
- codex-impl（Codex単発ループ）の変更（相互参照に留める）
- Orca/cockpit-supervisor系の変更（実装レーンにOrcaは使わない方針のまま）
- 実装ワーカー側の契約変更（roles/implementer.md・reviewer.mdは現状維持）

## 現状

- 2026-07-18の調査（Opus・読み取り専用）で確認済み: 機構部品はほぼ揃っている。役割別の読み順は agents-registry/harness/delegate.py `_reading_steps()` が機械実装済み（ただしdelegate.py経由の委任限定で、素のサブエージェント委任では注入されない）。並列規約（指揮官3レーン・同時レビュー2本・ファイル担当・worktree方針）は plan-registry/AGENTS.md にあるが散文のみ。単発委任ループは codex-impl.md（Codex専用）。
- 欠けているのは「対話型・非Orca・非フル自動の指揮官が実装開始時に開く束ねた入口」1枚（機構ギャップではなく導線ギャップ）。
- hook注入文の生成元は hooks-registry/shared/session-board/common.py（初回=_first_guide のフルガイド／毎ターン=_mirror の2〜3行ミラー。「レビュー宣言を確認…」の現行1行は _mirror 内の 種別=計画/実装 分岐）。フル手順の毎ターン注入は既存設計の流儀に反するため、1行参照が正。
- 先行計画 `planning/2026-07-17-worker役割別コンテキストと評価フォルダ分離`（評価02全PASS・完了済み）のドッグフーディング課題#4「読み順分岐の実地検証は次の実programで」の自然な続き。
- 実例: 2026-07-17-当日ボードSQL化 子05/06 のOpus 2レーン並列委任（2026-07-18）で、編成判断・委任プロンプトが指揮官の頭の中とチャットにしか無いことを実地確認。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤（skills/・hooks-registry/shared/session-board/）
- 実行形: delegated-single
- 最初に読む順番:
  1. AIエージェント基盤/AGENTS.md
  2. この計画
  3. global-skill-registry/AGENTS.md（Skill新設・命名・露出規約）
  4. plan-registry/AGENTS.md §2-4（並列・レビュー・責務地図）
  5. agents-registry/harness/delegate.py・roles/・claude/commands/codex-impl.md・hooks-registry/shared/session-board/common.py（参照先の現物）
- 依存成果: なし
- 変更可能範囲: 新Skillフォルダ（skills/配下）・common.py の _mirror 実装分岐1行・plan-registry/AGENTS.md の相互参照1行・runtime露出symlink
- 変更禁止範囲: delegate.py・program_run.py・roles本文・codex-impl.md本文・board.pyの状態遷移・_first_guide以外の注入文構造
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 手順の正本はSkill側1箇所（既存正本の本文をコピーしない・相対参照のみ）・注入は1行導線のみ・hookはSkill実行やレビュー合否を強制しない（plan-registry §4）
- 検証: session-board tests 全通過・注入文の実出力確認（種別=実装かつ計画ありで1行が出る／それ以外で出ない）・Skillの5runtime露出確認
- 停止・エスカレーション条件: common.py変更の承認前・Skill名/新設か縮小案かの計画レビュー裁定前
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

1. **薄いGlobal Skillを新設**（案A）: 内容は (a)必読順序（delegate.py `_reading_steps` と同一の順。二重定義にならないよう「正本はdelegate.py・ここは対話委任向けの写像」と明記） (b)並列レーン編成の判断手順（子計画の`並列:`宣言→ファイル交差確認→上限3・同時レビュー2） (c)委任プロンプト雛形（人間ゲートを「準備までで停止・報告」と書き込む定型・result packet要求） (d)回収後の都度/一括レビュー接続（impl-reviewer・評価NN.md・planctl同期への導線）。すべて既存正本への参照で構成し本文コピーしない
2. **hook注入文に1行参照**（案C併用）: common.py `_mirror()` の 種別=実装 かつ 計画あり分岐に、実装開始時はこのSkillを開く旨の1行を追加（人間ゲート）
3. **相互参照**: plan-registry/AGENTS.md 責務地図に本Skillの1行を追加（規約はregistry・手順はSkill、の分担を明記）
4. **計画レビューで人間と決める点**（未確定のまま起案）: 新Skill名（利用者意図の動詞名・内部名を打たせない規約に従う）／新設ではなく codex-impl をruntime中立の委任指揮コマンドへ拡張する縮小案との二択の最終裁定
5. Skillの露出は基本5runtime全露出（global-skill-registry規約に従う）

## 完了条件（レビュー項目）

- [ ] 実装開始時の指揮官手順（読み順・並列編成・人間ゲート止め委任プロンプト・result回収→レビュー接続）が1箇所のSkill（または裁定次第で拡張コマンド）にまとまり、既存正本（delegate.py・plan-registry・codex-impl・roles）の本文コピーが無い（対象: 新Skill本文）
- [ ] UserPromptSubmit注入文で、種別=実装かつ計画ありの時だけ入口への1行導線が出て、それ以外の種別では出ない。毎ターン注入が1行を超えない（対象: common.py・注入文実出力）
- [ ] plan-registry/AGENTS.md 責務地図と新入口の間で責務が矛盾しない（規約=registry／手順=Skill）（対象: plan-registry/AGENTS.md）
- [ ] session-board tests が全通過し、既存の _first_guide／ミラー挙動に回帰がない（対象: session-board tests）
- [ ] Skillが規約どおりruntimeへ露出され、二重登録が無い（対象: 露出symlink・global-skill-registry）

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
