親計画: ../program.md ／ 分類: loop ／ 種別: 新規作成

# ⏸自動判定（board-sweep）と定型台帳

## 目的

ボードの⏸（停止・確認待ち）行を判定エージェントが「実際に終わっているか」で弁別し、定型台帳一致またはone-shot完走を確認できたものは人間確認なしで「終わったこと」へ流す。⏸の堆積（07-09実測: codex行18本）を解消する。

## 現状（調査1・2026-07-09）

- ⏸は「返答待ち」「セッション死亡」「one-shot完走」の3つが混ざった状態。弁別材料は揃っている:
  - `codex exec`: rollout末尾に `task_complete` レコード必須＋mtime沈黙 → 機械判定可
  - Desktop automation: ボードに載らない（⏸堆積に無関係・スコープ外）
  - focusmap remote スレッド: transcript実体なし → 定型台帳の前方一致（「今」列の先頭24字仮置き仕様が照合キー）
  - Claude one-shot（`claude -p`）: transcript残存＋SessionEndフック（存在するが未使用）で検知可
- hookに判定を混ぜるのは不採用（10秒制限・Python=機械/AI=意味づけ境界・reconcile規律に抵触）。推奨は定期loop。

## 方針

1. 新loop `loops-registry/loops/board-sweep/`（launchd 30〜60分毎 or 定時・plist有効化は人間ゲート）。board-reconcile（機械・5分毎）とは別本。
2. sweep.py: ⏸列挙（board.py に読み取り専用 `list` サブコマンド追加・15行程度）→実体transcript照合→定型台帳マッチ→証跡収集→headless `claude -p` 判定（1sweepでまとめて1〜2回に集約）→ `board.py finish` を作用器に流し込み。当日＋前日ボードを対象（日付跨ぎ未解決も解消）。`AIJOBS_RUN=1` で自己登録防止。
3. 定型台帳 `hooks-registry/hooks/session-board/routine-ledger.md`: 1定型=1節・キー5つ（一致/終わり/確認/記載/判定）。`確認` は cmd:/file:/log:/none の4種（読み取り専用）。初期エントリは人間と作る。**エントリ名は業務カテゴリ名で呼ぶ（例: 架電・印刷・経理・focusmap定期。2026-07-09人間要望）** — 個別ジョブ名でなくカテゴリで束ね、同カテゴリの新作業が台帳修正なしでマッチする形を狙う。
4. 安全弁: 判定は3値（done/not-done/unknown）で unknown は無変更。自動finishは「定型台帳一致」or「one-shot完走＋沈黙N時間」に限定。計画列が実参照（?/なし以外）の行は自動対象外。finishの子entryに `[auto]` マーク＋根拠必須。git操作はコードパスごと持たせない。
5. 導入順: dry-runモード（ログのみ・板無変更）で1週間実測→誤判定率を見て流し込み有効化。1sweepの自動finish上限N件。23:30の節目で当日 `[auto]` 一覧を人間レビュー（Shutdown/夜の儀式に1項目）。
6. フェーズ2（任意）: Claude側 SessionEnd フックで「閉じたkey」をキューに落とし、sweepが優先消化（遅延短縮）。

## 完了条件（レビュー項目）

- [ ] 台帳不一致かつLLM判定unknownの⏸行は、sweep実行後もボード行が1バイトも変わらず残っている（dry-run・本番の両モードで実証）
- [ ] 自動finishされた行は「終わったこと」の該当repo見出しに親＋時刻・(+Nm)付き子で入り、子entryに `[auto]` と根拠（台帳名または証跡1行）が含まれる
- [ ] sweep実行の前後でボードの行数が増えない（`AIJOBS_RUN=1` ガードの実測・sweep自身が行を作らない）
- [ ] LLM失敗・タイムアウト・台帳パース失敗のいずれでもexit 0で終了しボード無変更（エラーはloopログのみ）
- [ ] 既存テスト97本が全緑のまま・sweepのコードパスにgit書き込み操作が存在しない

## 関連

- 依存: 02（計画列除外・[auto]語彙）。単体でも先行dry-run可。
- 流用資産: `hooks-registry/hooks/session-board/board.py`（finish/log/parse_line・envサンドボックス）・`loops-registry/loops/board-reconcile/`（plist雛形）・`loops-registry/loops/ai-jobs-dispatcher/scripts/`（headless起動パターン）・`~/.codex/sessions/**/rollout-*.jsonl`（task_complete）
- 運用契約の更新: session-end.md・README に「定型台帳一致は人間確認なしfinish可」の例外を明記（正本更新・人間承認）
