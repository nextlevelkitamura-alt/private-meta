分類: 横断 ／ 種別: 新規作成 ／ 優先: ◎

> 実装状況（2026-07-05）: **B実装完了**。全py統一・auto/claimed廃止・skill廃止・**毎ターン確認→節目確認(prompt型フック)**・入れ子記録(log)。正本＝`AIエージェント基盤/hooks/session-board/`。レビュー項目＝`hooks/research/2026-07-05/B実装レビュー項目.md`。残＝Codex接続(P3)・Notion同期(P4)・実セッションでの節目判定の精度調整。

> 追記（2026-07-05）: **P3 Codex接続の前提を更新＋実装着手**。調査で Codex（この環境＝Codex.app / `codex-cli 0.142.5`）は**正式なhooksを持つ**と判明（SessionStart / UserPromptSubmit / Stop / SubagentStart / SubagentStop、入力＝stdin JSON、注入＝`hookSpecificOutput.additionalContext`）＝§4/P3の「notify(turn-ended)しか無い・開始注入は未確定」は**解消**。方針: エンジン`board.py`・手順mdは共有のまま、受け口だけ `hooks/session-board/codex/`（`session-start.py`／`prompt-register.py`／`session-end.py`／`subagent.py`＝Subで🔵自動／`hooks.json`雛形）を実装し、`~/.codex/hooks.json`へ登録（trust＝人間ゲート）。差分3点（prompt型hook無し→節目確認は初期は機械flipのみ／Stopは`additionalContext`不可→reason経由／notifyはComputer Use専有→hooks(Stop)使用）。正本ドキュメント整備済み: `hooks/session-board/AGENTS.md`・`hooks/references/codex-hooks.md`（実務マニュアル）・`hooks/research/2026-07-05/Codex-hooks調査と構造案.md`。**Codex実装レビュー項目**: (1)`codex/`に4受け口＋`hooks.json`が在り `board.py`/手順mdを共有参照（本文コピーなし）(2)各受け口は stdin JSON を読む薄い層・`key=sid[:8]`(3)`session-start`は`additionalContext`形式で注入(4)`subagent`は`SubagentStart→sub`/`SubagentStop→run`を`hook_event_name`で分岐(5)実Codexで開始🟢/Stop⏸/サブ🔵自動が各1回実測（登録・trust後）(6)subagent・headless(`AIJOBS_RUN`)は非登録。**検証成功**（Codex再起動＋`/hooks` trust後、実Codexで🟢登録＋⏸を確認・保留解除）＝`plans/done/2026-07-05-Codex-session-board接続/`。**関連todo（別タスク・着手）**: 全体のgit管理ドキュメント整備（2repo構造 private-meta / ai-agent-foundation の正本記載）＝`plans/active/2026-07-05-git管理ドキュメント整備/`。

# セッション宣言型ボードとplans規約（デイリー刷新v1）

## 目的

「全部を生記録して後から機械がまとめる」旧デイリー（91%機械生成・141KB/日）をやめ、
**各セッションが開始時に意図を宣言し、終了時に完了を判断→人間確認→報告する**運用に置き換える。
デイリーmdは「動いているエージェント」「終わったこと」の2節だけを持ち、
ボードには**今生きているセッションだけ**が並ぶ（完了は行ごと「終わったこと」へ移す）。
あわせて、計画の置き場を repo-local `plans/` バケットで統一する。

## 現状

- 2026-07-04、旧機構を全停止済み: Claude/Codexの全hook撤去・launchd 5本bootout
  （経緯と再開手順: `AIエージェント基盤/loops-registry/実行一覧/personal-os.md`）。
- 停止理由: デイリー(07-03)が674行/141KB・auto区画91%・auto:log 101行に肥大し、人間の記入が埋もれた。
  記録内容は git log と transcript に既存＝二重管理だった。
- 明日以降のデイリーは自動生成されない（新設計が立つまで手動）。
- Notion同期（旧lanes-sync・毎分）も停止中。**md正本→Notion送信は継続する前提**で作り直す。
- cockpit系skill（orca-cockpit/cockpit-supervisor）は「要・作り直し」注記済み。本計画とは別レーン。

## 方針

