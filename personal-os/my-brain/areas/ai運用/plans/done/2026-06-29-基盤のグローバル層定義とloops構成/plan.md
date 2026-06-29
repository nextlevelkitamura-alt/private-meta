分類: repo
種別: 既存改善

# 基盤のグローバル層定義と loops 構成

日付: 2026-06-29 22:59 JST

## 目的

AIエージェント基盤を「リポジトリ全体のうち**グローバル/基盤レイヤを管理する場所**」として明文化し、その上で (1) loop 本体の置き場 `loops/`、(2) コードの置き場ポリシーを確定する。発端は「基盤はコードを持たない」という誤前提が、文書の穴（コード置き場ルールの不在）に紛れ込んだこと。穴を埋めるのが本計画。実装（基盤 `AGENTS.md` 反映）はこの plan を確定してから行う。

## 現状

1. 基盤の役割は「Global Skill正本・registry・symlink運用」とは書いてあるが、「グローバル層**全体**を管理する」という位置づけが明文化されていない。
2. **コード置き場ルールがどこにも明文化されていない**。実態として基盤には script がある（`global-skill-registry/scripts/link-global-skill.sh`、`skills/skill-creator-codex/scripts/*.py`、`skills/video-transcription/scripts/*.py`）。`ai運用/AGENTS.md` は「実装正本＝基盤」と書くが、「global code は基盤同梱／repo固有は projects／分けは §4」の1文が無い。
3. この空白に「基盤はコードを持たない」という誤前提が紛れ込んだ。出どころは2つの取り違え:
   - `areas/AGENTS.md`「~/Private にコードを置かない」＝ my-brain の**area内実行**の話。基盤は ~/Private に `.gitignore` 非追跡の別repoなのに「~/Private配下＝基盤も」と誤読。
   - `personal-os/AGENTS.md`「実装repoではない」「repo本体は projects/」＝ governance部分と**プロジェクトrepo丸ごと**の話。入れ子の「基盤だけ別repo＆実装正本」を見落として延長。
4. loop の**本体**（実行スペック＋script）の置き場が未定義。skill は `skills/<skill>/`（SKILL.md＋scripts/）があるが、loop に相当する `loops/` が無い。
5. `基盤/AGENTS.md` §1.1 で `plans/loop/`（loop計画の6バケット）は定義済み。ただしこれは「計画」であって「本体」ではない。

## 方針

### A. 基盤の位置づけ（明文化）
基盤＝リポジトリ全体のうち**グローバル/基盤レイヤを管理する場所**。具体的には global skill、global loop、runtime露出、registry、「何が global か」の判断を持ち、**global なものの実装正本（本体＋script）を集約**する。my-brain（考え・計画）、projects（個別プロジェクト実装）とは役割が異なる。

### B. loops/ 構成（skills/ と対称）
- `loops/<loop名>/` に `loop.md`（実行スペック）＋ `scripts/`（実行コード）＋ 任意 `references/`。`skills/<skill>/` と同じ作り。
- loop の稼働状態（稼働中/停止/廃止）は `loop.md` の frontmatter で持つ。フォルダで状態を分けない。← plans とは別物（plans は状態=フォルダ、本体は状態=frontmatter）。
- `plans/loop/` の計画（作る側）と `loops/<loop>/` の本体（成果）は相互参照する。`loop.md` frontmatter に `設計: plans/loop/done/<計画>`、plan 側は完了条件で成果 `loops/<loop>` を指す。名前を対応させる。
- **loop の起動の仕組み**（cron/launchd 等のスケジューラ登録、skill の runtime露出に相当）は**本計画のスコープ外＝別計画**。未確定として宿題に残す。

### C. コード置き場ポリシー（穴埋め＝4区別）

| 種類 | 置き場 |
|---|---|
| global skill/loop の本体＋script | 基盤 `skills/`・`loops/`（scripts 同梱） |
| 特定repo専用の script・業務ロジック | `projects/<repo>/` |
| 新しいプロジェクトrepo丸ごと | `projects/` |
| my-brain の area内実行 | ~/Private（doc のみ・コード不可） |

分け方の正本＝ `基盤/AGENTS.md` §4 の **Global / repo-local 判断**（skill と同じ基準を loop にも当てる）。迷ったら repo-local 優先、複数repoで再利用実績が出たら Global化を検討。

