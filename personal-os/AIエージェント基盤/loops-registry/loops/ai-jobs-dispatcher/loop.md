---
状態: 停止
設計: /Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-06-30-目的管理ハーネス/plans/04-実行レーン自動化とデイリー自動ログ.md（子04・未卒業・育成中。③④部分のみ実装済）
---

# ai-jobs-dispatcher

## 目的

ai-jobs 実行レーン（`loops-registry/ai-jobs/`）の **headless レーン限定**の自動化。
`ready/` に置かれた run-card を人手を介さず claim → headless AI ワーカーとして起動し、
`running/`・`reviewing/` に居座った card を一定時間で `ready` に戻す（stale 回収）。
見えるレーン（Orca を人が手で立ち上げる運用）はこの loop の対象外（別途 program B）。

## 起動条件

launchd 1本の plist（`com.kitamura.ai-jobs-dispatcher.plist`、`RunAtLoad: true` ＋ `StartInterval: 60`）が
`scripts/dispatcher.ts` を毎分起動する（`loop-runbook.md` の標準モデル）。
**plist は配置のみ。`launchctl load`（bootstrap/enable）はしていない＝有効化は人間ゲート。**
有効化する場合、人間が `~/Library/LaunchAgents/` へこの plist をコピーし（`__REPO_ROOT__` 等の置換は不要・絶対パス済み）
`launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.ai-jobs-dispatcher.plist` する。

## 各回の実行（tick）

`scripts/dispatcher.ts` 1回の実行が1 tick。

1. `/tmp/ai-jobs-dispatcher-*.lock` を走査し、生存（PID存在）または未stale（`STALE_MS` 未満）のものを「稼働中」として数える（死亡/staleは掃除）。→ `active`
2. `capacity = CAP - active`。`capacity <= 0` なら claim せず tick を終える（cap 超過分は `ready` に残る＝仕様）。
3. `ai-jobs/ready` を `ls`（**中身は解析しない**。ai-jobs/AGENTS.md §1 の発見規約どおり）。古い順（mtime昇順）に並べ、先頭 `capacity` 枚だけを候補にする。
4. 候補ごとに `jobctl.sh claim <card>`（`ready→running`・mv アトミック）。失敗（他プロセスと競合等）は無視して次へ。
5. claim 後に初めて card 本文を読み `担当:` を取る（ai-jobs/AGENTS.md §1「掴んだ後に読む」に対応）。
   - `担当` が `claude` か `codex` → 対応する headless CLI をバックグラウンド起動して **即終了**（起動待ちしない）。
   - それ以外（`orca` 等・不明）→ このループでは実行できないので `jobctl.sh back <card>` で `ready` に戻す（削除しない）。見えるレーン対象は program B 側で拾う想定。
6. stale 回収（下記）を同じ tick 内で実行する。
7. tick 概要（active/capacity/launched/skipped/reaped）を `output/logs/dispatcher-tick.log` に1行追記する。

## stale 回収（④）

`running/` と `reviewing/` を走査し、card の **ctime**（`mv` はこれだけを更新する＝直前の状態遷移時刻の代理指標。実測で確認済み）が
`STALE_MS` を超えていたら `jobctl.sh back <card>`（→ `ready`。削除しない）。
`review/`（レビュー待ちの受動キュー）は対象外＝そこは無期限に待ってよい。

- `scripts/stale-recovery.ts` は dispatcher.ts の tick から呼ばれる**関数**であり、単独スクリプトとしても実行できる（`tsx scripts/stale-recovery.ts`）。
- 冪等: 既に動いた card（`ready`/`review`/`done` 等に移動済み）は次回走査で見つからないので何もしない。`jobctl back` が失敗（競合で対象が既に無い）しても無視して次へ進む。

## 対象・設定（定数・既定値は仮値、要調整）

| 項目 | 既定値 | 上書き |
|---|---|---|
| 同時実行cap | `2` | 環境変数 `AI_JOBS_DISPATCHER_CAP` |
| staleMs（running・reviewing共通） | `45分`（`2_700_000ms`） | 環境変数 `AI_JOBS_DISPATCHER_STALE_MS` |

- ai-jobs base / jobctl.sh / worker-prompt.md のパスは `scripts/common.ts` で基盤 repo 正本の絶対パスに固定する（`jobctl.sh` 自身が同じ理由で cwd 非依存の絶対パスを固定しているのに合わせる）。worktree から実行しても常にこの絶対パスを見るため、jobctl.sh の実際の動作先とずれない（実装当初は自分の位置基準の相対計算にしていたが、worktree で手動検証した際に「dispatcher の ls と jobctl.sh の実体が別ディレクトリを見る」食い違いを実測で発見し、絶対パス固定に修正した）。このloop自身の state/log 置き場（`LOOP_DIR`）だけは自分の物理位置基準のままでよい。

## state / lock / log

- lock: `/tmp/ai-jobs-dispatcher-<sanitized-card>.lock`（PID＋起動時刻。参照実装 `nextlevel-dispatcher.ts` の `isTaskRunning` と同方式・card単位に一般化）。
- state: 明示的な state JSON は持たない（`/tmp` の lock ファイル自体が「今動いている card」の状態を表す。cardごとの単発実行で時刻ベースの cooldown 判定が不要なため、参照実装の `dispatcher-state.json` 相当は不要と判断）。
- log: `output/logs/`（このディレクトリはリポジトリルートの `.gitignore` の `output/` パターンで自動的に非追跡）。
  - `dispatcher-tick.log`: tick 概要1行/回。
  - `worker-<card>.log`: card単位のワーカー標準出力・標準エラー（`start`/`finish exit=<code>` を含む）。
  - `launchd.out.log` / `launchd.err.log`: launchd 自体の標準出力・エラー（plist で指定）。
- 生ログ・state・lock はいずれも repo に commit しない（`.gitignore` で担保）。

## 完了/停止条件

- 停止したい場合は `launchctl bootout gui/$(id -u)/com.kitamura.ai-jobs-dispatcher` してから frontmatter の `状態` を `停止` にする。
- 廃止する場合は `状態: 廃止` にし、`~/Library/LaunchAgents/` の plist も削除する。

## 既知の未解決点（要・確認/基盤側判断）

1. **ready の共有**: `ready/` は headless レーンと見える（Orca）レーンが共有する（plan `04-*.md` 方針）。本 dispatcher は `ls` 段で `担当` を見ないため、人がこれから Orca で手動 claim するつもりの card を先に headless 側が claim してしまう競合が理論上あり得る。claim 後に `担当` が `orca`（またはこの loop が対応しないengine）なら即 `back` するので**データは失われない**が、往復1周分のレイテンシが乗る。整理の余地ありなら基盤側（`ai-jobs/AGENTS.md` の contract）で調整判断。
2. **codex headless の実行は未実測**: `claude` 経路（`-p` ＋ `--dangerously-skip-permissions`）は既存実装（`projects/active/focusmap/scripts/task-runner.ts`）に前例があり踏襲。`codex exec --sandbox workspace-write` は `codex exec --help` から妥当と判断して実装したが、実際に card を1枚通す実測はしていない（本セッションでは費用・時間の都合上、実プロセスは起動していない）。有効化前に人間が一度実測することを推奨。
3. **claude起動の権限モード**: `--dangerously-skip-permissions` は無人実行のために必須だが、実行対象は worktree 隔離＋レビュー必須＋plist手動有効化の3層で守られている前提。この前提が崩れる場合は見直しが必要。
