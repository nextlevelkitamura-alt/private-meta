---
稼働状態: draft（未起動・launchd未ロード。人間がbootstrap登録するまで無効）
設計: ~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-06-デイリーNotion表反映/plan.md
起動: launchd `com.kitamura.daily-notion-sync`（StartInterval 30・symlink未登録＝人間ゲート）。手動実行は `scripts/sync.sh`。
---

# daily-notion-sync（当日デイリー→Notion表 30秒ミラー）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

当日デイリーの「## 動いているエージェント」と「## 終わったこと」を、Notionの表A/表Bへ30秒ごとに
反映し、外出先のスマホから今動いているものと当日終わったものを見られるようにする。
正本は常にローカルMD（デイリー）。Notionは表示専用のミラーであり、このloopはローカルMD側へは
一切書き込まない（読むだけ）。

## 対象

- 入力: `${GOAL_BASE:-~/Private/personal-os/my-brain/ゴール}/デイリー/<年>/<月>/<年-月-日>.md`
  （実行時点のJST当日のみ）。
  - `## 動いているエージェント` 節（board.pyのLINE_RE準拠・1行=1セッション）。
  - `## 終わったこと` 節（`### repo` ＞ `- 親タスク` ＞ `  - HH:MM 子成果` の入れ子）。
  - 見出し・行フォーマットの正本は `../../hooks-registry/hooks/session-board/board.py`。
- 出力: Notion「動いているエージェント」DB（表A・キー列=s:keyで冪等upsert）と
  「終わったこと」DB（表B・キー列=repo|親タスク|時刻|成果の連結で冪等upsert）。
  どちらも当日デイリーから消えた行はarchiveする。

## 起動条件（shouldRun）

- 30秒ごと（launchd `StartInterval 30`）。
- 当日デイリーが未生成の場合は0件として扱う（エラーにしない。日付またぎ直後の正常な空白期間）。
- 何度実行しても冪等（後述）。

## 各回の実行（command）

```
scripts/sync.sh
```

`runner: script`（差分検知・ロックは非AI・決定的。Notion呼び出しのpayload生成・JSON抽出だけ
Pythonヘルパ `notion_helper.py` を使う）。処理順:

1. **多重起動防止**: `sync.sh` 自身がmkdirロックで排他する（stale=300秒で自己修復）。
2. 当日デイリーの2節を `parse-daily.sh` でTSVへ正規化し、連結してsha256化する。
3. 前回値（`state/notion-session-table-sync-signature`）と一致すれば**Notion API呼び出しゼロ**でexit。
4. 不一致（変化あり）の時だけ `session-table.sh` を `SESSION_TABLE_STRICT=1` で実行する。
   - 親ページ「Personal OS」解決（renderer由来のN1/N2/N3と同じ `state/notion-parent-page-id`
     キャッシュを共有・再検索しない）。
   - 表A/表B DBの解決（state→search→無ければ作成）とスキーマの冪等PATCH。
   - 表A: 当日「動いているエージェント」全行をs:keyで完全一致upsert。消えたキーはarchive。
   - 表B: 当日「終わったこと」全行をrepo|親タスク|時刻|成果のキーでupsert（既存キー一致は
     不変ログのため何もしない・新規のみ作成）。消えたキーはarchive。
5. 成功時だけsignatureを更新する（失敗時は次回30秒tickが自動的に再試行する）。

## 冪等性

- 表A・表Bとも、同一キーでの2回目以降の実行は既存行のid照合のみで完結し、新規行を増やさない
  （`resolve_existing_id`の完全一致判定。実機smokeテストで2回連続実行の重複ゼロを確認済み）。
- 空データ誤archive防止: `state/notion-sessions-last-count` / `state/notion-done-last-count` に
  前回件数を保持し、今回0件・前回が0件でない場合はarchiveを今回skipして警告のみに留める
  （2回連続で0を確認できた時だけarchiveする。日付またぎ直後の一瞬のギャップでの誤archiveを防ぐ。
  renderer由来notion-lanes.shの空スナップショット誤アーカイブ防止と同じ設計）。

## 完了・停止条件

- 完了（1回）: `sync.sh` がexit 0で終わる（差分なし・差分ありどちらも正常終了）。
- 停止: launchd登録前は「未起動」。登録後の停止は
  `launchctl bootout gui/$(id -u)/com.kitamura.daily-notion-sync`（人間ゲート）。

## 設定・環境変数

secret以外はgit管理・secretはkeychainのみ（値は一切書かない）。

- `GOAL_BASE`: 既定 `~/Private/personal-os/my-brain/ゴール`（`scripts/_paths.sh`）。デイリー探索起点。テスト時は上書きする。
- `NOTION_SYNC_CONF`: 既定 `notion.conf`（このloop直下）。`NOTION_PARENT_PAGE_ID`を保持（空なら自動発見）。
- `NOTION_SYNC_STATE_DIR`: 既定 `state/`（このloop直下）。DB idキャッシュ・last-count・signature・lock置き場。
- `NOTION_SYNC_KEYCHAIN_SERVICE`: 既定 `notion-personal-os`。keychainのservice名。
- `SESSION_TABLE_STRICT`: `sync.sh`が変化検知時に`1`を付けて`session-table.sh`を呼ぶ内部フラグ。
  既定のフェイルセーフ（失敗時exit 0）を上書きし、失敗を非0終了として伝播させる。
- `SESSION_TABLE_SYNC_LOCK_DIR`: 既定 `state/notion-session-table-sync.lock`。多重起動防止ロックのパス。テスト時はfixture専用パスに差し替える。
- テスト専用: `NOTION_SECURITY_CMD` / `NOTION_CURL_CMD`（`notion-common.sh`経由でcurl/securityをstubへ差し替える）。

## ログ先

このloop自体の実行ログ（stdout/stderr）はrepo外（`loop-runbook.md` §5の規約どおり）。draft plistは
`output/logs/sync.{out,err}.log` を指定している（稼働中に切り替えた場合のみ生成される）。

## 関連

- 設計正本: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-06-デイリーNotion表反映/plan.md`。
- データ源の正本: `../../hooks-registry/hooks/session-board/`（`board.py`・`README.md`）。
- 移設した共有ロジック（secret取得・HTTP呼び出し・親ページ解決）: `scripts/notion-common.sh`・
  `scripts/notion_helper.py`（旧renderer由来。移設済み・renderer配下は参照しない）。
- 作り替え元（upsert/archive/差分syncのパターン見本。依存はしない・参照のみ）:
  `../renderer/scripts/notion-lanes.sh`・`../renderer/scripts/lanes-sync.sh`。
- 実行方式の選び方: `../../references/loop-types.md`（③hookではなく②script相当の毎tick決定的実行）。
