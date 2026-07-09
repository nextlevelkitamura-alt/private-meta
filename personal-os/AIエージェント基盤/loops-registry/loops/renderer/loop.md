---
稼働状態: 廃止（2026-07-06 引退。旧・日次自動ログ subsystem＝session-daily-log(削除)/renderer/daily-digest を session-board へ統一。元は 2026-07-04 停止。経緯は ../../実行一覧/personal-os.md）
設計: v1本体（auto:goal/log/done/align）はworktree renderer-v1でのdraft実装。3区画拡張
（auto:board-now/board-wait/board-plans・統合program子04a）はworktree board-live-v1でのdraft実装。
cockpit段階イベント連携（auto:board-nowの「イベント段階:…」併記・統合program子04b）はworktree
stage-events-v1でのdraft実装。Notion連携（N1一方向push・N2依頼インボックスpull・N3計画ボード・
N3bレーン実況の4本＋N3bへの毎分sync〔lanes-sync.sh・方針5c〕とrepo/並び順/状態絵文字列
〔方針5d〕。統合program）はworktree notion-board-v1でのdraft実装。
ロールアウト手順は README.md の【ロールアウトdraft】節。
起動: 2経路。① Claude Code Stop hook（`hooks/session-daily-log/session-daily-log.sh`）が末尾で
`scripts/render-debounced.sh` を非同期debounce起動（対話セッション終了のたび）。② launchd
`com.kitamura.daily-digest`（毎日23:30 JST）が `daily-digest/scripts/run.sh` 経由で
`scripts/render.sh --final` を「締めの最終レンダ」として実行（plist本体は daily-digest 側のまま・変更不要）。
---

# renderer（統合デイリーレンダラ v1）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

当日デイリーの生成〜自動集計を1本のレンダラに統合する。`daily-digest`（auto:done/auto:align の夜loop）と
`session-daily-log` hook（auto:log の即時upsert）を置き換えるのではなく、その2つが担っていた責務
（当日ファイルの用意・ログの取りこぼし救済・件数集計・要約整形）を1回の実行で決定的に完結させる。

- `## 逆算` の `auto:goal`（年間計画からの自動転記）＋ `auto:align`（当日の自動記録の件数集計）。
- `## 今日終わったこと` の `auto:done`（Claude対話ログ＋Codexセッション＋ai-jobs doneカードの自動まとめ）。
- `## ログ` の `auto:log`（hookが取りこぼした当日Claudeセッションのバックフィル・追記のみ）。
- `## 今やっていること` の `auto:board-now`（`orca worktree ps --json` のcockpitレーン実況。worktree名・
  agent種別/state・lastAssistantMessage最終行が段階語彙／完了・合否マーカーの場合はそれも表示）。
- `## 待ち` の `auto:board-wait`（人間確認待ち／着手可能／未紐付け〔レーン・当日コミット〕の3種）。
- `## 計画ボード` の `auto:board-plans`（`AREAS_BASE`配下の全領域active計画一覧。単発plan.mdと
  program.md子計画マップの両方）。
- 当日デイリー自体が無ければテンプレ（既定は repo 内蔵 `templates/デイリー.md`。`render.sh` からの
  相対パスで解決し、`GOAL_BASE` 側は既定では一切見ない）から生成する。

人間の手書き（マーカー外）は一切上書き・削除しない。形式契約（見出し名・マーカーキー）はこのloopの
`templates/デイリー.md` が正本（凍結済み8見出し。`auto:carry` / `auto:progress` は使わない）。
テンプレの正本はこの基盤repo側に一本化しており、`~/Private/.../my-brain/ゴール/templates/デイリー.md`
は（人間ゲートでのポインタ化後は）本文を持たない1行ポインタになる想定。二重管理禁止（README.md
ロールアウトdraft §2）。

## 対象

