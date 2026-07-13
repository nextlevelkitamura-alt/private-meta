分類: loop
種別: 統合整理
規模: フル
優先: ◎
次: 合意済み設計を実装レーンへ渡す

## 目的

`loops-registry/loops/` を「現在稼働中、または30日以内に再開できる global loop だけの棚」に整理し、
廃止物・壊れた停止物・draft・実行レーンを混在させない。

人間が全体を判断する正本を `実行一覧/personal-os.md`、対になる表示物を
`実行一覧/personal-os.html` とし、AGENTS 契約と機械検査で更新漏れを防ぐ。

## 現状

### 2026-07-03 の構造監査所見

この計画は当初、launchd 実態と loop 文書の次のズレを直すライト計画として始まった。

1. `watch-keeper` と `inbox-patrol` は文書と runtime 登録が不一致だった。
2. `exec-audit` は repo 正本 plist と runtime 側の実体が不一致だった。
3. `renderer` / `daily-digest` は状態表記が実態より古かった。

その後、2026-07-04 に旧loop群を停止し、2026-07-06 に `renderer` / `daily-digest` を廃止したが、
実装一式は現役loopと同じ `loops/` に残った。`実行一覧/personal-os.md` と旧HTMLも更新されず、
2026-07-11 の実機状態と不一致になった。

### 2026-07-11 の実測

- 実機で loaded: `board-reconcile` / `board-sweep` / `daily-notion-sync` / `session-record-prune` の4本。
- `daily-notion-sync/loop.md` は「draft・未起動」のままだが、実機では loaded・実行済み。
- `exec-audit` / `inbox-patrol` / `watch-keeper` は未ロード。
- `ai-jobs` / `ai-jobs-dispatcher` は休眠。専用計画
  `../2026-07-08-ai-jobs縮小/plan.md` が担当する。

### 完了済みの先行整理（terra レーン）

2026-07-11、人間の明示承認により次を実施済み。

1. `loops/daily-digest/` と `loops/renderer/` を削除。
2. tracked 49ファイル・10,577行、ignored の log/state/cache を削除。
3. 退避場所に残った両loopの LaunchAgents symlink 2本を削除。
4. 稼働中 `daily-notion-sync` の `_paths.sh` 参照を自身のloop内へ差し替え。
5. shell構文はPASS。`daily-notion-sync` テストは9/11 PASSで、失敗2件は今回の差分外の既存不整合。

削除監査の結果、停止中3本は削除済み資産へ依存し、現在のままでは再開不能と判明した。

- `exec-audit`: `daily-digest/scripts/_paths.sh` 依存。
- `inbox-patrol`: `daily-digest` / `renderer` の複数script依存。
- `watch-keeper`: `renderer` の lanes-sync 相乗り・snapshot 導線を文書上前提にする。

## 人間合意（2026-07-11）

meta-explain の変更前理解ゲートで、次の4項目を人間が「それでいい」と明示承認した。

1. `exec-audit` / `inbox-patrol` / `watch-keeper` は全部削除する。
2. `references/` は生きた共通規約を `loops-registry/AGENTS.md` へ統合して削除する。
3. 全体表示は `personal-os.md`（正本）＋ `personal-os.html`（人間表示）＋ `verify.py`（検査）の3点構成にする。
4. 停止loopの主棚残置は最大30日とする。

## 方針

### 1. loop の定義を狭くする

loop は「時刻または間隔を発火点として、人の操作なしに繰り返す処理」だけとする。

- runtime イベント直後に動くものは `hooks-registry/`。
- 人が呼ぶコマンドは所有 Skill または repo の `scripts/`。
- AI の実装・レビュー・采配は Skill / orchestration。
- 構想・draft は所有repoの `plans/`。

runner（`script` / `ai`）と scope（`global` / `repo-local`）は属性として `loop.md` に書き、
属性別フォルダを増やさない。

### 2. 主棚の寿命を決める

1. draft は plans/worktree だけに置き、main の `loops/` へ置かない。
2. 人間GO・テスト・plist検証・overview更新が揃ってから `loops/` へ入れる。
3. 一時停止は `loop.md` に停止理由と再判断期限を書き、最大30日だけ残せる。
4. 廃止は bootout → runtime symlink除去 → 参照修正 → 実体削除の順で行う。
5. 廃止物の archive フォルダは作らず、Git履歴とdone計画を履歴正本にする。

### 3. 最終構造を増やさない

```text
loops-registry/
  AGENTS.md
  CLAUDE.md -> AGENTS.md
  loops/
    board-reconcile/
    board-sweep/
    daily-notion-sync/
    session-record-prune/
  実行一覧/
    AGENTS.md
    CLAUDE.md -> AGENTS.md
    personal-os.md
    personal-os.html
    verify.py
```

- `ai-jobs/` と `ai-jobs-dispatcher/` の削除・関連導線更新は専用計画へ委ねる。
- `references/` の `worker-prompt.md` は ai-jobs と共に退役させる。
- `loop-runbook.md` / `loop-types.md` の生きた規約だけを `loops-registry/AGENTS.md` へ集約する。
- `実行一覧/output/` は廃止し、HTMLを対になるMDと同じ階層へ置く。

### 4. MD と HTML の役割を分ける

