# Cloud Run

## 正本

- サービス状態・権限・revision: [Google Cloud Console](https://console.cloud.google.com/run)
- build/deploy定義: 対象repoの最寄り`AGENTS.md`、git追跡済みのbuild設定とアプリコード
- 実行時の値: 対象repoまたは`../local/`のgitignore済み領域。ここには転記しない。

## 安全な確認

1. 対象repoでCloud Runに関係するbuild/deploy設定の**ファイル名だけ**を確認する。
2. `gcloud --version`でCLIが利用可能かを確認する。
3. ログイン状態の確認が必要な時だけ`gcloud auth list`をローカル端末で実行し、終了状態とactiveな認証の有無だけを確認する。アカウント名、project、service一覧、URLを記録しない。
4. `gcloud run services list`は一覧取得であっても実状態を表示するため、実行結果をチャット・文書・commitへ貼らない。

deploy、traffic切替、環境変数更新は外部副作用を伴う。対象repoの実行契約、対象projectの明示、readback、rollback手段が揃うまで実行しない。

サービス一覧コマンドの仕様は、[gcloud run services list公式リファレンス](https://cloud.google.com/sdk/gcloud/reference/run/services/list)を参照する。
