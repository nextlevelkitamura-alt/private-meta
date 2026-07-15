対象計画: 04-PromptSubmitとhookガード.md ／ ラウンド: 01
diff範囲: base e9a6e16 → head task/pf04（7ade5cf, f99c5d0, 0c51934） ／ 規模: フル ／ 評価者: codex read-only reviewer

# 評価01: Prompt Submitとhookガード（Wave 4）

再実行テストは4本とも終了コード0（test_plan_closeout / test_common / test_events / test_builders）。

## 項目別採点   ※ 子計画「完了条件（レビュー項目）」と同順

- [FAIL] 初回・ミラー注入の更新 — 候補文 `plan_management_guide_candidate()` には必要文言があるが、`register_prompt()` は旧 `_first_guide()`/`_mirror()` のみを呼び、実注入は未更新（テストも未有効化を明示確認）。※実行契約の「未有効化」との計画側矛盾 → 完了条件を「候補文＋テスト＋登録差分=完走ライン」へ明確化して解消（指揮官・2026-07-15）。
- [FAIL] plan-managementへの最小ゲート案内とhook非所有境界 — 候補文には存在するが実注入に無し。※同上、計画側明確化で解消。
- [FAIL] PreToolガード — 通常の `git mv` denyとbucketctl許可のfixtureはあるが、`git -C /tmp mv plans/active/a plans/done/a`（オプション付き）と `echo bucketctl; mv plans/active/a plans/done/a`（文字列連結）が実測で通過。拒否要件未達。
- [FAIL] Stopガードとmanifest phase判定 — 5ケースの正常系・`stop_hook_active` 1回blockは実装済み。ただしschema違反manifest（不正task_id・program_path数値・child_id配列）を受理して `review_passed` でblockし得る。schema不正はfail-openであるべき。
- [FAIL] SubagentStart/Stopと不変性テスト — 実装はcwd・branch・base照合とread-only省略を持つが、fixtureが非Git一時ディレクトリでbranch不一致を実証せず、不変性確認もplan/resultのみ（manifest・チェックボックス・バケット・worktreeの前後比較なし）。
- [FAIL] 無限ループ防止・fail-open・既存Stop共存 — `stop_hook_active`・`mark-wait.py` 共存・旧hooks/不在はテスト済み。壊れたJSON・schema不正・内部例外の明示的fail-open契約fixtureが不足。
- [PASS] `finish`≠archive承認・session-board所有境界 — common.py候補文・session-start/end説明・mark-wait.mdで一致。session-board既存テスト成功。
- [PASS] runtime未適用と承認セット — settings.json・hooks.json・symlink・trustに不接触。候補文は呼出経路に未接続。`registration-diff-04-plan-closeout.md` に登録差分・E2E・再trust手順あり。

## 追加指摘（非ブロッキング）

1. `events/pre-tool-use/AGENTS.md` の「判定は shared/plan-closeout/ に置く」が実体（guard-plan-bucket-move.py内判定）と不一致。
2. Prompt Submit未有効化の実行契約と「実注入に含める」完了条件は同時に満たせない — 承認前完走ラインの明文化が必要（→計画側で対応済み）。

## 総合判定

FAILあり（8項目中2 PASS・6 FAIL。うち2件は計画側の完了条件明確化で解消、実装対応は3系統+軽微1件）→ 修正01.mdへ。
