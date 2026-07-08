分類: loop
種別: 既存改善
規模: ライト

## 目的

sonnet棚卸しエージェントのlaunchctl実測で検出された3件の構造監査所見（launchd実態とloop文書のズレ）を解消し、文書と実機の整合を取る。

## 現状

インボックス原文（出所: 2026-07-03デイリー `/Users/kitamuranaohiro/Private/personal-os/my-brain/ゴール/デイリー/2026/07/2026-07-03.md`、起票: 再編実装レーン 18時台・sonnet棚卸しエージェントのlaunchctl実測）:

1. watch-keeperとinbox-patrolはplistがsymlink登録済み・文書上「稼働中」だが `launchctl list` 実測に不在=未ロード疑い（keeper死=見張り再起動網の空白。確認コマンド=`launchctl print gui/$UID/com.kitamura.watch-keeper` 同inbox-patrol・bootstrapは人間ゲート）
2. exec-auditの実機plistだけsymlinkでなく別実体（Jul1更新）でrepo正本（Jul2更新）とズレ疑い
3. renderer/daily-digestのloop.md冒頭状態表記が実態より古い（doc追従のみ）

## 方針

- 所見1（watch-keeper/inbox-patrol未ロード）: まず `launchctl print gui/$UID/...` で実態を確認。未ロードが確認されたら `launchctl bootstrap` で再登録する。bootstrapはlaunchd登録=人間ゲート事項のため、人間に確認してから実行する。
- 所見2（exec-audit plist乖離）: 実機plist（Jul1）とrepo正本plist（Jul2）をdiffし、差分内容を確認。repo正本が正しければ実機plistをsymlinkに張り替える（または内容をrepo正本に揃える）。
- 所見3（renderer/daily-digest loop.md状態表記）: 各loop.mdの冒頭状態表記を実態に合わせて更新する（doc追従のみ・コード変更なし）。

## 完了条件（レビュー項目）

1. watch-keeper/inbox-patrolが `launchctl list` に表示される（または人間判断で意図的に未ロードのままとする場合はloop.md状態表記を「停止」に更新済み）
2. exec-auditの実機plistがrepo正本とバイト一致する（symlinkまたは内容同期）
3. renderer/daily-digestのloop.md冒頭状態表記が実機のlaunchd登録状態・実行実態と一致する
