親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善
規模: フル
並列: 可（Wave 1） ／ レビュー: 一括（Checkpoint A / Final Gate）

# 業務レイヤ（Dailyコア）

## 目的

session-boardへ半日〜1日単位の業務行を追加し、work/privateの分離、Work end、Daily end、封印後の翌日回送を決定的なCLIとして実装する。

## 現状

- session-boardはセッション行のadd/update/flip/log/finish/reconcileとflock・原子的書込を持つ。
- 現在時刻の注入は実装済み。
- `biz-*`、`lane: work|private`、`work_closed`、`closed`、封印後の翌日回送は未実装。
- 現行baselineはsession-board 263 checksがPASS。古い計画内の「97本」を基準にしない。
- `md/store.py` の行形式と3状態は既存互換を壊せない共有hotspot。

## Terra実装パケット

### 担当とWave

- 担当: `Terra-02`（`gpt-5.6-terra`）
- Wave: 1。Terra-01 / 07 / 08と並列。
- このagentを `board.py` と `md/store.py` の唯一writerにする。
- 完了時は自己テスト結果とcommit hashだけをPlan 09へ渡す。

### 最初に読むもの

1. `/Users/kitamuranaohiro/Private/AGENTS.md`
2. この `plans/02-業務レイヤboard拡張.md`
3. `personal-os/AIエージェント基盤/hooks-registry/AGENTS.md`
4. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/AGENTS.md`
5. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/md/AGENTS.md`
6. `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/README.md`
7. Gate 0 baseline結果と、Terra-01が報告する8節正本pathだけ

`program.md` と他の子planは読まない。

### 触る場所

- `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/board.py`
- `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/md/store.py`
- `personal-os/AIエージェント基盤/hooks-registry/hooks/session-board/tests/` の本責務専用test

### 触らない場所

- `ゴール/` 配下、`common.py`、Turso層、runtime受け口、既存hook登録
- session-boardの共有README / AGENTS（Plan 09が統合後に更新）
- board-sweep、inbox-triage、Global Skill、loop overview
- `program.md`、他の子plan、実Daily、runtime symlink、launchd、git push

### 公開するCLI契約

- `biz-add`: `b:key`、業務名、条件、親slug、`lane: work|private` を冪等追加。
- `biz-update`: %と根拠など指定された業務行だけを更新。
- `biz-done`: finish実績と整合させ、100%は完了イベント時だけ許可。
- `work-close`: work laneだけを確定し、`work_closed HH:MM` を冪等upsert。privateは更新可能なまま。
- `close`: Daily全体を確定し、`closed HH:MM` を冪等upsert。
- `ensure-daily`: Terra-01の8節正本から当日Dailyを冪等生成。
- 封印後の通常書込は翌日へ回送。日付明示fixtureだけは指定日へ書ける。

### 実装すること

1. 既存セッション行の正規表現・3状態を変えず、業務行を別文法として追加する。
2. 業務行に必ず `lane` を持たせ、repo名からwork/privateを推測しない。
3. 業務行CRUD、定型レーン、セッションぶら下がり表示を既存手書き領域と分離する。
4. `work_closed`と`closed`を日付キーで冪等upsertする。
5. `closed`後だけ通常書込を翌日へ回送し、reconcileは封印済みDailyへno-op。
6. 全書込を既存flockと原子的置換の中で行い、LLMやネットワークをこのplanへ持ち込まない。

### 成果物と受け渡し

- CLI名、引数、exit code、翌日回送条件をPlan 09へ1枚で報告する。
- Terra-03 / 04はPlan 09がCheckpoint A後に公開するREADME契約だけを読む。
- 共有READMEへの本文反映とtrigger配線はPlan 09に委ねる。

### 自己テスト

- 既存session-board 263 checks。
- 新規業務CRUD・lane・seal・翌日回送tests。
- 同一操作2回の2回目diffが空。
- `board.py log` と並行したfixtureで行喪失がない。
- 許可範囲外のdiffがなく、`git diff --check`がPASS。

## 方針

- 業務行は既存セッション行と別文法にし、既存parse・整列・Turso送信を壊さない。
- セッションの業務紐づけは最初に最小方式で導入し、不足が実測された時だけメンバーlist形式へ拡張する。
- 機械占有表示は明示marker内だけ。人間の手書き行を全置換しない。
- work/privateの締め分離を最優先し、Work endでDaily全体を封印しない。

## 完了条件（レビュー項目）

- [ ] 既存session-board 263 checksが変更前後で全PASSする
- [ ] 業務CRUDがb:key単位で冪等で、既存セッション行と手書き領域に不要diffがない
- [ ] work/private両laneのfixtureで `work-close` 後もprivateだけ更新できる
- [ ] `close` 後の通常書込だけ翌日へ回送され、指定日fixtureと封印済みreconcileの契約が守られる
- [ ] 全書込が既存flockと原子的置換を使い、並行logテストで行喪失がない
- [ ] Checkpoint A / B / Final Gateで本plan対象と既存回帰がPASSする

## 完了報告

`変更ファイル / 公開CLI / 自己テスト件数 / 既知の制約 / commit hash` の5点だけをPlan 09へ渡す。
