---
name: skill-delete
description: Skill削除専用の安全ゲート。skill-creator-custom から削除実行を委譲された時、またはユーザーが明示的に skill-delete を指定した時に使う。AIエージェント基盤の削除ルールを読み、対象path、runtime露出、削除理由、人間承認、deletedログ、catalog更新を確認してから削除する。
---

# skill-delete

Skill削除だけを扱う安全ゲート。
通常のSkill作成・移行・改名・削除相談の入口は `skill-creator-custom`。

## 1. 必ず読む

1. `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`
2. Global Skill削除なら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/logs/AGENTS.md`
3. Global Skill削除なら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/global-skill-registry/catalog/AGENTS.md`
4. repo-local Skill削除なら `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/repo-registry/AGENTS.md` と `repo-registry/logs/AGENTS.md`

## 2. 削除前

1. 正本pathを確認する。
2. runtime露出を確認する。
3. `rg` で対象Skill名を検索し、他Skill、AGENTS、logs、catalogからの参照を確認する。
4. 参照が残る場合は、削除前に更新方針を決める。
5. Global Skillなら対象Skillが載っているcatalog行を確認する。
6. repo-local Skillなら所有repo側の現在導線を確認する。
7. 削除理由を確認する。
8. 人間の明示承認を確認する。
9. 理由は分類語だけで終わらせず、なぜ消すのかを1文で書く。

## 3. 削除後

1. Global Skillは `global-skill-registry/logs/deleted/YYYY-MM/MM-DD-<skill>.md`、repo-local Skillは `repo-registry/logs/repo-local-skills/deleted/YYYY-MM/MM-DD-<repo-id>-<skill>.md` に記録する。
2. 既存のcreated/migratedログがあれば要点をdeletedログへ引き継ぎ、元ログを削除する。
3. Global Skillは `global-skill-registry/catalog/AGENTS.md` に従い、該当catalogから削除済みSkillの行を外す。
4. repo-local Skillは所有repo側の現在導線の更新要否を確認する。
5. logs/catalog/所有repo側導線の更新は別workflowに逃がさず、この削除ゲートの完了条件として扱う。
6. deletedログの先頭には `日付時刻: YYYY-MM-DD HH:mm JST` を書き、ファイル名の `MM-DD` と同じ月日にする。実行時に `date '+%Y-%m-%d %H:%M JST'` で確認する。
7. 最終報告に、deletedログ更新先とcatalog削除元または所有repo側導線の更新先を書く。
8. commit / push は明示依頼がある場合だけ行う。
