---
稼働状態: 停止（2026-07-04 全停止・bootout済み。経緯と再開手順は ../../実行一覧/personal-os.md）
起動: 現行=launchd `com.kitamura.inbox-patrol`（StartInterval 1800・`~/Library/LaunchAgents/` へsymlink済み）。移行先（2026-07-03マルチ指揮官体制program子03裁定）=renderer `scripts/inbox-tick.sh` 経由の毎分（lanes-sync相乗り）。移行操作＝人間が renderer `state/inbox-patrol-enabled` を touch ＋ `launchctl bootout gui/$(id -u)/com.kitamura.inbox-patrol`（**両方とも人間ゲート**。二重駆動はmkdirロックで安全だが同時に行う。plist本体は温存・削除は人間承認）
---

# inbox-patrol（依頼インボックス巡回loop）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

当日デイリーの「依頼インボックス」に人間が書いた未処理の1行を検知し、`inbox-triage` Skillをheadlessで起動して計画（plan.md）まで起案させる。
**入口の位置づけ（2026-07-03子03裁定・この1行が正本）**: 依頼の既定の入口は起票ゲートskill（マルチ指揮官体制program子05・別途作成）。Notionインボックス（pull→デイリー）は例外入口（AI停止時・外出時・他者起票）。
**検出＝②script（決定的・非AI）／トリアージ判断＝headless AI（`inbox-triage` Skill）** の二段（`../../references/loop-types.md`）。
loopが起案より先（実装・実行）へ進まないことは、`inbox-triage` Skillの入力契約（起案までしかしない）と、このloopが patrol.sh 以外の経路で行を処理しないことで保証する。

**二重起案防止（差し戻し1回目で追加）**: 30〜60分間隔の launchd 起動どうしが重なる（前回実行が長引く／手動実行と重なる等）と、同じ行を2つの `patrol.sh` インスタンスが同時に拾って二重に起案し得る。これを防ぐため、実行全体を mkdir ロックで排他し（§各回の実行）、各行は起案（AI起動）の直前に未処理かを再確認してから「クレーム」してAIへ渡す（§冪等性・二重起案防止）。

## 対象

- `${GOAL_BASE:-~/Private/personal-os/my-brain/ゴール}/デイリー/<年>/<月>/<年-月-日>.md`（対象日のみ。既定は実行時点のJST当日）。
- 入力: 対象日デイリーの `## 依頼インボックス` 節（`../../loops/renderer/templates/デイリー.md` が見出し・マーカー流儀の正本）。
- 出力: `inbox-triage` Skillが書く plan.md（該当areaの `plans/active/`）と、対象デイリーの対象行末尾の処理済み印（`→計画作成済み(<パス>)`）。plan.md本文の作成とその最終マーカーへの置換はSkillが行う。**patrol.sh 自身が書き込むのは「起案直前のクレーム印」（`→処理中(hash=... pid=... ts=...)`）だけ**であり、これはAI起動直前に付け、AI失敗時は自分で剥がす（§冪等性・二重起案防止）。
- **行末注記の語彙（2026-07-03子03裁定で統一）**: `→処理中(claim)` → `→計画作成済み(<パス>)` → `→着手(担当X)` → `→完了` の順に進む。`→処理中` の実形式は上記のクレーム印（hash=...）。`→着手`と`→完了`は、send采配した全体管理者または着手した指揮官が **`→計画作成済み(<パス>)` の後ろへ追記する**（置換しない。行に `→計画作成済み(` が残るため patrol.sh の未処理判定は変更なしで追従する）。終端系 `→重複(`・`→サクッと判定(` は従来どおり。

## 起動条件（shouldRun）

- 毎分（renderer `scripts/inbox-tick.sh` が lanes-sync の1分tickに相乗りして呼ぶ。2026-07-03子03裁定で30分→毎分へ変更。移行後は独立plistを持たない＝launchd常駐を増やさない。統合見張り＝子06が来たら呼び出し元の1行をsentinel側へ移すだけでよい）。
- 何度実行しても冪等（後述）。当日デイリーが無い日はスキップ（生成はrendererの仕事。このloopはrendererを起動しない）。
- 現状: launchd 30分毎で稼働中（2026-07-02有効化）。毎分tick経由は renderer `state/inbox-patrol-enabled` フラグ未設置のため休止中（inbox-tick.sh はフラグが無い間 patrol.sh を呼ばない）。移行操作は frontmatter「起動」を参照（人間ゲート）。