- `${GOAL_BASE:-~/Private/personal-os/my-brain/ゴール}/デイリー/<年>/<月>/<年-月-日>.md`（対象日のみ）。
- 入力: 当日デイリーの `auto:log` 行、`${CLAUDE_PROJECTS_BASE}` 配下の当日Claude transcript、
  `${CODEX_INDEX}` の当日Codexセッション（cwd/repoは `${CODEX_SESSIONS_BASE}` の rollout先頭1行のみ参照）、
  `${AIJOBS_BASE}/done/` の当日 done カード、`${GOAL_BASE}/年間計画/<年>.md`、
  `${ORCA_PS_CMD:-orca worktree ps --json}` のcockpitレーン実況、
  `${AREAS_BASE}/*/plans/active/*` の全領域active計画（単発plan.md・program.md子計画マップ）、
  `${COCKPIT_EVENTS_FILE}` のcockpit段階イベント（§cockpit段階イベント）。
- 出力: 同じ日次ファイルの `auto:goal` / `auto:log`（追記のみ）/ `auto:done` / `auto:align` /
  `auto:board-now` / `auto:board-wait` / `auto:board-plans` の内側だけ。

## 起動条件（shouldRun）

- hook起動（対話終了ごと・debounce合流）と launchd起動（23:30・`--final`）の2経路。どちらも
  「何度実行しても冪等」なので、取りこぼし・多重起動を過度に恐れなくてよい＝安全側。
- 現状 **稼働状態: 停止**。hook本体（`hooks/session-daily-log/session-daily-log.sh`）は用意済みだが、
  `~/.claude/settings.json` への登録は人間ゲート（README.md ロールアウトdraft参照）。

## 各回の実行（command）

```
scripts/render.sh [YYYY-MM-DD] [--final]   # 省略時は実行時点のJST当日
scripts/render-debounced.sh [YYYY-MM-DD]   # 非同期debounceラッパ（hookから起動）
```

`runner: script` — 全工程が非AI・非乱数の決定的スクリプトで完結する（要約もgit解決も件数集計も
既存のbuild-content.sh由来ロジックの延長）。処理順は次のとおり（各ステップは独立に失敗しても後続を
止めない。goal/done/alignの builder（stdoutへ本文を出すスクリプト）が非0終了した場合はマーカーへの
反映自体をスキップし、既存内容を保持したまま警告のみ出す＝空ファイルで上書きしない。t14で検証済み）。

1. `ensure-daily.sh` が対象日のデイリーの有無を確認し、無ければ `templates/デイリー.md` から
   プレースホルダ（`<YYYY-MM-DD>` / `<曜>` / `<YYYY>`）を埋めて生成する。既存ファイルは一切触らない。
2. `build-goal.sh` が `年間計画/<年>.md` の「## 領域別の目標」から領域ごとのbulletを
   ファイル出現順で決定的に転記する（`auto:goal`）。
3. `claude-backfill.sh` が `CLAUDE_PROJECTS_BASE` 配下の当日(JST) mtime の transcript を走査し、
   `auto:log` に無いセッションだけをタイムスタンプ昇順で追記する（既存行は変更・並べ替えしない）。
4. `build-done.sh` が (a) `auto:log` から Claude セッションの箇条書き（`claude-log-bullets.sh`。
   commit sha は `git log --pretty=%s` で件名解決）、(b) `codex-pull.sh`（実体はpython3・1行ごとの
   プロセス起動を避けた単一パス実装。実測: 実環境1185行を1〜2秒で処理）が `CODEX_INDEX` から当日分の
   Codexセッションをid重複排除・時刻昇順で整形、(c) `daily-digest/scripts/collect-done-cards.sh`
   （相対参照・複製しない）の当日 done カード、の3ブロックを決定的順序で連結して `auto:done` に書く。
