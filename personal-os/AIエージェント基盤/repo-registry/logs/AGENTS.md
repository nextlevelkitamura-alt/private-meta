# Repo Registry Logs

このディレクトリは、repoとrepo-local Skillの履歴を短く残す。

現在状態やSkill本文は置かず、どこに何を登録したか、どこから移したか、どこから消したかの地図として使う。

## 1. 役割

1. `repositories/registered/YYYY-MM/MM-DD-<repo-id>.md`: repoを管理対象に追加した履歴。
2. `repositories/moved/YYYY-MM/MM-DD-<repo-id>.md`: repo pathやremoteなどの移動履歴。
3. `repositories/archived/YYYY-MM/MM-DD-<repo-id>.md`: repoをarchivedへ移した履歴。
4. `repositories/renamed/YYYY-MM/MM-DD-<repo-id>.md`: repo-idやrepo名の改名履歴。
5. `repositories/agents-updated/YYYY-MM/MM-DD-<repo-id>.md`: repoの `AGENTS.md` / `CLAUDE.md` を整備した履歴。
6. `repo-local-skills/created/YYYY-MM/MM-DD-<repo-id>-<skill>.md`: repo-local Skill作成履歴。
7. `repo-local-skills/migrated/YYYY-MM/MM-DD-<repo-id>-<skill>.md`: repo-local Skill移行履歴。
8. `repo-local-skills/deleted/YYYY-MM/MM-DD-<repo-id>-<skill>.md`: repo-local Skill削除履歴。
9. `repo-local-skills/renamed/YYYY-MM/MM-DD-<repo-id>-<skill>.md`: repo-local Skill改名履歴。

## 2. 書くこと

repo履歴:

1. 日付時刻。形式は `YYYY-MM-DD HH:mm JST` とする。
2. repo-id。
3. repo path。
4. 何をしたか。
5. 特殊事情だけの備考。

repo-local Skill履歴:

1. 日付時刻。形式は `YYYY-MM-DD HH:mm JST` とする。
2. repo-id。
3. repo path。
4. 正本、旧正本、新正本、削除元。
5. 概要。1〜2行で何をするSkillか、または何をするSkillだったかを書く。
6. 移行ログでは、移行理由、正本選定、検証。
7. 特殊事情だけの備考。

日付時刻は、実行時に `date '+%Y-%m-%d %H:%M JST'` で確認する。過去ログから引き継ぐ履歴で時刻が分からない場合だけ、引き継ぎ履歴内では日付のみを残してよい。

ログファイル名は、月フォルダ `YYYY-MM/` の下で `MM-DD-<repo-id>.md` または `MM-DD-<repo-id>-<skill>.md` にする。`MM-DD` は本文の `日付時刻` と同じ月日を使い、年はファイル名に入れない。

## 3. 書かないこと

1. Global Skill履歴。
2. repo現在状態のコピー。
3. repo-local Skill本文の長い要約。
4. コマンド生ログ。
5. diff全文。
6. 会話ログ。
7. 古くなるTODO。
8. secret、token、環境変数の値。

## 4. repo-local Skill削除時

1. `created/` または `migrated/` に同じrepo-local Skillのログがあれば、要点を `deleted/` ログへ引き継ぐ。
2. 削除済みrepo-local Skillの `created/` / `migrated/` ログは残さない。
3. 削除後にそのrepo-local Skillの経緯を見る場所は `deleted/` ログだけにする。
4. 削除理由は分類語だけで終わらせず、なぜ削除するのかを1文で書く。
5. 所有repo側の現在導線を外すかどうかを同じ作業単位で確認する。

## 5. 改名時

1. repoまたはrepo-local Skillの旧名ログの要点を新名側へ引き継ぐ。
2. 旧名ログは残さない。
3. 旧名は新名ログの備考にだけ短く残す。
4. 所有repo側のrepo-local Skill導線の更新要否を同じ作業単位で確認する。

## 6. テンプレート

repo登録:

```md
# repo-id

- 日付時刻: YYYY-MM-DD HH:mm JST
- repo: `/absolute/path/to/repo`
- 概要: 1〜2行で何をするrepoかを書く。
- 備考: なし
```

repo-local Skill作成:

```md
# skill-name

- 日付時刻: YYYY-MM-DD HH:mm JST
- repo-id: `<repo-id>`
- repo: `/absolute/path/to/repo`
- 正本: `<repo-relative-skill-path>`
- 概要: 1〜2行で何をするSkillかを書く。
- 所有repo側の導線: 追加済み / 更新不要
- 備考: なし
```

repo-local Skill削除:

```md
# skill-name

- 日付時刻: YYYY-MM-DD HH:mm JST
- repo-id: `<repo-id>`
- repo: `/absolute/path/to/repo`
- 削除元: `<repo-relative-skill-path>`
- 概要: 1〜2行で何をするSkillだったかを書く。
- 理由: <重複 / 統合 / 不要化 / 誤作成 / その他>。<なぜ削除するのかを1文で書く>
- 所有repo側の導線: 削除済み / 更新不要
- 引き継ぎ履歴:
  - 作成: <あれば日付時刻・正本>
  - 移行: <あれば日付時刻・旧正本・新正本>
  - 統合元ログ: <削除したcreated/migratedログpath。なければなし>
- 備考: なし
```
