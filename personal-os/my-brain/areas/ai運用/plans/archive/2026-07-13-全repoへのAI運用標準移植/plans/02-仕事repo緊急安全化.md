親計画: ../program.md ／ 分類: repo ／ 種別: 既存改善 ／ 規模: フル
並列: 可（人間ゲートとread-only監査） ／ レビュー: Review 1へ集約

# 仕事repo緊急安全化

## 目的

credential漏えいと有効な危険hookを先に封じ、既存未コミット変更を巻き込まずに仕事repoの移行作業を開始できる安全基線を作る。

## 現状

1. trackedのCodex設定に平文credentialがあり、Git履歴にも残る。値は出力・計画・HTML・commit messageへ載せない。
2. trust登録済みの仕事repo固有Stop hookが、AI応答の終了時に `git add -A` と自動commitを実行する。これはGlobalのsession-board hookとは別であり、「自動commit一般」ではなく「全差分を無条件stage・commitする経路」が危険である。
3. root移動後に存在しない旧絶対pathを参照するhook・Skill・scriptが複数ある。
4. 調査開始時の未コミット変更が調査中に別セッションで変化したため、実装開始時のsnapshotと対象pathの分離が必要である。
5. 仕事repoのdispatcher等repo-local loopとGlobal loop一覧の接続は現時点で検証PASSのため、loop実装の移植は不要である。
6. 2026-07-13の安全化レビュー中、変更前から読み込まれていた旧Stop hookが2回発火し、commit `f4b78f49`・`fb6f5047` を作成した。安全化対象に加えて別sessionのplanを `git add -A` で巻き込んだが、その後の正当な仕事commitとともに既に `origin/master` の祖先になっているため、reset前提の回復は現在の事実に合わない。
7. 2026-07-13の機械実装では、repo-local trust絶対pathとinline credentialを除去し、Codex/Claudeの業務hook 7本を同一・repo-root動的解決にした。危険なstage/commit経路、runtime有効面の旧root・固定絶対pathはいずれも0件で、Haiの12群テストを受けた独立reviewerが機械PASSと判定した。
8. 安全化差分は、Codex/Claude設定・hook・入口に加え、既存のroot `.mcp.json`、Codespaces setup、Antigravity setup/templateを含む10pathで、未stage・未commitである。tracked HEADには旧inline設定が残り、`.mcp.json` と `.claude/settings.json` は未追跡なので、credential失効・再発行と明示path commitまではGate 0未完了である。
9. Claude Code公式仕様ではproject MCP正本はroot `.mcp.json` であり、`.claude/settings.json` はhooks/settings正本である。旧ignored `.mcp.json` は承認1回で旧credentialを再有効化できたため、credential-freeな3server正本へsanitizeして追跡候補にし、Codespaces/Antigravityの上書き経路も停止した。LINE公式MCPは `CHANNEL_ACCESS_TOKEN`、repo-local line-readerは `LINE_CHANNEL_ACCESS_TOKEN` を要求するため、root `.env` の後者1値をClaude起動時だけ前者へaliasする。
10. 現行line-readerはSupabase service roleを参照しない。Supabaseの現役consumerは `scripts/staff-status/src/check.ts` だけで、非追跡 `scripts/.env.local` を読み、`staff_messages_sent`（同日同種別の送信重複防止）と `staff_entries_seen`（entryの新規判定）の2状態表だけを使う。endpointと既存credentialは現役だが、現在ログイン中のSupabase organizationには対象projectがない。既存Cloudflare D1には同名2表とUNIQUE制約が0行で存在するため、D1統合を推奨する。旧rootを読む一回性 `mcp/sql/migrate-to-d1.ts` は再実行禁止とし、Child 03の台帳・Child 07の所有権整理へ送る。
11. 別sessionのcircus実装は開始時HEAD `ef0ab3d0` 以降の複数commitへ分離され、安全化10pathとの重複は0件である。session-board上のcircus sessionは人間指示でfinish済みであり、安全化側はresetせず新runtime再読込を待つ。
12. 追加監査でLINE本線DBがCloudflare D1、Supabaseが `staff-status` の別系統であると確認したが、これはAI運用移植のGate 0ではなく、仕事repo固有のDB/セキュリティ計画へ送る発見事項である。

