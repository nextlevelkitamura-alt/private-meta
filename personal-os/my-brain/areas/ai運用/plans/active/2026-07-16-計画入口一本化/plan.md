分類: skill ／ 種別: 既存改善
規模: ライト
形態判定: 単発 ／ 理由: 同一skillの改名と参照追従で、1作業単位で戻せる
並列: 不可 ／ レビュー: 都度（1パス・差し戻し上限1）

# 計画入口一本化: plan-management を plan-create-review へ改名し全runtime露出

## 目的

利用者が打つ計画コマンドを1本にし、名前を意図（create=作る・review=評価する）で読めるものにする。plan-triage / plan-ops は内部道具として温存し、利用者が名前を覚える必要をなくす。あわせて、catalog登録済みなのに5runtimeどこにも未露出だった欠陥を解消する。

## 非対象

- plan-triage / plan-ops の改名・再編（参照89ファイルの大工事。利用者は直接打たないため効果が薄い）
- workflows本文の手順内容の変更（名前と導線の追従だけ行う）
- 完走済みprogram（2026-07-15-計画立案実行完了基盤）や過去計画の記録書き換え
- logs/created/ の旧履歴の書き換え（履歴は温存し、migrated/ に新ログを足す）

## 現状

- plan-management は利用者入口Skill。catalog/meta.md に登録済みだが、~/.agents・~/.codex・~/.claude・~/.gemini(config/antigravity-cli) の全てで未露出（symlinkなし＝コマンドとして呼べない）。
- 毎ターンの案内文（session-board common.py）は「不明なら plan-management」と誘導しており、実体と不整合。
- 人間承認: 2026-07-16 チャットで「一本化＋改名＋露出」を承認済み。名称は選択式で /plan-create-review に確定。

## 実行契約

- 対象repo: /Users/kitamuranaohiro/Private
- 実行形: direct（指揮官が直接実装。レビューのみ impl-reviewer サブエージェント）
- 最初に読む順番:
  1. personal-os/AIエージェント基盤/AGENTS.md
  2. この計画
  3. personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md（catalog/logs/露出の規約）
- 依存成果: なし
- 変更可能範囲: skills/plan-management（改名先 skills/plan-create-review 含む）、plan-registry/AGENTS.md、global-skill-registry/catalog/meta.md、global-skill-registry/logs/migrated/、hooks-registry/shared/session-board/common.py と tests/、runtime側 skill symlink（~/.agents・~/.codex・~/.claude・~/.gemini 2箇所）
- 変更禁止範囲: plans/ 配下の過去記録、logs/created/ の既存ログ、plan-triage / plan-ops 本文、hooks-registry/events/
- ファイル担当マップ: 不要
- worktree方針: 不要（直実装・小規模・単一作業単位）
- 維持する契約: 入口Skillの責務境界（規模基準・route・script・レビュー合否・runtime露出を所有しない）を変えない。CLAUDE.md→AGENTS.md等の既存symlink構造を壊さない。
- 検証: session-boardテスト全緑、link-global-skill.sh の5露出verify出力、grepで plan-management 残参照が過去記録（plans/・logs/created/・logs/migrated/＝移行履歴正本）のみ ※除外列挙は評価02の付記で明確化（2026-07-16）
- 停止・エスカレーション条件: 計画外領域で未知の参照・依存が見つかったら停止して人間へ
- 完了時に返す情報: result packet（status / base_commit / result_commit / changed_paths / tests / assumptions / blockers / remaining_risks / out_of_scope_findings）

## 方針

git mv で改名して履歴を保ち、SKILL.md（name・説明・見出し）、SKILL.html、workflows内の自己参照、plan-registry責務地図、catalog、案内文（common.py）とそのテストを同一作業単位で追従する。説明文には「作る・合流・評価・終了（done→終了記録→archive）」の受け口を明記する。移行ログを logs/migrated/2026-07/ に新設し、露出は link-global-skill.sh で5runtime一括実行・verifyする。

## 完了条件（レビュー項目）

- [x] skills/plan-create-review/ が存在し、SKILL.md の name と見出しが plan-create-review で、説明に「作る・合流・評価・終了（archiveまで）」の受け口が含まれる
- [x] skills/plan-management/ が存在せず、git上 rename として追跡されている
- [x] 過去記録（plans/ 配下・logs/created/・logs/migrated/＝移行履歴正本。移行ログの旧正本欄はlogs規約が必須とするため除外。評価02の付記で明確化・2026-07-16）を除き、personal-os 内の plan-management 参照が0件（plan-registry/AGENTS.md・catalog/meta.md・common.py・tests・SKILL.html・workflows を含む）
- [x] logs/migrated/2026-07/07-16-plan-create-review.md が規約（日付時刻 HH:mm JST・旧正本・新正本・理由・露出結果）を満たす
- [x] link-global-skill.sh により5 runtime全てで symlink が正本 skills/plan-create-review を指す（verify通過）
- [x] session-board テストが全緑（common.py 案内文の改名追従を含む）
- [x] 入口Skillの責務境界の記述（規模基準・route・script・合否・runtime露出を所有しない）が改名後も維持されている

## 実装結果

- status: completed（評価02 全PASS・2026-07-16）
- base_commit: e82deab ／ result_commit: 4298d9e（改名・参照追従・移行ログ・露出）+ d848b1d（対HTML追従の修正01）
- changed_paths: skills/plan-create-review/（旧plan-managementからrename、SKILL.md・SKILL.html更新）、plan-registry/AGENTS.md・AGENTS.html、global-skill-registry/catalog/meta.md、global-skill-registry/logs/migrated/2026-07/07-16-plan-create-review.md（新設）、hooks-registry/shared/session-board/common.py・tests/test_common.py
- tests: session-board 7スイート135件 全緑（4298d9e・d848b1d 両時点で実測）
- 露出: link-global-skill.sh で5runtime symlink作成・verify通過。実装中の本sessionでもSkillとして即時認識を確認。
- assumptions: 旧名はどのruntimeにも未露出だったため、利用者導線の互換シム（旧名symlink等）は不要。
- blockers: なし
- remaining_risks: doneバケット満杯（17/8）のため、全PASS到達済みでもdone遷移は既存計画是正（承認②）の排水待ち。
- out_of_scope_findings: 実装者の自己検証grepがcwd依存の相対pathで空振りした（評価01メタ所見）。検証コマンドは絶対pathで打つ。
- レビュー履歴: 評価01（FAIL1: 対HTML説明書2枚の追従漏れ）→ 修正01 → 評価02（全PASS・完了条件の除外列挙を明確化）。差し戻し1回＝ライト上限内。

## 終了記録

archive時に必須。実行中は記入しない。
