# Codex実行指示: personal-os/plans 廃止移行

種別: ai
状態: done
日付: 2026-06-29 JST
親計画: ../../plan.md

## このファイルの位置づけ

別エージェント（Codex想定）が、このチャットの文脈なしで実行できる手順書。
作業前に必ず読む正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`
（Skill正本を編集するため、9章Git運用・8章作業前チェックに従うこと）。

## ゴール

`personal-os/plans/` を廃止し、Personal OS基盤・Global Skill・repo・loop の計画を
`personal-os/my-brain/areas/ai運用/plans/` に一本化する。
あわせて、各所のルーティング記述を新しい置き場・規約へ書き換える。

## 前提（確定済みの設計判断）

1. 置き方は **areas方式に統一**する。
   - 1計画 = `ai運用/plans/<YYYY-MM-short-name>/plan.md`。
   - 種別（新規作成/既存改善/統合整理）と状態（planning/ready/active/paused/done）は
     **フォルダで分けず、plan.md 冒頭のフィールド `種別:` `状態:` で持つ**。
   - skill / repo / loop の区別は plan.md 冒頭に `分類:` フィールドで持つ（skill / repo / loop）。
2. **repo-local 側は今回いじらない**。各所有repo内の `plans/skills/<種別>/<状態>/` 規約はそのまま残す。
   今回廃止するのは `personal-os/plans/` のみ。Skill本文では「Global/Personal OS側」の記述だけ
   新パスへ変え、「repo-local/所有repo側」の記述は変更しない。
3. 履歴ログ（`repo-registry/logs/.../06-28-ai-agent-foundation.md` 等）は事実の記録なので書き換えない。

## 新しい置き場ルール（書き換え後の正しい記述）

- Personal OS基盤・横断・Global Skill・repo・loop の計画書:
  `/Users/kitamuranaohiro/Private/personal-os/my-brain/areas/ai運用/plans/<YYYY-MM-short-name>/plan.md`
- 計画ルーティングの規約正本: `personal-os/my-brain/areas/ai運用/AGENTS.md`
  （旧 `personal-os/plans/AGENTS.md` の内容をここへ移し替える）
- 種別・状態の定義: `personal-os/my-brain/areas/AGENTS.md`

## 手順

### Step 1: 旧規約を ai運用 へ移し替える
1. `personal-os/plans/AGENTS.md`（97行）の計画ルーティング規約のうち、まだ ai運用 側に無い実質ルール
   （種別の意味、Global/repo-local判断、書くこと/書かないこと、完了条件）を
   `personal-os/my-brain/areas/ai運用/AGENTS.md` に統合する。
2. ただし状態をフォルダで分ける記述は持ち込まない。状態はファイル内フィールドに読み替える。
3. 重複は作らない。種別・状態の定義は `areas/AGENTS.md` を参照で済ます。

### Step 2: 実体の計画ファイルを移す
`personal-os/plans/` の実ファイル7件を `ai運用/plans/<YYYY-MM-short-name>/plan.md` へ移す。
冒頭に `分類:` `種別:` `状態:` を補う（内容は変えない）。元の状態フォルダ名から状態を読み取る。

| 旧パス | 新パス（plan.md） | 状態 |
|---|---|---|
| plans/skills/新規作成/planning/2026-06-29-orca-cli-multi-agent-workflow新規作成.md | ai運用/plans/2026-06-orca-cli-multi-agent-workflow/plan.md | planning（生きてる） |
| plans/skills/新規作成/done/2026-06-28-repo-relocation-既存repo移動スキル.md | ai運用/plans/2026-06-repo-relocation/plan.md | done |
| plans/skills/既存改善/done/2026-06-27-skill-creator-custom-既存改善計画書命名ルール改善.md | ai運用/plans/2026-06-skill-creator-custom-命名ルール/plan.md | done |
| plans/skills/既存改善/done/2026-06-27-skill-creator-custom-計画書ディレクトリ構造改善.md | ai運用/plans/2026-06-skill-creator-custom-計画書構造/plan.md | done |
| plans/skills/既存改善/done/2026-06-27-skill-creator-custom-計画種別ルーティング改善.md | ai運用/plans/2026-06-skill-creator-custom-種別ルーティング/plan.md | done |
| plans/skills/既存改善/done/2026-06-27-基盤-機能説明更新.md | ai運用/plans/2026-06-基盤-機能説明更新/plan.md | done |
| plans/skills/統合整理/done/2026-06-29-repo-create-agents-md-governance統合整理.md | ai運用/plans/2026-06-repo-create-agents-md-governance/plan.md | done |

- 生きてる計画（orca-cli）は ops 種別5フォルダ（.gitkeep）も作る。done計画は ops 不要。
- ファイル移動は `git mv` を使う（追跡済みの場合）。

### Step 3: ルーティング記述を書き換える
下記ファイルの `personal-os/plans/...`（Global/Personal OS側）参照を、Step の新パス・新規約へ書き換える。
repo-local/所有repo側の記述（`所有repo内の plans/skills/...`）は触らない。

- personal-os/AIエージェント基盤/AGENTS.md（9箇所: 21,33,45,76,84,86,87,100,102 付近）
- personal-os/AIエージェント基盤/README.md（3箇所: 4,62,69 付近）
- personal-os/AIエージェント基盤/global-skill-registry/AGENTS.md（3箇所: 13,19,27 付近）
- personal-os/AIエージェント基盤/repo-registry/AGENTS.md（4箇所: 11,18,24,30 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/SKILL.md（24,60,63,64,65,66 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/references/create-rules.md（4,180,181,183,189,190 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/references/review-rules.md（4,36,118 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/references/absorb-rules.md（21 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/workflows/review-skill.md（26,61,63,68 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-custom/workflows/create-new.md（56,64,78,81,93,100 付近）
- personal-os/AIエージェント基盤/skills/skill-creator-codex/SKILL.md（176 付近）

書き換えの考え方:
- 「`plans/skills/global/<種別>/<状態>/` に置く」→「`ai運用/plans/<YYYY-MM-対象>/plan.md` に作り、`種別:` `状態:` を書く」
- 「`plans/AGENTS.md` を読む」→「`ai運用/AGENTS.md` と `areas/AGENTS.md` を読む」
- 「`plans/repositories/...`」「`plans/loops/...`」も同様に ai運用 へ。
- repo-local（所有repo内 plans/）の記述は維持。

### Step 4: 上位AGENTS.mdの更新
- personal-os/AGENTS.md: `plans/` をフォルダ概要・更新ルールから外し、計画は ai運用 へ。
- Private/AGENTS.md: `personal-os/plans/` の行を ai運用 系に更新。
- my-brain/AGENTS.md, areas/AGENTS.md: 既に「廃止予定」と記載済み。「廃止済み」に更新。

### Step 5: 検証
```
grep -rn "personal-os/plans\|plans/skills/global\|plans/repositories\|plans/loops" \
  /Users/kitamuranaohiro/Private/personal-os /Users/kitamuranaohiro/Private/AGENTS.md \
  | grep -v "my-brain/areas" | grep -v "logs/"
```
→ 履歴ログ以外でヒットが残っていないこと。残れば直す。

### Step 6: 旧フォルダ削除（人間承認ゲート）
- `personal-os/plans/` を削除する前に、人間に「削除してよいか」明示確認を取る。
- 承認後に削除。`AIエージェント基盤/AGENTS.md` 9章により、削除等の危険操作は人間承認必須。

## 完了条件
1. 履歴ログ以外に `personal-os/plans/` 参照が残っていない。
2. 実計画7件が ai運用/plans/ に移り、種別・状態がフィールドで持てている。
3. 旧規約の実質ルールが ai運用/AGENTS.md に移っている（重複なし）。
4. `personal-os/plans/` が削除されている（人間承認後）。
5. repo-local 側の規約は変更されていない。

## Git/commit
- `AIエージェント基盤/AGENTS.md` のGit運用に従う。
- 意味のある単位で分けてcommit。push と main 操作はしない。
- コミットメッセージ末尾に Co-Authored-By 行（Codex運用の規約があればそれに従う）。
