---
稼働状態: 停止（2026-07-04 全停止・bootout済み。2026-07-09 デイリー運用刷新 子06で60秒tick統合・権限強化へ改修済みだが **plistは未ロード**＝有効化は人間ゲート）
起動: `com.kitamura.inbox-tick.plist`（StartInterval 60・**draft・未ロード**・symlink方式で人間がbootstrapする）が `scripts/inbox-tick.sh` を呼ぶ。1tick = notion-inbox-pull.sh（Notion回収・常時）＋ patrol.sh（headless起案・`state/inbox-patrol-enabled` フラグがある時のみ＝第2の人間ゲート）。旧経路2本（launchd `com.kitamura.inbox-patrol` 30分毎=bootout済み・renderer lanes-sync相乗り=renderer停止中）は使わない。
設計: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-09-デイリー運用刷新/plans/06-インボックス即時起案.md`
---

# inbox-patrol（依頼インボックス巡回loop）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

当日デイリーの「依頼インボックス」に人間が書いた未処理の1行（またはNotionから回収した1行）を検知し、`inbox-triage` Skillをheadlessで起動して**対象repoの `plans/planning/` に計画ドラフト（plan.md）を起案**させ、完了を通知する。
**自動は planning バケットのドラフトまで。active化は人間承認**（2026-07-09 デイリー運用刷新program 裁定Q3。この1行が正本）。
**入口の位置づけ（2026-07-03子03裁定）**: 依頼の既定の入口は起票ゲートskill（`../../../skills/kickoff/`）。Notionインボックス（pull→デイリー）は例外入口（AI停止時・外出時・他者起票）。
**検出＝②script（決定的・非AI）／トリアージ判断＝headless AI（`inbox-triage` Skill）** の二段（`../../references/loop-types.md`）。
loopが起案より先（実装・実行）へ進まないことは、`inbox-triage` Skillの入力契約（起案までしかしない）と、このloopが patrol.sh 以外の経路で行を処理しないこと、および役割別許可設定（§権限）の三重で保証する。

**二重起案防止（差し戻し1回目で追加）**: tick起動どうしが重なる（前回実行が長引く／手動実行と重なる等）と、同じ行を2つの `patrol.sh` インスタンスが同時に拾って二重に起案し得る。これを防ぐため、実行全体を mkdir ロックで排他し（§各回の実行）、各行は起案（AI起動）の直前に未処理かを再確認してから「クレーム」してAIへ渡す（§冪等性・二重起案防止）。

## 構成（scripts/・2026-07-09 tick統合後）

- `scripts/patrol.sh` … 未処理行の決定的抽出→クレーム→headless AI起動→後始末・通知結線（本体）。
- `scripts/inbox-tick.sh` … 60秒tickの呼び出し口（pull→patrolの2段。renderer/scripts から移設）。
- `scripts/notion-inbox-pull.sh` … Notion「立案済」行の当日デイリー回収（renderer/scripts から移設。共有ライブラリ `../renderer/scripts/notion-common.sh`・`notion_helper.py` は renderer 側の正本を参照）。
- `scripts/notify-drafted.sh` … 起案完了通知（PC通知 osascript＋Notion行の状態=起案済みPATCH）。
- `settings/inbox-triage-permissions.json` … headless AIの役割別許可設定（§権限の正本）。
- `com.kitamura.inbox-tick.plist` … 60秒tickのlaunchdドラフト（**未ロード**）。
- `com.kitamura.inbox-patrol.plist` … 旧経路（patrol直叩き30分毎）。使わない・削除は人間承認待ち。
- `state/` … 実行時状態（gitignore）: `inbox-patrol-enabled`（patrol有効化フラグ・人間がtouch/rm）・`notion-inbox-pulled-ids`・`notion-inbox-origin-ids`（id↔依頼テキストの出所マップ）・`notion-inbox-database-id`・`notion-inbox-schema-planpath`・`notion-parent-page-id`。

## 対象

- `${GOAL_BASE:-~/Private/personal-os/my-brain/ゴール}/デイリー/<年>/<月>/<年-月-日>.md`（対象日のみ。既定は実行時点のJST当日）。
- 入力: 対象日デイリーの `## 依頼インボックス` 節（見出し文言は実装契約§1どおり既存互換。節の復活は子01=W1担当）。
- 出力: `inbox-triage` Skillが書く plan.md（**対象repoの `plans/planning/<YYYY-MM-DD-名前>/plan.md`**。repo判定は `../../../skills/plan-triage/SKILL.md` §3・起点は `../../../repo-registry/repo概要.md`）と、対象デイリーの対象行末尾の処理済み印（`→計画作成済み(<パス>)`）。plan.md本文の作成とその最終マーカーへの置換はSkillが行う。**patrol.sh 自身が書き込むのは「起案直前のクレーム印」（`→処理中(hash=... pid=... ts=...)`）だけ**であり、これはAI起動直前に付け、AI失敗時は自分で剥がす（§冪等性・二重起案防止）。
- **行末注記の語彙（2026-07-03子03裁定で統一）**: `→処理中(claim)` → `→計画作成済み(<パス>)` → `→着手(担当X)` → `→完了` の順に進む。`→処理中` の実形式は上記のクレーム印（hash=...）。`→着手`と`→完了`は、send采配した全体管理者または着手した指揮官が **`→計画作成済み(<パス>)` の後ろへ追記する**（置換しない。行に `→計画作成済み(` が残るため patrol.sh の未処理判定は変更なしで追従する）。終端系 `→重複(`・`→サクッと判定(` は従来どおり。

