# guard-plan-closeout.py

`Stop`で`PLAN_RUN_MANIFEST`を安全に読む。manifest不在・不正は通し、`review_passed`未同期だけを
`decision:block`で一回継続させる。`running` / `implemented` / `synced` / `closed` / `blocked`は通す。
`planctl rename --check`は日付陳腐化の案内だけに使い、計画のrenameや同期を実行しない。

`mark-wait.py`とは別handlerであり、session-boardの状態更新に依存しない。runtime登録は未適用。
