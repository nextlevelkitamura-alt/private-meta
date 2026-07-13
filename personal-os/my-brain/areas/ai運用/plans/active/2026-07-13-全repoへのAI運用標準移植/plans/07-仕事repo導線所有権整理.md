親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 不可 ／ レビュー: 都度

# 仕事repo導線所有権整理

## 目的

AGENTS/CLAUDE、Skill、hook、loop、runtime露出の所有者を人間が追える形に揃え、移植後の二重正本と壊れたsymlinkをなくす。

## 現状

1. 仕事rootの `CLAUDE.md -> AGENTS.md` と `.claude/skills -> ../.agents/skills` は標準どおりである。
2. `領域/*` の複数階層では、regular `CLAUDE.md` を正本にして `AGENTS.md -> CLAUDE.md` とする逆向き互換が残る。
3. `.agents/skills/` にGlobal Skillへのsymlinkがあり、一部は基盤正本でなくruntime露出先を参照する。
4. repo-local hookはGlobal hookと同時にtrust登録されており、合成仕様を無視して削除・追加できない。
5. dispatcher等の仕事固有loop実装とGlobal loop一覧の分離は既に機能している。
6. Subagent hook、board-sweep、board-reconcile、trust登録の説明は文書と実runtimeが一致する保証がなく、古い説明だけを根拠に変更できない。

## 方針

1. 階層ごとにAGENTS/CLAUDE本文差分と参照consumerを調べ、固有本文をAGENTSへ移す案を人間に提示する。
2. symlinkの向き変更は削除・改名を伴う人間ゲートとし、1階層ずつ実施する。
3. `.agents/skills` はrepo-local Skill正本、Global Skillはruntime露出から利用する原則へ揃える。
4. Global Skill symlinkを外す前に、Claude/Codex双方の発見順・自然言語発火・明示呼出しを実測する。
5. repo-local/global hookは責務、発火イベント、書込先、重複を一覧化し、自動commitを持たない合成へ揃える。hookは計画pathを決めず、Privateから仕事repoへ移った後の対象repo contextでだけrepo固有後処理を行う。
6. 旧絶対pathは現役参照だけを修正し、履歴文書を無差別に書き換えない。
7. 稼働loopは所有権が正しいため、移動せず検証結果だけを残す。
8. hook・sweep・reconcile・trustは実runtime登録と実行結果を先にread-only監査し、文書は実測結果へ合わせる。load状態やlaunchd、runtime symlinkの変更は別の人間ゲートにする。

## 完了条件（レビュー項目）

- [ ] 仕事rootと対象 `領域/*` で、正本がregular `AGENTS.md`、互換が相対 `CLAUDE.md -> AGENTS.md` である。
- [ ] symlink向き変更前の固有指示が失われず、Claude/Codexの両方から解決する。
- [ ] `.agents/skills` の各entryにrepo-local / Global-runtime / externalの所有者が一意に定まり、runtime露出先を正本と呼ぶ記述がない。
- [ ] Global Skill symlink整理後も、対象Skillの発見・明示呼出し・自然言語発火がClaude/CodexでPASSする。
- [ ] repo-local/global hookの責務表に、イベント・書込先・発火回数・安全ゲートがある。
- [ ] Subagent hook、board-sweep、board-reconcile、trust登録が実runtime基準で確認され、停止済み・未loadの仕組みを稼働中と説明していない。
- [ ] 計画ルーティングはAGENTS/plan-triageが担い、hook内に担当repo・領域・計画pathの判断がない。
- [ ] Private側へ仕事repo固有hook本文を複製せず、仕事repo contextに入った時だけrepo-local hookが発火する。
- [ ] activeな旧root絶対pathが0件で、履歴文書の不要な全置換がない。
- [ ] 稼働中の仕事loopが同じ所有repo・実行間隔・Global一覧接続でPASSする。
- [ ] 削除・改名・symlink変更は人間承認済みのpathだけである。
