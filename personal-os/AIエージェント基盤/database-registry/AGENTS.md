# database-registry

Focusmapに関係する接続サービスを安全に案内する入口。ここは値の保管庫ではなく、各サービスの正本、確認方法、CLI/公式コンソール、repo内設定の探し方を結ぶ案内だけを所有する。

## 置くもの

- `接続案内.md`: 共通の安全規約とproviderへの入口
- `providers/`: Supabase、Turso、Cloudflare、Cloud Runの値を持たない案内
- `local/`: このMacだけで必要になった補助設定の隔離場所

## 置かないもの

- secret、token、credential、環境変数値、接続URL、実プロジェクト名・数・現在状態
- `.env`、認証ファイル、CLIのcredential、設定のコピー、実行結果の貼り付け

## 利用手順

1. `接続案内.md`で、対象providerと作業種別を決める。
2. `providers/<provider>.md`の「安全な確認」だけを先に行う。
3. 変更が必要なら、対象repoの最寄り`AGENTS.md`とサービスの公式コンソールを正本として扱う。
4. マシンだけの補助設定が必要な時だけ`local/`に置く。値を共有・commit・コピーしない。

資源を作成・変更する前には、対象provider、対象環境、操作権限、readback方法、rollback方法を対象repoの実行契約で決める。この案内だけを根拠に操作しない。

Cloudflareは単一providerとして扱い、WorkersとR2を`providers/cloudflare.md`の別節で区別する。Workers/R2のCLIはどちらもWranglerを入口とし、R2のS3互換アクセスはWranglerの認証とは別種のアクセスキーを必要とする場合がある。
