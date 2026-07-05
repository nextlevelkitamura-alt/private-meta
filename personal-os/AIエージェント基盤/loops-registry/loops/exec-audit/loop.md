---
稼働状態: 停止（2026-07-04 全停止・bootout済み。経緯と再開手順は ../../実行一覧/personal-os.md）
起動: launchd `com.kitamura.exec-audit`（専用plist・月/木 10:00 JST・StartCalendarInterval）
---

# exec-audit（自動実行の構造ドリフト検出 loop）

launchd 自動実行の「あるべき姿（正本＝repo内plist）」と「実態（`launchctl`／`~/Library/LaunchAgents`）」の
**構造的なズレ（ドリフト）**を、定期的に決定的スクリプトで検出する。exec-audit自身は検出と記録（レポート＋
依頼インボックスへの1行）までで、判断・修正はしない＝**検出＝②script**（`../../references/loop-types.md`）。
既定出力先の `inbox` では、書いた行を `inbox-patrol`（②script）＋`inbox-triage` Skill（headless AI）が拾って
plan.md を起案し、実行の要否は最終的に人（計画レビュー）が判断する。旧経路 `readycard` は
**対応＝①Orca**（人がカードを見て直接判断・修正）のまま温存する。

## 目的

「登録したが動いてない／もう使ってないのに残ってる／二重に走ってる」を早期に可視化し、
正本と実態のズレを溜めない。対象は `com.kitamura.*`（personal-os）と `com.nextlevel.*`／`com.work.*`（nextlevel）。

## 起動条件（shouldRun）

- 月・木 10:00 JST（launchd `StartCalendarInterval`）。純粋な3日周期にしたい場合は plist を
  `StartInterval` 259200 に差し替える（1箇所）。
- 何度実行しても冪等（後述）。

## 各回の実行（command）

```
scripts/audit.sh
```

`runner: script`（決定的・非AI・読み取りのみ）。検出する構造ドリフト:

1. **壊れplist**（`plutil -lint` 失敗）
2. **正本plist無し(orphan)**（`~/Library` にあるが repo に生成元 plist が無い）
3. **二重稼働候補**（dispatcher 統合済みの子が単独ロード＋dispatcher も稼働）

参考（アラートしない・多くは意図的）: 未ロード／未インストール。

## 出力・通知

出力先は `EXEC_AUDIT_OUTPUT`（既定 `inbox`）で切り替える。

- **ドリフト無し** → 静かに終了（通知なし）。当日レポートだけ `output/logs/audit-<日付>.md` に残す。
- **ドリフト有り** →
  1. **`inbox`（既定）**: 当日デイリー（JST当日・`daily-digest/scripts/_paths.sh` の `daily_file_for`）の
     `## 依頼インボックス` 節へ、1ドリフト種別（壊れplist／正本plist無し(orphan)／二重稼働候補）=1行で追記する。
     行書式: `- [exec-audit <日付>] <種別> <件数>件（詳細: <レポート絶対パス>）`。
     `inbox-patrol`（`../inbox-patrol/loop.md`）が拾える未処理行の書式（マーカー流儀は
     `../renderer/templates/デイリー.md` が正本）に準拠し、巡回後は `inbox-triage` Skill が
     plan.md を起案してボードに載る（人間ゲートは維持。exec-auditは行を書くだけで判断はしない）。
     当日デイリーが無い／`## 依頼インボックス` 節が無い場合は**勝手にファイルや節を作らず**、警告して非0で終了する。
  2. **`readycard`（温存・旧経路）**: `EXEC_AUDIT_OUTPUT=readycard` のとき、`ai-jobs/ready/exec-audit-<日付>.md`
     に **担当:orca** のカードを投下する（＝①Orcaレーンで人が判断。モードA活性化まで通常は使わない）。
  3. `NTFY_TOPIC` が env にあれば ntfy 通知（iPhone）。無ければスキップ。出力先ごとに通知文言を変える。

## 冪等性

- **`inbox`（既定）**: 依頼インボックス節内の各行からマーカー（`→処理中(`／`→計画作成済み(`／`→重複(`）を
  剥がした上で、これから書こうとする行と完全一致するものが既にあれば追記しない（同一日の再実行・巡回中/起案済みいずれでもスキップ）。
  行一致判定は `LC_ALL=C` を明示する（`inbox-patrol` と同じ理由。macOS標準awkがUTF-8ロケール下で日本語
  文字列同士の `==` を誤って真と判定する実測バグを避けるため）。`auto:*` マーカー区画・依頼インボックス節以外の
  行には一切触れない（単一writer原則）。
- **`readycard`（温存）**: 未処理の `exec-audit-*.md` が `ready/running/review/reviewing` にある間は
  **新規カードを投下しない**（積み上げ防止）。
- いずれの出力先でも、レポートは当日分を上書き。launchd/実態を**変更しない**（読み取り専用・検出のみ）。

## 完了・停止条件

- 完了（1回）: 実態を集めて判定し、ドリフト有りなら出力先スイッチに従って1回だけ出力する
  （`inbox`: 節へ未追記の種別だけ追記／`readycard`: カード1枚投下）。
- 停止: frontmatter `稼働状態` を `停止` にし、`launchctl bootout gui/$(id -u)/com.kitamura.exec-audit`。

## 設定・環境変数

secret は使わない。

| 変数 | 既定値 | 用途 |
|---|---|---|
| `EXEC_AUDIT_OUTPUT` | `inbox` | 出力先スイッチ。`inbox`＝当日デイリーの依頼インボックス節へ追記／`readycard`＝`ai-jobs/ready` へカード投下（旧経路・温存） |
| `NTFY_TOPIC` / `NTFY_BASE_URL` | 未設定（既定`https://ntfy.sh`） | ドリフト検出時のntfy通知（任意） |
| `GOAL_BASE` | `daily-digest/scripts/_paths.sh` 既定 | `inbox`出力時の当日デイリー探索起点。テスト時はfixtureの`$HOME`経由で上書きする |

## 関連

- 実行方式の定義: `../../references/loop-types.md`（②script／①Orca）。
- 依頼インボックス巡回loop（既定`inbox`出力の受け手）: `../inbox-patrol/loop.md`。
- トリアージ手順の正本（依頼インボックスの1行→plan.md起案）: `../../../skills/inbox-triage/SKILL.md`。
- インボックス見出し・マーカー流儀の正本: `../renderer/templates/デイリー.md`。
- 実行レーン契約（`readycard`温存時のカード＝`担当:` / フォルダ位置＝状態）: `../../ai-jobs/AGENTS.md`。
- 可視化インデックス: `../../実行一覧/`（personal-os.md / nextlevel-career.md）。
- nextlevel 実態確認: `仕事/scripts/launchd/status.sh`。
