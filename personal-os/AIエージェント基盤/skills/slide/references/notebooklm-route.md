# NotebookLM ルート手順

Step 9 で A (NotebookLM) を選択した時の生成手順。
企画フェーズ（Step 0-8）の出力を入力に、NotebookLM でスライドを生成する。

`nlm` CLI を Bash 経由で呼ぶ。MCP 接続不要・トークン消費ゼロ。

---

## A1. ノートブック構築

### A1.1 ノートブック作成

```bash
nlm create notebook "{資料名}"
# 出力された <id> を以下で使用
```

### A1.2 歯車アイコン設定（ペルソナ・方針注入）

NotebookLM の歯車アイコン（Configure notebook）にペルソナ・方針を設定すると、Studio 出力（スライド含む）に約 75% の確率で反映される。**主な構造指示はプロンプト欄で行うが、これはバックアップ的な位置づけ。**

**指揮官がユーザーに提示する内容（UI 操作が必須）:**

```
ノートブックの設定（歯車アイコン）に以下を貼り付けてください:

あなたはプロフェッショナルなプレゼンテーション資料を作成するデザイナーです。
- 日本語で作成する
- 1スライド = 1メッセージ
- 余白を十分に取り、情報を詰め込まない
- ブランドカラー（{primary HEX}）とトーン（{tone}）に忠実に従う
- ロゴは各スライドの{position}に配置する
- {visual_policy.density} を厳守
```

ユーザーの「設定しました」を待ってから次へ。

### A1.3 ロゴ画像をソースとして投入

`brand_asset.logo.path` が存在する場合:

```bash
nlm add source <id> --file ~/.claude/skills/slide/資料/ブランド設定/{ブランド名}/logo.png
```

NotebookLM が「これを各スライドに使う」と認識する確率を上げる。

---

## A2. ソース投入（リサーチ官の設計順序）

リサーチ官が出力した `sources` の `order` 順に投入。**構成指示書は最後**。

```bash
# order 1: コア情報
nlm add source <id> --file ~/Documents/service-overview.md

# order 2: データ（変換後の Markdown）
nlm add source <id> --text "$(cat case-studies-merged.md)"

# order 3: ブランドガイド
nlm add source <id> --file ~/.claude/skills/slide/資料/ブランド設定/{ブランド名}/brand.yaml

# order 4: 補助資料
nlm add source <id> --file ~/Documents/competitive-analysis.md

# order 5: 構成指示書（企画官モード2の出力・必ず最後）
nlm add source <id> --text "$(cat 構成指示書.md)" --confirm
```

### 投入後の確認

```bash
nlm list sources <id>
# 順序が想定通りか目視確認
```

---

## A3. 構成指示書の作成（企画官モード2）

Agent ツールで企画官を呼び出し、`mode: 2 (スライドマップ作成)` を指定。
入力には Step 1-7 の YAML 全てを渡す。

出力された Markdown を `構成指示書.md` としてローカル保存し、A2 の order 5 として投入。

---

## A4. ドライラン（生成前のテキストプレビュー）

**生成前にチャットでスライド内容をテキスト確認する。生成に時間がかかるため、ここで問題を発見できれば大幅な時間節約になる。**

```bash
nlm query notebook <id> "構成指示書に基づいて、各スライドの内容をテキストで詳細にプレビューしてください。
各スライドに入る見出し・箇条書き・数値を具体的に書いてください。
キーメッセージが反映されているか確認できるように出力してください"
```

### チェックポイント

- キーメッセージ（Step 5）が各スライドに反映されているか？
- ソースの情報と整合しているか？
- 情報量は適切か？（多すぎ/少なすぎ）
- ストーリーの流れが自然か？

→ 問題あり: ソース差替え or 構成修正（生成せずにやり直せる）
→ 問題なし: A5 へ

---

## A5. プリフライトチェック（最終確認）

```
━━━ プリフライトチェック ━━━
□ ソース: {N}個（構造化済み ✓ / 5-8個 ✓）
□ 構成: {N}枚（スライドマップ確定済み ✓）
□ キーメッセージ: {N}つ（構成に反映済み ✓）
□ ブランド: {ブランド名}（ロゴ投入済み ✓ / カラー指示 ✓）
□ ビジュアル方針: {density}, {tone}
□ 歯車設定: ユーザー設定済み確認
━━━━━━━━━━━━━━━━━━━━━━━

すべて OK なら生成を開始します。確認お願いします。
```

ユーザーの確認を得てから A6 へ。

---

## A6. スライド生成（Stage 1 → Stage 2 の2段階）

**理由**: 構造とスタイルを同時指示すると、AI が見た目の最適化のために構造を崩す。分離する。

### Stage 1: 構造プロンプト（内容・順序・枚数を固定）

```bash
nlm slides create <id> --prompt "$(cat <<'EOF'
構成指示書に従って、{N}枚のスライドを生成してください。

絶対ルール:
- 構成指示書のスライド順序を変更しない
- 構成指示書の文言をそのまま使用する
- 枚数は{N}枚固定
- 各スライドの「コアメッセージ」を必ず反映
- 数値は構成指示書の値を使用、勝手に作らない

形式: 詳細なスライド
EOF
)"
```