5. `build-align.sh` が対話ログ件数／Codex件数／done件数を集計して `auto:align` に書く。
6. `build-board-now.sh` が `orca-ps-snapshot.sh`（実体はpython3。`ORCA_PS_CMD`経由で
   `orca worktree ps --json` を実行しworktree×agent一件=1行に正規化。orca CLI不在・実行失敗・
   JSON不正は非0で終了しbuilder失敗として扱う＝空置換で消さない）の出力から、レーン名・agent種別/
   state・段階語彙／完了・合否マーカーに一致するlastAssistantMessage最終行だけを `auto:board-now` に書く
   （会話本文はマーカーに一致しない限り出さない）。加えて `COCKPIT_EVENTS_FILE`（§cockpit段階イベント）
   をworktree pathで突き合わせ、そのレーンの最新段階（`event=send`かつ`stage`非nullの最新ts）を
   行末に「イベント段階:…」として併記する。イベントファイルが無い/壊れていても従来表示のまま動く
   （best-effort拡張。orca-ps-snapshot.sh失敗時の非0伝播原則とは別扱いで、このaugmentation自体は
   非0を返さない）。
7. `build-board-wait.sh` が (a) `orca-ps-snapshot.sh` の lastAssistantMessage最終行に
   「人間確認待ち」を含むagent、(b) `plan-scan.sh`（`AREAS_BASE`配下を走査しplan.md単発／
   program.md子計画マップを正規化）で状態が「計画」の子（＝着手可能）、(c) displayNameに
   「子NN」パターンが無いレーン（未紐付けレーン）、(d) `auto:log`（既にpull済み）のcwdが
   orca psのどのレーンpathにも属さない当日コミット（未紐付けコミット）、の4種を `auto:board-wait` に書く。
8. `build-board-plans.sh` が `plan-scan.sh` の出力を「優先(◎/○) 計画名 … 領域」＋`場所:`の
   旧ダッシュボード書式（`areas/AGENTS.md` §2）で整形し、programは子計画マップの状態も添えて
   `auto:board-plans` に書く。
9. `notion-inbox-pull.sh`（2026-07-09 デイリー運用刷新 子06で `../inbox-patrol/scripts/` へ移設。
   render.sh は移設先を呼ぶ）がNotion「依頼インボックス」DB（統合program N2・先）の「状態=立案済」行を
   ローカル当日デイリーの「## 依頼インボックス」節末尾へ追記し、該当行を「回収済み」に更新する
   （ベストエフォート。トークン未設定/parent page未解決/API失敗/取り込み済みidの重複はいずれも
   警告のみでexit 0し、render.sh自体の成否には影響しない。取り込み済みidは移設先の
   `../inbox-patrol/state/notion-inbox-pulled-ids` に記録し二重取り込みを防ぐ。詳細は
   `../inbox-patrol/scripts/notion-inbox-pull.sh` 冒頭コメント参照）。
10. `notion-push.sh` が当日デイリー全文をNotionの当日子ページへ一方向push（統合program N1・ベストエフォート。トークン未設定/parent page未解決/API失敗はいずれも警告のみでexit 0し、render.sh自体の成否には影響しない。詳細は `notion-push.sh` 冒頭コメント参照）。
11. `notion-board.sh` が `plan-scan.sh` の出力（auto:board-plansと同一情報源）からNotion「計画ボード」
   DB（統合program N3・後）へactive計画をタイトルキーでupsertし、消えた計画の行をarchiveする
   （ベストエフォート。フェイルセーフはN1と同型。詳細は `notion-board.sh` 冒頭コメント参照）。
