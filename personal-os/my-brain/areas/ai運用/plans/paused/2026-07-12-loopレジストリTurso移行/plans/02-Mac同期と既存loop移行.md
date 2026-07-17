親計画: ../program.md ／ 分類: loop ／ 種別: 統合整理

# 02 Mac同期と既存loop移行

## 目的

既存Focusmap Mac Agentを単一observer/writerとして、launchd実態・実行履歴・Turso desired revisionを安全に同期する。
loopごとの状態監視launchdやTurso tokenを増やさない。

## 現状

- 現役7loopは4つのglobal実装と3つの仕事repo実装。各plistとログ先が異なる。
- 現行HTML生成時だけ `launchctl print` を読み、常時状態は持たない。
- Focusmap Mac Agentは既にagent token、heartbeat、API client、ローカル監督機能を持つ。
- Focusmap Agent本体のlaunchdは現在未導入で、Macアプリが子processとして管理する。Agent不在時は観測も送信も止まる。
- schedule/plistを一度にDB正本へ切り替えるとrollback不能になるためshadow期間が必要。

## 方針

1. Observer: 登録labelだけをlaunchctlで確認し、loaded/waiting/running/run count/last exit/observed hashを差分時に送る。
2. Run reporter: start/finish/skip/failureをevent id付きで送る。初期はwrapper可能なloopから行い、launchctl observationで不足を補う。
3. Offline spool: bounded JSONL＋lock＋batch replay。送信不能でもloop本体のexitやlaunchdを止めない。
4. Initial importer: 現行MD/fixture/plist/実装参照を読み、7loopをrevision=1としてAPIへ一括登録する。直接SQLは禁止。
5. Shadow: desired==observedで開始し、apply outboxを作らず、MD/launchctlとの一致だけを測る。
6. Apply: 人間承認済みoutboxだけclaimし、revision/hash確認→plist生成→lint→bootstrap/reload→再観測→completeする。
7. 冪等: 同revision/hashが既に適用済みならno-op成功。lease再配布で二重bootstrapしない。
8. Rollback: 直前applied revision/plistを保持し、canaryで失敗したら旧plistへ戻してTursoへ結果を記録する。
9. AGENTS切替: cutover後だけ `loops-registry/AGENTS.md` をMCP routerへ薄くする。MCP障害時は定義変更を禁止する。
10. Run精度: launchctl観測だけでstart/finish/durationは取れないため、安定配置した共通wrapperをcanary 1本→残り6本へ展開する。
    wrapperは既存stdout/stderrを既存ログへ流し、run id、revision、時刻、outcome、exit code、短いerror、log pointerだけをAPIへ送る。
11. 適用前backup: LaunchAgentsがsymlinkか実ファイルか、link target、bytes、launchctl snapshot、applied revisionをchange id単位で保存し、同じ形へ復元する。

## 対象境界

- Focusmap: `scripts/focusmap-agent/src/` のAPI client、types、observer、apply、spool。
- 基盤: `loops-registry/AGENTS.md`、現行7loopのsource reference、移行用snapshot。
- 仕事repo: 実装は変えず、3loopのsource referenceとrun reporter接続点だけ扱う。
- launchd変更は04の人間ゲートまで行わない。

## 完了条件（レビュー項目）

- [ ] Agent 1体が7labelを観測し、loop別監視launchdを新設していない。
- [ ] Agent不在・Macアプリ停止時はofflineになり、最後の観測を現在状態として扱わない。
- [ ] waitingを正常、non-zero exit・stale observation・unloadedを別状態として送れる。
- [ ] 無変更tickはTursoへ書かず、heartbeat期限からMac offlineを判定できる。
- [ ] offline spoolがevent順とevent idを保持し、再送後に重複run/runtimeを作らない。
- [ ] API/Turso障害時も7loopの実処理・launchd状態・exit codeが影響を受けない。
- [ ] importerが7loop・55step・label・schedule・retry・log ref・implementation refをrevision=1へ登録できる。
- [ ] 未承認outbox、別user/runner、stale revision、hash不一致をAgentが拒否する。
- [ ] 同revision再配布はno-opで、canary rollbackが旧plist・loaded状態を復元できる。
- [ ] 共通wrapper経由のrun start/finish/exit/durationがcanaryで記録され、report失敗がloop本体の成否を変えない。
- [ ] global 4本のLaunchAgents symlinkと仕事3本の実ファイルを区別してbackup・復元できる。
- [ ] token値、生ログ、仕事の個人データをspool/API payload/Tursoへ入れない。