## 起動条件（shouldRun）

- 60秒ごと（`com.kitamura.inbox-tick.plist` StartInterval 60。**未ロード**＝現在は動いていない。稼働中の daily-notion-sync 30秒tickと同方式）。
- 1tick = (1) `notion-inbox-pull.sh`（常時・AIなし・冪等） → (2) `patrol.sh`（`state/inbox-patrol-enabled` が存在する時のみ＝launchdロードとは別の第2の人間ゲート）。
- 何度実行しても冪等（後述）。当日デイリーが無い日はスキップ（生成は他機構の仕事。このloopは生成しない）。
- チャット入口は検知不要（そのセッションが kickoff→plan-triage を対話実行・処理印を自分で付ける）。

## 各回の実行（command）

```
scripts/inbox-tick.sh                      # tick 1回分（pull→patrol）
scripts/patrol.sh [YYYY-MM-DD] [--dry-run] # patrol単体。日付省略時は実行時点のJST当日
```

`runner: script`（抽出・ロック・クレームは非AI・決定的）。patrol.sh の処理順:

0. **実行全体を mkdir ロックで排他する**（`INBOX_PATROL_LOCK_DIR`、既定 `${TMPDIR:-/tmp}/com.kitamura.inbox-patrol.lock`）。`mkdir` はbash3.2でも原子的。既に他インスタンスが動いていて取得に失敗したら、**待たずに即 `exit 1`**（後述）。`--dry-run` も含めて実行全体がこのロックの内側。
1. 対象日デイリーの `## 依頼インボックス` 節から、次の**すべて**を満たす行だけを未処理行として決定的に抽出する。
   - 行頭が `- ` で始まり、bullet本文が空でない（テンプレの空プレースホルダ `- ` を除外）。
   - 最終マーカー `→計画作成済み(` を含まない。
   - クレームマーカー `→処理中(` を含まない（＝他の実行が起案中でない）。
