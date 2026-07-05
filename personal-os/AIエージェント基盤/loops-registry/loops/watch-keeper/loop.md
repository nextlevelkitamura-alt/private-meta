---
稼働状態: 停止（2026-07-04 全停止・bootout済み。経緯と再開手順は ../../実行一覧/personal-os.md）
起動: launchd `com.kitamura.watch-keeper`（`StartInterval` 300秒=5分。正本plistはこのフォルダ・
`~/Library/LaunchAgents/` へはsymlink登録済み）
---

# watch-keeper（見張り番キーパー・v1常設化）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

指揮官セッションの見張り番（`skills/orca-cockpit/scripts/watch.sh`）は指揮官セッションのbackgroundタスクであり、
`/compact`（手動）→離席の組合せや、デスクトップアプリ終了・cronの7日失効などでセッションごと消えうる。
見張り番が消えている間は「次の発話まで」検知が空白になり、20〜30分のロスタイムが生まれ得る（学び12）。
watch-keeperはこの空白の上限を5分に抑える常設の外部監視（launchd・5分毎ワンショット）。
チャット記憶に依存せず、監視対象は毎回 `orca worktree ps --json` から機械的に再構築する。

正本計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-02-見張り番キーパー/plan.md`（方針v1）。
v0（指揮官セッションのcron・5分毎の再装填/裁定/自己削除）と役割分担: v0＝生きている間の再装填判断、
watch-keeper（v1）＝死んだ後も5分粒度で復活を検知する層。**読み取りのみ・`~/Private`側は一切変更しない**。

## 対象

- 入力: `${KEEPER_PS_CMD:-orca worktree ps --json}` の実行結果（cockpitレーン＝`agents`配列に
  `agentType` を持つエージェントが1件以上ある worktree のみを対象とする）。
- 入力: `${KEEPER_PGREP_CMD:-pgrep -f watch.sh}`（見張り番watch.shプロセスの生存確認）。
- 出力: macOS通知（`osascript display notification`。デフォルトはtitle=`watch-keeper: <lane>`、
  body=`<kind>: <line>`）と `state/alerts.jsonl` への1行追記。判断・裁定は一切しない（grepと状態突合のみ）。

## 起動条件（shouldRun）

- launchd `StartInterval` 300秒（5分毎）。`RunAtLoad` は付けない（daily-digest/inbox-patrolと同じ方針・
  起動直後の連打を避ける）。
- 何度実行しても冪等（後述§冪等性）。cockpitレーンが1本も無い（＝agent持ちworktreeが0）場合は
  何も検知せず静かに終了する（`WATCH_MISSING`判定も対象レーン0のため発火しない）。

## 1分tick統合（子06フェーズ1・2026-07-03）

親計画（マルチ指揮官体制program 子06）方針3の統合形として、keeper.sh の検知を
**lanes-sync の毎分tickへ相乗り**させた。`renderer/scripts/keeper-tick.sh` が keeper.sh を
ワンショット起動し、`renderer/scripts/lanes-sync.sh` の毎分tickから inbox-tick.sh の隣で呼ばれる
（呼び出し口は keeper-tick.sh 1本・plistを増やさない）。これで検知の到達上限が 5分→1分 に縮む。

- **keeper.sh 自体は不変**（tick入口を足しただけ・ロジック改変なし）。seen.txt 完全一致ガードが
  周期非依存のため、5分plistと1分tickが併走しても二重通知は起きない
  （`renderer/tests/keeper-tick-tests.sh` が連続2tick=通知1回を担保）。
- **1回の `orca worktree ps` スナップショットを lanes-sync と共有する統合（親計画方針1）は
  フェーズ2**。フェーズ1では keeper と lanes-sync がそれぞれ ps を1回ずつ読む（毎分2回）。
- **旧5分plist（`com.kitamura.watch-keeper`）は本統合で冗長化する**。1分tick稼働後は standalone
  plist を bootout して二重駆動を止める（**人間ゲート**・手順は §完了・停止条件 の bootout）。
  bootout 実行までは5分plistと1分tickが併走するが、seen.txt ガードにより無害（冗長なだけ）。

### フェーズ2（2026-07-03裁定・検知強化）

- **psスナップショット共有（親計画方針1）**: `lanes-sync.sh` が毎tick `orca worktree ps` を1回だけ取得し、
  `KEEPER_PS_CMD`/`ORCA_PS_CMD` を同一スナップショットへ向けて keeper と自身の変化検知で共有する
  （従来の毎分2回読み→1回）。keeper.sh 側は既存の `KEEPER_PS_CMD` 差替knobをそのまま使う（keeper.sh無改変）。
- **レーン停滞検知（(d)）**: 上記§各回の実行に統合済み（working無しのidle/waiting継続が10分超でSTALL）。
  司令部(main Private)worktreeのレーン停滞は中間指揮官ペイン停滞の集約プロキシも兼ねる。
- **出所なしレーン検知（(e)・裁定1=events.jsonl結合キー）**: `events.jsonl`（`COCKPIT_EVENTS_FILE`）を
  結合キーの正とし、psのアクティブagentレーン(非main)のうち up/send(将来spawn)記録が無いものを
  `NO_ORIGIN` として検知する（cockpit経由でない直起動/緊急直依頼の可能性）。デイリー起票行とは突合しない
  ＝人間可読層で機械的な結合キーが無いため（インボックスはplan/タスク単位・worktree名は起票行に現れない）。
  events.jsonl不在時はorigin判定不能につきスキップ（保守側・誤WAKEしない）。司令部main worktreeは対象外。
- **フェーズ2b（spawn 999356d マージ後・采配9玉A・実装済み）**: spawnが書くペイン台帳
  `state/panes.jsonl`（`COCKPIT_PANES_FILE`。ts・handle・worktree・role・owner・model・prompt保存パス。
  JSONL追記型・git非管理）の**読み手側を実装**。keeper.shが台帳の一貫フィールド（worktree/owner/role）を読み、
  (1) 出所なし検知(e)の origin へ台帳の worktree を合流（spawn起動レーンを出所ありにする）
  (2) 停滞検知(d)のWAKE行に台帳の owner/role を付す（どの指揮官のレーンか）。読取失敗は空台帳扱い
  （events由来の検知は維持・新規誤検知しない）。
- **フェーズ2b 残（裁定2の per-ペイン識別・agent無し起動レース）**: 個々のペイン単位の識別（ps agentの
  paneKey↔台帳handleの突合）は、spawnの`handle`列が dict-repr と plain 文字列で不安定（999356d時点）なため
  未実装。handle列の書式正規化後に着手（spawn側=中間指揮官2へ申し送り）。それまでは司令部main worktreeの
  レーン停滞集約（(d)）＋owner付与で運用。

## 各回の実行（command）

```
scripts/keeper.sh
```

`runner: script`（判断はしない・非AI・決定的。判定ロジックのみ `orca-cockpit/scripts/watch.sh` の
`PY_JUDGE` を正本として転用する。watch.sh本体は複製しない）。処理順:

1. `$KEEPER_PS_CMD`（既定 `orca worktree ps --json`）を1回実行し、標準出力のJSONを1回だけ読む。
   出力が空（orca CLI不在・失敗）なら何もせず終了する（exit 0・空出力で誤検知しない）。
2. python3のワンショット判定（`KEEPER_JUDGE`。watch.shの`PY_JUDGE`と同一の`DONE_RE`・`is_gate`ロジックを転用）が、
   `agents`配列に`agentType`を持つエージェントが1件以上あるworktree（＝cockpitレーン）だけを対象に、
   レーンごとに次を判定する。JSON不正・非objectは`PARSE_ERR`の1行のみを返し、keeper.shはそのまま終了する
   （watch.shのPARSE_ERR処理と同じ思想）。
   - **DONE_MARKER**: いずれかのagentの`lastAssistantMessage`最終行が
     `[A-Z][A-Z0-9_]*_DONE|REVIEW_RESULT: (?:PASS|FAIL)`（watch.shの`DONE_RE`）に**fullmatch**。
   - **HUMAN_GATE**: いずれかのagentの`lastAssistantMessage`最終行が「`段階:`で始まり`人間確認待ち`を含み
     30文字以内」（watch.shの`is_gate`と同一条件）。
   - **AGENT_ERROR**: いずれかのagentの`state`が`error`/`failed`/`crashed`。
3. bash側で `$KEEPER_PGREP_CMD`（既定 `pgrep -f watch.sh`）を実行し、稼働レーン（手順2でカウントした
   cockpitレーン数）が1本以上あるのにヒット0本なら、**WATCH_MISSING**（`lane=ALL`・
   `line=稼働レーン<N>本・watch.shプロセス0本`）を検知に加える。
   ※ `pgrep -f`はコマンドライン文字列の部分一致のため、`watch.sh`をエディタ等で開いているだけの
   プロセスも稀に誤ってヒットしうる（＝watch.sh不在の見逃し方向の誤差。逆方向の誤検知＝実際に動いている
   watch.shを見逃す方向の誤差は生じない）。既知の限界として記録する。
3b. **レーン停滞（STALL・子06フェーズ2）**: 各cockpitレーンが`working`のagentを1体も持たない
   （＝idle/waiting）状態の継続時間を`state/stall-since.tsv`（`path(base64)\t停滞開始epoch`・毎回再構築）で
   追跡し、`KEEPER_STALL_SECONDS`（既定600=10分）超で`STALL`（`lane=<worktree名>`）を検知に加える。現在時刻は
   `KEEPER_NOW`で注入可能。seenキーは停滞開始時刻ベースで安定＝同一エピソードで毎tick再通知しない。
   `working`復帰でタイマーがクリアされ、再停滞は新エピソードとして再度検知される。
3c. **出所なしレーン（NO_ORIGIN・子06フェーズ2・裁定1）**: `events.jsonl`（`COCKPIT_EVENTS_FILE`。
   既定は `skills/orca-cockpit/state/events.jsonl`）から up/send(将来spawn)実績のあるworktree path集合を作り、
   psのアクティブagentレーン(非main)のうちその集合に無いものを`NO_ORIGIN`（`lane=<worktree名>`）として
   検知に加える。デイリー起票行とは突合しない（人間可読層・機械結合キー無し）。events.jsonl不在時はスキップ。
4. 手順2・3・3b・3cで見つかった検知（0件以上・1レーンが複数種を同時に検知することもある）ごとに、
   `(lane, line)` の組を `state/seen.txt` と完全一致（`grep -Fxq`）で照合する。
   - 未出（新規）なら: macOS通知 → `state/alerts.jsonl`へ1行追記（`{"ts","lane","kind","line"}`。
     `ts`はUTC ISO8601） → `state/seen.txt`へ`lane|line`を1行追記 → （`KEEPER_AUTOPILOT=1`の時のみ）
     ワンショット監督起動。
   - 既出なら: 何もしない（再通知しない＝再ウェイクループ防止。watch.shの`WATCH_SEEN`と同じ思想）。

## 判定ロジックの正本

DONE_RE・`is_gate`は `../../../skills/orca-cockpit/scripts/watch.sh` の `PY_JUDGE` が正本。
watch-keeperは同一の正規表現・同一の判定条件をこのloop内に**転用**する（importや共有モジュール化はせず、
bash+python3ヘルパースクリプトという実行形態の違いから複製の形を取るが、ロジックの値そのものは
watch.sh側を変更した際に追従する必要がある＝**2箇所同期の負債**として認識しておく。差分が出た場合は
`tests/keeper-tests.sh` と watch.sh側テストの両方で検知できるようにする）。

watch-keeperが持たないもの（watch.shとの違い）: pollループ・優先度順・タイムアウト・画面シグネチャ検知
（対話ダイアログ/利用上限）・稼働時間ハートビート。これらは「生きている間」の watch.sh 側の責務であり、
keeper.shは「死んだ後にも5分粒度で気づく」ための一発判定に徹する（§目的の二層モデル）。

## 冪等性

- 手順1〜3（判定）は読み取り専用・非AI・非乱数。同一の`$KEEPER_PS_CMD`/`$KEEPER_PGREP_CMD`出力なら
  同一の検知結果を返す。
- 同一の`(lane, line)`検知は`state/seen.txt`の完全一致照合により2回目以降は通知・alerts追記・
  autopilot起動のいずれも行わない（同一入力を2回連続実行しても、通知は初回の1回だけ）。
- `state/alerts.jsonl`は追記のみ（既存行を書き換えない）。`state/seen.txt`も追記のみ。

## リソース実測

実測（このworktree・2026-07-02・実orca CLI使用・`time`計測）:

```
real  0m0.489s
user  0m0.355s
sys   0m0.107s
```

内訳: `orca worktree ps --json` 単体で約0.32秒（実測）、残りが python3判定＋bashの後処理。
5分毎288回/日 ≒ 0.49秒×288 ≒ 141秒/日 ≒ 2.4分/日のCPU時間・常駐プロセスなし。
計画（`plan.md` §3b）の試算「1秒未満・合計5分/日以下」の範囲に収まることを実測で確認した。

## 完了・停止条件

- **完了**（1回の実行として）: `$KEEPER_PS_CMD`を1回読み、対象レーンの判定を終え、新規検知があれば
  通知・記録を終えていること（検知0件でも正常終了＝exit 0）。
- **停止**: frontmatter `稼働状態` が `停止`（現在値。draft plistは配置のみで symlink登録していない）。
  稼働中への切替は下記§登録手順（人間ゲート）。
- **停止（稼働中からの停止）**: `launchctl bootout gui/$(id -u)/com.kitamura.watch-keeper`
  （その後 `rm ~/Library/LaunchAgents/com.kitamura.watch-keeper.plist` でsymlinkも外す）。

## 設定・環境変数

secret / token は使わない。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `KEEPER_PS_CMD` | `orca worktree ps --json`（unquoted展開・複数語コマンド差替可） | cockpitレーン実況の取得コマンド。テスト時は `cat fixture.json` 等に差し替える（watch.shの`WATCH_PS_CMD`と同じ方式） |
| `KEEPER_PGREP_CMD` | `pgrep -f watch.sh`（unquoted展開） | watch.shプロセスの生存確認コマンド。テスト時は `echo <pid>`（在）/ `true`（不在）等に差し替える |
| `KEEPER_STATE_DIR` | `<このフォルダ>/state` | `alerts.jsonl`・`seen.txt`の置き場。テスト時はfixture専用ディレクトリに差し替える |
| `KEEPER_NOTIFY_CMD` | 未設定（既定は内蔵の`osascript display notification`呼び出し） | 通知コマンドの差し替え（1実行ファイルへの完全パス。`title` `body`の2引数で呼ばれる）。テストではstubスクリプトに差し替え、実osascriptは一切呼ばない |
| `KEEPER_AUTOPILOT` | `0`（OFF） | `1`の時のみ、新規検知ごとにワンショット監督起動（`claude -p`）をbackgroundで行う。既定OFF＝通知のみ（AI呼び出しコスト・安全性の判断は人間に残す） |
| `KEEPER_AUTOPILOT_CMD` | 未設定（既定は内蔵の`claude -p "<prompt>" --dangerously-skip-permissions --output-format text --max-budget-usd 5`をbackground起動） | autopilot起動コマンドの差し替え（1実行ファイルへの完全パス。`lane` `kind` `line` `prompt`の4引数で呼ばれる）。テストではstubスクリプトに差し替え、実claudeは一切起動しない |
| `KEEPER_STALL_SECONDS` | `600`（10分・子06フェーズ2裁定） | レーン停滞（working無しのidle/waiting継続）をSTALLとして検知する閾値秒数。継続時間は`state/stall-since.tsv`で追跡 |
| `KEEPER_NOW` | 未設定（既定 `date +%s`） | 停滞判定の現在時刻（epoch秒）注入。テストで時間経過を決定的に再現するために使う（本番は未設定） |

`state/` はこのrepoの `.gitignore` で除外（実行時状態・追記のみ・正本ではない）。

## ログ先

このloop自体の実行ログ（stdout/stderr）は repo外（`loop-runbook.md` §5準拠）。plistは
`output/logs/launchd.{out,err}.log` を指定する（daily-digest/inbox-patrolと同じ方針。稼働中に
切り替える前に `mkdir -p output/logs` を用意する）。
このloopが**生成する**ログ・記録は `state/alerts.jsonl`（検知履歴）と `state/seen.txt`
（再通知防止の完全一致リスト）のみ。

## 登録手順（人間ゲート・bootstrap自体は指揮官側が実施）

正本plistは `com.kitamura.watch-keeper.plist`（このフォルダ直下）。**cpではなくsymlink**で
`~/Library/LaunchAgents/` へ登録する（常設loopのため、リポ側の編集がそのままlaunchd登録に反映される
ようにする設計判断。daily-digest/inbox-patrolは`cp`だが、watch-keeperは編集頻度・常設性の観点から
symlinkを採用する）。

```
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/watch-keeper/com.kitamura.watch-keeper.plist' \
  ~/Library/LaunchAgents/com.kitamura.watch-keeper.plist
mkdir -p '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/watch-keeper/output/logs'
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.watch-keeper.plist
launchctl enable gui/$(id -u)/com.kitamura.watch-keeper
```

停止:

```
launchctl bootout gui/$(id -u)/com.kitamura.watch-keeper
rm ~/Library/LaunchAgents/com.kitamura.watch-keeper.plist
```

手動実行（動作確認・通知/alerts追記が実際に起きる。secretは使わない）:

```
cd <このフォルダ> && scripts/keeper.sh
```

## 関連（重複させず backlink）

- 正本計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-02-見張り番キーパー/plan.md`。
- 判定ロジックの正本（DONE_RE・is_gate）: `../../../skills/orca-cockpit/scripts/watch.sh`。
- 判断・監督手順（KEEPER_AUTOPILOT=1時の委譲先）: `../../../skills/cockpit-supervisor/SKILL.md`。
- loop 起動標準: `../../references/loop-runbook.md`。
- `orca worktree ps --json` を同じ方式（`ORCA_PS_CMD`/`WATCH_PS_CMD`差替）で読む先例:
  `../renderer/scripts/orca-ps-snapshot.sh`。
- 実行一覧（5分毎・何を検知するかの一覧）: `../../実行一覧/personal-os.md`。
