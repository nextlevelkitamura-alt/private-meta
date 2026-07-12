分類: loop ／ 種別: 既存改善（renderer廃止後のNotion連携を session-board 源で作り直す） ／ 優先: ○ ／ 規模: ライト
次: `loops/daily-notion-sync/` は実装・launchd登録済み。現行実体と状態は同loopの `loop.md` と `実行一覧/personal-os.md` を正とする。

# デイリー状態のNotion表反映（session-board 源・30秒）

## 目的

当日デイリーの「動いているエージェント」と「終わったこと」を Notion の表(DB)へ30秒ごとに反映し、外出先のスマホから **今動いているもの** と **当日終わったもの** を一目で見られるようにする。正本は常にローカルMD（デイリー）。Notionは表示専用のミラー。

## 現状

- デイリーは session-board（`hooks/session-board/board.py`）がイベント駆動で2節を書く。
  - `## 動いているエージェント`: 1行=1セッション。`- HH:MM | repo | 種別 | 要約 | 状態 <!-- s:key -->`（`LINE_RE`）。状態は🟢動作中/⏸停止・確認待ち/🔵サブ稼働中の3値。
  - `## 終わったこと`: `### repo` ＞ `- 親タスク` ＞ `  - HH:MM 子成果` の入れ子。
- 旧Notion連携（`../2026-07-02-Notionオンライン盤面/plan.md`）は renderer loop 配下で N1（全文push）/N2（インボックスpull）/N3（計画ボード）/N3b（レーン実況）を実装したが、**renderer廃止（2026-07-06）で停止**。旧「レーン実況」DBは `orca worktree ps` 源で、session-board源ではない（データ源が違う）。
- **現行Notion資産**（2026-07-11再確認）: keychain `notion-personal-os`、親ページ「Personal OS」、`loops/daily-notion-sync/state/` と同loopの `scripts/`。旧rendererへの実行依存はない。
- launchd `com.kitamura.daily-notion-sync` は登録済み・loaded（StartInterval 30秒）。
- **申し送り（2026-07-09・デイリー運用刷新の調査4より）**: 実装済みの `loops/daily-notion-sync/scripts/parse-daily.sh` は旧v1行形式の正規表現のままで、**現行ボードv2.2行に1行もマッチしない（断線中）**。修正時は正規表現の二重定義をやめ board.py `parse_line` の import へ一本化を推奨（以後の行フォーマット進化に自動追従）。また `../2026-07-09-デイリー運用刷新/` が「## 今日すること」業務行(b:key)等の新節を足すが、セッション行のLINE_REは変えない設計（業務表を足すなら新DB＝純加算）。

## 方針

1. **置き場所**: 新独立loop `loops-registry/loops/daily-notion-sync/` を新設し、Notion連携部を廃止renderer から救出・移設する。renderer廃止フォルダへの依存を断つ。
2. **流用（移設）**: `notion-common.sh`（token取得・親ページ解決・HTTP・DB解決）と `notion_helper.py`（JSON payload生成）を移設して使う。全文ページ `notion-push.sh` は補助として温存（今回は主役でない・§未確定）。
3. **作り替え**:
   - データ源: `orca worktree ps` → **デイリーmdの2節をparse**（`board.py` の `LINE_RE`・入れ子構造と同型の解析）。
   - `lanes-sync.sh` → **`sync.sh`**（デイリー2節の差分検知30秒ラッパ）。
   - `notion-lanes.sh` → **`session-table.sh`**（2節 → 2つのDBへupsert／archive）。
   - `notion_helper.py` に **表A・表B用の payload生成サブコマンド**を追加（旧11列lane payloadは使わない）。
4. **表A・動いているエージェント**（`## 動いているエージェント` → DB）: 1行=1セッション。
   - 列: 内容(title=`summary`)／状態(select=`state`)／種別(select=`type`)／開始(rich_text=`time`)／repo(select=`repo`・グループ用)／キー(rich_text=`s:key`・**upsert照合キー**・普段は隠し列)。
   - **upsertキー=s:key**。デイリーから消えたキーの行は archive。
   - ビュー: 時刻左・repoグループ化（初回1回の人間設定）。
5. **表B・終わったこと**（`## 終わったこと` → DB）: 1行=1成果（時刻付き子）。
   - 列: 成果(title=子本文)／時刻(rich_text)／repo(select=`### repo`・グループ)／親タスク(select or rich_text=`- 親`・サブグループ)。
   - **repo ＞ 親タスクの2段グループ化**で入れ子表示（Notion DBのグループ化上限=2段。今の3階層 repo＞親＞子 に過不足なく収まる）。
   - upsertキー: `repo|親タスク|時刻|成果` のハッシュ等で冪等に（同一入力→同一DB状態・全置換 or キー照合）。当日分のみ対象。
6. **更新頻度**: launchd `StartInterval 30`。各節の差分検知（sha256）で無変化ならAPIゼロ。多重起動防止mkdirロック（旧 `lanes-sync.sh` 同型・stale自己修復）。
7. **フェイルセーフ**: token取得失敗・API失敗はいずれも警告1行+exit 0で吸収。正本MD運用に一切影響させない（N1と同一規律）。
8. **secret規律**: `NOTION_TOKEN` は keychain から変数保持のみ。表示・記録・commit禁止。
9. **人間ゲート**: launchd登録（symlink+bootstrap）と Notion ビューの初回設定（グループ化・並べ替え）は人間が行う。

## 未確定 / 運用で決める

- 表Bの既定ビュー: repoグループ化 か 親タスクグループ化（両ビュー可能・切替）。
- 旧「レーン実況」DB（orca ps源・`...6e9e`）: 新DBに置き換え、旧DBはNotion側で archive。
- 全文ページ(N1・`notion-push.sh`)を並行運用するか: 当面は表A/表Bのみで開始し、必要なら後付け。
- 深い入れ子（3段超）が必要になった場合: 表Bだけ DB→ページのトグルへ（時刻ソート/件数は失う）。現状は不要。
- 旧 renderer フォルダ本体（builder群）の削除: Notion資産の移設完了後に別作業・人間承認で。

## 完了条件（レビュー項目）

- [ ] `loops/daily-notion-sync/` が新設され、`notion-common.sh`・`notion_helper.py` が移設され、スクリプトが renderer 配下を参照しない。
- [ ] 表A DBに、当日デイリー「動いているエージェント」の全行が 1行=1セッションで載る（`s:key` で冪等upsert・2回連続実行で重複ゼロ）。
- [ ] デイリーから消えたセッション行が、次回 sync で表A上で archive される。
- [ ] 表B DBに、当日「終わったこと」が repo＞親タスクの2段グループ化で入れ子表示できる（成果・時刻・repo・親タスクの各フィールドが全行埋まる）。
- [ ] 「動いているエージェント」節が無変化のとき、sync 実行で Notion API 呼び出しが 0回（差分検知が効く・signature一致で即exit）。
- [ ] `StartInterval 30` のplistで前回runと多重起動しない（mkdirロック・stale自己修復）。
- [ ] token・認証値が repo・ログ・デイリーのどこにも出ない（`grep` 確認）。
- [ ] Notion障害・API失敗時にローカルMD運用が一切影響を受けない（失敗は警告のみ・正本はMD）。
- [ ] 実機スモーク: デイリーを1件更新 → 30秒以内に表A/表Bへ反映し、スマホで確認。