2. `--dry-run` 指定時は、上記抽出結果を1行1件で標準出力するだけで終わる（**AIを一切起動しない・クレームも書かない**）。動作確認・テスト専用。
3. `--dry-run` 無指定時、未処理行が1件以上あれば、行ごとに次を行う。**1tickのAI起動は `INBOX_PATROL_MAX_PER_TICK`（既定3）で頭打ち**にし、残りは次tickへ持ち越す（取りこぼしなし・費用と暴走の上限）。
   1. **起案直前の再確認**: その行がまだ未処理か（手順1と同じ条件）を、ファイルを読み直して再確認する。既に他の実行がクレーム/処理済みなら（同一内容の重複行が先の反復で一括クレームされた場合を含む）その行はスキップする。
   2. **クレーム（先行書込）**: `→処理中(hash=<内容一致キー> pid=<PID> ts=<epoch秒>)` を対象行の末尾に追記して書き戻す。内容が完全一致する行**すべて**に同時に付く＝同一内容の重複行は1回のクレームで冪等ユニットとして扱われる。
   3. `inbox-triage` Skill（`../../../skills/inbox-triage/SKILL.md`）の手順の正本とクレーム済みの行を指すプロンプトを組み立て、headless AIを起動する（§権限の起動形。`--dangerously-skip-permissions` は**使わない**）。
   4. **成功時**: Skill自身がクレーム印 `→処理中(...)` を最終マーカー `→計画作成済み(<path>)` に置き換える（対象行のみ。他の行には触れない契約）。続けてpatrol.shが、自分のクレームがまだ残る兄弟行（＝同一内容の重複行のうちSkillが書き換えなかった側）が無いかを走査し、あれば `→重複(同一依頼として処理済み)` へ書き換える（重複が無ければ何もしない）。最後に `notify-drafted.sh` を1回呼ぶ（§通知。ベストエフォート＝失敗してもpatrolは失敗にしない）。
   5. **失敗時**: patrol.shがクレーム印を剥がし、行を元の未処理状態に戻す（次回実行で再挑戦できるようにする）。
   - 経路判定（対象repo）・規模判定・plan.md起案は、起動された headless AI（`inbox-triage` Skill）自身が行う。
   - テスト・特殊運用時は環境変数 `TRIAGE_AI_CMD` で起動コマンドを差し替えられる（`tests/run-tests.sh` はこれでAIをstubに差し替える）。

## 権限（headless AIの役割別許可設定・2026-07-09子06）

他者も書けるNotion行テキスト（＝信頼できない入力）をheadless AIへ渡すため、skip-permissionsを廃止し、最小権限で起動する。

- 起動形（patrol.sh `invoke_ai`）: `claude -p "<prompt>" --settings settings/inbox-triage-permissions.json --setting-sources "" --permission-mode dontAsk --output-format text --max-budget-usd ${INBOX_PATROL_MAX_BUDGET_USD:-5}`
- **`--settings`**: 役割別許可の正本 `settings/inbox-triage-permissions.json`。読み=広く（Read/Glob/Grep）、書き=`Private/**/plans/planning/**` とデイリー `ゴール/デイリー/**`（処理印の行の置換）のみ。Bashは `ls`・`mkdir`・`plan-ops/scripts/new-plan.sh` だけをallow。
- **deny（明示拒否）**: `git push/commit/add/reset/restore/checkout/clean/rebase/merge/rm/mv/stash`・`rm`・`mv`・`sudo`・`launchctl`・`security`（keychain＝トークンへAIを触れさせない）・`curl`/`wget`・`osascript`・WebFetch/WebSearch・`plans/active/**` への書込（planning隔離）・`.ssh`/`.env` の読取。
- **`--setting-sources ""`**: ユーザー/プロジェクト設定のallowや hook がheadlessへ混入しない（許可面が settings ファイル1枚に固定される）。
- **`--permission-mode dontAsk`**: allowlist外のツールは問い合わせずに自動拒否（headlessは応答者がいないため）。
- **不正settingsの防御**: `-p` モードは検証に失敗したsettingsを黙って無視する仕様のため、patrol.sh は起動前にJSONとして読めることを確認し、読めなければAIを起動しない（クレームをロールバックして次tickへ）。
- **上限**: `--max-budget-usd`（既定5）＋ 1tickのAI起動数 `INBOX_PATROL_MAX_PER_TICK`（既定3）。
- 選定理由: claude CLI 実オプションを確認し、`--allowedTools`/`--disallowedTools`（フラグ直書き）より settingsファイル1枚を正本にする方が、許可面の差分レビュー・deny必須項目の機械チェック（tests）・`--setting-sources ""` との組み合わせで再現性が高いため。

