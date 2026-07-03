分類: skill ／ 種別: 既存改善 ／ 規模: ライト ／ 優先: ◎

# orca-cockpit 評価レーンの型と簡素化

## 目的

orca-cockpit スキルに「評価レーンの型」を定義し（評価者=codex既定・異系統評価の原則をレビュー以外の評価にも適用）、あわせてSKILL.mdを入口だけに簡素化する（workflows新設ゼロ・詳細はreferencesへ・行数削減）。

## 現状（2026-07-03・なぜ評価にGPTが使われなかったか）

- 直接原因: 全体管理者Aがcodex 5h枠93%消費を理由に、spawn評価レーンの実行系計測をclaude実装ペインへ割り、codexを待機させた（枠温存の判断。ただし宣言なしの既定変更に見えた）。
- 構造原因: orca-cockpit の役割型が「実装=claude／レビュー=codex」の2役のみで、「評価レーン（第三者評価・評価者=codex既定）」の型・構成カード・レシピが未定義。型が無いため個別判断に落ちた。
- 肥大の兆候: 本日だけで owner タグ・spawn（子09実装中）・レシピ節（子09）が追加され、SKILL.md/scripts が未整理のまま成長中（ユーザー指摘=スキルが整理されていないから起きた）。
- 実行環境の答え: 評価worktreeが「Private」でなくAIエージェント基盤repo配下に立つのは、修正対象 cockpit.sh の正本が基盤repoにあるため（Privateにcockpit.shは無い）。

## 方針

1. 役割型は2役のまま（実装=claude／レビュー=codex）とし、**レビュー役の責務に評価（第三者実測・判定）を統合**する（2026-07-03夜前ユーザー裁定=「評価レーン」という別役割は作らない）。外す時は「計測=claude＋判定=codex後段」等の分担を明示し全体管理者が宣言してから（黙って既定を変えない）— この1行をレビュー役の節へ。あわせてモデル既定の矛盾（orca-cockpit §2.1 vs cockpit-supervisor §3.4・phase1調査で発見）はcockpit-supervisorを正としポインタ化で解消。
2. 簡素化（skill-creator-custom §5準拠）: SKILL.md=入口（目的・役割型・レシピ・安全）だけに削る。判断基準・詳細手順は references/ へ移動。workflows/ 新設ゼロ（教訓は既存Stepへ短く）。目標=現行行数から30%以上減。
3. 子09（spawn＋レシピ節・中間指揮官2実装中）のmainマージ後に本再編を実施（同一ファイルの衝突回避・直列）。
4. 実行=専用worktreeレーン cockpit-skill-reorg（監督=全体管理者A）: phase1=調査＋再編ドラフト（読み取り専用・即時）／phase2=再編実装＋codex 1パスレビュー（spawnマージ後・枠回復後）。手順は skill-creator-custom workflows/review-skill.md + references/review-rules.md に従う。

## 完了条件（レビュー項目）

- [x] SKILL.md のレビュー役の節に「評価（第三者実測・判定）を含む／外す時は分担明示のうえ全体管理者が宣言」が1項として存在する（別役割は新設しない）（2026-07-03 A実測=worktree SKILL.md §2.1行20）
- [x] モデル既定の記載が cockpit-supervisor §3.4 を正とするポインタに一本化され、矛盾が解消している（同上・同じ1項で両立）
- [x] SKILL.md 行数が調査時点比30%以上減り、移した内容が references/ から参照されている（88→48行=45.5%減・references新設2本・リンク切れはcodexレビューで既存の古い参照1件も発見し修正済み）
- [x] workflows/ の新設がゼロ（ls実測=SKILL.md/references/scriptsのみ）
- [x] 子09のレシピ節と重複せず1箇所に統合されている（文言完全一致で移設・差分ゼロ確認）
- [x] codex 1パスレビューPASS（2026-07-03・初回FAIL3点→修正→PASS・a6ff16a）・catalog meta.md 追従（差し戻し対応済みb8ee4dd＝評価統合の1句反映＋作業ドラフトのブランチ除去・A検収済み。原文はこのフォルダへ保全済み）

main反映: spawn 999356d のレビュー完了後にA が直列でマージ・push（cockpit.sh help文言の旧モデル既定表記の残存はスコープ外として次玉=中間2のレビュー対応と合流）。
