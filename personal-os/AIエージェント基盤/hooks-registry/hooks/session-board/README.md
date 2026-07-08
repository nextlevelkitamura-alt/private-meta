# session-board — セッション宣言型ボードの機構

当日デイリー2節ボード（`## 動いているエージェント` / `## 終わったこと`）を駆動する一式。
**skillは廃止**（2026-07-05）。**registry再編済み**（2026-07-06）。**2列ボード再設計**（2026-07-08・設計は
`my-brain/areas/ai運用/plans/active/2026-07-08-計画実行フロー統一/plans/01-session-board責務再設計.md`）。
手順md・エンジン・受け口すべて正本はこの repo（runtime へは symlink 窓で露出）。

境界原則: **Python＝枠と機械処理**（速く確実に・記録を落とさない）／**AI＝意味づけ**（種別・目標・今・置き場の判断）。
hook は AI が考える前に同期実行されるため、hook 側に意味の判断を入れない。

## 行フォーマット v2.2（2026-07-08〜）

```
- 🟢 HH:MM | <目標> | 今:<今> | <repo> | <種別> | <runtime/model> | 計画:<計画> <!-- s:KEY -->
```

- **状態**（行頭・絵文字3値）: 🟢動作中／⏸停止・確認待ち／🔵サブ稼働中。
- **目標**: 達成したらこのセッションを閉じられる1行（〜30字）。**AIが記入**（未記入は `?`）。
- **今**: いま着手している一歩（〜20字）。**AIが記入**。初回だけUPSフックがプロンプト先頭24字を仮置きし、以降Pythonは上書きしない。
- **repo**: フックが機械記入（cwd の git トップ）。
- **種別**: 5種（下記）。フックは `その他` で仮置きし、AIが正す。
- **runtime/model**: runtime（claude/codex）はフックが機械確定して `claude/?` を仮置き、モデル名はAIが自己申告で正す（例 `claude/fable5`）。
- **計画**（末尾・`計画:<値>`）: この作業の拠り所（実装・レビュー）／これから置く先（計画）。**AIが記入**（未記入は `?`）。値は3種で、**この節が語彙の正本**:
  - `?` … 未記入（催促対象）。フックの既定値。
  - `なし` … 構造3条件（①1〜2ファイル ②容易に戻せる ③人間ゲート無し）を全部満たすサクッと作業の宣言。**正当な最終値**（未記入ではない）。
  - **短縮参照** … repo計画は `企画名[/NN]`、area計画は `ai運用:企画名[/NN]`（子計画番号 `NN` は任意）。**バケットは書かない**（フォルダが状態。repo列＋plans規約からフルパスを復元できる）。
- **読み取り互換**: v2（計画列なし・2026-07-08〜）は `計画:?` を補って読む。v1（旧1要約列・状態語末尾・〜2026-07-08）も読める。書き込みは常に v2.2（どの書き込みでも自然移行）。
- 節の先頭に**目的別サマリ**を自動再生成（`<!-- goals-summary -->`〜`<!-- /goals-summary -->`・手で編集しない）:
  `- <目標> — N体（🟢x 🔵y ⏸z）`
- 行の並びは **目標グループ（生存優先）→ 状態 → 時刻**。同じ目的のセッションが隣接する。

## 種別（5種・この節が定義の正本）

- **計画** … 何をやるか・どう進めるかを決めて文書に落とす。成果物＝plan.md / program.md。
- **実装** … コード・設定・文書を変更して動く状態にする。成果物＝diff・commit。
- **リサーチ** … 調べて分かったことをまとめる。何も変更しない。成果物＝調査メモ・回答。
- **レビュー** … 既存の成果物を評価して指摘を返す。自分では直さない。成果物＝指摘・判定。
- **その他** … 上のどれでもない・まだ分からない。
- 運用原則: **迷ったらその他でよく、分かった時点で `update --type` で直すのが正常**（直しは失敗ではない）。
  定義は「一言＋成果物」以上に厚くしない（定義への固執で誤分類を生まないため）。境界例はここに追記して育てる。
  - 境界例: 「調べてから直して」＝実装（変更が成果物だから。調査はその途中工程）。

## 動作モデル（①枠→②機械処理＋注入→③AIが意味づけ→④機械flip）