## 方針

1. 仕事repo内でAI実装を始める前に、現在のdirty path一覧を値なしで記録し、触るpathと重ならない専用worktree/branchを使う。
2. 人間ゲートで漏えいcredentialを失効・再発行する。LINE tokenはrootの非追跡 `.env` に `LINE_CHANNEL_ACCESS_TOKEN` として1値だけ置き、2026-07-14に値非表示で更新・検証済みである。Claude公式MCP起動時に必要な別名へaliasする。staff-statusはD1統合を推奨し、`scripts/staff-status/src/check.ts` をD1 adapterへ最小変更する。Supabase access回復を選ぶ場合だけ、新Secret key移行を別scopeで扱う。保管統合は後続の所有権整理で扱う。
3. trackedファイルと現HEADをsecret scanし、値を標準出力へ出さず件数・path・判定だけを残す。
4. 履歴rewriteは全cloneへ影響する破壊操作として別の人間判断にする。credential失効を先に行い、履歴を残す/書き換える判断と理由を記録する。
5. まず仕事repo固有Stop hookの `git add -A` とcommit経路だけを停止し、他の業務hookは個別監査まで維持する。Stop時はread-onlyの `git status`、完了シグナル、session-board記録だけを許可する。
6. 禁止対象はStop hookによる無条件stage/commitとする。checkpoint commitが必要な場合は、節目の人間確認後にdiffを確認し、検証済みの `git add -- <明示path>` だけを使う。commit自体を一律禁止せず、対象path・検証結果・巻込みなしを人間ゲートにする。
7. local/global hookの発火回数と順序を実測し、Global session-board hookまで誤って停止しない。
8. 旧絶対pathは現役・履歴・生成物に分類し、現役hookから先に現在rootへ直す。launchd再登録が要る場合は別の人間ゲートにする。
9. 稼働中repo-local loopは、所有権とGlobal台帳参照が正しい限り変更しない。
10. 2件のauto-commitは既にremote履歴の祖先であるため、reset/rewriteを既定手順にしない。先にcredentialを失効・再発行し、履歴保持を推奨案として人間判断を記録する。規制・監査上の削除要件がある場合だけ、全cloneへ影響する履歴rewriteを別計画・別承認で扱う。
11. 変更前から開いていたClaude/Codex sessionを終了し、新sessionでrepo-local 7hookを再読込する。Codexは `/hooks` で再trustを確認し、Global session-boardとの重複発火がないことを実測する。
12. 人間確認後、安全化10pathのdiffだけを確認して `git add -- <明示10path>` でcheckpoint commitする。sanitize済み `.mcp.json` を確認する前にstageしてはならない。pushと履歴方針は別の人間判断とする。
13. commit後はHaiが作成したH0〜H7受入項目をIntegration担当が実行証拠へまとめ、Review 1で独立reviewerへ一括して渡す。HEADのtracked secret 0、fresh worktree build、新sessionの7hook再読込、Global session-board重複0、履歴判断記録を再検証する。
14. Turso/WebhookはGate 0の完了条件から外す。Gate 0完了後、既存のLINE返信計画への合流可否を検索し、無ければ仕事repo rootの計画箱へ独立計画として起票する。

## 実行パッケージ

