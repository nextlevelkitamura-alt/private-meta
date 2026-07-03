分類: skill
種別: 既存改善
規模: ライト

## 目的

skill-creator-custom の SKILL.md に記述された手順・分岐と実運用のズレを洗い出し（調査フェーズ=済み）、SKILL.md・workflows・logsテンプレを実運用に追随させる改善を実行する。段階runtime露出の追跡漏れという現存リスクを塞ぐのが第一。

## 現状

- インボックス原文: 「skill-creator-custom の監査（SKILL.mdの手順・分岐と実運用のズレ洗い出し→改善計画化。今日のTODO=A預かり分の実行）（起票: 全体管理者A 14時台・kickoff手順経由=子05実走1件目）」
- 出所: /Users/kitamuranaohiro/Private/personal-os/my-brain/ゴール/デイリー/2026/07/2026-07-03.md
- 調査フェーズ完了（2026-07-03・中間指揮官1・読み取り専用）: 所見の全文は同フォルダ `所見.md` に原文保全（チャット流しで終わらせない・2026-07-03ユーザー指示）。
- 健全性の確認済み: skills/19本 = catalog（meta 17 + applied 2）完全整合・削除2本の除去済み。
- 現存リスク: kickoff / morning-routine が「~/.claudeのみ露出・残り4runtimeは後日」の中途状態だが、後追い露出のバックログ機構が無い（所見 §2-1）。

## 方針（所見 §4 の優先順位に基づく改善アクション）

1. 段階runtime露出の手順化＋未完了バックログ（最優先・所見§2-1）: create-new.md / migrate-skill.md に「一部露出→残りをバックログ化→再チェック導線」を追加し、createdログの露出行を機械的に拾える書式へ統一（未完了露出の一覧が grep で出せる形）。
2. 削除ログの書式・テンプレ追随（所見§1-2/§1-3）: logs/AGENTS.md §6 テンプレへ実践フィールド（承認・吸収先）を反映し、日付時刻 HH:mm 必須を `date` コマンドごとテンプレに埋める。既存削除2件は書き換えない（履歴改変を避け、以後の運用で遵守）。
3. skill-creator-codex との双方向境界（所見§3-2）: custom §2 に「Codex対象→skill-creator-codexへ」の分岐1行・codex 側に「ライフサイクル判断はcustomが窓口」の1行。
4. 軽微の同梱（所見§2-2/§2-3/§2-4/§3-3）: global-scan.md へ三点照合（skills実体×catalog×deletedログ）ステップ追記／create-new から plan-ops scaffold へのポインタ1行／表形式→リスト化／改名入口の見出し分離。
5. 適用後: catalog meta.md の skill-creator-custom 概要行を更新し、変更記録を残す。

## 完了条件（レビュー項目）

1. create-new.md / migrate-skill.md に段階露出の手順と未完了露出の追跡方法が記載され、kickoff / morning-routine の残り露出（~/.agents・~/.codex・~/.gemini系）がバックログとして列挙されている。
2. logs/AGENTS.md §6 の削除テンプレが実ログのフィールド（承認・吸収先）を含み、日付時刻に HH:mm を強制する記載になっている。既存ログの書き換えが無い。
3. skill-creator-custom と skill-creator-codex の SKILL.md が相互ポインタを持つ。
4. global-scan.md に三点照合ステップが1項ある。
5. 変更対象が skill-creator-custom／skill-creator-codex／logs/AGENTS.md／catalog に閉じている（doc only・スクリプト変更なし）。
