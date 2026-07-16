---
稼働状態: 一時停止（2026-07-14、v3 session-board行の解析不整合によるNotion誤archive防止）
設計: ~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-06-hooks-registry再編とsymlink露出/plans/05-daily-notion-sync安全回復.md
起動: launchd `com.kitamura.daily-notion-sync` は2026-07-14に `bootout` 済み。修正・review・人間確認まで手動実行もしない。
---

# daily-notion-sync（当日デイリー→Notion表 30秒ミラー）

`../../AGENTS.md` のloop契約に沿った実行スペック。1 loop＝1タスク定義。

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
  - 見出し・行フォーマットの正本は `../../../hooks-registry/shared/session-board/board.py`。
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
   - 対象ファイル未生成、または必須節が存在する正しい空節は0件として成功する。
   - 見出し欠落、未知行、壊れた入れ子、重複キーは解析失敗として非0終了する。
   - 解析失敗時は `session-table.sh`、archive、signature更新へ進まない。
3. 前回値（`state/notion-session-table-sync-signature`）と一致すれば**Notion API呼び出しゼロ**でexit。
4. 不一致（変化あり）の時だけ `session-table.sh` を `SESSION_TABLE_STRICT=1` で実行する。
   - 親ページ「Personal OS」解決（renderer由来のN1/N2/N3と同じ `state/notion-parent-page-id`
     キャッシュを共有・再検索しない）。
   - 表A/表B DBの解決（state→search→無ければ作成）とスキーマの冪等PATCH。
   - 表A: 当日「動いているエージェント」全行をs:keyで完全一致upsert。消えたキーはarchive。
   - 表B: 当日「終わったこと」全行をrepo|親タスク|時刻|成果のキーでupsert（既存キー一致は
     不変ログのため何もしない・新規のみ作成）。消えたキーはarchive。
5. 成功時だけsignatureを更新する（失敗時は次回30秒tickが自動的に再試行する）。

## 冪等性と安全停止

- 表A・表Bとも、同一キーでの2回目以降の実行は既存行のid照合のみで完結し、新規行を増やさない
  （`resolve_existing_id`の完全一致判定。実機smokeテストで2回連続実行の重複ゼロを確認済み）。
- 2026-07-14に確認したv3行の0件誤認に対し、現在は `shared/session-board/md/store.py`
  のv3行と完了入れ子を解析する。表示用の目標要約行以外の未知形式は読み飛ばさない。
- `sync.sh` は解析失敗を非0で伝播する。`session-table.sh` の直呼びもsecret取得・Notion APIより前に
  同じ解析を行うため、解析不能時にupsert/archiveは始まらない。
- 正しい空節は「実際に0件」として当日DBへ即時反映する。解析エラーと空データの判定をarchive回数で
  代替しない。
- stubテストがPASSしてもloopは一時停止のままとし、独立reviewと人間確認前にNotion APIを実行しない。

## 完了・停止条件

- 完了（1回）: `sync.sh` がexit 0で終わる（差分なし・差分ありどちらも正常終了）。
- 停止:
  `launchctl bootout gui/$(id -u)/com.kitamura.daily-notion-sync`（人間ゲート）。
- 復帰: v3解析・archive保護・stub test・独立reviewがPASSした証跡を示し、人間が明示承認した時だけ
  `launchctl bootstrap` で再登録する。復帰前のNotion実書き込みは禁止。

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

このloop自体の実行ログ（stdout/stderr）はgitignoreされた
`output/logs/sync.{out,err}.log`。生ログはGit追跡しない。

## 関連

- 現在の安全回復計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-07-06-hooks-registry再編とsymlink露出/plans/05-daily-notion-sync安全回復.md`。
- 元の設計計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/paused/2026-07-06-デイリーNotion表反映/plan.md`（履歴・再開しない）。
- データ源の正本: `../../../hooks-registry/shared/session-board/`（`board.py`・`AGENTS.md`）。
- 移設した共有ロジック（secret取得・HTTP呼び出し・親ページ解決）: `scripts/notion-common.sh`・
  `scripts/notion_helper.py`（旧renderer由来。移設済み・renderer配下は参照しない）。
- upsert/archive/差分syncは旧renderer実装を移設して独立化済み。旧フォルダへの実行・文書依存はない。
- 実行方式: `../../AGENTS.md` の `runner: script`（hookではなく毎tickの決定的実行）。
