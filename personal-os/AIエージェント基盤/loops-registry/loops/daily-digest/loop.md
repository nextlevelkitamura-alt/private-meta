---
稼働状態: 停止（2026-07-04 全停止・bootout済み。経緯と再開手順は ../../実行一覧/personal-os.md）
設計: /Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/active/2026-06-30-目的管理ハーネス/plans/04-実行レーン自動化とデイリー自動ログ.md
起動: launchd `com.kitamura.daily-digest`（12:30/18:30/23:30 JSTの3回・StartCalendarInterval 3本・
  `~/Library/LaunchAgents/`へはsymlink登録=repo正本と同一実体。12:30/18:30は`--snapshot`・23:30は従来final＋digest。
  中央dispatcher経由ではなく単独スケジュール。plist変更時は毎回bootout→bootstrapが必要=§登録手順）。
---

# daily-digest（デイリー自動ログ 夜loop）

`../../references/loop-runbook.md` の loop 契約（§2）に沿った実行スペック。1 loop＝1タスク定義。

## 目的

朝夜ルーティン（`../../../my-brain/ゴール/朝夜ルーティン.md`）の「夜」を補完する。

⚠️ **現況（2026-07-03時点）**: 以下で説明する「12:30/18:30/23:30の3回」はrepo正本plist（draft）の
設計であり、実機`~/Library/LaunchAgents/com.kitamura.daily-digest.plist`はまだ**旧・毎日23:30単発**の
内容がcp配置されたまま稼働中（bootstrap済み）。つまり現状の実挙動は「23:30の締めレンダ+digestが
1日1回」であり、3回スナップはまだ反映されていない。切替手順は本ファイル末尾の
「## 登録手順（人間ゲート）」（実施は指揮官側）。

**生成ロジックの正本は `../renderer/`（統合デイリーレンダラv1）へ一本化した。** このloop（launchd
`com.kitamura.daily-digest`・12:30/18:30/23:30 JSTの3回）は、plistのコマンドパス互換を保ったまま
`scripts/run.sh` が `../renderer/scripts/render.sh`（＋`../renderer/scripts/digest.sh`）へ委譲する
薄いラッパになっている（二重管理禁止のため。旧実装の `auto:log` 整形ロジックは
`../renderer/scripts/claude-log-bullets.sh` へ移設済み）。`get-marker-block.sh` /
`set-marker-block.sh` / `collect-done-cards.sh` はこのフォルダに残し、renderer から相対参照される
（マーカーI/Oとdoneカード収集の正本はここのまま）。

2026-07-03人間裁定（案2採用）で「1日1回の締め」から「12:30/18:30/23:30の3回スナップ」へ拡張し、
各回で `## 今日のダイジェスト`（`auto:digest`）区画に repo別コミット要約＋cockpitレーン段階所要時間の
LLMダイジェストを冪等生成するようにした。生成ロジックの正本は `../renderer/scripts/digest.sh`
（このloopと同じく二重管理しない）。

形式契約の正本は出所計画（frontmatter `設計:`）の「## ログ(自動) 形式契約」節。ここは重複させず、
その契約を満たす実行手順だけを書く。

## 対象

- `~/Private/personal-os/my-brain/ゴール/デイリー/<年>/<月>/<年-月-日>.md`（当日分のみ）。
- 入力・出力とも renderer 委譲後の実処理範囲に拡張されている（`../renderer/loop.md` の「対象」節が
  詳細の正本）。このloopの23:30起動は「締めの最終レンダ」として `auto:goal` / `auto:log`
  （バックフィルのみ）/ `auto:done` / `auto:align` の4マーカーすべてを対象にする。
- 12:30/18:30起動（`--snapshot`）は締めの最終レンダは行わず、通常レンダ＋`auto:digest`のみを対象にする。
- `auto:digest`（当日repo別コミット＋cockpitレーン段階所要時間のLLMダイジェスト）は3回（12:30/18:30/23:30）
  すべてで対象にする（正本: `../renderer/scripts/digest.sh`）。

## 起動条件（shouldRun）

- 時間ベース：毎日 12:30／18:30／23:30 JST 目安（`loop-runbook.md` §1 のディスパッチャが分単位で
  判定する想定）。launchd側は3本のStartCalendarIntervalが同じコマンドを起動し、実行時刻（hour）で
  コマンド側が `--snapshot` の有無を切り替える（plist frontmatterコメント参照）。
- 当日分は各回1回で十分だが、このloop自体は**何度再実行しても冪等**（後述）なので、dispatcher側の
  state（最終実行時刻）判定に依存しすぎなくてよい＝安全側。
- launchd 登録は2026-07-02に人間ゲートを経て完了済み（`com.kitamura.daily-digest` 専用plist・
  稼働中）だが、それは**旧・毎日23:30単発構成**の登録である。12:30/18:30/23:30の3本化はrepo正本
  plistの書き換えのみ完了しており（2026-07-03）、実機への切替（3本化の反映）はまだ人間ゲートを
  経ていない（frontmatter `起動:` ・下記「## 登録手順」参照）。

