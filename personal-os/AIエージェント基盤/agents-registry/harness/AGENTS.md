# harness

runtime 非依存の Task Packet 委譲を担当する正本。`delegate.py` が task-scoped
worktree、run manifest、adapter 起動を一貫して管理する。

- 実行時state（manifest、process output、result packet）は対象repoで gitignore
  される state directory にだけ置く。ここへ実行結果やsecretを残さない。
- write task は明示base SHA、task ID ごとの worktree、非交差の変更可能範囲を必須にする。
- conflict、scope 衝突、dirty checkout は停止する。worktree の削除は行わない。
- runtime adapter は薄く保ち、未確認のCLI機能を推測で有効化しない。
- `PLAN_RUN_MANIFEST` は起動する全workerへ渡す。hookはこの値を検査するだけである。