### 0. 確実性の設計原則（2026-07-04 壁打ちで確定）

「AGENTS.mdに書けば守られる」を前提にしない。実測に基づく信頼度で機構を割り当てる。

- **開始時の宣言** … 指示遵守が期待できる（コンテキストが新鮮）が、運に任せず**フックで手順を機械注入**する。
- **終了時の更新** … 指示だけでは保証なし（長セッションで文脈圧縮・忘却）。**終了後に必ず走るのはフックだけ**なので、
  終了側はフックのスクリプトで機械化・強制する。
- **フックの役割分担** … 自然言語で「スキルを使え」と願うのではなく、
  (a) 機械でできる部分（状態flip・報告有無の検査）は**スクリプトが直接実行**（LLM不要・確実）、
  (b) 判断が要る部分（完了判断・成果の箇条書き）は**フックが参照md（手順書）を注入して強制**する。
  追加のLLM呼び出し（`claude -p` 等）は使わない＝セッション自身が書くのでトークン追加コストなし。
- **2026-07-04 実測追記**: 注入だけでは登録が実行されない（Claude/Codexとも実タスクで未実行を確認）。
  → **登録も機械化**: UserPromptSubmit フックが最初のプロンプトで auto行（`<!-- s:キー a -->`・
  要約=プロンプト先頭24字・種別=その他）を自動登録し、エージェントは `update` で claim（種別・要約を正す）。
  さらに実測第2弾で **claim も実行されない**ことを確認 → 終了手順の発動も機械化:
  ブロック時に session-end.md **本文をスクリプトが読んで丸ごと注入**（パス提示のみは不発と実測）。
- **2026-07-04 裁定（雑談例外の廃止）**: 登録された全セッションが、毎ターン終了時に完了判断を行い、
  **依頼を達成したと判断したら必ず人間確認①②③（記載/コミット/マージ&push）を出す**。
  ⏸の行はプロンプト送信で🟢へ自動復帰（ツール数による雑談判定は廃止）。
  Codex は UserPromptSubmit 相当が無く機械登録も未接続（P3で接続方式を実測）。

### 1. 新デイリーボード書式（md・2節のみ・チェックボックスなし）

当日デイリー `my-brain/ゴール/デイリー/YYYY/MM/YYYY-MM-DD.md` を次の2節だけにする。

```markdown
# デイリー YYYY-MM-DD

## 動いているエージェント
- 10:32 | AIエージェント基盤 | 実装 | Hooks整理と全停止 | 🟢動作中 <!-- s:ab12cd34 -->
- 09:15 | 仕事 | レビュー | 求人原稿の校正 | ⏸停止・確認待ち <!-- s:9f8e7d6c -->

## 終わったこと
### AIエージェント基盤
- Hooks全撤去（LINE・cockpit・Orca）と launchd 5本停止
### 仕事
- 求人原稿3本の校正
```

- 1行の型: `- 開始時刻 | repo | 種別 | 依頼の1行要約 | 状態`。**チェックボックスは持たない。**
- 行のライフサイクル: 開始で追加（🟢）→ 停止で⏸（フックが機械flip）→ **完了が人間確認されたら行を削除し、
  成果を「終わったこと」のrepo見出しへ箇条書きで移す**。ボードには今生きているセッションだけが残る
  （1日100セッションでも完了分は消えるので並ばない）。
- 種別の語彙: `計画` / `実装` / `レビュー` / `その他`（迷ったら その他）。
- 状態の語彙: `🟢動作中` / `⏸停止・確認待ち` の2値のみ。
- 行末の `<!-- s:xxxxxxxx -->` は自行特定用の短いキー（session id先頭8桁。フックの機械flipに必要）。
  **完全なsession id・transcriptパス・commit SHA羅列はボードに書かない**（git / transcript が正本）。
- 旧デイリーの他の節（逆算・TODO・依頼インボックス等）の行き先: **未確定**（後続で詰める。v1では2節のみ）。

### 2. 完了の扱い: AI判断 → 人間確認（①②③） → 移動＋git仕上げ

セッション終了フェーズの手順（正本は skill の `references/session-end.md`。3文書ドラフトとgit仕上げ②③は
2026-07-04 人間承認済み）。