## 各回の実行（command）

```
scripts/patrol.sh [YYYY-MM-DD] [--dry-run]   # 日付省略時は実行時点のJST当日
```

`runner: script`（抽出・ロック・クレームは非AI・決定的）。処理順:

0. **実行全体を mkdir ロックで排他する**（`INBOX_PATROL_LOCK_DIR`、既定 `${TMPDIR:-/tmp}/com.kitamura.inbox-patrol.lock`）。`mkdir` はbash3.2でも原子的。既に他インスタンスが動いていて取得に失敗したら、**待たずに即 `exit 1`**（後述）。`--dry-run` も含めて実行全体がこのロックの内側。
1. 対象日デイリーの `## 依頼インボックス` 節から、次の**すべて**を満たす行だけを未処理行として決定的に抽出する。
   - 行頭が `- ` で始まり、bullet本文が空でない（テンプレの空プレースホルダ `- ` を除外）。
   - 最終マーカー `→計画作成済み(` を含まない。
   - クレームマーカー `→処理中(` を含まない（＝他の実行が起案中でない）。
2. `--dry-run` 指定時は、上記抽出結果を1行1件で標準出力するだけで終わる（**AIを一切起動しない・クレームも書かない**）。動作確認・テスト専用。
3. `--dry-run` 無指定時、未処理行が1件以上あれば、行ごとに次を行う。
   1. **起案直前の再確認**: その行がまだ未処理か（手順1と同じ条件）を、ファイルを読み直して再確認する。既に他の実行がクレーム/処理済みなら（同一内容の重複行が先の反復で一括クレームされた場合を含む）その行はスキップする。
   2. **クレーム（先行書込）**: `→処理中(hash=<内容一致キー> pid=<PID> ts=<epoch秒>)` を対象行の末尾に追記して書き戻す。内容が完全一致する行**すべて**に同時に付く＝同一内容の重複行は1回のクレームで冪等ユニットとして扱われる。
   3. `inbox-triage` Skill（`../../../skills/inbox-triage/SKILL.md`）の手順の正本とクレーム済みの行を指すプロンプトを組み立て、headless AIを起動する（既定 `claude -p "<prompt>" --dangerously-skip-permissions --output-format text --max-budget-usd 5`。`ai-jobs-dispatcher/scripts/common.ts` の `buildWorkerCommand` と同じ起動系統を踏襲）。
   4. **成功時**: Skill自身がクレーム印 `→処理中(...)` を最終マーカー `→計画作成済み(<path>)` に置き換える（対象行のみ。他の行には触れない契約）。続けてpatrol.shが、自分のクレームがまだ残る兄弟行（＝同一内容の重複行のうちSkillが書き換えなかった側）が無いかを走査し、あれば `→重複(同一依頼として処理済み)` へ書き換える（重複が無ければ何もしない）。
   5. **失敗時**: patrol.shがクレーム印を剥がし、行を元の未処理状態に戻す（次回実行で再挑戦できるようにする）。
   - 領域判定・規模判定・plan.md起案は、起動された headless AI（`inbox-triage` Skill）自身が行う。
   - テスト・特殊運用時は環境変数 `TRIAGE_AI_CMD` で起動コマンドを差し替えられる（`tests/run-tests.sh` はこれでAIをstubに差し替える）。

## 冪等性・二重起案防止

