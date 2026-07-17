親計画: ../program.md ／ 分類: loop ／ 種別: 既存改善
規模: ライト
並列: 可（検証のみ） ／ レビュー: 一括（Checkpoint A / B / Final Gate）

# board-sweep互換確認

## 目的

すでに稼働しているboard-sweepを再実装せず、Dailyコア・8節テンプレ・3儀式の変更後も誤finishや自己登録を起こさないことをprogram横断テストで確認する。

## 現状

- `loops-registry/loops/board-sweep/` は実装済み。
- `com.kitamura.board-sweep` は2026-07-11から60分毎・`--apply`で稼働中。
- 二重鍵、1回最大3件、台帳ドラフト不流入の安全弁がある。
- `tests/test_sweep.py` は31 tests PASS。
- 旧programの「未ロード」は誤り。`loop.md` にpausedへ移ったprogramの旧 `plans/active/...` backlinkが残る。

## 検証パケット

### 担当

- 新規Terra workerは立てない。Plan 09の統合・テスト担当がCheckpoint A / B / Final Gateで読む。

### 最初に読むもの

1. この `plans/05-停止行自動判定sweep.md`
2. `personal-os/AIエージェント基盤/loops-registry/AGENTS.md`
3. `personal-os/AIエージェント基盤/loops-registry/loops/board-sweep/loop.md`
4. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/AGENTS.md`

### 触る場所

- 原則なし。回帰FAIL時だけ `loops-registry/loops/board-sweep/` の最小修正を所有planへ切り出す。
- 旧計画backlinkと共有overviewはPlan 09だけが更新する。

### 触らない場所

- 稼働中plistの発火条件、launchctl状態、routine-ledgerのドラフト解除。
- session-board core、実Daily、program/他plan、git push。

### 確認すること

- 8節Dailyでも⏸行を列挙・判定できる。
- `work_closed` / `closed` と競合せず、closed後の当日Dailyを変更しない。
- unknown / not-doneは1バイトも変更しない。
- 自動finishには `[auto]` と根拠があり、sweep自身のsession行を増やさない。
- programの現役pathへbacklinkが解決する。

## 方針

- 本programではboard-sweepの機能追加や再設計を行わず、既存稼働の互換確認に限定する。
- 回帰FAIL時だけ最小の所有planへ切り出し、稼働中設定を直接変更しない。
- CheckpointとFinal Gateで他機能とまとめて検証し、Plan 05単独の正式レビューは行わない。

## 人間判断待ち

- routine-ledgerのドラフト解除。
- 発火条件やapply上限を変更する場合の人間GO。本programでは変更しない。

## 完了条件（レビュー項目）

- [ ] board-sweep 31 testsがCheckpoint A / B / Final Gateで全PASSする
- [ ] 8節・lane・work_closed/closedを含むfixtureでunknown/not-doneが無変更
- [ ] 自動finish時だけ `[auto]` と根拠が入り、自己登録行が増えない
- [ ] 稼働中のlabel・発火・安全弁を無断変更していない
- [ ] 旧 `plans/active/...デイリー運用刷新` backlinkが現役pathへ直り、loop verifyがPASSする

## 完了報告

Plan 09が `31 tests / 追加互換fixture / 実機状態は変更なし / backlink / 判定` をCheckpoint結果へまとめる。
