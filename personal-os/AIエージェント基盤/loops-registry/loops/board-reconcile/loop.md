---
稼働状態: 稼働中（2026-07-08 新設・ロード済み。5分毎 StartInterval・kickstart実測 exit0。停止手順は末尾）
設計: ../../../../my-brain/areas/ai運用/plans/active/2026-07-08-計画実行フロー統一/plans/01-session-board責務再設計.md
---

# board-reconcile — session-board 生存照合の保険loop

## 目的

session-board の reconcile（🟢/🔵を実体トランスクリプトで照合し、沈黙を⏸へ降格）は
Stop / SessionStart 相乗りで発火する。**全セッションを閉じて放置している間は発火せず**、
Notion・スマホ側で古い🟢が残って見える。このloopはその隙間を5分毎の機械実行で埋める保険。

## 起動条件

- launchd `com.kitamura.board-reconcile`・`StartInterval 300`（5分毎）。
- 1分毎は過剰: 閾値が🟢=10分／🔵=30分なので、5分間隔で表示の遅れは最悪〜15分に収まる。
- `RunAtLoad` は付けない（起動直後の連打回避・既存draft plistと同方針）。

## 各回の実行

- `scripts/reconcile.sh` → `hooks-registry/hooks/session-board/board.py reconcile` を1回。
- board.py 自身が flock を持つためロック不要。当日ボードが無ければ何もしない（空ファイルを作らない）。
- 対象は当日ボードのみ（日付跨ぎの前日掃除は既知の制約・session-board README 参照）。

## 完了・停止条件

- 常駐（当日ボードの掃除が目的のため完了なし）。session-board 機構を廃止する時に一緒に bootout。

## ログ先

- `output/logs/board-reconcile.{out,err}.log`

## 有効化（人間ゲート・symlink方式＝lanes-sync と同型）

```sh
ln -s '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/board-reconcile/com.kitamura.board-reconcile.plist' \
  ~/Library/LaunchAgents/com.kitamura.board-reconcile.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.board-reconcile.plist
launchctl enable gui/$(id -u)/com.kitamura.board-reconcile
```

停止: `launchctl bootout gui/$(id -u)/com.kitamura.board-reconcile`
有効化・停止したら `../../実行一覧/personal-os.md` を同じ作業で更新する。
