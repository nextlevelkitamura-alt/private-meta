親計画: ../program.md ／ 分類: 横断 ／ 種別: 統合整理
並列: 不可 ／ レビュー: 都度

# 統合検証とruntime確認

## 目的

01・02の後に、登録、symlink、実行経路、文書参照が一貫していることを証拠付きで確認する。

## 現状

Codexはhooks内容・パスが変わるたびにtrust確認が必要。これはAIがconfigを書き換えて代行してはいけない人間ゲートである。

## 方針

1. JSON、Python構文、symlink実体、現行登録を秘密値なしで検査する。
2. session-boardのシムE2E、ボードE2E、個別Pythonテストを実行する。
3. researchを除いた現行ソースに旧構造・廃止同期器・README案内がないことを検査する。稼働中の
   `GLOBAL_AGENTS.md`、loop、Skillに残る旧 `hooks/session-board/` 参照は、現行の
   `shared/session-board/` とevents設計へ最小限で更新する。
4. 人間がCodex `/hooks` を再trustし、開始/Stopを実機確認するまで、完了扱いにしない。

## 完了条件（レビュー項目）

- [ ] `test-shims.sh`、`test-session-board.sh`、各 `test_*.py` が全PASSする。
- [ ] Claude/Codexのagent-hooks窓とCodex hooks.json窓が正しいrepo実体を指す。
- [ ] Claude設定とCodex hooks.jsonがJSONとして有効で、5イベントが期待する共通本体を指す。
- [ ] `GLOBAL_AGENTS.md` と稼働中のloop・Skillが、現行のsession-board正本とイベント構造を指す。
- [ ] Codex `/hooks` 再trustと実機結果が人間から報告されるまで、親計画を完了にしない。