## 通知（notify-drafted.sh・2026-07-09子06）

起案成功（対象行が `→計画作成済み(<パス>)` になった）1件につき patrol.sh が1回だけ呼ぶ。サクッと判定（`→サクッと判定(`）は無通知。

1. **PC通知**: `osascript display notification`（argv方式・watch-keeper `keeper.sh` の前例と同型）。`INBOX_NOTIFY_CMD` で差し替え可（テストはstub）。
2. **Notion行PATCH**: pull時に記録した出所マップ `state/notion-inbox-origin-ids`（`id<TAB>依頼テキスト`）で該当行を逆引きし、`状態=起案済み`＋`計画パス`（rich_text）をマージPATCHする（スマホ到達）。マップに無い行（デイリー直書き・kickoff起票）はPC通知のみ。旧DBに「起案済み」選択肢と「計画パス」プロパティが無い場合に備え、初回のみDBスキーマを冪等PATCHする（`state/notion-inbox-schema-planpath` マーカー。selectのoptionsは置き換え挙動のため既存選択肢を全量含めて送る）。
3. 全経路ベストエフォート（警告1行＋exit 0）。通知失敗は起案の成否に影響しない。
- Notion状態機械: 空白(下書き) → `立案済`(人間がスマホで切替=回収対象) → `回収済み`(pull) → `起案済み`(notify・計画パス付き)。

## 冪等性・二重起案防止

- 抽出（`--dry-run`含む）は読み取り専用・非AI・非乱数。同一入力なら同一出力（同じ未処理行の集合を返す）。
- **プロセス間の排他**: 実行全体を mkdir ロックで排他するため、`patrol.sh` の複数インスタンスが同時に同じ行を処理することはない（後から来た側は即終了する）。
- **同一実行内の再確認**: 各行は「起案直前」に未処理かどうかを再度確認してからクレームする。これにより、直前の反復でのクレーム書込が終わった直後の行（＝同一内容の重複行）を二重に起案しない。
- **同一内容の重複行の扱い（決定）**: インボックスに同一文言の行が複数あっても、内容一致を鍵にした1つの冪等ユニットとして扱う。クレームは内容が一致する行すべてへ同時に書き込むため、2行目以降は「起案直前の再確認」で既にクレーム済みと判定されスキップされる＝AIは1回しか起動されない。行番号やUUID等の識別子は導入しない（依頼インボックスは自由記述のテキストであり、位置情報を安定した識別子として使えないため）。ただし `inbox-triage` Skillは契約上「渡された対象行だけ」を書き換え、クレームされた兄弟行には触れないため、Skill完了後にpatrol.sh自身が後処理として、自分のクレームがまだ残る兄弟行を `→重複(同一依頼として処理済み)` という終了状態サフィックスへ書き換え、`→処理中(...)` が永久に残留しないことを保証する（差し戻し2回目対応。`finalize_duplicate_leftovers`）。
- **失敗時のロールバック**: headless AI起動が失敗（非0終了）した場合、patrol.shはクレーム印を剥がして行を元の未処理状態に戻す。次回実行で再挑戦できる。
- **ロックの手動復旧**: patrol.sh はロックの stale 自動回収を持たない（MVP）。プロセスが異常終了してロックが残った場合は、人間が `rm -rf "$LOCK_DIR"` で手動解除する（`$LOCK_DIR/owner` に `pid`/開始時刻を記録している）。
- **既知の実装上の注意（macOS標準awkの `==` バグ）**: クレーム/最終マーカーの行一致判定で `awk '{ if ($0 == target) ... }'` を使う箇所は、すべて `LC_ALL=C` を明示している。UTF-8ロケール（`en_US.UTF-8` 等）のままだと、macOS標準awk（one true awk）が日本語の**異なる**文字列同士を `==` で誤って真と判定することを実測で確認した（例: `"重複した依頼" == "単独の依頼"` が真になる）。`extract_unprocessed` の見出し検出・空白trim・マーカー含有チェック（`index()`）はASCIIパターンとバイト単位一致で完結するため、`LC_ALL=C` に切り替えても抽出結果は変わらない。この注意が無いまま行一致判定を追加・変更すると、無関係な行を誤ってクレーム/上書きする恐れがある（`tests/run-tests.sh` の t8 がこの回帰を検出する。`notify-drafted.sh` のパス抽出・出所逆引きも同じ理由で `LC_ALL=C`）。

