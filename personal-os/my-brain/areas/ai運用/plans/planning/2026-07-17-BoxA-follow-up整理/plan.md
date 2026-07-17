分類: skill ／ 種別: 統合整理
規模: ライト
形態判定: 単発 ／ 理由: registry・skill窓の小規模な整合作業4件で1commitずつ戻せる
並列: 不可 ／ レビュー: 都度

# BoxA follow-up整理

## 目的

archive済み「2026-07-07-グローバルskill整理BoxA」の未了follow-up4件を独立に完了させ、skill配置とregistryの整合を閉じる。

## 非対象

- Box A本体の再実施（完了済み・archiveの終了記録参照）
- 新しいskillの作成・削除判断

## 現状

Box A本体（移設・統合・削除・撤去）は2026-07-08完了。2026-07-17の棚卸しで本体をarchive（merged）にし、残っていたfollow-upを本計画へ切り出した。

1. deletedログの補記（global-skill-registry/logs）
2. calendar-linksの所属確認（globalかrepo-localか）
3. task-routerの参照更新（BoxA移設後の旧path参照）
4. 起業スキル5窓のdangling symlink処理（削除は人間承認が必要）

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private（private-meta）
- 実行形: direct
- 最初に読む順番:
  1. /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md
  2. この計画
  3. plans/archive/2026-07-07-グローバルskill整理BoxA/plan.md（実行台帳・読み取り専用）
- 依存成果: BoxA本体の実行台帳（archive）
- 変更可能範囲: global-skill-registry/logs・task-router skill本文・runtime窓のsymlink（dangling分のみ）
- 変更禁止範囲: skill本体の移動・削除（dangling窓の削除は人間承認後のみ）
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 正本はAIエージェント基盤側・runtime窓はsymlinkのみ
- 検証: 各項目の対象パスを目視・grepで確認
- 停止・エスカレーション条件: calendar-links所属が判断できない場合は人間確認へ
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

4件を独立に処理する。dangling窓の削除だけは人間承認を先に取る。

## 完了条件（レビュー項目）

- [ ] global-skill-registry/logs にBoxA移設分のdeletedログが補記されている
- [ ] calendar-linksの所属（global / repo-local）が決まり、所属先AGENTS.mdまたはregistryに記録されている
- [ ] task-router本文にBoxA移設前の旧path参照が残っていない（grepで0件）
- [ ] 起業スキル5窓のdangling symlinkが人間承認のうえ削除、または存置理由が記録されている

## 実装結果

実装後にplanctlが追記・更新する。実行前は記入しない。

## 終了記録

archive時に必須。実行中は記入しない。