12. `notion-lanes.sh` が `orca-ps-snapshot.sh`（auto:board-now/auto:board-waitと同一情報源）＋
   `cockpit-stage-lookup.sh`（build-board-now.shと共有するcockpit段階イベントlookup）から
   Notion「レーン実況」DB（統合program N3b・最後）へレーン単位でupsertする。
   **列再設計v2**（統合program plan.md 方針5e・2026-07-03朝ユーザー裁定）。
   **upsertキーはworktreeの絶対パス**（専用列 `フォルダーパス`(rich_text) に書き込み、これだけを
   照合キーにする＝完全一致のみ。タイトルは状態が変わるたびに変化するため絶対にキーにしない。
   旧形式行〔このキー列が無い時代に作られた行〕からのフォールバック照合は撤去済み＝キー列が
   空の行は遺物として次回同期でarchiveされる）。同じ列がそのまま「パス」表示列を兼ねる
   （別列を増やさない）。
   行=レーン＋固定タイトル「■サマリ」の稼働状況集計行。
   **タイトル形式**: `<状態絵文字><状態語>`のみ（例: `🔔確認待ち`／`▶実装中`／`✅完了`／
   `⏸待機中`）。worktree名は含めない。
   **計画**(rich_text): orca-ps-snapshot.shのdisplayName（cockpitの`--title`が入る）をそのまま
   使う。displayNameが空（非cockpit worktree）、またはbranch名と同じ（cockpitがdisplayNameを
   明示設定しなかった既定値）の場合は`-`。
   **種別**(select・worktree/mainの2値): パスが`~/orca/workspaces`配下または`.claude/worktrees`
   配下ならworktree、それ以外（repoルート直下等）はmain。
   **作業内容**(rich_text・全行必ず埋まる機械判定): (1)agentが1体も居ない→
   「エージェント無し(worktree回収対象候補)」、(2)全agent doneかつ直近メッセージが`*_PASS`→
   「レビューPASS・マージ/回収待ち」、(3)それ以外→段階語
   （実装中／レビュー中／修正中／確認待ち／完了／稼働中／待機中）。「down済み」値は廃止
   （閉じたレーンは行ごとarchiveするため作業内容を書き換える必要が無い）。
   **repo**(select・全行必ず埋まる): worktree親ディレクトリ名から導出。不明瞭な結果
   （空/"."/"/"）はworktree自身のbasenameへフォールバックする（空にしない。■サマリ行は
   プレースホルダ`-`）。
   **並び順**(number): -1=■サマリ／0=人間の出番〔人間確認待ち・agentエラー・段階=完了・
   全agent done〕／1=稼働中〔段階=実装系/修正系・またはagent working〕／2=それ以外。
   状態絵文字は並び順から一意に決まる（0=🔔／1=▶／2=⏸）。
   列は レーン名(title)／計画／種別／作業内容／段階／ペイン／要注意／更新／`repo`／`並び順`／
   `フォルダーパス` の11列。**閉じたレーン・遺物行はarchiveする**（down済み表示はしない）:
   前回まで存在し今回のorca psに居ないレーン、およびフォルダーパス列が空の遺物行（旧形式・
   移行漏れ）は、行ごと`PATCH /pages/{id}` `archived:true`でarchiveする（計画ボード(N3)と同じ
   挙動に統一。プロパティは書き換えず直前の値のまま保持される）。DBスキーマ（11プロパティ）は
   既存DB（本追加より前に作られたもの）にも `PATCH /v1/databases/{id}` で毎回冪等に追加する
   （ベストエフォート。フェイルセーフはN1と同型。詳細は `notion-lanes.sh` 冒頭コメント参照）。

マーカー内側の読み書きは常に `daily-digest/scripts/get-marker-block.sh` / `set-marker-block.sh`
（相対参照・複製しない）が行う。マーカー（`auto:goal` / `auto:log` / `auto:done` / `auto:align` /
`auto:board-now` / `auto:board-wait` / `auto:board-plans` のいずれか）が無い日次ファイルには
**足さない**。該当マーカーだけをスキップし、警告を標準エラーに出す。

## 冪等性

- `set-marker-block.sh` は毎回マーカー内側を全置換する（追記しない）。同じ入力なら同じ出力。
- `claude-backfill.sh` はセッションIDで重複判定するため、同じtranscriptから二重追記しない。
- `ensure-daily.sh` は既存ファイルを一切変更しない（初回生成のみ）。
- `orca-ps-snapshot.sh` / `plan-scan.sh` も非AI・非乱数（決定的ソート・awk/pythonの単純走査のみ）。
  `ORCA_PS_CMD` が同じ出力を返す限り（本番は実orca CLIの現在状態、テストはfixture固定）2回連続実行は
  差分ゼロ（t18で検証済み）。
- 全体が非AI・非乱数のため、同一入力（同じ対象日・同じ外部データ）での2回連続実行は差分ゼロ。

## 完了・停止条件

