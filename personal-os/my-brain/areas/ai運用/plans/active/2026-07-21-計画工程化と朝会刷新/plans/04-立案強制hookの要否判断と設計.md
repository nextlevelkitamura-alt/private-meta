親計画: ../program.md ／ 分類: 横断 ／ 種別: 新規作成
規模: フル
形態判定: Program子 ／ 理由: 立案強制の要否判断を独立子として記録し、実装 or 見送りを追跡する
並列: 可 ／ 差し戻し上限: フル=2
人間ゲート: hook登録（実装する場合のみ）

# 子04: 立案強制hookの要否判断と設計

## 目的

「ライト以上の実装を、計画なしで始めたら止める/警告する」強制を hook で持つべきかを判断し、
やるなら最小の設計を出す。現状は助言のみ（強制力なし）で、AIの規律に依存している穴を埋めるか決める。

## 非対象

- 実装を必須にするあらゆる操作への広範なゲート（過剰摩擦）。plan-triage/plan-opsの変更。

## 現状

- 登録hook: register-and-guide（UserPromptSubmit・毎回リマインド注入・exit0＝非ブロック）／guard-plan-bucket-move（PreToolUse Bash・バケット移動の危険操作だけ止める）／capture-subagent-detail／sync-subagent-status／reconcile-and-notify／mark-wait。
- 「計画を立てずに実装するのを止める」hookは無い。強制力は規約＋AIの規律のみ。
- GLOBAL_AGENTS.md §7がサクッと3条件を定義するが、適用はAI任せ。

## 実行契約

- 対象repo: ~/Private（hooks-registry・実装する場合のみ・判断は文書のみ）
- 実行形: delegated-single
- 最初に読む順番:
  1. hooks-registry/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この計画
  5. GLOBAL_AGENTS.md §7（サクッと3条件）・register-and-guide.py（既存hook）
- 依存成果: 子01（工程節の有無を強制対象にできるか次第）
- 変更可能範囲: hooks-registry/events/pre-tool-use/（実装時のみ）・settings.json登録（実装時のみ）・本子の設計文書
- 変更禁止範囲: 既存hookの挙動（register-and-guide等）・plan-triage/plan-ops
- 維持する契約: サクッと（3条件YES）は免除する（正当な軽微実装を止めない）
- 検証: 実装する場合はhook単体で「計画なし実装→警告・サクッと→通過」を確認。見送る場合は判断根拠の記録
- 停止・エスカレーション条件: 誤検知で正当なサクッと実装まで止める設計しか作れない場合は見送りを記録
- 完了時に返す情報: result packet（status / 判断結果=実装or見送り / changed_paths / remaining_risks）

## 方針

1. 要否判断: 立案強制がもたらす安全性と、正当なサクッと（3条件YES）への摩擦を比較する。
2. 実装するなら最小案: 実装系ツール（Edit/Write等）使用前のPreToolUseで、対象repoに紐づくactive計画/当日起票の有無を確認し、無ければ**警告のみ**（ブロックしない）から始める。段階的に強度を上げる。
3. サクッと（GLOBAL_AGENTS.md §7の3条件）は明示的に免除する経路を持つ（摩擦の最小化）。
4. 見送る場合: 理由（誤検知・摩擦・規律で足りる）を記録し、代わりに子03の朝会で計画確認を担保する方針にする。

## 完了条件

- [x] 立案強制hookの要否が根拠付きで判断され、記録がある（対象: 本子の実装結果 or 見送り記録）
- [ ] 実装する場合: 警告hookが登録され、サクッと3条件は免除される（対象: hooks-registry・settings.json）※hook本体は実装・単体検証済み／登録は人間ゲート保留
- [ ] 見送る場合: 代替（朝会での計画確認）で穴が埋まることを明記（対象: 本子・子03との整合）※対象外（人間が段階1採用を選択）

## 実装結果

- status: 判断・実装済み（人間判断=段階1採用）／hook登録の人間ゲートが保留。
- 判断: references/子04-立案強制hook判断.md（見送り側の分析＋段階案）。人間は見送りでなく段階1を選択。
- changed_paths: hooks-registry/events/pre-tool-use/{guard-plan-gate.py(新),guard-plan-gate.md(新),AGENTS.md(2hook反映)}・references/子04-立案強制hook判断.md。
- 検証: guard-plan-gate.py単体（.git+active計画→免除／なし→警告1回／別session再警告／.md・scratchpad免除／異常入力exit0）。
- 人間ゲート保留: guard-plan-gate登録（settings.json＋codex hooks.json＋再trust）。未登録＝現在は作用しない。
- サクッと免除: 免除条件に.md・active計画・session1回を実装（3条件の完全自動判定は原理的に不可のため弱い信号でwarn-only）。

## 終了記録

archive時に必須。実行中は記入しない。