1. **枠登録**（SessionStart / `session-start.py`）: reconcile ＋ 行の枠（時刻・🟢・repo・runtime/?）を `add`
   （**既存行は上書きしない**冪等）＋キー通知1行だけ注入。旧設計の手順md全文注入は廃止。
2. **機械処理＋二段注入**（UserPromptSubmit / `prompt-register.py`）: 未登録なら保険add／⏸→🟢復帰／
   「今」未記入なら先頭24字を初回だけ仮置き。注入は**目標未記入=フルガイド**（updateコマンド・種別5定義・
   既存目標一覧と合流規約・計画チェーン）／**記入済み=2〜3行ミラー**（現在行＋ズレ回収の催促。計画種別のみ置き場1行追加）。
   ミラーが「今」の書き忘れ回収網を兼ねる。注入文の生成は `common.py`（動的要素があるためmdでなくコード側）。
3. **意味づけ**（AI・応答ターン）: `update --type --goal --now --model` で行を正す。
   既存目標と同じ目的なら**文言をそのままコピーして合流**（親名=目標名で成果が1親に集まる）。
4. **状態flip**（Stop / `session-end.py`）: run のとき⏸へ機械flip＋reconcile。**ブロックしない**。
5. **節目確認**（Stop / prompt型 `../../claude/milestone/session-board-milestone.md`・**Claude専用**）:
   大目標達成＋満足の気配でのみ `session-end.md` の完了手順を促す。
6. **入れ子記録**: 節目ごとに `log`、完了は人間確認後に `finish`。子には**所要時間 `(+Nm)` を自動付与**
   （基準＝同じ親の直前の子 → 無ければセッション行の開始時刻。日跨ぎは+24h補正。AIが所要を推測で書かない）。
   行の計画値が参照（`?`/`なし` 以外）なら、親行末尾に `‹計画: <値>›` を**自動転記**（Pythonが運ぶ＝AIの追加作業ゼロ。
   既に `‹計画:` を含む親行には付けない＝先勝ち・重複禁止）。

## board.py コマンド

```
board.py add    --key K --repo R [--type T] [--goal G] [--now N] [--who W] [--time HH:MM]
                                   # 既存行があれば何もしない（枠のみ）
board.py update --key K [--repo R] [--type T] [--goal G] [--now N] [--model M] [--who W]
                                   # --summary は --goal の別名（旧互換）。--model は who のモデル部だけ置換
board.py flip   --key K --state run|wait|sub
board.py log    --key K --repo R --parent P --entry E [--entry E ...]   # 時刻・(+Nm) 自動付与
board.py finish --key K --repo R --parent P [--entry E ...]             # 自行削除＋子追記
board.py reconcile                 # 🟢/🔵を実体照合し沈黙(🟢≥10分/🔵≥30分)を⏸へ＋整列（--key不要）
board.py check  --key K            # missing|run|wait|sub
board.py show   --key K            # state/goal/now/type/repo/who のタブ区切り（無ければ missing）
board.py goals                     # 現在の目標一覧（重複なし・未記入除外・表示順）
```

## 状態（3値）

- 🟢 **動作中**（run）… 自分が処理中
- 🔵 **サブ稼働中**（sub）… バックグラウンドのサブエージェント待ち。**Stopで⏸にならず維持**され、
  プロンプト送信でも🟢に戻さない（サブ完了でエージェントが `flip --state run`・Codex は `subagent.py` が自動）。
- ⏸ **停止・確認待ち**（wait）… 手が空いた。次プロンプトで🟢復帰。

`session-end.py`（Stop）は `run` のときだけ⏸へflip（`sub`/`wait`は触らない）。
`prompt-register.py` は `wait` のときだけ🟢復帰（`sub`は触らない）。

## 生存照合と並び替え（2026-07-08 更新）

イベント駆動だけでは「閉じる合図」が鳴らないと🟢/🔵が固着する。これを現実と突き合わせて解く。

- **並び替え**: どの書き込み後も「目標グループ（グループ内の最良状態が代表）→ 目標 → 状態 → 時刻」で整列。
  生きている目的が上・同じ目的が隣接。目的別サマリも同時に再生成。
