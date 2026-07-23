親計画: ../program.md ／ 分類: 横断 ／ 種別: 実装
テンプレ: v2
規模: フル
形態判定: Program子 ／ 理由: Codex先行実装とClaude互換検証を同じ共通エンジンで閉じる
並列: 不可 ／ 差し戻し上限: フル=2
自律実行: board DB migration適用・hook登録表変更・Codex公式API自動trust・readback

# Hook順序とrepo実行Context

## 目的

SessionStartでrepo/worktree/cwdを観測して固定policyを返し、UserPromptSubmitの1本の統括ScriptでContext更新・pending受付・候補取得・短い動的Context返却を直列化する。Codex JSONを先に検証し、その後Claude plain textを同じ入力で検証する。

## 非対象

- 同一イベントの複数Hook間で順序を期待すること
- 既存session tableのALTERと推測backfill
- Focusmap UI

## 現状

両runtimeはすでに共通イベントPythonを呼ぶ。現行repo識別はbasenameだけで、Theme/Plan候補注入とpending提案行は未実装。登録pathを維持できれば設定表変更は不要。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤
- 実行形: direct
- 最初に読む順番:
  1. AIエージェント基盤/AGENTS.md・hooks-registry/AGENTS.md
  2. ../program.md
  3. ../実装/共通.md
  4. この計画
  5. hooks-registry/events/*/AGENTS.md・shared/session-board/AGENTS.md
- 依存成果: 子10の分類語彙とpolicy契約
- 変更可能範囲: hooks-registry/events/session-start/、events/prompt-register/、shared/session-board/、codex/hooks.json（必要時のみ）、~/.claude/settings.jsonのhooks項目（必要時のみ）
- 変更禁止範囲: 既存sessions/events/logs/subagents schema、remote URL/credential保存、Focusmap実装
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 非ブロッキング、DB障害時も対話継続、session状態は既存3値、Plan本文は所有しない
- 検証: fake Turso、test_common.py、test_shims.py、Codex JSON/Claude text出力、registered.sh
- 停止・エスカレーション条件: 既存session状態を壊す、Hook出力が上限を超える、登録path変更が必要になる
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

新規additive tableにrepo観測事実とroute proposalを分ける。固定policyは各SessionStartイベント、毎UserPromptSubmitは今日＋対象repoの候補または現在所属だけを含むbounded packetにする。AIが提案を書かなくてもpendingを残す。

## 工程

<!-- 1行1工程。NNは連番、種別は 実装|レビュー|修正、評価は 都度|まとめ。まとめ評価が既定。 -->
- [x] 01 実装: additive migrationとSQL builderをfake DBへ追加する  評価: まとめ
- [x] 02 実装: SessionStartのrepo execution context記録を追加する  評価: まとめ
- [x] 03 実装: UserPromptSubmitのpending・候補packetを直列化する  評価: まとめ
- [x] 04 実装: route-propose / route-context CLIを追加する  評価: まとめ
- [x] 05 実装: Codex JSON出力を先に検証する  評価: まとめ
- [x] 06 実装: Claude plain text出力と既存Orca並列非依存を検証する  評価: まとめ

## 完了条件

- [x] 未登録Git・linked worktree・非Gitcwdを区別したrepo_keyが得られる
- [x] UserPromptSubmitごとにpendingが冪等作成され、AI未提案でも消えない
- [x] SessionStartの固定policyとUserPromptSubmitの候補・required actionが役割分離される
- [x] CodexとClaudeが同じ共通ロジックを異なる出力形式で受け取る
- [x] 既存Hook登録pathと既存session状態テストが維持される

## 実装結果

`routing.py`・`sanitize.py`・追加2表migration・`route-prepare/route-propose/route-context`・共通Hook連携を実装した。全Python回帰とshell shimがPASSし、migrationは本番Tursoへ適用済み。追加2表・3 indexと実DBへのproposal書込み・読戻しも実測した。CodexはJSON、Claudeはplain textで同一内容を返す。Codex SessionStartはapp-server公式APIで自動trustし、対象9 Hookがすべてtrustedであることをreadbackした。子14の統合評価待ち。

## 終了記録

archive時に必須。実行中は記入しない。
