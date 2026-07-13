親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
並列: 不可 ／ レビュー: 都度

# Prompt Submit計画注入の再設計

## 目的

計画を作る時に UserPromptSubmit が渡す案内を、状態遷移とバケット上限の正本に一致させる。初回ガイドは必要な判断だけ、2回目以降は現在の計画状態に応じた最小の次手だけを注入する。

## 現状

共有本体 `hooks/session-board/common.py` の `_first_guide` と `_mirror` が、計画の3判定、`評価NN.md`、`全PASS=done` を文字列で直接注入している。`session-start.md` はそのガイド相当を説明し、`session-end.md` は人間確認後に `finish` するセッション終了手順を持つ。これらは計画バケットの archive 操作と独立であること、active=3／paused=3／done=8の容量を明示していない。

Codex と Claude の prompt-register は薄いシムで、注入本文の正本は `common.py` である。本文を各runtimeの受け口や複数MDへコピーすると二重管理になる。

## 方針

1. 01で決めた語彙を使い、初回ガイドを「既存計画確認 → planning に起案 → 指揮官が active 化 → 最終評価PASSで done → 人間が明示確認して archive」の5段階と、`active=3 / paused=3 / done=8 / planning・archive=無制限`として短く案内する。詳細規約は正本へのポインタに留める。
2. ミラー注入は常に状態を推測しない。計画種別には、今どのバケットかを確認して `bucketctl check` で容量を見てから次操作を選ぶよう促し、実装・レビューには「評価PASS後は done、archive は人間確認後」「満杯なら人間へ候補を返し、自動退避しない」の境界だけを出す。
3. `session-board finish` はデイリーのセッション記録を閉じる操作であり、計画 archive の許可や実行ではないと、`common.py`、`session-start.md`、`session-end.md`、README、Claude milestone に同じ責務境界で記す。自動 `git mv` はフックに足さない。
4. 動的な注入本文は `common.py` に一箇所だけ置き、README／手順MDは生成元と責務を説明する。Codex/Claudeのシムは変更不要なら触らない。
5. `tests/test_common.py` に初回ガイド・計画ミラー・実装ミラー・曖昧な完了時の非archiveを追加し、必要に応じてshims E2Eも更新する。hook変更後のCodex再trust要否は既存の登録規約に従い、実際のtrust操作は人間確認の範囲で扱う。

## 完了条件（レビュー項目）

- [ ] 初回・ミラー注入に planning→active→done→archive の責務分離と active=3／paused=3／done=8 の容量案内があり、旧 `done=未評価` や自動archiveを示す文言が残っていない。
- [ ] 注入は `bucketctl check` を容量の事実確認先にし、満杯時にAIが自動退避せず人間判断を求めることを明示する。
- [ ] `finish` と archive の非同一性が `common.py`、session-start/end、README、milestone の対象箇所で一致する。
- [ ] Prompt Submit の本文は共有 `common.py` が唯一の生成元であり、runtime別シムに本文コピーを増やしていない。
- [ ] 変更した注入文字列を対象にした `test_common.py` と既存session-boardテストが通る。
- [ ] Codex/Claudeのhook登録・trustに必要な人間操作を、変更の有無に応じて完了報告へ明示できる。
