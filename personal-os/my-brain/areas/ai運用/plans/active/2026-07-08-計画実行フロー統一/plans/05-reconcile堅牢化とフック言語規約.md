親計画: ../program.md ／ 分類: 横断 ／ 種別: 既存改善

# reconcile堅牢化とフック言語規約

## 目的

W4評価（2026-07-08）で出た reconcile の潜在リスクを最小追補（方針A）で潰し、あわせて
「フックは基本Python」という暗黙の慣行を明文化して、今後のフック作成の判断を1つに固める。

## 現状

- `board.py` の `reconcile_rows` NOFILE分岐（実体が見つからない枠の掃除）に3つの弱点:
  ① 探索ルートが空だと RUN/🔵 を一括⏸（単一点障害）／③ 🔵サブが15分で落ち30分猶予を貫通／
  ⑤ 逆行クロックで `+1440` が誤発火。
- テストは bash（`tests/*.sh`）。純ロジックの検証には回りくどい。実行時に `sbtest/` 作業ゴミが散る。
- フックの実装言語の既定が明文化されていない（実態は本体=Python・loop入口=sh・テスト=sh）。

## 方針（方針A・2026-07-08 人間承認）

1. **reconcile 4行統合**（`board.py` 275-279行付近）: NOFILE分岐を
   `m=_minutes_between(...)`／`limit=STALE_MIN_SUB if SUB else STALE_MIN_NOFILE`／
   `if files and limit < m < 720:` に統合。これで ①（`files`空→抑止）③（🔵は30分）
   ⑤（上限720で逆行クロックの≈1439を弾く）を同時に解消。
2. **注記受容**（今回直さない・裁定済み）:
   - ② 外付けSSD部分断での誤爆 → 実測で transcript は現在ローカル実体（`~/.claude/projects` 317M・
     `~/.codex/sessions` 4.0G）＝**今は非該当**。①の空ルート抑止で全断は救える。部分断は狭いため受容し、
     「生きた記録は退避しない」を運用メモに残す（対策の本体は別計画=記録削除loop）。
   - ④ スラッシュ初回の登録漏れ → 途中の通常プロンプトで登録されるため受容（人間裁定 2026-07-08）。
3. **新テストは Python 1本**: `board.py` を import して `reconcile_rows`／`_minutes_between` を直接検証
   （空ルート抑止・🔵30分・逆行クロック非降格・日跨ぎ正算）。既存 bash 87本は**書き直さない**（維持）。
   `tests/` の作業ゴミ（`sbtest`/`sbtest2`）は scratch/tmp へ逃がして tests/ を綺麗にする。
4. **フック言語規約を明文化**（正本＝`hooks-registry/AGENTS.md` の §規律へ追記・references新設しない）:

   > ### フックの実装言語
   > - **既定は Python。** hook本体は stdin の JSON を読み・状態を構造化編集し（flock／原子的書き込み）・
   >   単体テストで守るため、ロジックを持つものは Python に統一（`board.py`・`common.py`・各受け口 `.py`）。
   > - **shell を使ってよいのは次だけ:** launchd/cron の入口スクリプト（`cd` して `.py` を呼ぶ薄い起動役）／
   >   他コマンドを繋ぐだけのグルー／ワンショット診断（`registered.sh` 等）／パイプ主体の集計。
   > - **迷ったら Python。** テストも原則 Python（`board.py` 等は import して関数を直接検証／通しの E2E だけ
   >   `tests/*.sh` 可）。パースやロジックが要る所は loop でも `.py`（例: `notion_helper.py`）。

5. **実装は worktree で**（`board.py` は本番フック・merge=デプロイ）。受け口シム・`hooks.json` は無変更を維持
   （`git diff` で担保＝Codex再trust不要）。

## 完了条件（レビュー項目）

- [ ] reconcile: `files` が空なら幽霊掃除をしない／🔵は30分閾値／逆行クロック（>720分）では降格しない
      （Python テストで直接確認）
- [ ] 既存 bash 87本＋新 Python テストが全緑
- [ ] `tests/` に実行時の作業ゴミ（sbtest等）が残らない（tmp退避）
- [ ] `hooks-registry/AGENTS.md` に上記フック言語規約が入り、実態（本体py／loop入口sh／テスト方針）と一致
- [ ] 受け口シム・`hooks.json` に diff なし（再trust不要の担保）
- [ ] ②④を直さない判断と根拠が本計画に明記され、②は記録削除loop（別計画）へ引き継がれている

## 依存

- 子01（W4=幽霊枠行対処）マージ済みの上に積む。② の恒久対策は別計画「セッション記録の定期削除loop」。

## 関連

- 評価: w4-eval／改善設計: w4-fix-design（2026-07-08 Artifact）
- 正本: `hooks-registry/hooks/session-board/board.py`・`hooks-registry/AGENTS.md`
