親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル

# 02 Focusmap「今日」UI統合

## 目的

既存 `/dashboard/workspace/sessions` を作り直さず、デイリーの目標・稼働セッション・サブ稼働・待ち・終わったことを見る「今日」画面としてAI運用ハブへ接続する。

## 現状

- Focusmap mainにはsessions routeとTurso読取層が存在する。
- 実行計画は `projects/active/focusmap/plans/active/2026-07-11-セッション時間ダッシュボード/program.md`。
- 同programの子計画には実装済み内容と未完了チェック、子05のmap未掲載など状態ドリフトがあるため、先に実装実体と計画を一致させる必要がある。
- session-boardはMD正本、Turso mirror。Tursoの現在値欠測により幽霊runが出る可能性は子05で扱う。

## 方針

1. 既存Focusmap programをrepo-local実行計画の正本として維持し、本子計画に画面仕様をコピーしない。
2. `/dashboard/workspace/sessions` は互換routeとして維持する。
3. AI運用ナビ上では「今日」と表示し、次を読む。
   - 今日の目標ツリー。
   - 稼働中session / sub数 / 状態。
   - メイン実行 / サブ実行 / 待ちの集計。
   - 終わったことと自動finishの根拠。
4. mirrorの鮮度を表示する。最終同期が閾値超過、writer不明、snapshot欠損なら `stale` / `unknown` とし、正常表示にしない。
5. 初期はread-only。既存 `addGoal` / ＋ボタンはfeature flagで隠し、子09の成功ack・再試行契約がPASSするまでAPIも書き込みを拒否する。
6. 「自動処理」一覧は子03へ分離し、今日画面に全unitカードを詰め込まない。

## 実行前ゲート

- 既存Focusmap programの実装済みcommit / 未実装項目 / 未追跡計画を正す。
- 子09のTurso parityとgoal-add成功ack方針を確定する。
- Focusmap repoのmain worktreeと作業branchを確認し、stale `temp-cleanup-branch`へ実装しない。

## 完了条件（レビュー項目）

- [ ] Focusmap既存programの子mapと実装状態が一致し、本子計画と仕様二重管理になっていない。
- [ ] AI運用ナビから「今日」へ到達し、既存 `/dashboard/workspace/sessions` の互換が保たれる。
- [ ] 目標・session・sub・待ち・完了の値が保存SQL / Turso実データと一致する。
- [ ] mirror欠測・最終同期超過・接続不能を `stale` / `unknown` と表示し、稼働中や成功に偽装しない。
- [ ] read-only状態でMD、launchd、runtime設定を直接変更するコードがない。
- [ ] 子09完了前は `addGoal` / ＋ボタンが非表示で、直接APIを呼んでも書き込みが拒否される。
- [ ] モバイル / PC双方で「目的→現在→完了」の順に読め、既存Focusmap画面へ回帰がない。
