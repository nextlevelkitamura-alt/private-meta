# plan-triage

- 日付時刻: 2026-07-22 16:05 JST
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/plan-triage`
- 概要: 「やりたいこと」1件の入口判断（規模サクッと/ライト/フル・経路・起動形・モデル）を書き込みなしで1回解決し、routeカードを出す決定手続きだった。
- 承認: 2026-07-22 人間承認（program「計画立案システム刷新」子02の人間ゲート＝skill-delete。指揮官セッションでの明示承認）。削除は人間ゲートのため必須。
- 露出削除: 撤去対象なし（削除時点で5窓いずれにも露出symlinkが存在せず＝0本。created logは2026-07-02の5窓露出を記録していたが、実測で既に全窓に無し。exposure-manifest記載もなし）。
- 理由: 統合。決定手続き（規模基準の当て方・二段ルーティング・fail-closed）と検証テストが plan-registry の規約と同じ基準を二重に持っていたため、実体を plan-registry へ畳み込み（子02）、重複する skill 本体を削除して正本を一本化した。
- 吸収部品の移動先:
  - `workflows/triage.md` → `plan-registry/triage.md`（端から端の手順）
  - `references/route-contract.md` → `plan-registry/route-contract.md`（出力JSON・handoff契約）
  - `examples/01-03` → `plan-registry/examples/`
  - `scripts/validate-route-cases.mjs`・`validate-inbox-contract.mjs`＋`fixtures/route-cases.json` → `plan-registry/scripts/`（挙動不変・移設先テストbyte-identicalで実証）
  - 決定手続き本文（基準＋当て方＋fail-closed）→ `plan-registry/AGENTS.md` §6「経路解決（triage決定手続き）」
- 引き継ぎ履歴:
  - 作成: 2026-07-02 21:45 JST・正本 `skills/plan-triage`・基盤mainマージ e18d004（実装d26e13e＋修正440948d・レビューPASS）。基準は運用契約§2・決定ログ#3・cockpit-supervisor参照で独自定義なし。計画正本=my-brain/areas/ai運用/plans/active/2026-07-02-計画トリアージスキル。
  - 統合元ログ: `logs/created/2026-07/07-02-plan-triage.md`（本削除ログへ引き継ぎ後に削除）
- 備考: データ契約識別子 `plan-triage.route/v1` は改名すると caller/fixture の契約変更になるため名称を維持（skill参照ではない）。表示専用HTML（各SKILL.html・plan-registry/AGENTS.html）は削除後にstale/リンク切れが残るため、`/html` 再生成をフォローアップに分離（AI実行導線外）。