1. **S01 snapshot**: HEAD、ahead/behind、dirty/staged、明示10path、並行commitとの重複0を値なしで固定する。
2. **S02 staff-state方針ゲート**: LINEは再発行済み。人間が「Supabase access回復」と「既存D1への2表統合」を選ぶ。推奨はD1統合であり、この時点ではSupabase keyを作成・無効化しない。
3. **S03 10path再検証**: secret件数、JSON/TOML parse、hook parity、値なし/fake-env起動、diff-check。実repoのsecret値や外部APIを使わない。
4. **S03b staff-state D1統合**: 人間がscope拡張を承認した場合だけ `scripts/staff-status/src/check.ts` を追加し、既存D1の2表へread-only lookup→dry-run→最小writeの順で移行する。既存ローカルJSON fallbackも単一方針へ直し、UNIQUE競合と自動送信への影響を検証する。
5. **S04 fresh runtime**: 旧sessionを終了し、新Claude/Codexで業務hook各7、Global hook各1、MCP source重複0とD1 staff-state経路を確認する。
6. **S05 明示commit**: 人間確認後に元の10pathと承認済みS03b pathだけをstage/commitし、別session差分0、tracked secret 0、H0〜H7実行証拠をIntegration担当が固定する。正式採点はReview 1。pushは別判断。

## S01〜S05の固定scope manifest

以下の10pathだけをGate 0のtracked差分として扱う。S01で開始snapshotとの一致を再確認し、増減・別差分との重複が1件でもあればS05を止める。値は表示しない。

1. `.codex/config.toml`
2. `.codex/hooks.json`
3. `.claude/settings.json`
4. `.gitignore`
5. `AGENTS.md`
6. `scripts/hooks/inject-line-rules.sh`
7. `.mcp.json`
8. `scripts/setup-codespace.sh`
9. `antigravity/setup.md`
10. `antigravity/mcp-config-template.json`

## rollbackと完了証拠

- S05は10path commitのrevertで戻す。credential rotationは旧値へ戻さず、問題時は再度新規発行する。
- 完了証拠はsnapshot、明示10path、commit hash、値なしのテスト件数、規約名評価md、fresh runtime確認。いずれかが欠ければChild 04/10のwriterを開始しない。

## 実装記録

### 2026-07-13 23:27 JST — S01/S03事前検証

- 仕事repo snapshot: `HEAD 6e0862e53a93`、`origin/master 25c981ad936f`、ahead 5 / behind 0。
- dirtyは上記manifest 10pathと完全一致、staged 0、ahead 5の変更11pathとの重複0。
- `.codex/hooks.json`、`.claude/settings.json`、`.mcp.json`、Antigravity templateのJSON parse、`.codex/config.toml` のTOML parse、対象diffのwhitespace検査はPASS。
- 値を出さない構造scanで、working treeのlikely literal credential assignmentは0、現HEADは9。したがってS05 commit前のHEADは未安全であり、working treeを巻き戻してはならない。
- Codex/Claudeのhook設定はbyte-identicalで各7entry。manifest内の `git add -A` 文字列1件はroot `AGENTS.md` の禁止説明だけで、hook commandには0件。`git commit` commandも0件。
- runtime `.env` と `scripts/.env.local` は存在しGit ignore対象。値・更新日時・provider側失効状態は検査していない。
- 未完了: S02 credential失効・再発行と履歴方針、S04旧session終了/fresh runtime実測、S05明示10path commit。これらの完了前に仕事repo writerを起動しない。

### 2026-07-14 — 新しい仕事repoタスクでのGate 0再検証

