# Private/ — 人生の全体オーケストレーター

このディレクトリはユーザー（北村）の人生を管理する2つの主要リポジトリとその他のプロジェクトを含む。

<!-- AGENT-ROUTER:START -->
## Agent Router
This repository keeps long-lived product requirements, feature specs, progress status, and contradiction records outside this entry file.

### Source of truth
- Product requirements: `docs/requirements/product-requirements.md`
- Requirements ledger: `docs/requirements/requirements-ledger.md`
- Progress board: `docs/requirements/progress-board.md`
- Contradictions and open issues: `docs/requirements/contradictions.md`
- Non-goals: `docs/requirements/non-goals.md`
- Feature specs: `docs/specs/`
- Architecture decisions: `docs/adr/`

### Required workflow
Before adding a new feature or changing existing behavior, use the `requirements-governor` skill to check scope, contradictions, affected requirements, and acceptance criteria.
After implementation, update the requirements ledger and progress board. Do not mark items as `done` without evidence.

### Entry file size policy
Keep this file short. Target under 200 lines. If it grows beyond 250 lines, move procedures, templates, or detailed references into docs or skills. Do not exceed 300 lines without explicitly justifying why.

### Do not
- Do not treat this file as the full product spec.
- Do not add long procedures here.
- Do not mark requirements as done without evidence.
- Do not implement new features before checking `non-goals.md` and `contradictions.md`.
<!-- AGENT-ROUTER:END -->

## Codex Notes
- Project skills live in `.agents/skills/`.
- Use `$requirements-governor` or mention `requirements-governor` when auditing requirements, gating new features, syncing progress, or reviewing contradictions.
- Keep long workflows inside skills or docs, not in this file.

## 最優先: フラット評価（絶対原則）

忖度しない。「良いですね」で締めない。矛盾・盲点・リスクを率直に指摘する。
書籍・他者の意見を鵜呑みにしている兆候は問い返す。`人生管理/人生の軸/` と噛み合わない選択は必ず指摘する。

**短絡評価の禁止**: 表面の矛盾に飛びつかない。指摘する前に「矛盾」ではなく「優先順位」「時間軸の違い」「両立構造」である可能性を必ず検証する。steelmanを通した上で残る懸念だけを指摘する。

## 主要リポジトリ（2つ）

### 人生管理/ — 戦略層 + 運用層
自分の人生そのものを管理する。
- **戦略層**: `人生の軸/`（アイデンティティ・価値観・北極星）、`仕組み/`（行動ルール）、`素材/`、`日誌/`
- **運用層**: `計画一覧.md`、`プロジェクト一覧.md`、`領域/`、`予定/`
- **現況**: `現況.md`

### 起業スキル/ — 実装層
起業に必要なスキル・ツール・テンプレートの実装資産。
- `skills/`（web-build・browser-auto・sales-deck等）、`templates/`、`scripts/`、`docs/`
- 再利用可能なツール群。人生管理/とは独立した git リポジトリ

## 情報フロー原則（一方向）

```
人生管理/（戦略）
    ↓ 方向性・価値観・北極星を提供
起業スキル/（実装）
    ↓ 実装成果物
人生管理/（運用: プロジェクト一覧・予定へ登録）
    ↓ 実行
実行結果 → 人生管理/日誌/
    ↓ 重要な学びのみ逆流（昇華）
人生管理/人生の軸/ or 仕組み/
```

## 越境防止ルール

どのリポジトリで Codex が動いても、守備範囲を超えた作業を検知したら**明示的に指摘**する:

- 人生管理/ で「商品価格・営業文面・法規制詳細」に踏み込みそうになったら → 「これは起業スキル/ の領域です」と伝え、本人に確認
- 起業スキル/ で「自分のアイデンティティ・人生の方向性」に踏み込みそうになったら → 「これは人生管理/人生の軸/ の領域です」と伝え、本人に確認
- 起業スキル/ の `idea-forge` `concept-check` を使う時は**仮説生成ツール**として扱い、最終決定は人生管理/人生の軸/ と照合して本人が行う

## 重複禁止領域

- 人生のビジョン・価値観・アイデンティティ → **人生管理/人生の軸/ のみ**
- 商品設計・営業戦術・法規制詳細 → **起業スキル/ のみ**
- 日次業務・プロジェクト進捗 → **人生管理/（運用層） のみ**

同じ情報を2箇所に書かない。片方が更新されても整合性が失われないように。

## その他リポジトリ（個別ツール/プロジェクト）

Private/ 配下には他にも以下がある。これらは独立したツール・プロジェクト:
- **`仕事/`** — e-nextlevel キャリア事業部 CA業務。本業の日々のオペレーション。管理画面自動化・求人管理・エントリー処理・候補者パイプライン等。仕事の話題が出たら必ず `~/Private/仕事/AGENTS.md` を読むこと。
- `AI カンパニー/`、`P dev/`、`playnote/`、`skill 販売プラットフォーム/`、`チーム共有/`、`リモートワーカー/`、`投資/`、`動画生成/` など

これらは**人生管理/と起業スキル/のオーケストレーション対象外**。個別の目的で使う。

## 言語
日本語で対話してください。
