# Cloudflare

Cloudflareは1つのprovider文書として扱う。WorkersとR2は別の資源だが、どちらもWranglerを共通CLI入口にできる。正本は[Cloudflare Dashboard](https://dash.cloudflare.com/)と対象repoのWrangler設定であり、この文書は値を持たない案内である。

## 共通の安全な確認

1. 対象repoの`wrangler.toml`、`wrangler.json`、`wrangler.jsonc`の**存在と追跡状態だけ**を確認する。
2. `wrangler --version`、またはrepo内に既に導入済みの場合だけ`npx --no-install wrangler --version`でCLI経路を確認する。暗黙の`npx`インストールは行わない。
3. 認証の確認が必要な時だけ、既に導入済みの同じ経路で`wrangler whoami`をローカル端末で実行する。出力には個人情報やアカウント情報が含まれ得るため、終了状態だけを確認し、貼り付け・保存・commitをしない。

## Workers

- 正本: DashboardのWorkers画面と対象repoのWrangler設定・コード
- 確認: configの存在、CLIバージョン、必要時だけDashboardでデプロイ状態を目視
- 変更: `deploy`、secret更新、route変更は外部副作用を伴う。対象repoの実行契約とreadbackが揃った時だけ行う。

## R2

- 正本: DashboardのR2画面と、Worker bindingを使う場合は対象repoのWrangler設定
- 確認: configの存在、CLIバージョン、必要時だけDashboardでbucketを確認
- Wrangler: `npx wrangler r2 ...`でbucketやobjectを扱える。`npx wrangler r2 bucket list`のような一覧出力は記録しない。
- S3互換アクセス: AWS CLIやS3互換ツールの直接R2アクセスは、WranglerのOAuth/API tokenとは別種のR2アクセスキーを必要とする場合がある。両者を置換可能とみなさず、キーを相互に流用・転記しない。

Wranglerの認証確認は[公式一般コマンド](https://developers.cloudflare.com/workers/wrangler/commands/general/)、R2のWrangler操作は[R2 CLI公式ガイド](https://developers.cloudflare.com/r2/get-started/cli/)、S3互換APIの認証は[R2 API token公式ガイド](https://developers.cloudflare.com/r2/api/tokens/)を参照する。

Workers deploy・route/secret変更、R2 bucket/object操作の前には、対象accountとresource、環境、権限、readback、rollbackを対象repoの実行契約で確定する。
