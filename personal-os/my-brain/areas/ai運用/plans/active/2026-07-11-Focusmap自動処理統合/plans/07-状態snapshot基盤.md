親計画: ../program.md ／ 分類: repo ／ 種別: 新規作成 ／ 規模: フル

# 07 状態snapshot基盤

## 目的

Global / Focusmapのローカルverify結果から、Focusmap UIに必要な非機密要約だけをTursoへ送り、認可された本人だけが読める再生成可能snapshotを作る。publisherのowner・trigger・retry・staleを本子計画で完結させる。

## 現状

- 子03は自動処理UI、子04 / 08はmanifest / verifyを担当するが、Cloud snapshot publisherは既存計画にない。
- ローカルverifyには絶対path、runtime登録先、host / process、log / state pathなど、Cloudへ出すべきでない情報が含まれ得る。
- FocusmapにはTurso read modelとheartbeat / snapshot APIの既存資産があるが、自動処理unit用schemaはない。

## 方針

### repo境界

- Global側: 各registryのローカルverifyが、network送信せずJSONをstdoutへ返す。認証情報を持たない。
- Focusmap側: `scripts/focusmap-agent/src/automation-observer.ts`（予定）がallowlist済みverifyだけを起動し、ローカル詳細を論理IDへ変換して送る。API / migration / 認可 / 表示schemaもFocusmap repoが所有する。
- 同じpublisherを両repoへコピーしない。network publisherはFocusmap agentの1 writerだけにする。

### 公開allowlist

Cloudへ送ってよいもの:

- logical `unit_id`、kind、scope、owner role。
- intention state、runtime stateの要約。
- last success / failure時刻、stale、短い非機密reason code。
- trigger kind / periodの要約、health result、plan ID。

送らないもの:

- 絶対path、home directory、host名、PID / process command。
- runtime登録path、ProgramArguments全文、log / state path。
- raw log、prompt、SQL、env名の値、token / credential、Keychain情報。

### publisher契約

- observerのtrigger / period / entrypoint / ownerをFocusmap manifestへ記録する。
- 1 unit 1 upsert、payload上限、保持期間、batch上限を固定する。
- retryはbounded backoff。失敗時は前回snapshotを残しstaleへ進める。
- idempotency keyはunit ID + observed_at / revision。遅い旧snapshotで新状態を上書きしない。
- publisher停止 / DB障害がruntime hook / loop本体を止めない。

### 認可

- user / tenant境界を必須にし、本人以外のsnapshotを読めない。
- server-only credential。ブラウザへtokenを渡さない。
- migration、token、env、publisherのload / enableはそれぞれ人間ゲート。

## 完了条件（レビュー項目）

- [ ] Global publisherとFocusmap API / migrationのowner・repo・entrypoint・triggerが明記され、担当不在がない。
- [ ] Cloud payloadが公開allowlistだけを持ち、絶対path・host・PID・runtime path・log/state path・raw logを含まない。
- [ ] 他user / tenantのsnapshotをAPIから読めず、server credentialがclient bundleへ出ない。
- [ ] payload上限、batch上限、保持期間を超える入力が拒否または切り詰められる。
- [ ] retryがboundedで、失敗時は前回値＋staleになり、runtime本体を止めない。
- [ ] 遅い旧snapshotが新状態を上書きしない。
- [ ] feature flag / publisher停止で既存session-board、Global loops、Focusmap agentに回帰がない。
