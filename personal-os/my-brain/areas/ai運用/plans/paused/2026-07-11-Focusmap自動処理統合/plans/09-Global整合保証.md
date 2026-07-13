親計画: ../program.md ／ 分類: loop ／ 種別: 既存改善 ／ 規模: フル

# 09 Global整合保証

## 目的

Focusmapがsession-board mirrorを読む前提として、board-sweepの自動完了を冪等化し、MD / Turso現在値の欠測とgoal-addの偽成功を修復する。Focusmap repo-local hook / agentは触らない。

## 現状

- board-sweepは毎時 `--apply` でloaded。二重鍵は強いがrun全体lockがない。
- `board.py finish` は対象行が無くても完了子を追記でき、並行runで重複し得る。
- spool対象はevents / logsのみ。sessions upsert / delete、reconcile、goal-addは失敗後に修復されない。
- hook timeoutは10秒だが、複数board.py呼出と同期Turso送信 / replayが連なる。

## 方針

### A. 自動完了の排他・冪等性

- board-sweep全体に専用flockを入れる。
- 自動finishは対象行の存在を条件にするか、date + session key + finish kindの冪等keyを持つ。
- 二重鍵、unknown無変更、実計画行除外、1回3件上限、LLM read-onlyは維持する。

### B. MD / Turso parity

- MD正本は変えない。
- sessions現在値はoutbox / periodic reconcile / snapshot repairのいずれか1方式に決め、複数repair writerを作らない。
- finish delete、reconcile wait、通常upsertの欠測を検出して最終一致させる。
- 古いupsertが新しいdelete / stateを上書きしないrevision契約を持つ。

### C. goal-addとtimeout

- goal-addはaccepted / retrying / failedを返し、失敗を成功扱いしない。
- 子02は本子計画がPASSするまでaddGoalをOFFにする。
- hook本線はMD確定を優先し、Turso障害時もruntime timeout budget内で終了する。
- replayを本線から分離する場合も、追加loop / launchdは人間ゲート。

### commit境界

1. board-sweep排他・冪等化。
2. session parity / outbox。
3. goal-add ack / timeout budget。

別repo作業やFocusmap UIを同じcommitへ混ぜない。

## 完了条件（レビュー項目）

- [ ] board-sweep並行2runで同じsession keyの自動完了が1件だけになる。
- [ ] 条件不成立 / unknown / LLM失敗 / 実計画行では0件変更になる。
- [ ] finish / reconcile / upsert欠測が選択した単一repair方式で最終一致し、完了sessionがrunで残らない。
- [ ] 古いretryが新しいdelete / stateを上書きしない。
- [ ] goal-add失敗がacceptedにならず、retrying / failedを呼出側が区別できる。
- [ ] Turso障害時もMD確定がruntime timeout budget内で完了し、Turso失敗がMDへ逆伝播しない。
- [ ] 既存session-board / 4 loopsのテストに回帰がなく、追加テストが外部DB / secretへ触れない。