1. **完了判断**: 最初に依頼された内容＋途中で追加・変更された内容が終わっているかをAIが判断する。
   判断材料は会話内容と **git実体（status/log）の二重チェック**。
2. **終わっていると判断した場合**: 人間に**①②③を明示して1回だけ**確認する——
   「完了と判断しました。①『終わったこと』へ記載（案添付） ②未コミット分のコミット（このセッションで
   触ったファイルのみ・パス指定） ③main以外ならmainへマージ→push（main上ならpushのみ）。
   ②③不要なら『①だけ』と返答を」。
   - 人間OK → ①成果を「終わったこと」の該当repo見出しへ追記 → ②ボードから自分の行を削除 →
     ③git仕上げ（OKが②③を含む場合のみ）。
   - **gitガード**: パス指定コミットのみ（`git add -A` 禁止・他セッション/人間の未コミット変更を巻き込まない）／
     コンフリクト・repoポリシー（main直pushブロック等）・detached HEAD は中断して報告／
     force push・履歴改変・ブランチ削除はしない／repo-local AGENTS.md のgit運用が優先。
   - 返答が得られない／NG → 行は `⏸停止・確認待ち` のまま残す（掃引は朝夜会。v1では手動）。
3. **終わっていない場合**: 行を実態（残作業が分かる依頼要約）に書き換えて `⏸停止・確認待ち` で残す。

### 3. skill構造: SKILL.md＝索引、手順は references で開始/終了に分割

`AIエージェント基盤/skills/session-board/` を新設。

```text
skills/session-board/
  SKILL.md                      # 索引＋共通語彙（行の型・種別/状態語彙・書かないもの）
  references/
    session-start.md            # 開始手順: repo特定→種別判定→1行要約→board.sh add
    session-end.md              # 終了手順: 完了判断→人間確認→行削除＋終わったこと追記
  assets/
    daily-template.md           # 2節テンプレ
```

- SKILL.md に手順本文は書かない（「開始時は session-start.md、終了時は session-end.md を読む」の導線と共通語彙だけ）。
- フックが注入するのは対応する references 1枚だけ＝注入コンテキストが小さく、手順が混ざらない。

### 4. フック: 正本は hooks/、Claude・Codex 両方へ symlink で接続

機構の正本を `AIエージェント基盤/hooks/session-board/` に置く（スクリプト本文をツール側にコピーしない）。

```text
hooks/session-board/
  start-inject.sh               # SessionStart: references/session-start.md を機械注入
  stop-guard.sh                 # Stop: (a)自行を⏸へ機械flip (b)報告未記入なら1回ブロックして session-end.md を注入
  board.sh                      # 行upsert・flip・報告有無の検査（flock付き。skillからも同じものを使う）
  README.md                     # 登録スニペット（Claude/Codex両方）・テスト手順
```

- **Claude**: `~/.claude/settings.json` の SessionStart / Stop に登録（コマンドは正本への参照。
  ツール側にスクリプトを置く場合は symlink。全セッションに効くため登録は人間ゲート）。
  Stopブロックは公式仕様（decision:block＋reason注入・`stop_hook_active` で無限ループ防止）を使う。
- **Codex**: 同じ正本スクリプトへ接続する。停止側は `config.toml` の `notify`（turn-ended）から
  stop-guard.sh 相当を呼ぶ（旧codex-notify.shと同じ経路・実測済みの機構）。
  開始側の注入手段（SessionStart相当のイベント有無）は**P3で実測**して決める
  （無ければ AGENTS.md 契約＋停止側ガードでカバーし、その旨を本計画に追記する）。
- subagent・headless実行には作用しない（環境変数ガードで抑止。旧AIJOBS_RUN方式を流用）。

### 5. セッション契約（GLOBAL_AGENTS.md への短い追記）

- 「セッションの開始/終了は session-board skill の手順に従う」＋plans置き場の判断（§6）を短く追記。
  本文複製はしない（正本は skill と本計画）。
- **登録しないもの**: subagent、headless/機械実行、依頼が発生しない雑談。

### 6. repo-local plans/ 規約（計画の置き場の統一）

