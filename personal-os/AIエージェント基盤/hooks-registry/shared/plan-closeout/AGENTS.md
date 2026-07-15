# shared/plan-closeout — 計画完了guardの共通判定

`PLAN_RUN_MANIFEST` を読むStop・Subagent guardのruntime非依存判定を置く。イベント受け口は
`../../events/`、session-boardの状態更新は隣の`../session-board/`が正本であり、ここは触らない。

- manifest不在・不正・内部失敗は必ずfail-openする。
- 正常に検証できた`review_passed`未同期、implementerのresult欠落、reviewerの評価欠落だけを一回継続要求できる。
- `stop_hook_active`が真なら再blockしない。永続カウンタ、計画本文、バケット、manifest、result packetは変更しない。
- `planctl rename --check` は案内用に読み取り実行するだけで、renameは実行しない。

`tests/` は共通判定と両runtimeのstdin/stdout fixtureを検証する。`CLAUDE.md`はこのファイルへの相対symlink。