## 完了・停止条件

- 完了（1tick）: pull 1回＋対象日デイリーの未処理行（上限 `INBOX_PATROL_MAX_PER_TICK` 件まで）に対して headless AI起動を1回ずつ行い終える（`--dry-run` の場合は抽出結果を出力し終える）。
- 有効化（**両方とも人間ゲート**）: §有効化手順を参照。
- patrol一時停止（tickは回したままAI起案だけ止める）: 人間が `rm state/inbox-patrol-enabled`（pullによるNotion回収は続く）。
- 完全停止: `launchctl bootout gui/$(id -u)/com.kitamura.inbox-tick`＋`~/Library/LaunchAgents/` のsymlinkを外し、frontmatter を `停止` に戻す。

## 有効化手順と検証（人間ゲート後のE2E手順書）

launchd未ロードのため、以下は**有効化後に人間が行う手順書**（機械で事前検証済みの範囲は tests/run-tests.sh が担う。§関連のテスト対照表を参照）。

1. 事前: `scripts/patrol.sh --dry-run` で抽出のみ確認（AI起動なし）。`tests/run-tests.sh` 全緑を確認。
2. 旧stateの引き継ぎ（任意・推奨）: `mkdir -p state && cp ../renderer/state/notion-inbox-pulled-ids state/ 2>/dev/null || true`（renderer時代のpull済みid。省略すると「立案済のまま残っている行」が1回だけ再取り込みされ得る）。
3. tick有効化（人間ゲート1）: plist冒頭コメントのsymlink＋bootstrap＋enable を実行。
4. patrol有効化（人間ゲート2）: `touch state/inbox-patrol-enabled`。
5. E2E確認（子計画06のレビュー項目）:
   - **Notion経路E2E**: スマホでインボックスDBに1行入れ「立案済」へ→90秒以内に対象repoの `plans/planning/<YYYY-MM-DD-名前>/plan.md` ができ、現状節に原文と出所（Notion行・デイリーパス・日付）が残る。
   - **重複冪等**: 同一文言を2回起票→planningの新規フォルダは1つ・デイリー2行目は `→重複(` で終端・`→処理中(` が5分後に残留しない。
   - **planning隔離**: `plans/active/` に新規フォルダが増えない・`git log` にheadless由来のcommitが無い（`git status` でplan.mdはuntracked）。
   - **通知到達**: Notion行が「起案済み」になり「計画パス」プロパティが読める。PC在宅時はmacOS通知が1回だけ出る。
   - **秘匿・権限**: plan.md・デイリー・`output/logs/tick.*.log` に token/認証値が現れない。`settings/inbox-triage-permissions.json` の deny に push・削除系が含まれる。
6. 初日は `output/logs/tick.err.log` を数回確認し、警告の常連が無いことを見る。

## 設定・環境変数