## 各回の実行（command）

```
scripts/run.sh [YYYY-MM-DD] [--snapshot]
  # YYYY-MM-DD  省略時は実行時点の当日日付（date '+%Y-%m-%d'）。
  # --snapshot  12:30/18:30向け。省略時（23:30向け）は従来どおり --final 付きで render.sh へ委譲する。
  # いずれの場合もdigest.shは必ず実行する（digest.shの失敗はrun.sh全体の成否に影響させない）。
```

`runner: script` — `run.sh` は `../renderer/scripts/render.sh`（`--snapshot`指定時は素のまま、
省略時は `--final` 付き）を実行した後、`../renderer/scripts/digest.sh` を1ステップ追加で実行する
薄いラッパ。年間計画の `auto:goal` 転記・`auto:log` の Claude backfill・`auto:done`（Claude対話ログ＋
Codexセッション＋doneカード）・`auto:align`（件数集計）・`auto:digest`（repo別コミット＋レーン段階
所要時間のLLMダイジェスト）の実処理はすべて renderer 側（`../renderer/loop.md` 参照。digest.shのみ
このloopの起動元から直接呼び出す）で行う。マーカー内側の読み書きは常に
`get-marker-block.sh` / `set-marker-block.sh`（このフォルダが正本・renderer から相対参照）が行い、
マーカー外の人間の行には一切触れない。

**TODO（AI強化・未実装）**: transcript本文の読解による自然文要約の質向上、および
`年間計画/3年計画.md` と突き合わせた深い逆算判定は今回未実装（renderer側のスコープとして持ち越し）。
理由は、transcript形式（Claude/Codexどちらのrunnerかで想定フォーマットが変わりうる）を本計画の
ドキュメントだけでは断定できず、誤読・誤要約のリスクがあるため。実装するなら、renderer が組み立てた
構造化データをAIに渡して自然文へ整形させ、その結果を**引き続き** `set-marker-block.sh` 経由でしか
書き込まない形にする（AIがファイルを直接編集しない）。

## 冪等性

- `set-marker-block.sh` は毎回マーカー内側を**全置換**する（追記しない）。同じ入力なら同じ出力になり、
  再実行しても二重生成しない。
- マーカー外（人間の `- ` 行、見出し、メモ欄）は読み取り対象にも書き込み対象にもしない。
- `auto:log` 行が0件・当日 done カードが0件でも空文字列を安全に扱う（クラッシュしない）。
- `auto:digest` も毎回全置換。LLM要約が失敗しても機械集計だけの素朴なダイジェストへ
  フォールバックし、クラッシュしない（正本: `../renderer/scripts/digest.sh`）。

## 完了・停止条件

- **完了**（1回の実行として）: 当日デイリーが存在し（無ければ renderer が生成し）、存在する
  `auto:goal` / `auto:log` / `auto:done` / `auto:align`（23:30起動のみ）と `auto:digest`
  （3回とも）マーカーの内側が最新の内容で置換されていること。
- **スキップ**（異常ではない）: テンプレも当日デイリーも無ければ警告のみで終了。マーカーが無い
  日次ファイルには**足さない**。該当マーカーだけをスキップし、警告を標準エラーに出す（他のマーカーの
  処理は継続する）。digest.sh自体の失敗（LLM呼び出し失敗・イベント集計失敗等）も警告のみでexit 0
  （run.sh全体の成否には影響させない）。
- **稼働中**（現在の実機状態）: launchd `com.kitamura.daily-digest` が**旧・毎日23:30単発**構成で
  ロード済みで自動実行される。12:30/18:30/23:30の3本化はrepo正本plist（draft）のみ完了しており、
  実機への切替は未実施（frontmatter `起動:` ・下記「## 登録手順」参照）。
- **停止**にする場合: frontmatter `稼働状態` を `停止` にし、plist を unload する（人間判断）。

## 設定・環境変数

secret / token は一切使わない（digest.shが呼ぶ `claude -p` もこのloop自身はトークンを扱わない）。
パス既定値は `scripts/_paths.sh` に集約し、テスト時は環境変数で上書きできる（本番は既定値のまま
使う想定）。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `GOAL_BASE` | `~/Private/personal-os/my-brain/ゴール` | デイリー日次ファイルの探索起点 |
| `AIJOBS_BASE` | `~/Private/personal-os/AIエージェント基盤/loops-registry/ai-jobs` | done カードの探索起点 |

digest.sh固有の環境変数（`DIGEST_LLM_CMD` / `DIGEST_EVENTS_FILE` / `DIGEST_REPO_OVERVIEW` /
`DIGEST_REPO_PATH_*`）はここでは重複させず、`../renderer/scripts/digest.sh` 冒頭のコメントを正本にする。