- ユーザーの「あなたが進めて」という委任により、新しい可視Codexタスク `019f5c2d-7c8d-7591-892a-98c75f78ee9b` を仕事repoのlocal環境で起動した。中央planを複製せず本Childを参照し、root AGENTS読了とsession-board key `019f5c2d` の仕事repo登録を確認した。
- snapshotは `master@6e0862e53a93`、`origin/master@25c981ad936f`、ahead 5 / behind 0、staged 0、dirty固定10pathで開始記録と一致した。
- S01/S03再検証はscope一致、JSON/TOML 5件、shell 2件、Codex/Claude hook 7件ずつの同一性、旧root参照0、working treeのcredential形式0、`git diff --check` をPASSした。仕事repoへの新規変更、stage、commit、pushは0件、secret値出力は0件。
- Git履歴はrewriteせず保持する方針で確定した。credential失効・再発行と再検証PASS後の固定10path明示stage/commitは承認済みとして扱い、pushは未承認のまま禁止する。
- 2026-07-14にLINE Channel access tokenを再発行し、仕事repo rootのGit非追跡 `.env` の `LINE_CHANNEL_ACCESS_TOKEN` へ保存した。値は表示・ログ出力せず、キー1件・非空・printable-only・ignoredかつuntrackedを検証した。
- Supabase endpointと既存credentialは生存している一方、現在ログイン中のSupabase account/orgには対象projectがない。service_roleだけではproject所有者を逆引きできないため、適当なprojectを選んでkeyを作成してはならない。
- 推奨するcommit前の停止条件は、`scripts/staff-status/src/check.ts` を追加するscope承認、D1 2表へのadapter実装、read-only→dry-run→最小writeのruntime確認、Supabase参照撤去である。Supabase access回復を選ぶ場合は、Secret key移行を別scopeで行う。いずれもS05 commit後のfresh runtimeでH0〜H7を検証する。Child 04/10 writerはそれまで開始しない。

## 本program外へのhandoff

Turso移行、D1 schema正本化、Webhook署名不正拒否、LINE gateway集約は仕事repo固有の別計画候補とする。本ChildのPASS/FAILへ含めない。

## 完了条件（レビュー項目）

- [ ] 漏えいcredentialが失効・再発行済みで、tracked設定にcredential実値が0件である。
- [ ] LINE公式MCPとline-readerがroot `.env` の単一LINE tokenから起動でき、値無し時は外部package起動前に安全終了する。
- [ ] Claude project MCP正本がtracked root `.mcp.json` 1箇所で、`.claude/settings.json`、Codespaces、Antigravityに重複定義・上書き・credential手入力導線がない。
- [ ] `staff-status` の2状態表が既存D1で動作し、read-only・dry-run・UNIQUE競合・自動送信影響なしを確認したうえでSupabase参照を撤去している。Supabase access回復を選んだ場合は、この条件をSecret key移行・legacy key無効化の別計画で置換する。旧migration scriptは再実行禁止として台帳へ送られている。
- [ ] Git履歴対応について、保持またはrewriteの人間判断・影響範囲・次の一手が仕事repoの計画に記録されている。
- [ ] secret scanが値を出力せず、working treeと現HEADで0件PASSしている。
- [ ] trust登録済みrepo-local hookに `git add -A` と無条件自動commitが残っていない。
- [ ] Stop時はread-onlyの状態確認・完了シグナル・session-board記録だけで、無条件stage/commitを実行しない。
- [ ] commit時は対象diffの確認と `git add -- <明示path>` が必要で、別タスクの変更を巻き込まない。
- [ ] repo-local/global hookを各1回実測し、重複発火・無限loop・旧root参照エラーがない。
- [ ] 移行用worktreeに、開始時snapshot外の並行セッション変更が混入していない。
- [ ] dispatcher等の稼働中loopが変更前と同じ所有repo・実行状態である。
- [ ] commit、push、launchd再登録、履歴rewriteは、それぞれ必要な人間承認を得た操作だけである。
- [ ] 変更前から開いていた仕事sessionを終了・再起動し、旧hookを保持するsessionが残っていない。
- [ ] 旧hookが作成した `f4b78f49`・`fb6f5047` に別作業planが混在せず、安全化差分と別作業差分が明示的に分離されている。
- [ ] S01〜S05の開始snapshot、commit hash、値なしテスト件数、fresh runtime証拠が揃い、Turso/Webhookを本Childの未完了条件へ混ぜていない。
