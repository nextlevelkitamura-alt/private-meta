# Provider案内

各文書はproviderごとの安全な入口を示す。サービスの実プロジェクト、認証値、接続URL、実行結果をここへ書かない。

## 共通ルール

- 先に対象repoの`AGENTS.md`を読む。provider文書はrepoの正本を置き換えない。
- 非破壊のCLI確認は、バージョン・help・認証有無の確認に留める。資源一覧や認証結果を記録しない。
- 変更は公式コンソールまたは対象repoで定義されたCLI経路から行い、サービス側でreadbackする。
- 認証や補助設定の実体は`../local/`または対象repoのgitignore領域だけに置く。

## 文書

- `supabase.md`
- `turso.md`
- `cloudflare.md`（WorkersとR2を同一providerとして扱う）
- `cloud-run.md`
