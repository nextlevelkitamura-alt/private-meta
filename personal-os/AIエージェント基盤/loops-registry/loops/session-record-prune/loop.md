---
稼働状態: draft・未ロード（2026-07-09 新設）。有効化は人間ゲート。**初回は dry-run をログ確認してから**本番化する。
設計: ../../../../my-brain/areas/ai運用/plans/planning/2026-07-08-セッション記録の定期削除loop/plan.md
---

# session-record-prune — 古いセッション記録の定期削除loop

## 目的

Claude / Codex のセッション記録（`.jsonl`）は放置で膨張し続ける（実測: `~/.codex/sessions` 4.0G）。
内蔵ディスク逼迫（95%使用）と、それに伴う「外付けSSDへ退避したい」誘惑（session-board の生存判定を
壊す経路）を根から断つため、**保持日数を超えた記録を ~/.Trash へ移す**。

## 方式（2026-07-08 裁定）

- 保持日数 **30日**（board 生存判定は直近30分しか見ないため十分安全）。
- 削除でなく **~/.Trash へ移動**（復旧余地を残す・OSが後で空にする）。
- 対象は `~/.codex/sessions`・`~/.claude/projects` 配下の `*.jsonl` のみ。**その2ディレクトリ以外は触らない**
  （`prune.py` が realpath で配下判定し、外付けへ退避された実体＝realpath が外に出るものは対象外）。
- 記録の中身は読まない（stat と move のみ）。ログは件数・容量・ディレクトリのみ。

## 各回の実行

- launchd `com.kitamura.session-record-prune`・`StartInterval 86400`（日次）。
- `scripts/prune.sh` → `scripts/prune.py --apply` を1回。`RunAtLoad` なし。

## 安全運用

- **既定は dry-run**（`python3 scripts/prune.py` は何も動かさない・件数と容量だけ報告）。
  launchd 入口だけが `--apply` を付ける。
- 有効化する前に必ず手動 dry-run のログを人間が確認する。
- テストは `tests/test_prune.py`（Python・env で対象/ゴミ箱/保持日数を差し替え・実運用に非接触）。

## ログ先

- `output/logs/session-record-prune.{out,err}.log`

## 有効化（人間ゲート・symlink方式＝board-reconcile と同型）

```sh
# まず必ず dry-run で確認
cd '/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/loops-registry/loops/session-record-prune'
python3 scripts/prune.py
# 問題なければ有効化
ln -s "$PWD/com.kitamura.session-record-prune.plist" ~/Library/LaunchAgents/com.kitamura.session-record-prune.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kitamura.session-record-prune.plist
launchctl enable gui/$(id -u)/com.kitamura.session-record-prune
```

停止: `launchctl bootout gui/$(id -u)/com.kitamura.session-record-prune`
有効化・停止したら `../../実行一覧/personal-os.md` を同じ作業で更新する。
