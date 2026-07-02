親計画: ../program.md ／ 分類: loop ／ 種別: 統合整理 ／ 規模: ライト

# 05 ai-jobs休眠の後始末

## 方針

1. `ready/` の `exec-audit-20260702.md` を手動処理し、exec-audit loop の出力先をデイリー（ボード区画）へ変更する（決定ログ#2-⑥）。
2. doc追従: `hooks/session-daily-log/README.md`「状態: 未登録」等のstale記述を実測（launchctl / settings.json / 当日デイリー）に合わせて修正。旧オーケ計画のCard1を吸収。
3. 活性化条件は運用契約§1に記載済み。dispatcher実装と `feat/ai-jobs-*` branchは温存（削除しない）。

## 完了条件（レビュー項目）

- [ ] `ready/` が空で、デイリー/ボードの件数表示と実フォルダが一致
- [ ] 「未登録」等のstale記述が実測と一致（launchctl list / settings.json 確認）
- [ ] dispatcher・branchが削除されていない
