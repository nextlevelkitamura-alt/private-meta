分類: skill
種別: 新規作成

# Orca CLI 複数エージェント運用 Skill 新規作成計画

- 種別: 新規作成
- 変更内容: Orca CLIで監督、計画、実装、レビュー、closeoutを回すSkill候補を作る。
- 目的: Orca上のworktreeとterminalだけで、多段AI作業を開始、監督、差し戻し、commit/push、削除まで完結させる。
- 対象: Orca CLI、Orca Automations、Orca orchestration、agent hooks、Codex terminal、Git closeout。

## 最終判断

1. 標準案はOrca内で完結させる。
2. 起動は `orca automations` を第一候補にする。
3. 判断はOrca CLIで起動した `監督` terminalが持つ。
4. `計画`、`実装`、`レビュー` はworker terminalとして扱う。
5. workerへの配送、完了通知、待受、human gateはOrca orchestrationを使う。
6. agent hooks / `worktree ps` はworker完了状態のfallback確認に使う。
7. 自作の常駐待機scriptを標準案にはしない。

## 役割

1. `起動`: `orca automations create --trigger hourly` で時間起動する。
2. `監督`: task、terminal handle、cursor、gate、commit/push/closeを管理する。
3. `計画`: 実装前の方針を作る。
4. `実装`: 差分を作り、テスト結果を返す。
5. `レビュー`: 差分、テスト、secret、仕様逸脱を確認する。

## こういう時はこれを使う

1. 定期実行したい:
   `orca automations create --trigger hourly --provider codex --prompt <監督prompt>` を使う。

2. GWSやSpreadsheetに差分がある時だけ起動したい:
   `orca automations create --precheck <差分確認コマンド>` を使う。precheckが0なら続行、それ以外ならskipにする。

3. 新しい作業部屋を作りたい:
   `orca worktree create --name <english-slug> --agent codex --prompt <監督prompt>` を使う。

4. Orca UIの表示だけ日本語にしたい:
   `orca worktree set --worktree <selector> --display-name <日本語名>` を使う。

5. worker terminalを追加したい:
   `orca terminal create --worktree <selector> --title <計画|実装|レビュー> --command codex` を使う。

6. taskとして渡したい:
   `orca orchestration task-create` と `orca orchestration dispatch --inject` を使う。

7. worker完了を待って監督へ戻したい:
   `orca orchestration check --terminal <監督handle> --types worker_done,status --wait --inject` を使う。

8. workerが完了通知を出さなかった時に確認したい:
   `orca worktree ps --json` の `agents[].state` と `lastAssistantMessage` を見る。

9. terminal出力を直接読む必要がある:
   `orca terminal read --cursor <n> --json` を補助的に使う。

10. 人間判断で止めたい:
   `orca orchestration gate-create` と `gate-resolve` を使う。

## Orchestration標準フロー

1. 監督が計画taskを作る。
2. `dispatch-show --preamble` で注入promptを事前確認する。
3. `dispatch --inject` で計画terminalへ渡す。
4. 監督は `check --wait --inject` で `worker_done` / `status` を待つ。
5. 計画が弱ければ、監督が追加promptを送る。
6. 計画OKなら実装taskを作り、実装terminalへdispatchする。
7. 実装完了後、レビューtaskを作り、レビューterminalへdispatchする。
8. レビュー結果で、commit/push/close、差し戻し、human gate、blockedを選ぶ。

## worker_done / status

workerにはtaskごとに、完了時の返送ルールを入れる。

1. `status`: 途中経過、待機、詰まり、heartbeatに使う。
2. `worker_done`: workerの担当完了に使う。
3. `worker_done` は必ず監督handleへ送る。
4. payloadには `task-id`、`dispatch-id`、`phase`、`files-modified`、`report-path` を入れる。
5. 監督は `worker_done` を読んで次のworkerへ渡すか、差し戻すか、closeoutへ進むか決める。

例:

```sh
orca orchestration send \
  --to <監督handle> \
  --type worker_done \
  --subject "implementation done" \
  --task-id <task_id> \
  --dispatch-id <dispatch_id> \
  --phase implementation \
  --files-modified "path/a,path/b" \
  --report-path "reports/run.md"
```

## Agent Hooksの位置づけ

Orca管理のagent status hooksは有効化できる。
Codexにも `Stop` などのhookが入り、Orcaは `done` や `lastAssistantMessage` を受け取れる。

1. 状態確認:
   `orca agent hooks status --json`

2. 完了状態の確認:
   `orca worktree ps --json`

3. 使い方:
   `orchestration check --wait --inject` が第一候補。agent hooks / `worktree ps` は取りこぼし確認と復旧に使う。

4. 制約:
   公開CLIで確認できる範囲では、agentがdoneになった瞬間に任意promptを登録実行する汎用callback設定はない。

## closeout

1. 変更あり:
   レビューOK、Git差分確認、secret確認、テスト確認、commit、push、`workspace-status completed`、terminal stop、worktree rm、path/branch確認。

2. 変更なし:
   Git clean確認、no-op理由記録、`workspace-status completed`、terminal stop、worktree rm、branch確認。

3. 未完了:
   テスト失敗、レビューNG、push失敗、人間確認待ちは削除しない。`in-review`、`blocked`、commentで止まった理由を残す。

## 安全条件

1. branch/worktree名は英語slug、Orca表示名は日本語で分ける。
2. secret、token、credential、GWS認証値をpromptやログに残さない。
3. run id、worktree path、branch、terminal handles、cursor、task idを記録する。
4. 最大差し戻し回数を決める。例: 計画2回、実装2回。
5. 外部反映、削除、権限判断はhuman gateに上げる。
6. 毎時実行では、前回runが未完了なら新規runを増やさない。

## 完了条件

1. Orca Automationsで監督を定期起動できる。
2. 監督がOrca orchestrationで計画、実装、レビューを橋渡しできる。
3. `worker_done`、`status`、`gate`、agent hooksの使い分けがSkill本文に反映されている。
4. 変更ありはcommit/push/close、変更なしはno-op close、未完了は残す方針になっている。
5. Skill作成時にlogs/catalog更新要否を確認する。
