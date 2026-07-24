分類: repo ／ 種別: 新規作成
テンプレ: v2
規模: ライト
形態判定: 単発 ／ 理由: 基盤内の案内文書・無視設定を1つのrollback単位で整える
並列: 不可

# database-registry整備

## 目的

Focusmapに関係する接続サービスについて、secretや実プロジェクト情報を保存せず、正本・安全な確認・CLIと公式コンソール・マシンローカル設定の置き場を基盤の一箇所から辿れるようにする。

## 非対象

- 既存の認証情報、環境変数、CLI設定、クラウド資源の移動・削除・変更
- サービスの実プロジェクト数・接続URL・token・環境変数値の記録
- CloudflareのWorkersとR2を別providerとして登録すること

## 現状

基盤には接続運用を横断して案内するレジストリがない。既存の基盤入口には新規フォルダを列挙する規約があり、ローカル専用の設定領域はgitignoreで隔離する必要がある。

## 実行契約

- 対象repo: `/Users/kitamuranaohiro/Private`（AIエージェント基盤）
- 実行形: direct
- 最初に読む順番:
  1. `personal-os/AIエージェント基盤/AGENTS.md`
  2. この計画
  3. `personal-os/AIエージェント基盤/database-registry/AGENTS.md`（作成後）
- 依存成果: なし
- 変更可能範囲: `personal-os/AIエージェント基盤/database-registry/`、同階層の`AGENTS.md`、この計画とその`explain/`
- 変更禁止範囲: 既存の`.env`、認証情報、各サービスの実プロジェクト設定、基盤外のrepo
- ファイル担当マップ: 不要
- worktree方針: 不要
- 維持する契約: 正本はサービス側と各repoの設定に残し、レジストリは値を持たない案内だけを所有する
- 検証: Markdown見出し・symlink・gitignore・secret検査を実行し、関連パスだけをcommit/pushする
- 停止・エスカレーション条件: 新規分類が既存の正本と競合する時、またはsecretらしき値を検出した時
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

`database-registry/` を基盤の案内入口とし、provider別の文書を置く。Cloudflareは単一文書内でWorkersとR2を分け、Wranglerで両方を扱うことと、S3互換のR2直接アクセスには別種のキーが必要になり得ることを明記する。ローカル設定の実体は`local/`にだけ置けるようにして追跡しない。

## 工程

- [x] 01 実装: database-registryの案内、provider文書、ローカル隔離領域、入口一覧を整える  評価: まとめ
- [x] 02 レビュー: 構造・安全制約・リンクと追跡範囲を評価する  評価: まとめ

## 完了条件

- [x] `database-registry/`の入口・provider別文書・local領域に、役割と正本の境界が記載され、すべての新規フォルダに`AGENTS.md`と`CLAUDE.md` symlinkがある。
- [x] Supabase、Turso、Cloudflare（Workers/R2）、Cloud Runの各案内が、値を保存せずに安全確認・CLI・公式コンソール・repo内設定の確認順を示す。
- [x] `local/`の任意の設定実体はgit追跡されず、sampleにもsecret・接続URL・実プロジェクト情報がない。
- [x] 基盤入口のフォルダ一覧、計画、派生HTML、評価の内容が一致し、対象パスだけをcommit/pushできる。

## 実装結果

- database-registry、provider別案内、ローカル隔離領域、基盤入口一覧、派生HTMLを追加した。
- 値を読まずに設定ファイル名とキー種別だけを確認し、Supabase、Turso、Cloudflare R2、Cloud Runの関係する設定の存在を確認した。
- `評価01.md`で4つの完了条件を全PASSとした。

## 終了記録

archive時に必須。実行中は記入しない。
