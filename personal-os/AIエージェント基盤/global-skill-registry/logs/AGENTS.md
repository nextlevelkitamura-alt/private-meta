# Global Skill Logs

このディレクトリは、Global Skillの作成、移行、削除履歴を短く残す。

Skill本文は置かず、どこに何を作ったか、どこから移したか、どこから消したかの地図として使う。

## 1. 役割

1. `created/YYYY-MM/MM-DD-<skill>.md`: 新規作成履歴。
2. `migrated/YYYY-MM/MM-DD-<skill>.md`: 移行履歴。
3. `deleted/YYYY-MM/MM-DD-<skill>.md`: 削除履歴。

## 2. 書くこと

1. 日付時刻。形式は `YYYY-MM-DD HH:mm JST` とする。
2. 正本、旧正本、新正本、削除元。
3. 概要。1〜2行で何をするSkillか、または何をするSkillだったかを書く。
4. 移行ログでは、移行理由、正本選定、検証。
5. runtime露出結果。
6. 特殊事情だけの備考。
7. **段階runtime露出のバックログ**: 一部runtimeだけ露出した場合は、残りを `未露出バックログ:` 行へ列挙する（新規作成テンプレ参照）。`grep -rl '未露出バックログ' created/` で未完了露出を持つSkillを、`grep -r '未露出バックログ' created/` で残り露出先を機械的に一覧できる。実運用後に人間承認で追加したら、該当runtimeを `露出:` 側へ移し、全runtimeへ露出したら `未露出バックログ:` 行を消す。

日付時刻は、実行時に `date '+%Y-%m-%d %H:%M JST'` で確認する。**HH:mm を必ず入れる**（月日だけにしない）。過去ログから引き継ぐ履歴で時刻が分からない場合だけ、引き継ぎ履歴内では日付のみを残してよい。

ログファイル名は、月フォルダ `YYYY-MM/` の下で `MM-DD-<skill>.md` にする。`MM-DD` は本文の `日付時刻` と同じ月日を使い、年はファイル名に入れない。

## 3. 書かないこと

1. repo-local Skill履歴。
2. Skill本文の長い要約。
3. コマンド生ログ。
4. diff全文。
5. 会話ログ。
6. 古くなるTODO。
7. secret、token、環境変数の値。

## 4. 削除時

1. `created/` または `migrated/` に同じSkillのログがあれば、要点を `deleted/` ログへ引き継ぐ。
2. 削除済みSkillの `created/` / `migrated/` ログは残さない。
3. 削除後にそのSkillの経緯を見る場所は `deleted/` ログだけにする。
4. 削除理由は分類語だけで終わらせず、なぜ削除するのかを1文で書く。

## 5. 改名時

1. 旧名ログの要点を新名側へ引き継ぐ。
2. 旧名ログは残さない。
3. 旧名は新名ログの備考にだけ短く残す。
4. 旧名のruntime symlinkは削除し、新名でruntime露出を作り直す。

## 6. テンプレート

新規作成:

```md
# skill-name

- 日付時刻: YYYY-MM-DD HH:mm JST
- 正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-name`
- 概要: 1〜2行で何をするSkillかを書く。
- 露出: <実際に露出したruntime。全露出は `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`。段階露出なら露出した分だけ書く（例 `~/.claude`（YYYY-MM-DD））>
- 未露出バックログ: <段階露出で残したruntimeを列挙（例 `~/.agents` `~/.codex` `~/.gemini/config` `~/.gemini/antigravity-cli`）。実運用後に人間承認で追加予定。**全runtimeへ露出済みなら本行を書かない**>
- 備考: なし
```

移行:

```md
# skill-name

- 日付時刻: YYYY-MM-DD HH:mm JST
- 旧正本: `<old-path>`
- 新正本: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-name`
- 概要: 1〜2行で何をするSkillかを書く。
- 移行理由:
- 正本選定:
- 露出: `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`
- 検証:
- 備考: なし
```

削除:

```md
# skill-name

- 日付時刻: YYYY-MM-DD HH:mm JST（`date '+%Y-%m-%d %H:%M JST'` で確認・**HH:mm 必須**。月日だけにしない）
- 削除元: `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/skills/skill-name`
- 概要: 1〜2行で何をするSkillだったかを書く。
- 承認: <YYYY-MM-DD 人間承認（決定ログ#N 等の参照）。削除は人間ゲートのため必須>
- 露出削除: <実際に撤去した露出先。例 5露出先すべて `~/.agents` / `~/.codex` / `~/.claude` / `~/.gemini/config` / `~/.gemini/antigravity-cli`（計N本）>
- 理由: <重複 / 統合 / 不要化 / 誤作成 / その他>。<なぜ削除するのかを1文で書く>
- 吸収部品の移動先: <このSkillから吸収した部品→移動先path を列挙。無ければ「なし」（詳細な吸収候補調査は別ログへ）>
- 引き継ぎ履歴:
  - 作成: <あれば日付時刻・正本・露出>
  - 移行: <あれば日付時刻・旧正本・新正本・露出>
  - 統合元ログ: <削除したcreated/migratedログpath。なければなし>
- 備考: なし
```
