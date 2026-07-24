親計画: ../program.md ／ 分類: repo ／ 種別: 統合整理 ／ 規模: フル
並列: 可（監査先行、書込みはpath別） ／ レビュー: Review 1へ集約

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

## 実行パッケージ

1. **O01 AGENTS/CLAUDE監査**: rootと6領域の本文差・symlink向き・固有指示をread-onlyで記録する。
2. **O02 Skill/hook/loop監査**: cross-repo Skill symlink 3件、repo/global hook、load済みloop、plist source/runtimeを値なしで記録する。
3. **O03 6領域lossless変換**: 人間承認後、1階層ずつregular `AGENTS.md` と相対 `CLAUDE.md -> AGENTS.md` へ変換する。
4. **O04 Global Skill発見試験**: Claude/Codex fresh sessionで発見・明示呼出し・自然言語発火を確認後、承認されたrepo symlinkだけを整理する。
5. **O05 hook合成**: repo/global各1回、書込先、旧root、自動commit 0を確認し、trust変更は別gateにする。
6. **O06 active旧path**: 現役Skill/scriptだけを分類単位で修正し、履歴・生成物を無差別置換しない。
7. **O07 launchd整合**: plist正本/runtime/load/exitを照合し、再登録が必要なら独立人間gateで実行する。

## 並列・rollback

- O01/O02はChild 02と並行するread-only監査。O03/O04/O05は仕事pilot後、allowed pathsが重ならない場合だけ並列可。
- symlink、trust、launchdは単位別commitと復元手順を持つ。loop実装はPASSなら変更しない。

## 実装記録

### 2026-07-13 — O01/O02完了

- 仕事repoは開始/終了とも `master@6e0862e53a93`、Gate 0のdirty 10pathだけで変化0。
- rootはregular `AGENTS.md`＋`CLAUDE.md -> AGENTS.md`。6領域は全件 `AGENTS.md -> CLAUDE.md` の逆向きで、各regular CLAUDEの固有本文hashを固定した。O03は12path＋`DEVELOPMENT.md` を1領域ずつlossless変換する。
- `.agents/skills` は62entry（repo-local 57、cross-repo symlink 3、regular file 2）。`sns-post` はClaudeだけにGlobal露出されているため、Codex/共通ハブ露出→fresh発見試験の前にrepo symlinkを外さない。
- Global hookは5event各1、仕事hookはPostToolUse 5＋Stop 2、Codex/Claude manifestはbyte-identical。自動stage/commit/pushは0。Stop cleanupにtracked-file削除防止がなくO05で修正対象とする。
- Global 4＋仕事3 loopはloaded・last exit 0、`loops-registry/verify.py` は7 PASS。loop実装は変更しない。
- 旧absolute pathはtracked 56file / 114 occurrence。active候補だけを `../references/仕事repo移植台帳.md` に固定し、履歴・backup・handoffを一括置換しない。
- worker-search source plist 2枚は旧root、runtimeはcanonical。O07はtemplate renderとruntime semantic比較後、不一致labelだけ人間承認で再登録する。
- O03〜O07のwriterはGate 0 S05完了まで開始しない。正式採点はReview 1へ集約する。

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
