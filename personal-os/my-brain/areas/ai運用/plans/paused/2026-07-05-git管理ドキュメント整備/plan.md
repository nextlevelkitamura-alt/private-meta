分類: 横断 ／ 種別: 新規作成 ／ 優先: ○

# git管理ドキュメント整備（2repo構造の正本）

## 目的

AIエージェント基盤に「全体のgit管理」を一望できる正本を1つ作る。`~/Private` が2つのgit repoに
分かれている構造（`private-meta` / `ai-agent-foundation`）・各repoが何を追跡するか・`.gitignore`の
再include方針・push先・スマホ(GitHubアプリ)での見方を、人間がすぐ把握できる形で置く。

## 現状（2026-07-05）

- 2repo構造の知識が分散している（`AIエージェント基盤/CLAUDE.md` のgit節、`~/Private/.gitignore`、会話のみ）。
  「`private-meta` を見ても基盤(hooks)の変更が見えない」という混乱が実際に起きた。
- 既存 `AIエージェント基盤/repo-registry/` は移動・登録・削除の履歴ログ。全体像の一望図は無い。
- 事実: `private-meta`＝`~/Private`外側（remote `nextlevelkitamura-alt/private-meta`）。
  `ai-agent-foundation`＝`personal-os/AIエージェント基盤/`（別repo・remote同アカウント）。
  `.gitignore` が `/personal-os/*` を無視し一部mdだけ再include、基盤は非追跡（追跡0件・実測）。

## 方針（確定・2026-07-05）

- 置き場: 新フォルダ `AIエージェント基盤/git-registry/`（`-registry` 慣習に沿う・人間承認済み）。
  中身は `git-overview.md`（全体像の正本）＋`AGENTS.md`＋`CLAUDE.md`→AGENTS.md symlink。
- 内容: 2repoの一覧（名前・remote・追跡範囲）／`.gitignore` 再include規則／push先とブランチ／
  2repoにまたがる変更の束ね方／スマホでの見方／正本の切り分け。
- `repo-registry` は履歴logs専用なので統合せず別フォルダに。基盤 `AGENTS.md` のgit節は
  `git-overview.md` へのポインタに縮約（二重管理しない）。

## 完了条件（レビュー項目）

1. AIエージェント基盤配下に、2repo（`private-meta` / `ai-agent-foundation`）の追跡範囲・remote・push先を一望できる正本mdが1つある。
2. `.gitignore` の personal-os 再include方針と「AIエージェント基盤は別repo」が明記されている。
3. 既存 `CLAUDE.md` git節・`repo-registry` と内容が重複せず、正本が1つに定まっている（他は参照）。
4. secret/token/認証値を含まない。

## 実施結果（2026-07-05・完了）

- 作成: `AIエージェント基盤/git-registry/{git-overview.md, AGENTS.md, CLAUDE.md→AGENTS.md}`。
- 更新: 基盤 `AGENTS.md` のフォルダ一覧に `git-registry/` を追加・git節を `git-overview.md` へのポインタに縮約。
- レビュー項目 1〜4 すべて達成（一望正本1枚・`.gitignore`/別repo明記・重複なし・secretなし）。
- 残: 人間レビュー後に commit/push（ai-agent-foundation＝doc/AGENTS、private-meta＝計画）。OK なら `done/` へ。
