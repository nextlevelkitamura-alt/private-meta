# 実行loop一覧

このMDは、Mac上で現在動かす自作の定期loopを一望する正本。
実装・plist・詳細ログは各loopまたは所有repoを正とし、ここには判断に必要な要約と導線だけを置く。

- 最終全体確認: 2026-07-12 16:53 JST
- 対象: 時刻・間隔で自動発火する自作loop
- 対象外: hook、手動コマンド、外部アプリのupdater、常駐service
- 実機状態: `launchctl print gui/$(id -u)/<label>` を正とする

表示と追加先は次の2領域だけに分ける。

- `Personal OS`: Mac・AIエージェント基盤・セッション・情報同期・保守
- `仕事`: 仕事repoが所有する業務自動化

## AI運用・セッション管理

<!-- LOOP:board-reconcile -->
### `board-reconcile`
- 領域: Personal OS
- 分類: AI運用・セッション管理
- scope: global
- 目的: session-boardの生存照合を補完し、沈黙した稼働表示を停止へ戻す
- 内部処理: [{"name":"当日ボードを確認","detail":"当日のデイリーが無ければ何も作らず終了する"},{"name":"稼働行を抽出","detail":"動作中・サブ稼働中の行だけを対象にする"},{"name":"実体記録を照合","detail":"行のキーに対応するClaude/Codex transcriptの最新更新時刻を探す"},{"name":"沈黙閾値を判定","detail":"動作中は10分、サブ稼働中は30分を目安に実体の沈黙を判定する"},{"name":"停止表示へ戻す","detail":"閾値超過行だけを停止・確認待ちへ変更し、Turso側のイベントも同期する"}]
- 実行方法: launchd → reconcile.sh → board.py reconcile
- 発火: 5分ごと
- 発火設定: {"StartInterval":300}
- launchd構成: 専用loop。状態照合だけを低負荷で行う
- 統合判断: 維持。閾値が10分・30分なので5分周期に固有の意味がある
- 失敗時: 即時再試行なし。次の5分tickで再実行
- 記録: ローカル `loops/board-reconcile/output/logs/board-reconcile.{out,err}.log`
- runner: script
- launchd label: com.kitamura.board-reconcile
- 正本: loops/board-reconcile/loop.md
- plist: loops/board-reconcile/com.kitamura.board-reconcile.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

<!-- LOOP:board-sweep -->
### `board-sweep`
- 領域: Personal OS
- 分類: AI運用・セッション管理
- scope: global
- 目的: 停止行を安全弁つきで判定し、確実に完了した行だけを完了へ流す
- 内部処理: [{"name":"停止行を列挙","detail":"当日と前日の停止・確認待ち行を収集する"},{"name":"transcriptを照合","detail":"Claude/Codexの実体記録とCodex末尾task_completeを確認する"},{"name":"定型台帳を照合","detail":"routine-ledgerの一致条件・完了判定・沈黙ガードを確認する"},{"name":"会話を要約","detail":"初回依頼と末尾ターンを優先し、対象行ごとの会話ダイジェストを作る"},{"name":"read-only AI判定","detail":"台帳対象外をまとめてdone・not-done・unknownに分類する"},{"name":"二重鍵と上限を適用","detail":"機械証跡とAI doneの両方、または台帳一致だけを対象にし、1回最大3件へ制限する"},{"name":"完了へ移動","detail":"適格行だけboard.py finishで終わったことへ移し、失敗時はボードを変更しない"}]
- 実行方法: launchd → sweep.sh --apply → sweep.py → read-only AI判定
- 発火: 60分ごと
- 発火設定: {"StartInterval":3600}
- launchd構成: 専用loop。意味判定とAI呼び出しを低頻度で行う
- 統合判断: 維持。5分の生存照合とは責務・負荷・安全条件が異なる
- 失敗時: ボード無変更で終了。次の60分tickで再評価
- 記録: ローカル `loops/board-sweep/output/logs/board-sweep.{out,err}.log`
- runner: script
- launchd label: com.kitamura.board-sweep
- 正本: loops/board-sweep/loop.md
- plist: loops/board-sweep/com.kitamura.board-sweep.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