UI 操作: 形式選択（詳細 / プレゼンター）と長さ選択は UI 上で実行。

### Stage 2: スタイルプロンプト（リビジョンとして適用）

Stage 1 の生成完了後、**リビジョン** で色・フォント・雰囲気を適用:

```bash
nlm slides revise <id> --prompt "$(cat <<'EOF'
スライド全体のスタイルを以下に統一してください:

- ブランドカラー: primary={#HEX}, accent={#HEX}, text={#HEX}, bg={#HEX}
- フォント: heading={fontname}, body={fontname}
- トーン: {tone}
- 雰囲気: {visual_policy.reference}
- 避けるもの: {visual_policy.ng の項目}

構造（順序・内容・枚数）は変更しないでください。スタイルだけ調整してください。
EOF
)"
```

### 生成後ダウンロード

```bash
nlm download slide-deck <id> --format pptx --output ~/Downloads/{資料名}.pptx
```

---

## A7. 後処理（共通 Step 10）

NotebookLM ルートでもロゴ適用が 75% の確率なので、**python-pptx での確実な後処理**を実行:

```bash
~/.claude/skills/slide/scripts/inject-brand.ts \
  --pptx ~/Downloads/{資料名}.pptx \
  --brand {ブランド名} \
  --mode logo-only
```

→ 全スライドに `brand.yaml` の position/size でロゴ配置（既存ロゴ検出時はスキップ）。

SVG 抽出も任意:
```bash
~/.claude/skills/slide/scripts/pptx-to-svg.sh \
  --pptx ~/Downloads/{資料名}.pptx \
  --out ~/Documents/{資料名}/
```

---

## モード 2: 壁打ち

ノートブックに対してチャットで問いかけるモード。スライド生成しない。

```bash
# ソース確認
nlm list sources <id>

# 質問
nlm query notebook <id> "{質問内容}"

# 例: 「このソース群で気になる矛盾はある？」
# 例: 「想定読者にとって最も刺さる切り口を3つ提案して」
```

新規ノートブックなら、Step 8（ソース設計）まで実行してから壁打ち開始。
既存ノートブックの場合は memory/slide.md からノートブック ID を探して直接 query。

---

## モード 3: 音声生成

NotebookLM 専用機能。

```bash
# 音声プレビュー（Audio Overview）
nlm audio create <id> --prompt "{狙い}"
# 例: --prompt "経営層向けに、サービス導入のROIを中心に12分で解説してください"

# ダウンロード
nlm download audio <id> --output ~/Downloads/{資料名}.m4a
```

---

## モード 4: 汎用操作

```bash
# ノートブック作成
nlm create notebook "{名前}"

# ソース追加（さまざまな形式）
nlm add source <id> --file path.md
nlm add source <id> --file path.pdf
nlm add source <id> --text "テキスト直接"
nlm add source <id> --url https://example.com

# ソース削除
nlm remove source <id> <source_id>

# ソース一覧
nlm list sources <id>

# ノートブック一覧
nlm list notebooks
```

---

## CLI / UI 操作の区分

| 操作 | CLI (`nlm`) | UI 操作が必要 |
|------|:-----------:|:-----------:|
| ソース追加（テキスト/PDF/MD/URL） | ✓ | - |
| ソース追加（画像 PNG/JPG） | 要検証 | 確実 |
| ソース削除 | ✓ | - |
| チャット（構成案・ドライラン） | ✓ | - |
| スライド生成・リビジョン | ✓ | - |
| ダウンロード | ✓ | - |
| 歯車アイコン設定 | - | 初回のみ |
| 形式選択（詳細/プレゼンター） | - | 毎回 |
| 長さ選択 | - | 毎回 |

---

## トラブルシュート

### 認証切れ
```bash
nlm login
# ブラウザが開く → Google 認証
```

### ソース追加失敗
- PDF が大きすぎる（50MB+）→ 分割 or テキスト抽出して投入
- URL アクセス不可 → WebFetch でローカル保存してから --file で投入

### 生成枚数が指定と違う
- 構成指示書の「枚数固定」指示が効いていない → 歯車設定を確認 → リビジョンで再生成依頼

### スタイル崩れ
- Stage 1 と Stage 2 を同時実行している → 必ず分離
- ブランドカラー指示が無視される → 歯車設定 + リビジョン両方で言う

---

## 参考: 旧 notebooklm スキルからの主な変更点

- 企画フェーズが SKILL.md と `references/企画フロー.md` に共通化（NotebookLM/PPT 両ルートで使用）
- ブランディングが `brand.yaml` 形式に統一（旧 ブランド設定 .md 形式から移行）
- スライドマップ作成は企画官 Agent（旧 Step 4b と同じ）
- ロゴ後処理（A7）が新規追加（python-pptx で確実適用）
