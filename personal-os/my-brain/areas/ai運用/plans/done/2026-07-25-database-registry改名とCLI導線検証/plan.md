分類: repo ／ 種別: 既存改善
テンプレ: v2
規模: ライト
形態判定: 単発 ／ 理由: 同一レジストリの改名と非破壊な導線検証を、1つのGit rollback単位で扱う
並列: 不可

# database-registry改名とCLI導線検証

## 目的

既存の`DBレジストリ/`を既存registry群と同じ英小文字・ハイフンの`database-registry/`へ改名し、Supabase、Turso、Cloudflare（Workers/R2）、Cloud Runの公式入口と非破壊CLI導線を、値を記録せず検証可能な形に整える。

## 非対象

- 基盤入口`AGENTS.md`・`GLOBAL_AGENTS.md`・親ディレクトリ一覧の変更
- 新規project、database、bucket、migration、deployment、削除、token生成、認証情報の変更
- token、接続URL、アカウント名、project名、CLI生出力の記録

## 現状

既存の案内は専用ブランチに`DBレジストリ/`として存在するが、現在の作業ブランチには未導入である。親の基盤入口一覧の更新は別タスクの所有範囲である。

## 実行契約

- 対象repo: `/Users/kitamuranaohiro/Private`（作業worktree: `/Users/kitamuranaohiro/.codex/worktrees/878a/Private`）
- 実行形: direct
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/AGENTS.md`
  2. この計画
  3. `personal-os/AIエージェント基盤/database-registry/AGENTS.md`（改名後）
- 依存成果: `codex/db-registry-connection-guidance`の既存案内コミット
- 変更可能範囲: `personal-os/AIエージェント基盤/database-registry/`、`personal-os/my-brain/areas/ai運用/plans/done/2026-07-25-DBレジストリ整備/`、`personal-os/my-brain/areas/ai運用/plans/done/2026-07-25-database-registry改名とCLI導線検証/`
- 変更禁止範囲: `personal-os/AIエージェント基盤/AGENTS.md`、`personal-os/AIエージェント基盤/GLOBAL_AGENTS.md`、認証情報・ローカル設定実体・各providerの資源
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: レジストリはCLI・公式コンソール・安全手順の案内のみを所有し、サービス状態・認証値・対象repoの設定を正本化しない
- 検証: `git mv`後の追跡パス、Markdown相対リンクと外部URL、全`CLAUDE.md` symlink、`local/.gitignore`、CLIの存在・help・出力を保存しない認証確認を検査する
- 停止・エスカレーション条件: secretらしき値の検出、既存の未コミット変更、CLI確認が資源変更を要求する場合
- 完了時に返す情報: 改名後構成、CLI導線の検証結果、できること／未対応、commit/push、親AGENTS一覧の追記要否

## 方針

既存案内を履歴付きで取り込み、`git mv`で`database-registry/`へ改名する。CLI検証はversion/helpと、資源一覧を表示・記録しない範囲の認証有無確認だけに限定する。Cloudflare CLIが未導入なら導入はせず、未対応として記録する。親の一覧更新は実施せず、最終報告で別タスクへの依頼事項として明示する。

## 工程

- [x] 01 実装: 既存案内を取り込み、`database-registry/`へ改名してCLI安全導線を補強する  評価: まとめ
- [x] 02 レビュー: 構成、リンク、symlink、gitignore、CLI検証結果と禁止操作を採点する  評価: まとめ

## 完了条件

- [x] `database-registry/`へ履歴を保って改名され、配下の`AGENTS.md`・`CLAUDE.md`・`local/.gitignore`・provider文書が一貫して新名称を示す。
- [x] Supabase、Turso、Cloudflare（Workers/R2）、Cloud Runの各文書から、CLIと公式コンソールの入口、非破壊確認、変更前に決める対象・環境・権限・readback/rollbackが辿れる。
- [x] 全providerのCLIについて、インストール有無とhelpを確認し、可能な認証確認は出力を保存せずに実施する。資源作成・変更・削除は0件である。
- [x] 相対リンク、外部公式URL、`CLAUDE.md` symlink、`local/.gitignore`、関連パスだけのcommit/pushを検証し、親`AGENTS.md`の一覧追記が未実施であることを記録する。

## 実装結果

- `DBレジストリ/`の既存案内を取り込み、`database-registry/`へ改名した。親`AGENTS.md`は最終差分0で、一覧更新は実施していない。
- Supabase、Turso、gcloudはhelpと出力非保存の認証プローブが成功した。Wranglerは未導入のため、導入・認証確認を行わず未対応とした。
- provider文書の公式URL到達、`CLAUDE.md -> AGENTS.md`、`local/.gitignore`、旧名参照0件、機密値形式0件、`git diff --check`を確認した。

## 終了記録

archive時に必須。実行中は記入しない。
