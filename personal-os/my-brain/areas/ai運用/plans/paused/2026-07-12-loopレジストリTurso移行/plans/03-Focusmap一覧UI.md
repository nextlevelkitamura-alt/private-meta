親計画: ../program.md ／ 分類: repo ／ 種別: 新規作成

# 03 Focusmap一覧UI

## 目的

Focusmapの設定領域に、Turso由来のloop定義・実機状態・drift・履歴をPC/モバイルで確認できるread-only画面を作る。

## 現状

- loopはユーザーのMac全体に属し、既存Focusmap workspaceのspace/課金/メンバー管理とは責務が異なる。
- そのため `/dashboard/workspace/loops` より `/dashboard/settings/loops` が既存導線に合う。
- Focusmapには可視中だけpoll、差分cursor、heartbeat、Card/Badge/Sheet、設定shellの再利用パターンがある。
- 現行HTMLは白基調だが、Focusmapは共通design tokenを持つ。画面だけ独自配色にしない。

## 方針

1. 配置: `/dashboard/settings/loops`。設定概要のAI/自動化領域から入る。
2. 所有: 初期はuser_id＋runner/device。space_idはnullable前提にし、workspace所属へ固定しない。
3. PC: summary→Mac接続→Personal OS/仕事→横長loop row。詳細は展開または右Sheet。
4. Mobile: 領域切替、2×2 summary、44px以上のrow、詳細Sheet。内部step全文を一覧へ詰めない。
5. 一覧: 状態、名前、目的、周期、次回、直近結果、driftを表示。
6. 詳細: ordered steps、failure/retry、log ref、definition/applied revision、runtime、最近20runs。
7. Poll: visible時のみ差分取得、復帰時即refresh、idleは低頻度。runs全文を一覧pollへ混ぜない。
8. MVPはread-only。definition編集、停止、再開、approve UIは04または後続人間ゲートで追加する。
9. APIエラー、空、部分欠損、古いheartbeat、Mac offlineを正常表示へ丸めない。

## 触る候補

- `src/app/dashboard/settings/loops/page.tsx`
- `src/components/settings/loop-registry-settings.tsx` または `src/components/loops/*`
- `src/hooks/useLoopRegistry.ts`
- `src/types/loop-registry.ts`
- `src/components/settings/settings-overview.tsx`
- API routeは01所有。UI担当はshared type/fixtureを利用し同じrouteを編集しない。
- `docs/CONTEXT.md` のUI導線・polling境界。

## 完了条件（レビュー項目）

- [ ] DB fixture/read API由来のPersonal OS 4本・仕事3本が表示され、Markdownを読んでいない。
- [ ] waiting/running/succeeded/failed/disabled、synced/pending/drifted、online/offlineを混同しない。
- [ ] `not running` のinterval loopを停止扱いせず、stale heartbeatは正常扱いしない。
- [ ] 各loopで内部step、周期、retry、log ref、latest run、definition/applied revisionを確認できる。
- [ ] 1440px相当と375px相当で主要情報が欠けず、tap targetが44px以上ある。
- [ ] 非表示tabではpollせず、復帰時即時更新、idle時低頻度、in-flight重複なし。
- [ ] 401/403/503/空/部分欠損/offline/driftの表示があり、古いデータを無言で正常表示しない。
- [ ] Focusmap既存の色、Badge、Card、Sheet、Lucide iconを使い、現行HTMLの独自CSSをコピーしていない。