- **生存照合**（`reconcile`）: 🟢/🔵の各行について、**パスにキー（sid先頭8字）を含む** `.jsonl` の最新mtimeを見る。
  パス照合なのでサブエージェント実体（`<親uuid>/subagents/agent-*.jsonl`）の書き込みが**親の生存として数えられる**
  （長いサブ委託中の🔵誤降格を防ぐ・2026-07-08修正）。沈黙の閾値は **🟢=10分・🔵=30分**。
  実体が見つからない行は判定不能として触らない（推測で落とさない）。
- **発火**: `common.stop_flip`（Stop）と `common.start_register`（SessionStart）から毎回。
  **UserPromptSubmit には乗せない**（開始レイテンシを守る）。保険として launchd 5分毎の
  `loops-registry/loops/board-reconcile/`（**未ロード**・有効化は人間ゲート）が全セッション放置中の残留を埋める。
- 探索根は `SESSION_BOARD_TX_ROOTS`（:区切り）で差し替え可（テスト・移設用）。

## 登録（窓経由・登録は人間ゲート／session-board は包括承認）

正本は repo、runtime には **symlink 窓**で露出する。

- **Claude** `~/.claude/settings.json`（パスは窓 `~/.claude/agent-hooks/<イベント>/…`・trust不要・保存で自動反映）:

```json
{ "hooks": {
  "SessionStart":     [{ "matcher":"startup|resume|clear|compact",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-start/session-board-session-start.py","timeout":10}] }],
  "UserPromptSubmit": [{ "matcher":"",
    "hooks":[{"type":"command","command":"~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py","timeout":10}] }],
  "Stop": [
    { "matcher":"", "hooks":[{"type":"command","command":"~/.claude/agent-hooks/session-end/session-board-session-end.py","timeout":10}] },
    { "hooks":[{"type":"prompt","prompt":"<claude/milestone/session-board-milestone.md の内容>"}] }
  ]
}}
```
（実ファイルは絶対パス `/Users/…/.claude/agent-hooks/<イベント>/…` で記述）

- **Codex** `~/.codex/hooks.json` → `../../codex/hooks.json` への **symlink**（repo が正本）。
  パスは窓 `~/.codex/agent-hooks/<イベント>/…`。**hook を変えたら `/hooks` 再 trust**（hash/パスに紐づく）。

窓の実体: `~/.claude/agent-hooks → hooks-registry/claude/`、`~/.codex/agent-hooks → hooks-registry/codex/`。現況は `registered.sh`。

## ガード（登録・作用しないもの）

- `AIJOBS_RUN` 非空（headless）／ session id が `agent-*`（subagent）／ transcript が `*/subagents/*`／
  スラッシュコマンド・空・添付のみのプロンプト。

## テスト用 env

- `GOAL_BASE`（デイリー基点）／ `SESSION_BOARD_DATE`（YYYY-MM-DD）／ `SESSION_BOARD_TEMPLATE`／`SESSION_BOARD_TX_ROOTS`。
- 受け口は窓越しに叩いて検証できる（例: `echo '{...}' | ~/.claude/agent-hooks/prompt-register/session-board-prompt-register.py`）。
  `realpath` で共有本体を解決するので窓経由でも `board.py` を正しく指す。

## 既知の制約

- **日付跨ぎは未解決**: `reconcile` は当日ボード対象。前日ボードの固着行は自動掃除されない。
  当面は必要時に `SESSION_BOARD_DATE=YYYY-MM-DD board.py reconcile` を手動実行。恒久対応は別途検討。
- 節目判定（milestone）はモデル依存＝確率的。迷ったら素通し設計で「聞かなさすぎ」に倒す。
- **Codex には prompt型フックが無く、「終わったこと」記載を促す網が無い**（状態⏸への機械flipは漏れない）。
  既知の制約として受け入れ、人間の「締めて」声かけ（夜会等）で補う。
- Codex接続（`codex/`）は実装・登録・trust 済みだが、**2026-07-08 の受け口更新で要再trust**。
  UPS注入（JSON `additionalContext`）は実測未確認。`board.py`・`common.py` は runtime非依存で共用。詳細は `../../codex/AGENTS.md`。

計画: `~/Private/personal-os/my-brain/areas/ai運用/plans/`（2列ボード再設計は `active/2026-07-08-計画実行フロー統一/`）。
