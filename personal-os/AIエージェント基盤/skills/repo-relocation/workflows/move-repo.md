# move-repo

既存repoを別フォルダへ移動する標準手順。

旧パス互換symlinkは標準では作らない。移動は新パスを正本にし、旧パス参照を更新して、新パスだけで動く状態まで検証する。

## 1. 入力

1. 旧path。
2. 新path。
3. repo-id。
4. launchdを本登録してよい対象。

足りない場合は推測で移動せず、短く確認する。

## 2. 移動前スキャン

1. `AGENTS.md` を読む。
2. `git status --short --branch` を見る。
3. `git remote -v` を見る。
4. `git worktree list --porcelain` を見る。
   複数worktreeがある場合だけ `references/worktree-relocation.md` も読む。
5. repo内の旧path絶対参照を検索する。
6. `~/Library/LaunchAgents/*.plist` の旧path参照を検索する。
7. `.codex`、`.claude`、`.agents`、MCP設定、Playwright storageState、auth.json系のpath参照を確認する。secret値は表示しない。
8. 旧pathへ向いているsymlinkを検索し、runtime露出、手作業リンク、互換リンクを分けて記録する。

## 3. 移動と旧パス参照更新

1. 新pathの親ディレクトリを作る。
2. 新pathが空いていることを確認する。
3. repoを旧pathから新pathへ移動する。
4. 旧pathに互換symlinkを作らない。
5. 新pathで `git rev-parse --show-toplevel` と `git status --short --branch` を確認する。
6. 旧pathが存在しない、または移動対象ではない別物になっていないことを確認する。
7. 移動前スキャンで見つけた旧path参照を、新pathへ更新する。
8. 旧pathへ向いていたruntime symlinkは、新pathの正本へ直接張り替える。
9. `git worktree list --porcelain` に複数worktreeがある場合、root/common `.git` とlinked worktreeを分けて記録する。
10. linked worktreeも整理対象なら、同じ作業で新しい置き場へ `git worktree move <worktree> <new-path>` する。
11. worktree移動やroot移動の後は `git worktree repair <linked-worktree-path...>` を実行し、各worktreeの `.git` が新root配下を指すことを確認する。
12. 旧path参照が残る場合は、すぐ壊れる参照か、履歴・ログ・旧pathメモとして残してよい参照かを分けて記録する。

## 4. launchd

launchdがないrepoでは、この章は「該当なし」と記録する。

launchdがあるrepoでは、repo内に `scripts/launchd/install.sh` と `scripts/launchd/status.sh` があるか確認する。なければ、そのrepoの既存plistに合わせて最小版を作る。

最小版に入れるもの:

1. `--dry-run`
2. `core`
3. `all`
4. `--unload`
5. 旧rootから新rootへの置換
6. `plutil -lint`
7. `launchctl bootout`、`bootstrap`、`enable`
8. `bootout` 直後の `bootstrap` 失敗に備えた短いretry
9. `current-root`、`old-root-reference`、`other-root` の表示

本登録前に必ず確認すること:

1. `RunAtLoad`
2. `StartInterval` または `StartCalendarInterval`
3. 実行コマンド
4. ログ出力先
5. 外部送信・外部書き込みの可能性

起動してよい対象だけ本登録し、`launchctl print`、必要なら `kickstart`、ログ更新時刻で反応を見る。

## 5. テスト

1. dry-run系を実行する。
2. read-only系を実行する。
3. launchdは `loaded`、`current-root`、`runs`、`last exit code`、ログ更新時刻を見る。
4. 失敗は `移動由来`、`既存の認証/外部サービス由来`、`未分類` に分ける。
5. 外部更新系の本処理は、ユーザーが明示しない限り実行しない。
6. runtime symlinkがあるrepoでは、runtime側の入口から主要ファイルが読めることを確認する。
7. 旧path参照が残っていないか再検索する。履歴や移行ログの旧pathは、残してよい参照として分類する。

## 6. rollback判断

旧パス互換symlinkは作らないため、失敗時はsymlinkで隠さず、原因別に判断する。

1. 移動由来の失敗で、短時間で修正できる場合は、新path側で参照更新や設定修正を行う。
2. 移動由来の失敗で、修正範囲が大きい場合は、repoを旧pathへ戻す案を出す。
3. 既存の認証・外部サービス由来の失敗は、移動完了を妨げるかを分けて報告する。
4. rollbackする場合は、新pathから旧pathへ `mv` で戻し、Git状態と主要テストを確認する。
5. rollback後も、runtime symlinkやlaunchdなど移動中に更新した参照を旧pathへ戻す。
6. rollbackしない場合は、旧path互換symlinkなしで完了できる根拠を最終報告に書く。

## 7. repo-registry記録

`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/` のルールに従い、必要なprofileと移動ログだけを更新する。

profileに書く最小項目:

1. Path
2. Remote
3. 目的
4. AGENTS.md状態
5. launchd有無
6. 移動時の注意点

移動ログに書く最小項目:

1. 日付
2. repo-id
3. 旧path
4. 新path
5. 旧path互換symlink未作成
6. launchd本登録結果
7. テスト結果
8. 旧path参照の残存有無
9. rollback要否
10. 残課題

## 8. 完了条件

1. repo実体が新pathにある。
2. Gitが新pathで正常に見える。
3. 旧path互換symlinkを作っていない。
4. launchdがあるrepoでは、登録状態と反応結果が説明できる。
5. repo-registry更新先または更新不要理由が説明できる。
6. runtime symlinkや設定ファイルが新pathを参照している。
7. 旧path参照の残存有無と、残す場合の理由が説明できる。
8. rollback不要、またはrollback済みであることが明確になっている。
