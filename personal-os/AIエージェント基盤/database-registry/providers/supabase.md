# Supabase

## 正本

- サービスの状態・権限・SQL実行履歴: [Supabase Dashboard](https://supabase.com/dashboard)
- repo内の宣言的なローカル構成: 対象repoの`supabase/`と最寄り`AGENTS.md`
- 実行時の値: 対象repoのgitignoreされたローカル設定。ここには転記しない。

## 安全な確認

1. 対象repoで`supabase/`とローカル設定ファイルの**存在だけ**を確認する。
2. `supabase --help`または対象repoのpackage runner経由の`supabase --help`でCLI経路を確認する。
3. 認証有無を確認する必要がある時だけ`supabase projects list`をローカル端末で実行し、終了状態だけを確認する。project一覧は表示・記録・commitしない。
4. 実プロジェクトの状態が必要ならDashboardを開き、画面の値・URL・一覧を記録しない。

`supabase init`はローカルの`supabase/`構成を作る操作であり、既存repoでは新規実行しない。既存の構成とmigrationは対象repoの履歴を正本とする。

## 変更時の入口

- ローカル構成・migration: 対象repoの既存コマンドとレビュー手順
- 本番側の変更: Dashboardまたは対象repoで明示された安全なCLI経路
- 値の追加・更新: 対象repoのgitignore済みローカル設定だけ。値をこのレジストリへ移さない。

project作成、link、migration適用、secret更新の前には、対象project、環境、権限、readback、rollbackを対象repoの実行契約で確定する。

公式CLIのプロジェクト内利用と`supabase/`構成の位置付けは、[Supabase CLI公式ガイド](https://supabase.com/docs/guides/local-development/cli/getting-started)を参照する。
