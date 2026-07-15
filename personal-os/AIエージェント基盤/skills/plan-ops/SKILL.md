---
name: plan-ops
description: 計画ライフサイクルの機械手続き（program.md子計画マップの機械書換、計画テンプレからの雛形生成、program.mdの静的整合チェック、レビュー項目の範囲付き判定）を固定パスのscriptで安全に実行する窓口。Use when program.mdの子計画マップを更新する（状態/次の一手/参照repo@hash）, 単発plan.md/program.md/子計画.mdの雛形を作る, program.mdの整合（実ファイル有無・backlink・状態語彙・完了条件チェック漏れ）を機械チェックする。中身の判断（何をやるか・どう直すか）は判断系skillへ委譲し、ここは手続きだけを担う。
---

# plan-ops

計画ライフサイクルの**決定的な機械手続き**だけを実行するSkill。何を計画するか、規模、置き場、レビュー合否は決めない。

## 入口

| やりたいこと | 読むworkflow | 使うscript |
|---|---|---|
| plan / program / 子計画の雛形を作る、既存子のマップを更新する | `workflows/scaffold-and-update.md` | `new-plan.sh` / `new-child.sh` / `progctl.sh` |
| plan / 子計画 / program の実行契約を検査する | このSkillと `references/script-map.md` | `plan-lint.sh` |
| バケット遷移・終了記録を検証する、実装結果と評価を同期する | `references/script-map.md` | `bucketctl.sh` / `planctl.py` |
| 自動・手動の境界、各scriptのpathとCLIを確認する | `references/script-map.md` | 6 scripts |

## 実行前に確認する正本

1. 規模・段階・人間ゲート: `../../GLOBAL_AGENTS.md` §6–7。
2. planの物理配置・テンプレ・評価規約: `../../../my-brain/areas/AGENTS.md` §3–5。
3. 計画運用の集約入口が配置済みなら、`../../plan-registry/AGENTS.md` を先に読む。ここには規約本文を複製しない。

## 不変の境界

1. 置き場の解決・既存planへの合流・規模判定は `plan-triage`、計画内容の判断は判断系Skillが担当する。
2. このSkillは固定pathのscriptを呼ぶ窓口であり、`scripts/`、`templates/`、`__tests__/` を移動・改名しない。
3. `plan-lint.sh` は明示pathだけを読む。雛形直後だけは `--allow-placeholders` を使えるが、実行開始前はplaceholder無しで通す。書込み・`git mv`・commitはworkflowの条件と人間ゲートに従う。pushはしない。
4. バケット（フォルダ）と `program.md` の子計画マップ、各plan本文が状態の正本であり、第2の台帳は作らない。run manifestはgitignore配下の実行時情報であり、状態台帳ではない。
5. secret・token・認証値をplan、出力、commit対象へ入れない。

## 使わない場面

- 「どこに計画を置くか」や「サクッと／ライト／フル」を決めるだけなら `plan-triage`。
- 実装のレビュー、実行中レーンの監督、完了判断はこのSkillの外。必要なSkill・計画の手順へ戻る。

人間向けの全体図は `SKILL.html`。正本はこの `SKILL.md` と各workflow/referenceである。