- 抽出（`--dry-run`含む）は読み取り専用・非AI・非乱数。同一入力なら同一出力（同じ未処理行の集合を返す）。
- **プロセス間の排他**: 実行全体を mkdir ロックで排他するため、`patrol.sh` の複数インスタンスが同時に同じ行を処理することはない（後から来た側は即終了する）。
- **同一実行内の再確認**: 各行は「起案直前」に未処理かどうかを再度確認してからクレームする。これにより、直前の反復でのクレーム書込が終わった直後の行（＝同一内容の重複行）を二重に起案しない。
- **同一内容の重複行の扱い（決定）**: インボックスに同一文言の行が複数あっても、内容一致を鍵にした1つの冪等ユニットとして扱う。クレームは内容が一致する行すべてへ同時に書き込むため、2行目以降は「起案直前の再確認」で既にクレーム済みと判定されスキップされる＝AIは1回しか起動されない。行番号やUUID等の識別子は導入しない（依頼インボックスは自由記述のテキストであり、位置情報を安定した識別子として使えないため）。ただし `inbox-triage` Skillは契約上「渡された対象行だけ」を書き換え、クレームされた兄弟行には触れないため、Skill完了後にpatrol.sh自身が後処理として、自分のクレームがまだ残る兄弟行を `→重複(同一依頼として処理済み)` という終了状態サフィックスへ書き換え、`→処理中(...)` が永久に残留しないことを保証する（差し戻し2回目対応。`finalize_duplicate_leftovers`）。
- **失敗時のロールバック**: headless AI起動が失敗（非0終了）した場合、patrol.shはクレーム印を剥がして行を元の未処理状態に戻す。次回実行で再挑戦できる。
- **ロックの手動復旧**: patrol.sh はロックの stale 自動回収を持たない（MVP）。プロセスが異常終了してロックが残った場合は、人間が `rm -rf "$LOCK_DIR"` で手動解除する（`$LOCK_DIR/owner` に `pid`/開始時刻を記録している）。
- **既知の実装上の注意（macOS標準awkの `==` バグ）**: クレーム/最終マーカーの行一致判定で `awk '{ if ($0 == target) ... }'` を使う箇所は、すべて `LC_ALL=C` を明示している。UTF-8ロケール（`en_US.UTF-8` 等）のままだと、macOS標準awk（one true awk）が日本語の**異なる**文字列同士を `==` で誤って真と判定することを実測で確認した（例: `"重複した依頼" == "単独の依頼"` が真になる）。`extract_unprocessed` の見出し検出・空白trim・マーカー含有チェック（`index()`）はASCIIパターンとバイト単位一致で完結するため、`LC_ALL=C` に切り替えても抽出結果は変わらない。この注意が無いまま行一致判定を追加・変更すると、無関係な行を誤ってクレーム/上書きする恐れがある（`tests/run-tests.sh` の t8 がこの回帰を検出する）。

## 完了・停止条件

- 完了（1回）: 対象日デイリーの未処理行すべてに対して、headless AI起動を1回ずつ行い終える（`--dry-run` の場合は抽出結果を出力し終える）。
- 毎分tick経由への移行: 人間が renderer `state/inbox-patrol-enabled` を `touch` し、`launchctl bootout gui/$(id -u)/com.kitamura.inbox-patrol` で旧plist駆動を止める（**人間ゲート**。tick側の追加launchctl登録は不要＝lanes-syncが既に毎分回っているため）。
- 完全停止: renderer `state/inbox-patrol-enabled` を `rm`（tick経由を止める）。旧plist駆動が残っていれば bootout も行い、frontmatter を `停止` に戻す。

## 設定・環境変数

secret / token は使わない。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `GOAL_BASE` | `~/Private/personal-os/my-brain/ゴール`（`../../daily-digest/scripts/_paths.sh` 経由） | デイリー日次ファイルの探索起点。テスト時は上書きする |
| `TRIAGE_AI_CMD` | 未設定（既定は `claude -p ...`） | headless AI起動コマンドの差し替え。テストではstubスクリプトを指す |
| `INBOX_PATROL_LOCK_DIR` | `${TMPDIR:-/tmp}/com.kitamura.inbox-patrol.lock` | 実行全体を排他する mkdir ロックのパス。テスト時はfixture専用パスに差し替える |

## ログ先

このloop自体の実行ログ（stdout/stderr）は repo外（`loop-runbook.md` §5 の規約どおり）。draft plist は `output/logs/launchd.{out,err}.log` を指定している（稼働中に切り替えた場合のみ生成される）。

## 関連

- 実行方式の定義: `../../references/loop-types.md`（②headless、判断部分のみAI）。
- loop 起動標準: `../../references/loop-runbook.md`。
- トリアージ手順の正本: `../../../skills/inbox-triage/SKILL.md`（複製しない・ここから参照のみ）。
- headless起動系統の参考実装: `../ai-jobs-dispatcher/scripts/common.ts`（`buildWorkerCommand`）。
- インボックス見出し・マーカー流儀の正本: `../renderer/templates/デイリー.md`。
- 親計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-02-状態と記録の統合設計/plans/06-依頼インボックスloop.md`（完了条件はここが正本）。
- 統合program 方針§8: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-02-状態と記録の統合設計/program.md`。