- **完了**（1回の実行として）: 対象日のデイリーが存在し（無ければ生成し）、存在する `auto:*` マーカー
  すべての内側が最新の集計・転記で置換されていること。
- **スキップ**（異常ではない）: テンプレが無く当日デイリーも生成できない場合は警告のみで終了。
  マーカーが無い日次ファイルには足さない（該当マーカーだけスキップ・警告）。
- **停止**: frontmatter `稼働状態` が `停止`（現在値）。`稼働中` への変更は
  hook登録（`~/.claude/settings.json`）とセットで人間が判断する（README.md ロールアウトdraft）。

## 設定・環境変数

レンダラ本体（ステップ1〜8）はsecret / token を一切使わない。例外は後段のNotion連携4本
（ステップ9〜12・`notion-inbox-pull.sh`=N2／`notion-push.sh`=N1／`notion-board.sh`=N3／
`notion-lanes.sh`=N3b）のみ: `NOTION_TOKEN` を実行時に `security find-generic-password` でkeychainから
取得し、値は出力・ログ・コミットのどこにも一切出さない（変数保持のみ）。4本とも同じkeychainサービス名
（既定 `notion-personal-os`）・同じ「Personal OS」親ページ解決キャッシュ
（`state/notion-parent-page-id`）を共有する（secret取得・HTTP呼び出し・親ページ解決の共通ロジックは
`notion-common.sh` に集約し、N2/N3/N3bはこれをsourceする。N1は既存実装のまま独立を保つ＝変更しない）。
取得失敗／parent page未解決／DB解決失敗／API失敗はいずれも警告1行＋exit 0で吸収し、レンダラ本体
（ステップ1〜8）や他のNotion連携ステップには影響しない
（詳細は各スクリプト冒頭コメント参照）。パス既定値はすべて本番パス。テスト時だけ環境変数で上書きする。
`codex-pull.sh` は実体が python3 スクリプト（ファイル名は呼び出し元互換のため `.sh` のまま）。
実行環境に `python3` が必要（`/opt/homebrew/bin` 等・plist の PATH に既に含まれる）。

`GOAL_BASE` / `AIJOBS_BASE` は `daily-digest/scripts/_paths.sh` で `export` 済み。これを
`source` する render.sh・hook（session-daily-log.sh）双方から、子プロセス
（build-goal.sh 等）まで一貫して伝播する。export していなかった旧実装では、GOAL_BASE が
環境に無い実行（hook/launchd起動）で build-goal.sh が即死し `auto:goal` が空置換される
不具合があった（t13で再現・修正確認）。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `GOAL_BASE` | `~/Private/personal-os/my-brain/ゴール` | デイリー日次ファイル・年間計画の探索起点（テンプレの既定探索起点ではない） |
| `AIJOBS_BASE` | `~/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs` | done カードの探索起点 |
| `DAILY_TEMPLATE` | repo内蔵 `loops-registry/loops/renderer/templates/デイリー.md`（`render.sh` からの相対パスで解決。`GOAL_BASE`は見ない） | 新規生成に使うテンプレ。テスト・特殊運用時のみ上書き |
| `CODEX_INDEX` | `~/.codex/session_index.jsonl` | Codexセッション索引 |
| `CODEX_SESSIONS_BASE` | `~/.codex/sessions` | Codex rollout（cwd/repo解決に先頭1行のみ使用） |
| `CLAUDE_PROJECTS_BASE` | `~/.claude/projects` | Claude transcript（auto:log バックフィル対象） |
| `RENDERER_STATE_DIR` | `~/.cache/personal-os-renderer` | debounceの状態（pending/lock/ログ） |
| `RENDERER_DEBOUNCE_SECONDS` | `60` | debounce窓の秒数 |
| `AREAS_BASE` | `~/Private/personal-os/my-brain/areas` | `auto:board-plans`/`auto:board-wait`（着手可能）の走査起点（全area共通・plan.md単発／program.md子計画マップ） |
| `ORCA_PS_CMD` | `orca worktree ps --json` | `auto:board-now`/`auto:board-wait`が呼ぶcockpitレーン実況コマンド。テスト時は `cat fixture.json` 等に差し替える（cockpit-supervisor-v1 watch.shのWATCH_PS_CMDと同じ方式） |
| `COCKPIT_EVENTS_FILE` | `<repo>/skills/orca-cockpit/state/events.jsonl` | cockpit段階イベントJSONLの場所（§cockpit段階イベント）。`build-board-now.sh`と`cockpit.sh`が同じ既定パスを共有。テスト時は差し替え用fixtureパスに上書きする |

