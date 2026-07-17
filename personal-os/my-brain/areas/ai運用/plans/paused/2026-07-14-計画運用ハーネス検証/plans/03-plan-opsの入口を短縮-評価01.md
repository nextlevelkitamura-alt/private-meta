親計画: ../program.md ／ 対象計画: `plans/03-plan-opsの入口を短縮.md` ／ ラウンド: 01 ／ 規模: フル ／ 評価者: repair_plan_registry（独立レビュー担当）
diff範囲: `AIエージェント基盤/skills/plan-ops/` と `global-skill-registry/catalog/meta.md` の作業ツリー差分

# 評価01: plan-opsの入口を短縮

## 項目別採点   ※ 子計画の完了条件と同順

- [PASS] `plan-ops/SKILL.md` が70行以内で、workflowとreferenceを1ホップで指名している。
  根拠: `SKILL.md` は37行で、入口表から `workflows/scaffold-and-update.md`、`workflows/validate-and-promote.md`、`references/script-map.md` を直接指名している。
- [PASS] 6つの既存scriptのpath、CLI、既定dry-run、書込み条件、手動に残す判断がreferenceまたはworkflowで確認できる。
  根拠: 6本を実装と照合し、`progctl`/`bucketctl` は既定dry-run、`new-plan`/`new-child` は新規pathのみ、lint/section checkは読み取り専用で、workflow/referenceの記載と一致した。
- [PASS] `scripts/` と `templates/` のファイル移動・改名が0件である。
  根拠: `git diff --name-status HEAD -- skills/plan-ops` にrename/deleteはなく、script 6本・template 5本が現行pathに残る。`bucketctl.sh` の一時WIP例外は内容変更であり移動・改名ではない。
- [PASS] plan-opsの既存テストが通り、`program-lint` がこの親programに違反なしを返す。
  根拠: `bash __tests__/run.sh` は92 pass / 0 fail、親programへの `program-lint.sh` は「違反なし」を返した。
- [PASS] `SKILL.html` が新しいrouter/workflow/reference構成と一致する。
  根拠: `SKILL.html` は白背景・`color-scheme: light` を固定し、router → 2 workflow → reference → 既存script/template/testの構成を人間向けに示している。ローカル `file://` はブラウザのURLポリシーで表示確認できないため、暗色切替なし・アンカー対応・構造一致を静的確認した。

## 総合判定

全PASS。子03の実装レビューは完了し、人間確認へ進める。子01の `修正01` が未解決のため、program全体の統合完了・子02への着手はまだ行わない。