1. **実作業repo**（仕事・focusmap 等）: repo直下に `plans/planning|active|paused|done/` が無ければ作る。
   - 計画セッション: まず `planning/` に計画mdを書く → 実行で `active/` へ、完了で `done/` へ**フォルダ移動＝状態遷移**
     （md内に状態や「実行中」マークを書かない。動いてる/止まったはボード側が持つ）。
2. **personal-os / my-brain 系**: `my-brain/areas/<領域>/plans/` に **`planning/` バケットを追加**し、
   同じ4バケットで運用（archive/移行済みは既存どおり維持）。`areas/AGENTS.md` §3・§4.1 の
   「planningは基盤のみ」を改訂する（既存active計画は動かさない）。

### 7. Notion同期の再開（後続・v1スコープ外）

- 新書式デイリーmdを正本として、Notionへ定期送信する薄いsyncを再開する。間隔60秒から
  （30秒化・DB構造は後で調整。未確定）。

### 段階

1. **P1 書式と土台**: 2節テンプレ・session-board skill（SKILL.md＋references 2枚＋assets）・
   hooks/session-board/（board.sh 先行）・当日デイリーを新書式で1枚作る。
2. **P2 フック接続・Claude（人間ゲート）**: start-inject.sh / stop-guard.sh 作成 → settings.json 登録＋
   GLOBAL_AGENTS.md 契約追記 → Claude で開始登録・機械flip・完了確認→移動・報告ガードを実測。
3. **P3 Codexとplans敷設**: Codex notify(turn-ended) の機械flip実測・開始注入手段の実測 →
   仕事/focusmap に plans/ 生成・my-brain 全領域に planning/ 追加（areas/AGENTS.md改訂）・1件をフォルダ移動で実測。
4. **P4 Notion再開（人間ゲート）**: 新書式対応syncを起動（launchd登録は人間ゲート）。

## 完了条件（レビュー項目）

1. 当日デイリーmd（`ゴール/デイリー/2026/07/` の新書式）が2節のみで構成され、
   `skills/session-board/`（SKILL.md・references 2枚・テンプレ）と `hooks/session-board/`（3スクリプト）が存在する。
2. ボード行にチェックボックスが無く、`時刻|repo|種別|依頼|状態` 型である（テンプレ・実運用行とも）。
3. Claude Code の新セッション開始で、ボードに🟢の1行が登録される（実測1回）。
4. セッション終了時、**Stopフックの機械flipだけで**状態が⏸になる（指示への依存なし・実測1回）。
5. 完了時、人間確認（「終わったことに入れてよいか」）→ OK後に**行が削除され**、成果が「終わったこと」の
   repo見出しに入り、git実体と矛盾しない（実測1回）。
6. 報告未記入のままstopした場合、ブロックが1回働き、session-end.md の手順実行後に終了する（実測1回）。
7. Codex セッションでも開始登録（または P3 で確定した代替手段）と終了機械flipが各1回実測できる。
8. 仕事repo・focusmap に `plans/planning|active|paused|done/` が、my-brain の全領域 plans/ に `planning/` が存在し、
   計画md 1件がフォルダ移動で状態遷移する（実測1件）。`areas/AGENTS.md` の語彙が改訂済み。
9. subagent・headless実行の行がボードに登録されていない（環境変数ガードの実測含む）。
10. ボード・計画mdに完全なsession ID・transcriptパス・commit SHA羅列・secret/token/認証値が含まれない
    （行末の `s:` 短キーのみ許容）。
11. session-end.md に ①②③明示の確認文・パス指定コミット（`add -A`禁止）・中断条件・禁止事項が明記され、
    人間OKなしにgit操作（commit/merge/push）が実行されない。
12. （P4）Notion側に新書式ボードの内容が同期されている。

## 未確定（後続で詰める）

- 旧デイリー人間節（逆算・TODO・依頼インボックス）の行き先と朝夜会（morning-routine）の読み替え
  （⏸滞留行の掃引手順を含む）。
- Codex側の開始注入手段（SessionStart相当の有無。P3実測で判断）。
- Notion DB構造・送信間隔（60s/30s）・送信対象の範囲。
- 領域（areas）ごとの計画運用の細部（本計画は置き場の統一まで）。
- cockpit/監督系の作り直し（別計画。本ボードの状態語彙と整合させる）。
