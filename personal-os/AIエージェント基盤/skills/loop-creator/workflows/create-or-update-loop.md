# create-or-update-loop

「loopを作る」「朝に自動実行する」「既存loopを変更する」を、所有判定から検証・報告まで完了させるworkflow。

## 0. 入力・期待出力・失敗時

### 入力

1. 目的と繰り返す処理。
2. 希望する時刻・間隔・タイムゾーン。未定でよい。
3. 所有repoの見当。未定でよい。
4. runner候補（`script` / `ai`）、外部書込み、secret、失敗時影響。未定なら調査する。

### 期待出力

1. canonical所有repoと `loops/<loop-id>/`。
2. `loop.md`、必要な時だけscript・gitignoreされたlogs・plist。
3. registry source referenceと、repo-localなら基盤directory symlinkの整合結果。
4. テスト結果、launchdの実行時状態、未実行の人間ゲート。

### 失敗時

1. 正本・所有repo・loop root・registryが一意にならなければ書込み0件で停止する。
2. scaffold後の検証が失敗したらlaunchdを有効化せず、差分・原因・戻し方を報告する。
3. 既存loopがあれば新規scaffoldせず変更モードへ切り替える。

## Step 1: loopかを判定する

1. 時刻または間隔で、人の操作なしに同じ責務を繰り返す処理だけをloopとする。
2. runtimeイベント発火はhook、手動起動はコマンド、一回限りはCodex automation、人の方向修正が要るAI作業は可視ペインへ返す。
3. 外部書込み・資格情報・失敗時影響を確認し、人間が待つ処理をheadlessにしない。

## Step 2: 所有repoと計画経路を解決する

1. repo内起点は最寄り `AGENTS.md` から始める。
2. Private起点は `plan-triage` に委譲し、`/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/repo概要.md` でcanonical repoだけを選ぶ。
3. Privateから別repoへ書く場合は、グローバル指示が定める新しい対象repo所有sessionへのhandoff後に続行する。
4. 特定repoの業務・固有データ・資格情報に依存するならrepo-local。複数repo/runtimeにまたがる運用責務だけglobal候補とする。
5. 既存planを先に検索し、一意なら合流する。新設・発火変更・停止・再開・廃止は人間ゲートとする。

## Step 3: canonical loop rootを確定する

1. repo-localは対象repoの `AGENTS.md` が宣言する `<repo>/loops/`、globalは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/` を使う。
2. repo-localはroot直下の `loops/AGENTS.md`、globalは親の `loops-registry/AGENTS.md` を読み、rootが未宣言・不存在・複数候補なら停止して `repo-create` へ返す。AI判断でrootを作らない。
3. 基盤の `implementation-links/` や旧互換symlinkをcanonical rootにしない。`pwd -P` とGit rootで実体を確認する。
4. `loop-id` は英小文字・数字・ハイフンで一意にし、既存loop、registry、launchd labelとの衝突を検索する。

## Step 4: scaffoldをdry-runする

1. 新規時だけ次を実行する。既定はdry-runで、ファイルを書かない。

```sh
scripts/scaffold-loop.sh \
  --root '<canonical /absolute/path/to/loops>' \
  --id '<loop-id>' \
  --owner '<repo-id>' \
  --scope '<global|repo-local>' \
  --runner '<script|ai>'
```

2. 出力path、rootを宣言するAGENTS、作成物が `loop.md` だけであることを人間へ示す。
3. ユーザーの依頼が明確な作成命令でない場合は、ここで明示承認を取る。
4. 承認後だけ同じ引数に `--apply` を付ける。同じ所有・scope・runnerで既にscaffold済みならno-op成功、それ以外の既存pathは上書きせず停止する。

## Step 5: loop.mdと必要な実装だけを完成させる

1. `loop.md` の目的、所有、発火、runner、canonical command、state/lock、logs、成果物、停止、rollbackを具体化し、`<未設定>` を残さない。
2. 実処理が必要な時だけ `scripts/` を作る。runnerが無ければ空フォルダを作らない。
3. ファイルログが必要な時だけ `logs/` を使い、対象repoの `.gitignore` と `git check-ignore` で非追跡を確認する。
4. lockは原則 `/tmp`。永続stateと成果物は既存正本・DB・dashboardなど目的に合う場所を `loop.md` に明記し、汎用 `state/`・`output/` を作らない。
5. testは影響度と対象repoの既存規約に従う。定型の `tests/` は作らない。

## Step 6: plistを必要な時だけ作る

1. macOS launchdを使う場合だけ、所有loop直下に固有labelのplist正本を置く。共通化するのは雛形・runnerまでとする。
2. plistはcanonical絶対pathの `ProgramArguments` / `WorkingDirectory` を使い、`implementation-links/` を実行pathにしない。
3. `loop.md` にlabel、発火、人間向け周期、実行command、ログ先を記録し、plistと一致させる。
4. `plutil -lint <plist>` を通す。plistへsecretや認証値を書かない。
5. `~/Library/LaunchAgents/<label>.plist` は正本へのsymlink露出先。作成・置換、`launchctl bootstrap/bootout`、enable/disable、周期変更は対象とrollbackを示し、実行直前に人間の明示承認を取る。

## Step 7: 基盤linkとregistryを整合させる

1. repo-localは `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/implementation-links/AGENTS.md` を読む。
2. `<repo-id> -> <canonical repo>/loops/` のroot全体への相対directory symlinkを1本だけ検証する。個別loop linkは作らない。
3. linkが存在する時は次で、相対linkかつ解決先がcanonical rootと一致することを検証する。

```sh
scripts/verify-repo-loop-link.sh \
  --link '<absolute path to implementation-links/<repo-id>>' \
  --root '<canonical /absolute/path/to/loops>'
```

4. linkが無い・不一致なら、期待targetと相対pathを提示し、人間承認後だけ作成・置換する。リンク経由で実体を削除しない。
5. registryは作業時点の `loops-registry/AGENTS.md` が示す唯一の正本へ、目的、意図状態、発火、runner、label、canonical source pathを登録する。
6. md/Turso移行中でも二重正本にせず、派生HTMLは正本から再生成する。

## Step 8: 検証して報告する

1. `scripts/test-scaffold-loop.sh`、対象repoのtest、`plutil -lint`、`git check-ignore`、`readlink` / `realpath`、registry verifierを必要範囲で実行する。
2. 未解決プレースホルダ、secretらしき値、旧path、implementation linkを使う実行pathが無いか `rg` で確認する。
3. launchdを変更する時は、最初の変更前に対象labelの `launchctl print gui/$(id -u)/<label>` とLaunchAgents symlinkの `readlink` を記録する。labelが未loadedなら、その事実をbaselineとして記録する。
4. launchd変更後は同じ対象だけを再確認し、変更前のsnapshotと比較する。後から取得した状態を変更前の証拠として扱わない。外部更新系scriptを検証目的で起動しない。
5. 正本path、作成/変更ファイル、runtime露出、registry、loaded状態、baseline比較、テスト、未実行ゲートを報告する。
6. 既存loopの移動・削除が必要なら本workflowで続けず、対象・依存・backup・rollbackを持つ別計画へ返す。

## 完了条件

1. 所有repo・loop root・registry・実行path・runtime露出が一意に説明できる。
2. 必須は `loop.md` だけで、optional構成は実際の必要性がある。
3. launchdの有効化を行った場合は、人間承認と対象labelの実機確認がある。
4. 失敗時はlaunchd未有効化、原因・差分・rollbackを返して親作業へ戻る。