secret / token は keychain（`notion-personal-os`）参照のみ。値を表示・記録・コミットしない。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `GOAL_BASE` | `~/Private/personal-os/my-brain/ゴール`（`../../daily-digest/scripts/_paths.sh` 経由） | デイリー日次ファイルの探索起点。テスト時は上書きする |
| `TRIAGE_AI_CMD` | 未設定（既定は `claude -p ...`） | headless AI起動コマンドの差し替え。テストではstubスクリプトを指す |
| `INBOX_PATROL_CLAUDE_CMD` | `claude` | 実起動系統の差し替え（テストが起動引数の契約を検証するための口。stub使用時は `TRIAGE_AI_CMD` が優先） |
| `INBOX_PATROL_SETTINGS` | `settings/inbox-triage-permissions.json` | 役割別許可設定の差し替え |
| `INBOX_PATROL_MAX_PER_TICK` | `3` | 1tickあたりのheadless AI起動数上限 |
| `INBOX_PATROL_MAX_BUDGET_USD` | `5` | headless 1起動あたりの費用上限（`--max-budget-usd`） |
| `INBOX_PATROL_LOCK_DIR` | `${TMPDIR:-/tmp}/com.kitamura.inbox-patrol.lock` | 実行全体を排他する mkdir ロックのパス。テスト時はfixture専用パスに差し替える |
| `INBOX_PATROL_ENABLED_FILE` | `state/inbox-patrol-enabled` | patrol有効化フラグ（inbox-tick.sh が見る。人間が touch/rm） |
| `INBOX_TICK_DISABLED` | 未設定 | 非空でtick全体をskip（テスト切り離し口） |
| `INBOX_NOTIFY_CMD` | 未設定（既定は内蔵osascript） | PC通知コマンドの差し替え（`title` `body` の2引数。テストはstub） |
| `NOTION_PUSH_STATE_DIR` | `state/`（本loop配下） | pull/notifyの実行時状態置き場。テスト時はfixture専用パスに差し替える |
| `NOTION_PUSH_CONF` | `../renderer/notion-push.conf` | parent page id のconf（renderer側を参照） |
| `NOTION_PUSH_KEYCHAIN_SERVICE` | `notion-personal-os` | keychainサービス名 |
| `NOTION_SECURITY_CMD` / `NOTION_CURL_CMD` | `security` / `curl` | notion-common.sh のstub差し替え口（テスト用） |

## ログ先

このloop自体の実行ログ（stdout/stderr）は draft plist が `output/logs/tick.{out,err}.log` を指定（gitignore済み。稼働させた場合のみ生成される）。定常tick（立案済0件・未処理0件）は無音（1日1440tickでログを埋めない）。

## 関連

- 実行方式の定義: `../../references/loop-types.md`（②headless、判断部分のみAI）。
- loop 起動標準: `../../references/loop-runbook.md`。
- トリアージ手順の正本: `../../../skills/inbox-triage/SKILL.md`（複製しない・ここから参照のみ）。
- 経路判定（対象repo→plans/planning）の正本: `../../../skills/plan-triage/SKILL.md` §3、repo一覧の起点: `../../../repo-registry/repo概要.md`。
- 共有Notionライブラリの正本: `../renderer/scripts/notion-common.sh`・`../renderer/scripts/notion_helper.py`（移設しない・参照のみ）。
- PC通知の前例: `../watch-keeper/scripts/keeper.sh` の `notify()`。
- テスト: `tests/run-tests.sh`（抽出・冪等・二重起案防止・件数上限・権限契約・通知。AI/Notion/通知は全てstub・実ファイル/実API非接触）。
- インボックス見出し・マーカー流儀の正本: `../renderer/templates/デイリー.md`。
- 旧親計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/done/2026-07-02-状態と記録の統合設計/plans/06-依頼インボックスloop.md`。
- 現行設計・完了条件の正本: frontmatter「設計:」の子計画06。
