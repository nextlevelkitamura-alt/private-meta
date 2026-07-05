# worktree relocation

複数worktreeがあるrepoだけ読む。

1. `git worktree list --porcelain` を正にする。
2. root/common `.git` を持つworktreeと、linked worktreeを分ける。
3. rootを `mv` するだけだと、linked worktreeの `.git` 参照が旧rootへ残ることがある。
4. linked worktreeは原則 `git worktree move <old> <new>` で動かす。
5. 手で動かした場合は `git worktree repair <linked-worktree-path...>` を必ず実行する。
6. 旧path互換symlinkは作らず、新rootだけで `git status --short --branch` を全worktreeで確認する。
7. 新root側から `git worktree repair <linked-worktree-path...>` を再実行する。
8. 各linked worktreeの `.git` を `cat` し、新root配下の `.git/worktrees/` を指すか確認する。
9. installed LaunchAgentsやruntime設定に旧pathがないことを確認する。
10. build、localhost、launchd再起動など、移動由来の確認だけを通す。
11. lint/testの既存失敗は、移動由来かどうかを分けて報告する。
12. 問題がなければ旧path互換symlink未作成、旧path参照の残存有無、rollback不要をrepo-registryへ短く残す。