## ログ先

このloop自体の実行ログ（stdout/stderr）は repo外（`loop-runbook.md` §5 の規約どおり）。
このloopが**生成する**ログは当日デイリーの `auto:goal` / `auto:log` / `auto:done` / `auto:align` /
`auto:digest` マーカー内側のみ（実処理は renderer 委譲）。

## 登録手順（人間ゲート・3本化への切替）

正本plist（`com.kitamura.daily-digest.plist`・このフォルダ直下）は2026-07-03に
12:30/18:30/23:30の3本へ書き換え済みだが、**実機の登録はまだ旧・毎日23:30単発のまま**
（2026-07-02人間ゲートで`cp`配置・bootstrap済み・稼働中）。plist frontmatterのコメント
（`稼働状態`/`起動`）が示すこの二重状態（repo正本=draft 3本／実機=旧1本）を解消するには、
下記の切替（実施は指揮官側）が必要。

併せて登録方式も **`cp` → `symlink`** へ移行する（watch-keeperの`loop.md`「## 登録手順」と同型）。
理由: 今回`cp`のまま3本化の編集を進めた結果、「repo側は直したのに実機は古いまま」という二重状態が
実際に発生した（差し戻し#1）。symlinkは実機ファイルとrepo正本を**同一の実体**にし、`cp`し忘れによる
on-disk上の内容乖離（コピーが2つ存在して食い違う事態）を構造的に防ぐ。

⚠️ symlinkが解決するのはそこまでで、**launchdの再読込は自動化されない**。launchdは`bootstrap`時に
plist内容を読み込んでジョブ定義として保持するため、symlink経由でもファイル内容を編集しただけでは
稼働中ジョブのスケジュール・コマンド等は更新されない。plistを変更したら（symlink化後も）毎回
`launchctl bootout` → `launchctl bootstrap`（→`enable`）を人間ゲートで実施する必要がある
（この手順自体は`cp`方式と同じ。今回の差し戻し#1のような「repo正本は書き換えたが実機へのbootout→
bootstrapを実施し忘れる」事態はsymlink化だけでは防げない点に注意）。

```
launchctl bootout gui/$(id -u)/com.kitamura.daily-digest   # 旧(23:30単発・cp配置)を止める
rm ~/Library/LaunchAgents/com.kitamura.daily-digest.plist   # 旧cpファイルを削除(symlinkへ移行するため)
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/daily-digest/com.kitamura.daily-digest.plist' \
  ~/Library/LaunchAgents/com.kitamura.daily-digest.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.daily-digest.plist
launchctl enable gui/$(id -u)/com.kitamura.daily-digest
```

切替後の確認（3本のStartCalendarIntervalが載っているか）:

```
launchctl list | grep com.kitamura.daily-digest   # 稼働確認（0=running）
plutil -p ~/Library/LaunchAgents/com.kitamura.daily-digest.plist | grep -A2 Hour
```

停止:

```
launchctl bootout gui/$(id -u)/com.kitamura.daily-digest
rm ~/Library/LaunchAgents/com.kitamura.daily-digest.plist
```

切替完了後、本ファイルとplist frontmatterコメントの「現況」注記（draft/未反映の記述）を
削除し、frontmatter `稼働状態` から二重状態の説明を外す（人間/指揮官が実施）。

## 関連（重複させず backlink）

- **生成ロジックの正本: `../renderer/loop.md`**（このloopはそこへの薄い委譲ラッパ）。
- **ダイジェスト生成ロジックの正本: `../renderer/scripts/digest.sh`**（このloopの起動元から直接呼ぶ）。
- 形式契約・全体計画: frontmatter `設計:`（出所計画。§「## ログ(自動) 形式契約」節が正本）。
- loop 起動標準: `../../references/loop-runbook.md`。
- 実行レーン契約: `../../ai-jobs/AGENTS.md`（done カードの形＝§2）。
- symlink登録方式の先例: `../watch-keeper/loop.md`「## 登録手順」（本loopの3本化切替はこれに倣う）。
- 対象repo概要（digest.shがLLM要約の文脈として読む）: `../../repo-registry/repo概要.md`。
- デイリー雛形の正本: `../renderer/templates/デイリー.md`（9見出し。`## 今日のダイジェスト`
  ＝auto:digest空区画を2026-07-03に追加。renderer は既定でこちらを
  参照し、`~/Private/.../my-brain/ゴール/templates/デイリー.md` は既定では見ない）。my-brain側は
  人間ゲートで1行ポインタ化する予定（`../renderer/README.md` ロールアウトdraft §2参照。現状は
  旧8見出しの現物のまま残っており、renderer が直接使うことはない）。
- 朝夜ルーティン: `~/Private/personal-os/my-brain/ゴール/朝夜ルーティン.md`（夜のどこを補完するか）。
