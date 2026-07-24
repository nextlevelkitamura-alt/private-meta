# Turso

## 正本

- データベース・権限・使用状況: [Turso Dashboard](https://turso.tech/app)
- 接続を使うアプリの設定名と実装: 対象repoの最寄り`AGENTS.md`とgit追跡済みコード
- 接続値・認証値: 対象repoまたは`../local/`のgitignore済み領域。ここには転記しない。

## 安全な確認

1. 対象repoでTursoに関係する設定ファイルの**ファイル名とキー種別だけ**を確認する。
2. `turso --help`でCLIが利用可能かを確認する。
3. ログインが必要な時だけ`turso auth login`を対話的に実行する。出力、認証先、資源一覧を記録しない。
4. 実データベースの確認はDashboardで行う。変更系の`create`、`destroy`、token生成はこの案内から実行しない。

Turso CLIの認証とdatabase操作の入口は、[Turso CLI公式ドキュメント](https://docs.turso.tech/cli/introduction)を参照する。
