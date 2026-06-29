種別: ai
状態: ready
日付: 2026-06-29 JST
親計画: ../../plan.md

# Codex実行指示: 2repoにまたがる未コミット変更の整理

## このファイルの位置づけ

別エージェント（Codex想定）がこのチャットの文脈なしで実行できる手順書。
作業前に必ず読む正本:
- `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤/AGENTS.md`（特に10章 Git運用）
- 親計画 `../../plan.md`（背景・4つの問題・完了条件）

## 絶対に守ること（承認ゲート）

1. `git push` しない。明示依頼が無い限りローカルコミットまで。
2. `main` へ直接コミットしない。Repo#1 は現在 `main` なので、コミット前に人間へ
   「作業ブランチを切ってよいか / それとも main に直接コミットする運用か」を確認する。
3. `git add -A` や `git add .` を使わない。今日と無関係な変更を巻き込まないため、必ずパス指定で stage する。
4. `git reset --hard` / `git clean -fd` / force / rebase / 履歴改変はしない。
5. secret・token・認証情報・環境変数の値が差分に含まれていないか、stage 前に確認する。含むなら止めて報告。
6. 不明点・想定外の差分が出たら、自己判断で握りつぶさず人間に短く報告する。

## 前提チェック（コミット前に必ず）

A. ドキュメント一貫性。計画バケット化の Skill 側書き換え
   （`../../2026-06-計画バケット化/ops/ai/codex-skill-bucket化.md`）が完了していること。
   未完なら先にそれを終える。終わっていないまま「フィールド方式」と「バケット方式」が混在した
   状態でコミットしない。
B. 参照クリーン検証（履歴ログ以外でヒット0を確認）:
   ```
   grep -rn "personal-os/plans\|plans/skills/global\|plans/repositories\|plans/loops" \
     /Users/kitamuranaohiro/Private/personal-os /Users/kitamuranaohiro/Private/AGENTS.md \
     | grep -v "my-brain/areas" | grep -v "/logs/"
   ```
   ヒットが残れば、それは未処理。コミット前に解消するか人間に報告。

## 全体像（repoは2つ）

- Repo#1 = `/Users/kitamuranaohiro/Private`（ルート、branch main、remote 無し）。
  `personal-os/AIエージェント基盤` は .gitignore 済みで非追跡。
- Repo#2 = `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤`
  （独立repo、branch codex/align-agent-registries、remote 公開GitHub）。

各 repo で別々にコミットする。1論理変更が2repoに分かれている事実を、コミットメッセージで束ねる。

---

## 手順 Repo#1（Private ルート）

### 1-1. ブランチ確認（ゲート2）
`git -C /Users/kitamuranaohiro/Private branch --show-current` が `main` のはず。
人間に確認のうえ、作業ブランチを切る（例 `restructure/my-brain-areas`）。
main 直コミット運用だと人間が明言した場合のみ main のまま進める。

### 1-2. 今日の変更だけを stage（ゲート3：パス指定）
今日の「area再構成 / plans廃止移行 / 計画バケット化」に該当するのは概ね次。実際の `git status` で確認しつつ、
**これらだけ**を stage する:
- `personal-os/my-brain/`（新規 areas、ai運用 計画、ops 等すべて）
- `personal-os/AGENTS.md`
- `personal-os/plans/` の削除（旧フォルダ。`git add -A personal-os/plans` 等で削除を stage）
- `AGENTS.md`（Privateルート、plans 記述更新分）/ `CLAUDE.md`（変更があり今日分なら）

**stage しない**（今日と無関係。温存する）:
- `docs/`、`scripts/`、`schemas/`、`tests/`、`.claude/`、`.gitignore`（今日の作業起因でないもの）
- 判断に迷う変更は stage せず、最後に人間へ一覧で報告。

### 1-3. 意味単位でコミット
差分量が多いので、読みやすく分けるなら次の2コミット（1つにまとめても可、判断はCodex）:
- コミットA: `my-brain: areas構造とopsルールを整備（work/money/health/ai運用）`
- コミットB: `plans: personal-os/plansを廃止しai運用へ一本化（バケット方式・Private側）`
`git status` を再確認し、意図したパスだけが入っていること。

---

## 手順 Repo#2（AIエージェント基盤）

`cd /Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤`。branch は codex/align-agent-registries（OK）。
未コミットは2系統に分かれる。**別コミットにする**:

### 2-1. registry 整理（このブランチ本来の目的）
- 対象: `global-skill-registry/`、`repo-registry/` の変更。
- これらを review し、ブランチ意図（registry alignment）として一貫・完結しているなら1コミット:
  `registry: align global-skill / repo registries`（実際の変更内容に合わせて調整）。
- WIP や意図不明な差分が混じるなら、stage せず人間に報告。

### 2-2. plans移行 + バケット化の Skill 書き換え（今日の作業）
- 対象: `skills/`（skill-creator-custom / skill-creator-codex のルーティング書き換え）、`README.md`、`AGENTS.md`。
- 1コミット: `skills: plans廃止に伴う計画ルーティングをai運用バケット方式へ更新`。
- repo-local（所有repo内 `plans/skills/<種別>/<状態>/`）の記述は変更されていないことを差分で確認。

---

## コミットメッセージ規約
- 1行目は簡潔な要約。本文に「なぜ」を短く。
- 2repoのコミット本文に、対になる相手repoの変更を一言添えて束ねる
  （例: 「対: Private repo の ai運用 計画一本化」）。
- フッタは AIエージェント基盤のCodex運用規約に従う。指定が無ければ Co-Authored-By 行は付けなくてよい。

## 検証（コミット後）
- 各repo `git log --oneline -5` で意図したコミットができている。
- 各repo `git status --short` で、温存対象（無関係分）だけが未コミットで残っている。
- 前提チェックBの grep が引き続きヒット0。

## 最後に人間へ報告すること
1. 両repoで作ったコミットの一覧（ハッシュ＋要約）。
2. Repo#1 で温存した無関係な未コミット（docs/scripts 等）の一覧と、別途整理が要る旨。
3. push は未実施である旨（必要なら依頼してくださいと添える）。
4. Repo#1 が remote 無しである点（バックアップの検討事項）。
