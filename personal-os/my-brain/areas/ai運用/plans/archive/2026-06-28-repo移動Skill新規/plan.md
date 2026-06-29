分類: skill
種別: 新規作成

# 既存repo移動Skill

- 種別: 新規作成
- 変更内容: 追加
- 目的: 既存repoを `projects/active/` などへ移動する時に、Git、旧パスsymlink、launchd、テスト、repo-registry記録を小さい手順で扱えるようにする。
- 対象: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/repo-relocation`
- 判断: `repo-create` は新規repo作成用、`agents-md-governance` はAGENTS整備用なので、既存repo移動は独立Skillにする。

## 実行順

1. `SKILL.md` と `workflows/move-repo.md` の2ファイルだけで作る。
2. 旧パスsymlinkは移動直後に残し、削除前は必ず人間に確認する。
3. launchdはdry-run、対象確認、本登録、kickstart、ログ確認の順で扱う。
4. Global created logとcatalogを更新する。
5. runtime露出は正本へのdirect symlinkにする。

## 完了条件

1. Skill正本が `skills/repo-relocation/` にある。
2. workflowが1ファイルだけで読める。
3. symlink削除前確認が明記されている。
4. logsとcatalogが更新されている。
5. runtime露出が確認されている。

## logs/catalog

- logs: `global-skill-registry/logs/created/2026-06/06-28-repo-relocation.md`
- catalog: `global-skill-registry/catalog/meta.md`

## 保留事項

- なし