## cockpit段階イベント

`skills/orca-cockpit/scripts/cockpit.sh` の `up` / `send` / `down` が、実行のたびに
`COCKPIT_EVENTS_FILE`（既定 `skills/orca-cockpit/state/events.jsonl`）へJSONL1行を**追記**する
（正本はcockpit.sh側。ここは読み手としての契約のみ記す）。

- **形式**: 1イベント=JSONL1行。キーは `ts`（UTC ISO8601）・`repo`・`branch`・`worktree`（絶対path）・
  `terminal`（handle）・`event`（`up` / `send` / `down`）・`stage`・`owner`。未確定の値は `null`。
- **段階(`stage`)は`send`の任意フラグ`--stage`でのみ記録される**。送信者（人/AI）が明示宣言した
  文字列をそのまま記録するだけで、機構が本文から段階を推測することはしない（運用契約§2の語彙の
  妥当性判断はAI/人が持つ。cockpit.shは検証しない）。`--stage`無しの`send`・`up`・`down`は
  `stage: null` で記録される。
- **管轄(`owner`)は`up`/`send`/`down`の任意フラグ`--owner`で記録される**（先行部品①・f2d5f7bで実装）。
  管轄指揮官（例: 全体管理者／中間指揮官1）を送信者が明示宣言した文字列をそのまま記録するだけで、
  機構は本文から推測しない（`stage`と同じ契約）。`--owner`無指定は `owner: null`。owner欄を持たない
  既存行（f2d5f7b以前のJSONL）も後方互換で読める＝読み手は欠落/未知キーを無視する（純加算・既存行は書き換えない）。
- **置き場・git管理**: `skills/orca-cockpit/state/` はこのrepoの `.gitignore` で除外（実行時状態・
  追記のみ・正本ではなくcockpitの引き金の記録＝運用契約§3の「記録の保証はpull」原則に沿う）。
- **ローテーション**: v1では自動ローテーションを持たない（複数cockpitレーンが同時にsend/up/downを
  実行しうる前提で、file rewrite方式の自動trimは他レーンの追記と競合してイベント消失のリスクが
  あるため、あえて実装しない設計判断）。肥大化したら人間が手動で
  `tail -n 20000 events.jsonl > events.jsonl.new && mv events.jsonl.new events.jsonl` 等で縮小する。
- **読み手**: `build-board-now.sh`（本loop）が `worktree` を突き合わせキーにして、レーンごとの
  最新段階（`event=send`かつ`stage`非nullの最新`ts`）を`auto:board-now`へ「イベント段階:…」として
  併記する。ファイルが無い/壊れていても既存表示のまま動く（best-effort・非0にしない）。

## レーン実況の毎分sync（`lanes-sync.sh`・統合program plan.md 方針5c）

`render.sh`（hook debounce・23:30締め）とは別の、**独立した毎分loop**。`com.kitamura.lanes-sync.plist`
（このディレクトリ直下・draft・`StartInterval 60`）が起点。render.shの全工程（goal/log/done/align/
board-wait/board-plans/N1/N2/N3）は呼ばない。`auto:board-now`（ローカル）と `notion-lanes.sh`（N3b）
だけを動かす軽量loopで、**変化が無ければAPI呼び出しゼロ**。