## 情報同期

<!-- LOOP:daily-notion-sync -->
### `daily-notion-sync`
- 領域: Personal OS
- 分類: 情報同期
- scope: global
- 目的: 当日デイリーの稼働中・完了情報を表示専用のNotion表へミラーする
- 内部処理: [{"name":"多重起動を防止","detail":"mkdirロックを取得し、300秒超のstale lockは自己修復する"},{"name":"当日2節を解析","detail":"動いているエージェントと終わったことをTSVへ正規化する"},{"name":"差分signatureを計算","detail":"前回と同じならNotion APIを呼ばず終了する"},{"name":"Notion側を準備","detail":"親ページ・当日ページ・表A/表Bをstate→検索→必要時作成の順で解決する"},{"name":"表Aを同期","detail":"稼働行をsession keyでupsertし、消えた行を安全ガード付きでarchiveする"},{"name":"表Bを同期","detail":"完了行をrepo・親・時刻・成果の複合キーでupsertし、消えた行をarchiveする"},{"name":"成功を確定","detail":"全処理成功時だけsignatureを更新し、失敗時は次の30秒周期へ持ち越す"}]
- 実行方法: launchd → sync.sh → 差分検知 → Notion API
- 発火: 30秒ごと
- 発火設定: {"StartInterval":30}
- launchd構成: 専用loop。30秒ごとに起動するが差分なしならAPI呼び出しゼロ
- 統合判断: 維持。外出先表示の反映速度を担い、他loopと時間軸が異なる
- 失敗時: signatureを更新せず、次の30秒tickで自動再試行
- 記録: ローカル `loops/daily-notion-sync/output/logs/sync.{out,err}.log` ／ Notion表示 ／ stateは同loopの `state/`
- runner: script
- launchd label: com.kitamura.daily-notion-sync
- 正本: loops/daily-notion-sync/loop.md
- plist: loops/daily-notion-sync/com.kitamura.daily-notion-sync.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

## 保守・整理

<!-- LOOP:session-record-prune -->
### `session-record-prune`
- 領域: Personal OS
- 分類: 保守・整理
- scope: global
- 目的: 30日を超えたClaude・Codexセッション記録を内蔵ディスク上のTrashへ移す
- 内部処理: [{"name":"対象を固定","detail":"Claude projectsとCodex sessions配下のjsonlだけを対象にする"},{"name":"保持期限を判定","detail":"最終更新から30日を超えたファイルだけを候補にする"},{"name":"安全ガードを確認","detail":"ファイルsymlinkを除外し、symlink directoryへ降りず、Trashと同じvolumeだけを扱う"},{"name":"内容を読まず集計","detail":"statだけで対象件数と容量を計算し、セッション本文は開かない"},{"name":"Trashへ移動","detail":"同名衝突を連番で避けながら復旧可能なTrashへ移す"},{"name":"結果を判定","detail":"件数・容量・対象directoryだけを記録し、対象があるのに全件失敗ならexit 1にする"}]
- 実行方法: launchd → prune.sh → prune.py --apply
- 発火: 月・水・金 18:00
- 発火設定: {"StartCalendarInterval":[{"Weekday":1,"Hour":18,"Minute":0},{"Weekday":3,"Hour":18,"Minute":0},{"Weekday":5,"Hour":18,"Minute":0}]}
- launchd構成: 専用calendar loop。定刻を逃すとMac復帰時に1回実行される
- 統合判断: 維持。曜日・時刻で動く保守処理で短周期loopと統合する意味がない
- 失敗時: 即時再試行なし。次の月・水・金18:00。発火を逃した場合はwake時に1回
- 記録: ローカル `loops/session-record-prune/output/logs/session-record-prune.{out,err}.log`
- runner: script
- launchd label: com.kitamura.session-record-prune
- 正本: loops/session-record-prune/loop.md
- plist: loops/session-record-prune/com.kitamura.session-record-prune.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / never exited

## 仕事・求人運用

