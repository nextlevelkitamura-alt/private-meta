# verify-plan-worker.py

`SubagentStart`ではimplementerのmanifestと観測できる`cwd`／branch／baseを照合し、不一致は
`systemMessage`で警告するだけで開始を止めない。read-only roleはworktree照合を省略する。

`SubagentStop`ではimplementerのresult packet、reviewerの評価MD必須項目を読む。欠落時だけ
`decision:block`で一回継続を求め、`stop_hook_active=true`なら通す。explorerは構造化結果の内容を評価しない。
既存の`sync-subagent-status.py`とは別handlerで、状態やworktreeを変更しない。runtime登録は未適用。