### D. 反映先（実装時。AGENTS.md 編集はこの plan 確定後）
1. 基盤 `AGENTS.md` §0/§2: 基盤の位置づけ（グローバル層管理・実装正本の集約）を明文化。
2. 基盤 `AGENTS.md` §1: フォルダ地図に `loops/` 追加 ＋ §1.2「loops/ 構成」を §1.1 の隣に新設。
3. 基盤 `AGENTS.md`: コード置き場ポリシー（上の4区別＋§4準用）を1ブロック追記。「基盤はコードを持たない」と読める箇所を作らない。
4. 基盤 `AGENTS.md` §4: Global/repo-local 判断が **loop も対象**だと明記（現状 Skill のみ言及）。
5. `ai運用/AGENTS.md` / `personal-os/AGENTS.md`: 必要なら loops への導線を1行。

## 完了条件

1. 基盤の位置づけ（グローバル層管理）が基盤 `AGENTS.md` に1か所明文化されている。
2. `loops/` 構成（`loop.md`＋`scripts/`、状態=frontmatter、`plans/loop` との相互参照）が §1.2 として書かれている。
3. コード置き場の4区別と「分けは §4」が基盤 `AGENTS.md` に明文化され、「基盤はコードを持たない」と読める箇所が無い。
4. §4 が loop も対象だと読める。
5. loop の起動の仕組みは「未確定（別計画）」と明記され、放置でなく宿題として残っている。
6. 二重管理・新規空フォルダの乱立が無い。

## 関連

1. 先行: `done/2026-06-29-計画ライフサイクル設計`（育成→卒業、`plans/` §1.1 の定義）。本計画はその続きで「本体（`loops/`）とコード置き場」を扱う。
2. 既実装: 基盤 `AGENTS.md` §1.1（`plans/`）。本計画は §1.2（`loops/`）と code policy を足す。
3. 宿題（別計画に切り出す）: loop 起動の仕組み（スケジューラ／runtime露出）。

## 結果

実装日: 2026-06-29 JST / コミット: 基盤 `45b5c2f`（codex/align-agent-registries）＋ ~/Private 本コミット（codex/commit-cleanup）

- **A 位置づけ**: 基盤 `AGENTS.md` §0 に「グローバル/基盤レイヤを管理する場所・global実装正本の集約」を明文化。
- **B loops/**: §1 地図に `loops/` 追加、§1.2「loops/ の構成」新設（`loop.md`＋`scripts/`、状態=frontmatter、`plans/loop` と相互参照、起動の仕組みは未確定として宿題化）。§2.1・§6 にも導線。
- **C コード置き場**: §4 に「コード（実装）の置き場」（scope軸の4区別）を追記し、「基盤はコードを持たない」と読める箇所を排除。§4.1 に loop を Global判断対象として追加。
- 反映先: 基盤 `AGENTS.md`（§0/§1/§1.2/§2/§4/§6）、`personal-os/AGENTS.md` §6.6（Global loop正本＝`基盤/loops/`）。
- 宿題（別計画）: loop 起動の仕組み（スケジューラ/runtime露出）。実体 `loops/` フォルダは初回 loop 作成時に生やす（今は空フォルダを作らない）。
- 評価（done→archive）は人間。

### 追記2（2026-06-30）: loop起動の標準化 ＋ skill計画の置き場変更

- **loop 起動の宿題を標準化**: `loops/references/loop-runbook.md`（launchd ＋ 軽量ディスパッチャ ＋ runner 2系統 `ai`/`script`）を新設。リファレンス実装は仕事リポ `scripts/nextlevel-dispatcher/`（実地調査で既に本番稼働を確認）。`loops/` 実体を作成。
- **skill 計画の置き場変更**: `plans/skill/`（未実体）→ `global-skill-registry/plans/` に移動。`plans/` は loop 専用に。基盤 `AGENTS.md` §1.1/§1.2/§2.6/§3.7/§6/§7 ＋ `personal-os/AGENTS.md` §6.2 を整合。
- **残る宿題**: グローバル dispatcher 本体の実装と、仕事リポ自動化の統合・移行（仕事は今のまま稼働）。
- コミット: 基盤 `eeeaa4c` ＋ ~/Private 本コミット。