<!-- LOOP:nextlevel-dispatcher -->
### `nextlevel-dispatcher`
- 領域: 仕事
- 分類: 仕事・求人運用
- scope: repo-local
- 目的: NextLevel系の時限処理・求人更新・認証維持・求人巡回・月次生成を一括巡回する
- 内部処理: [{"name":"巡回stateを読む","detail":"6タスクの最終起動時刻をdispatcher-state.jsonから読む"},{"name":"期限を判定","detail":"タスクごとの毎分・15分・60分・日次・月金条件をJSTで評価する"},{"name":"重複起動を防止","detail":"タスク別PID lockを確認し、実行中はskip、期限超過lockは除去する"},{"name":"entry-schedule","detail":"毎分、自動処理表から期限内の未実行行を拾い、エントリー・Meet・確定案内・カレンダー・架電・通知へ振り分ける"},{"name":"keep-alive","detail":"通常15分、平日朝の認証枠で未認証なら毎分、管理画面sessionを確認・延命する"},{"name":"job-update","detail":"15分ごとに月別求人更新表を読み、対象求人を管理画面で一括更新して結果を書き戻す"},{"name":"job-update-schedule-generator","detail":"9時以降60分ごとに当月、10日以降は翌月の求人更新表不足を補完する"},{"name":"monthly-schedule-generator","detail":"9時以降1日1回、翌月の自動処理表を作成または補完する"},{"name":"job-patrol","detail":"月曜・金曜の12時以降に1回、掲載求人を巡回して月別求人表を更新する"},{"name":"子processを記録","detail":"処理をbackground起動し、個別logへstart・finish・exit codeを書き、最終起動stateを保存する"}]
- 実行方法: launchd → dispatcher.ts → 条件成立した内部タスクを別processで起動
- 発火: RunAtLoad＋60秒ごと
- 発火設定: {"StartInterval":60}
- launchd構成: 親dispatcher。旧6本のNextLevel launchdを1本へ統合済み
- 統合判断: 統合済み。1分tickはこの1本だけに集約し、内部条件で実処理頻度を分ける
- 失敗時: 子taskのログへ記録し、lockと状態条件に従って次の60秒tick以降に再判定
- 記録: ローカル `~/Private/projects/active/仕事/scripts/nextlevel-dispatcher/output/logs/`
- runner: script
- launchd label: com.nextlevel.dispatcher
- 正本: ../../../projects/active/仕事/領域/整備/自動実行/マニュアル/自動実行一覧.md
- plist: ../../../projects/active/仕事/scripts/nextlevel-dispatcher/com.nextlevel.dispatcher.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

<!-- LOOP:worker-search-kanto -->
### `worker-search-kanto`
- 領域: 仕事
- 分類: 仕事・求人運用
- scope: repo-local
- 目的: 関東の新着ワーカーを定期検索し、監視結果へ追記する
- 内部処理: [{"name":"稼働時間を確認","detail":"9時から19時以外は処理せず終了する"},{"name":"認証guard","detail":"PlaywrightとGoogle Sheets認証を確認し、未復旧なら今回をskipする"},{"name":"連続失敗を確認","detail":"認証失敗が5回に達して通知済みなら検索を停止状態のまま維持する"},{"name":"対象を検索","detail":"東京・神奈川・埼玉・千葉、20〜39歳を更新日降順で最大10ページ取得する"},{"name":"既存と差分比較","detail":"ワーカーIDで既存行を照合し、新規と更新日変更者を分ける"},{"name":"profileを補完","detail":"新規と更新対象の詳細画面から生年月日・職業・就職支援希望を取得する"},{"name":"除外と重複排除","detail":"都道府県間重複をIDで除外し、学生判定と同名・電話番号照合を行う"},{"name":"スプシを更新","detail":"新規または再浮上対象を関東監視結果の上部へ追加し、既存者のメモ・更新日も更新する"},{"name":"結果を通知・記録","detail":"対象者がいれば関東だけntfy通知し、関東実行ログへ件数と結果を追記する"},{"name":"認証状態を保存","detail":"ブラウザsessionを保存して閉じ、認証エラー時は失敗回数を更新する"}]
- 実行方法: launchd → npm run cycle:kanto → Playwright＋Google Sheets
- 発火: RunAtLoad＋4分ごと
- 発火設定: {"StartInterval":240}
- launchd構成: worker-search共通実装の関東target専用loop
- 統合判断: 統合候補。全国と同じ4分周期・同じ実装なので1親schedulerから順次起動できる
- 失敗時: 非0終了は60秒以上空けて再起動。認証失敗は5回で自動停止し通知
- 記録: ローカル `~/Private/projects/active/仕事/scripts/worker-search/output/logs/schedule.{out,err}.log` ／ スプシ `関東実行ログ`
- runner: script
- launchd label: com.nextlevel.worker-search.schedule
- 正本: ../../../projects/active/仕事/領域/整備/自動実行/マニュアル/自動実行一覧.md
- plist: ../../../projects/active/仕事/scripts/worker-search/launchd/com.nextlevel.worker-search.schedule.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

