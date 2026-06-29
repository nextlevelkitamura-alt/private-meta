分類: repo
種別: 既存改善

# コミット整理

## 目的

今日の plans 廃止移行・area 再構成・計画バケット化で、2つの独立 git repo にまたがって溜まった
未コミット変更を、安全に・意味単位で整理してコミットする。

## 背景（git構成と4つの問題）

構成は repo が2つ:

- Repo#1 = `/Users/kitamuranaohiro/Private`（ルート）。branch `main`、remote 無し。
  `personal-os/`（my-brain 等）を追跡。`personal-os/AIエージェント基盤` は .gitignore 済みで非追跡。
- Repo#2 = `/Users/kitamuranaohiro/Private/personal-os/AIエージェント基盤`。独立repo。
  branch `codex/align-agent-registries`、remote `github.com/.../ai-agent-foundation`（公開）。

二重管理（同一ファイルを両repoが追跡）は起きていない（gitignoreで分離済み）。問題は別:

1. 今日の1論理変更（plans廃止→ai運用一本化）が Repo#1 と Repo#2 にまたがり、原子的にコミットできない。
   かつ Repo#2 の Skill が Repo#1 の `ai運用` パスを参照する相互依存。
2. Repo#1 は `main` の上で、今日と無関係な既存未コミット（docs 29, scripts 6, .claude 4 等）と混在。
   remote 無しでバックアップも無い。
3. Repo#2 は「ブランチ本来の registry 整理（global-skill-registry 35 + repo-registry 40）」と
   「今日の plans 移行 skill 書き換え（skills 42 + README + AGENTS）」が未分離で混在。
4. （構造・中期課題）公開 Repo#2 の Skill が北村マシン固有の絶対パスを多数含み非ポータブル。
   今回は是正しない。別計画で扱う。

## 前提（先に終わっているべきこと）

- 計画バケット化の Skill 側書き換え（`../2026-06-計画バケット化/ops/ai/codex-skill-bucket化.md`）が完了し、
  Global/ai運用 側の Skill 記述がバケット方式で一貫していること。
- 未完なら先にそれを終え、ドキュメントが矛盾しない状態にしてからコミットする。

## 残作業（Codexへ委譲）

詳細手順は `ops/ai/codex-commit整理.md`（種別: ai / 状態: ready）。

## 完了条件

1. Repo#1: 今日の `personal-os/`・`AGENTS.md`・`CLAUDE.md` 関連だけが意味単位でコミットされ、
   無関係な docs/scripts/.claude 等は未コミットのまま温存されている。
2. Repo#2: registry 整理と plans 移行が別コミットに分かれている。
3. どちらも `git push` していない（明示依頼が無い限り）。`main` への直接コミットをしていない（要承認）。
4. secret・token・認証情報をコミットしていない。
5. 残った未コミット（無関係分）の整理方針が人間に短く共有されている。

## 関連

- 計画バケット化: `../2026-06-計画バケット化/plan.md`
- plans廃止移行（完了）: `../../done/2026-06-基盤整理/plan.md`