- **変化検知**: `orca-ps-snapshot.sh` ＋ `cockpit-stage-lookup.sh`（既存収集ロジックの再利用・第2の
  収集実装は作らない）からレーン集合・agent種別/state・lastAssistantMessage最終行・段階を正規化し、
  `shasum -a 256` でhash化。前回値（`state/notion-lanes-sync-signature`・他stateと同じgit非管理）と
  一致すれば即exit 0（API呼び出しゼロ）。
- **変化時のみ**: (a) `build-board-now.sh` の出力を `set-marker-block.sh` 経由で `auto:board-now` へ
  適用（デイリー未生成ならこのステップだけ警告skipし(b)は継続）。(b) `notion-lanes.sh` を
  `LANES_STRICT=1` 付きで実行。(a)のbuilder/適用失敗、または(b)の失敗が無い時だけsignatureを
  更新する（差し戻し修正・High: 失敗時はsignature未更新のまま警告+exit 0し、次の毎分実行が
  「変化あり」として自動的にリトライする。デイリー未生成そのものは失敗扱いにしない）。
- **`LANES_STRICT`**（`notion-lanes.sh`側・差し戻し修正・High）: 既定(未設定)ではN1と同じ
  フェイルセーフ（内部の全失敗をwarn_exit0一箇所に集約し、警告+exit 0）。`LANES_STRICT=1`の時
  だけwarn_exit0が警告のうえ非0で終了する。render.sh本流が呼ぶ`notion-lanes.sh`にはこれを
  付けない（既定のフェイルセーフのまま）。lanes-sync.shだけがこれを付けて呼び、実際のAPI失敗
  （archive PATCH失敗等）を終了コードで検知してsignature非保存に繋げる。
- **多重起動防止**: `state/notion-lanes-sync.lock`（mkdirベースの簡易ロック・300秒でstale自己修復）。
  StartIntervalは前回runの終了を待たないため、runが長引いた場合の二重起動を防ぐ。
- **API調査結果**（2026-07-03・ユーザー要望に添付）: Notion APIは全プランで従量課金なし、制限は平均
  3req/秒のみ。変化時1回あたり15〜25req程度なら毎分運用でも余裕。
- **稼働**: 稼働中（2026-07-03 人間承認=毎分要望を経てsymlink登録＋bootstrap。実走確認: 1回目=変化検知でsync・2回目=無変化でAPIゼロ静音）。停止・再登録手順は `com.kitamura.lanes-sync.plist` 冒頭コメント参照。
- **ビューのソート/列順**: Notion APIから設定不可。`並び順`（number）列を昇順ソートするビュー設定は
  **人間が初回1回だけ**Notion側で保存する（以後は行のupsertのたびに自動で並ぶ）。

## ログ先

このloop自体の実行ログ（stdout/stderr）は repo外。hook起動分は `RENDERER_STATE_DIR/render.log`、
launchd起動分は daily-digest の `output/logs/`（plist継続利用のため）。
このloopが**生成する**ログは当日デイリーの `auto:goal` / `auto:log` / `auto:done` / `auto:align` /
`auto:board-now` / `auto:board-wait` / `auto:board-plans` マーカー内側のみ。

## 関連（重複させず backlink）

- ロールアウト手順（人間ゲート）: `README.md` の【ロールアウトdraft】節。
- マーカーI/Oの正本: `../daily-digest/scripts/get-marker-block.sh` / `set-marker-block.sh`。
- done カード収集の正本: `../daily-digest/scripts/collect-done-cards.sh`。
- loop 起動標準: `../../references/loop-runbook.md`。
- hook 本体: `../../../hooks/session-daily-log/`（`README.md` に登録スニペット）。
- テンプレ雛形（このloopの正本・凍結済み8見出し）: `templates/デイリー.md`。
- cockpit段階イベントの書き手（正本）: `../../../skills/orca-cockpit/scripts/cockpit.sh`（`_log_event`・
  `up`/`send --stage`/`down`）。判断・監督手順は `skills/cockpit-supervisor/SKILL.md`。
- レーン実況の毎分sync（統合program plan.md 方針5c）: `scripts/lanes-sync.sh` ＋
  `com.kitamura.lanes-sync.plist`（このディレクトリ直下・draft）。