<!-- LOOP:worker-search-zenkoku -->
### `worker-search-zenkoku`
- 領域: 仕事
- 分類: 仕事・求人運用
- scope: repo-local
- 目的: 全国の新着ワーカーを定期検索し、監視結果へ追記する
- 内部処理: [{"name":"稼働時間を確認","detail":"9時から19時以外は処理せず終了する"},{"name":"認証guard","detail":"PlaywrightとGoogle Sheets認証を確認し、未復旧なら今回をskipする"},{"name":"連続失敗を確認","detail":"認証失敗が5回に達している間は検索を停止状態のまま維持する"},{"name":"対象を検索","detail":"北海道・大阪・愛知・京都・兵庫・福岡、20〜39歳を更新日降順で最大10ページ取得する"},{"name":"既存と差分比較","detail":"ワーカーIDで既存行を照合し、新規と更新日変更者を分ける"},{"name":"profileを補完","detail":"新規と更新対象の詳細画面から生年月日・職業・就職支援希望を取得する"},{"name":"除外と重複排除","detail":"都道府県間重複をIDで除外し、学生判定と同名・電話番号照合を行う"},{"name":"スプシを更新","detail":"新規または再浮上対象を全国監視結果の上部へ追加し、既存者のメモ・更新日も更新する"},{"name":"結果を記録","detail":"全国実行ログへ件数と結果を追記し、関東用ntfy通知は送らない"},{"name":"認証状態を保存","detail":"ブラウザsessionを保存して閉じ、認証エラー時は失敗回数を更新する"}]
- 実行方法: launchd → npm run cycle:zenkoku → Playwright＋Google Sheets
- 発火: 4分ごと
- 発火設定: {"StartInterval":240}
- launchd構成: worker-search共通実装の全国target専用loop
- 統合判断: 統合候補。関東と同じ4分周期・同じ実装なので1親schedulerから順次起動できる
- 失敗時: 非0終了は60秒以上空けて再起動。認証失敗は5回で自動停止
- 記録: ローカル `~/Private/projects/active/仕事/scripts/worker-search/output/logs/schedule-zenkoku.{out,err}.log` ／ スプシ `全国実行ログ`
- runner: script
- launchd label: com.nextlevel.worker-search.zenkoku
- 正本: ../../../projects/active/仕事/領域/整備/自動実行/マニュアル/自動実行一覧.md
- plist: ../../../projects/active/仕事/scripts/worker-search/launchd/com.nextlevel.worker-search.zenkoku.plist
- 意図状態: 稼働中
- 最終実機確認: 2026-07-12 16:53 JST loaded / last exit 0

## 更新手順

新しい自作loopを有効化する時は、同じ変更でこのMDへ追加する。

1. 領域は `Personal OS` または `仕事` のどちらかを選び、領域内の内容分類へ置く。
2. `<!-- LOOP:<一意名> -->` と全必須項目を書く。`内部処理` は起動後の順番が追えるJSON arrayにする。
3. `python3 verify.py --write-html` で人間向けHTMLを再生成する。
4. `python3 verify.py` と `python3 verify.py --self-test` を通す。
5. 新設・有効化・発火変更・停止・再開・廃止は人間確認を取る。

`launchd構成` には専用loop・親dispatcher・target分割などの関係を書き、`統合判断` には同周期・同実装の
重複を維持する理由、統合済み、統合候補のいずれかを根拠つきで書く。
