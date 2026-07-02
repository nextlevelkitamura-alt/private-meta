親計画: ../program.md ／ 分類: loop ／ 種別: 統合整理 ／ 規模: ライト

# 05 ai-jobs休眠の後始末

## 方針

1. `ready/` の `exec-audit-20260702.md` を手動処理し、exec-audit loop の出力先をデイリー（ボード区画）へ変更する（決定ログ#2-⑥）。
2. doc追従: `hooks/session-daily-log/README.md`「状態: 未登録」等のstale記述を実測（launchctl / settings.json / 当日デイリー）に合わせて修正。旧オーケ計画のCard1を吸収。
3. 活性化条件は運用契約§1に記載済み。dispatcher実装と `feat/ai-jobs-*` branchは温存（削除しない）。
4. （2026-07-02 実装中に発見・後半へ追加）exec-audit `audit.sh` の冪等チェックにバグ: 既存カードの検出が `ls` 複数globの非マッチ時exit code依存で、ready/ 以外にカードが無い状態だと「既存なし」と誤判定して上書き再生成する。出力先変更（項目1後半）と同時に修正する。

## 完了条件（レビュー項目）

- [ ] `ready/` が空で、デイリー/ボードの件数表示と実フォルダが一致
- [ ] 「未登録」等のstale記述が実測と一致（launchctl list / settings.json 確認）
- [ ] dispatcher・branchが削除されていない