- `personal-os.md`: AIが読む current overview の正本。現在 `loops/` にあるloopだけを載せる。
- `personal-os.html`: 同じbasenameの人間向け表示。AIの実行導線から参照しない。
- 実機状態は変動値なので、MDには「意図状態」と「最終実機確認時刻」を分けて書く。
- 廃止履歴、長い経緯、実行ログは current overview に混ぜない。

MD/HTMLの更新対象は、目的・稼働状態・発火条件・launchd label・正本pathが変わる時だけとする。
内部実装だけの修正で一覧項目が変わらない場合は再生成不要。

### 5. AGENTS と機械検査で守らせる

`loops-registry/AGENTS.md` に次を集約する。

1. loop の定義と置き場。
2. draft → 稼働 → 最大30日停止 → 廃止の寿命。
3. 削除の安全手順。
4. MD/HTML更新条件。
5. `verify.py` PASSを変更完了条件にする規則。

`実行一覧/verify.py` は少なくとも次を検査する。

1. `loops/` のディレクトリ名と `personal-os.md` の掲載名が一致する。
2. 各loopに `loop.md` と1本以上の plist があり、`plutil -lint` を通る。
3. `personal-os.html` の `source-sha256` が `personal-os.md` のSHA-256と一致する。
4. MD掲載loop名がHTMLにも全て存在する。

## 実行順

1. `exec-audit` / `inbox-patrol` / `watch-keeper` の runtime 未ロードとsymlink残骸を再確認する。
2. 現役4本が停止3本へ依存していないことを `rg` と実行入口から確認する。
3. 停止3本と、削除対象だけを指す runtime symlink・ignored生成物を削除する。
4. `references/` の生きた規約を `loops-registry/AGENTS.md` に統合し、参照元を更新してから削除する。
5. `実行一覧/personal-os.md` を現役4本だけの current overview に書き直す。
6. `実行一覧/personal-os.html` を同階層へ生成し、旧 `output/personal-os.html` と空 `output/` を削除する。
7. `実行一覧/verify.py` を追加し、AGENTS 2枚へ更新契約を書く。
8. `daily-notion-sync/loop.md` など現役4本の状態表記を実機と一致させる。
9. `verify.py`、plist検証、現役4本の関連テストを実行する。
10. 実装と異系統のモデルが完了条件を評価し、`評価01.md` に記録する。

## 対象外

1. `ai-jobs/` / `ai-jobs-dispatcher/` の削除と `areas/AGENTS.md` などの実行導線更新。
2. 現役4本の機能変更。
3. `daily-notion-sync` の既存テスト失敗2件の修正。
4. repo-local loop 本体の移動・再設計。
5. commit / push。実装後の節目で人間確認を取る。

## リスクと戻し方

1. 削除対象への隠れ依存があれば現役loopが壊れるため、削除前の `rg` と入口テストを必須にする。
2. launchd の loaded/disabled はMDの固定値ではなく実機確認を正とし、設計との差を黙って上書きしない。
3. 削除した実装は Git から復元可能。archiveコピーは作らない。
4. `personal-os.html` は派生物なので、壊れた場合は正本MDから再生成する。
5. `verify.py` が過剰制約になった場合も、検査を無効化せず計画へ戻して契約を見直す。

## 完了条件（レビュー項目）

1. `loops-registry/loops/` の実体が、現役4本と ai-jobs専用計画の対象
   `ai-jobs-dispatcher` だけになり、`exec-audit` / `inbox-patrol` / `watch-keeper` が存在しない。
2. `~/Library/LaunchAgents/` と退避場所に、削除した5loop
   （`daily-digest` / `renderer(lanes-sync)` / `exec-audit` / `inbox-patrol` / `watch-keeper`）を指すsymlinkが残っていない。
3. `loops-registry/references/` が存在せず、生きたloop定義・runner/scope・寿命・削除手順・更新契約が
   `loops-registry/AGENTS.md` に一意に存在する。
4. `実行一覧/personal-os.md` が現役4本だけを掲載し、目的・発火・runner・label・正本pathを確認できる。
5. `実行一覧/personal-os.html` がMDと同階層にあり、4本を人間向けに表示し、旧 `実行一覧/output/` が存在しない。
6. `python3 実行一覧/verify.py` が、loop実体・plist・MD・HTMLの整合を検査してPASSする。
7. 現役4本の `loop.md` 状態表記が、2026-07-11の実機確認結果または実装時の再実測と一致する。
8. `rg` で削除済みloopへの現在形の実行依存が0件。過去計画・決定ログ・デイリーの履歴参照は対象外として分類されている。
9. 現役4本の関連テストと `plutil -lint` がPASSする。既存失敗を除外する場合は、今回差分外である証拠を評価文書に残す。
10. secret・token・credential・認証値が差分、ログ、overview、HTMLに含まれない。
11. 実装と異系統のモデルによる `評価01.md` で全項目PASSになっている。

## 関連

- ai-jobs専用計画: `../../planning/2026-07-08-ai-jobs縮小/plan.md`
- 実装正本: `../../../../../../AIエージェント基盤/loops-registry/`
- 種類・寿命・本文ドラフトの合意: 2026-07-11 meta-explain セッション
