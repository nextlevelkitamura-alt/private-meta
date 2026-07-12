# Claude for PowerPoint アドイン ルート手順

Step 9 で B（Claude for PowerPoint）を選択した時の生成手順。

> **Microsoft Copilot for PowerPoint とは別物**。Anthropic 公式の M365 アドイン。
> サイドバーから Claude（Opus 4.6 / Sonnet 4.5）が直接 PowerPoint のスライド・マスター・図形を読み書きする。

---

## 事前認証（初回 / 認証切れ時）

PowerPoint Online + Claude アドインの認証を `~/.playwright-auth-pptx/` に保存しておく。
Gemini 画像生成の `~/.playwright-auth` と同じ仕組み。

```bash
# 初回セットアップ or 認証切れ
npx tsx ~/.claude/skills/slide/scripts/pptx-auth.ts --show-browser

# 認証確認（ヘッドレス・ログが出るだけ）
npx tsx ~/.claude/skills/slide/scripts/pptx-auth.ts
```

**--show-browser 操作手順**:
1. ブラウザが開いたら Microsoft アカウントでサインイン
2. office.com で PowerPoint Online を開く（新規 or 既存）
3. アドイン（Claude by Anthropic）を起動
4. Claude サブスクアカウントでサインイン
5. ログイン完了後、**Ctrl+C** で終了 → セッション自動保存

認証 OK なら `~/.playwright-auth-pptx/` に保存済み。次回から自動使用。

---

## 前提条件（最初に必ず確認）

- [ ] **Claude サブスクリプション**: Pro / Max / Team / Enterprise のいずれか
- [ ] **PowerPoint 365 デスクトップ版**（Windows / Mac）。**2016/2019・iPad・Android は非対応**
- [ ] **アドイン導入済み**: Home → Add-ins → "Claude by Anthropic" を検索 → Add
- [ ] **Claude アカウントでサインイン**済み

未導入なら指揮官は以下を提示:
```
Claude for PowerPoint アドインが必要です。
1. PowerPoint を開く
2. 「ホーム」タブ → 「アドイン」（または「アドインを取得」）
3. ストアで「Claude by Anthropic」を検索 → 追加
4. サイドバーで Claude アカウントにサインイン
完了したら教えてください。
```

---

## フロー概要

```
B1. テンプレート選択（既存ロゴ埋込済み .pptx を選ぶ）
B2. テンプレを PowerPoint で開く → アドイン起動 → モデル選択
B3. Instructions field に「永続設定」を貼付（Claude 生成）
B4. 本文プロンプトを貼付・送信（Claude 生成）
B5. 出力レビュー（マスター踏襲・枚数・トーン）
B6. .pptx 保存 → ロゴが乗っていなければフォールバックで inject-brand.ts
B7. SVG 抽出（任意）
```

---

## B1. テンプレート選択

ブランドのテンプレライブラリ: `資料/ブランド設定/{ブランド名}/template.pptx`

Claude for PowerPoint は **開いたファイルのスライドマスター・配色・フォント・レイアウトを自動で踏襲** する。
→ ロゴをマスタースライドに埋め込んだテンプレを使えば、生成された全スライドにロゴが自動で乗る（公式機能）。

**選び方**:
- ブランドあり + テンプレあり → そのまま使用
- ブランドあり + テンプレなし → 一度だけマスタースライドにロゴ配置 → `template.pptx` として保存
- ブランドなし → 新規空白プレゼン or 既存社内テンプレ

```
選択テンプレ: ~/.claude/skills/slide/資料/ブランド設定/{ブランド名}/template.pptx

このファイルを PowerPoint で開いてください。
（開いたら教えてください → B2 に進みます）
```

---

## B2. アドイン起動 + モデル選択

ユーザーへの提示:

```
━━━ Claude for PowerPoint 起動 ━━━

1. PowerPoint で template.pptx が開いている状態にする

2. アドインを開く
   • Mac:     ツール → アドイン → Claude by Anthropic
   • Windows: ホーム → アドイン → Claude by Anthropic
   サイドバーが右側に開きます

3. モデルを選択
   • Opus 4.6   ← デック全体生成・複雑な再構成（今回はこれ）
   • Sonnet 4.5 ← 単一スライド修正・タイポ修正

4. サインイン状態を確認

準備できたら教えてください → B3 に進みます
━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## B3. Instructions field に永続設定を貼付

サイドバーの **Instructions field**（歯車・設定アイコンから開く永続設定欄）に貼る内容を Claude が生成する。
全会話で適用されるブランド・bullet・トーン・数値ルール等。

企画官を Agent ツールで呼び出し、`brief.yaml` の `purpose / audience / visual_policy / brand_asset` を入力に Instructions テキストを生成させる。

雛形は `references/powerpoint-prompts.md` の「Instructions field 用テンプレ」を参照。

ユーザーへの提示:

```
━━━ Instructions field（永続設定）━━━

サイドバーの設定アイコン（歯車）→ Instructions に以下を貼付してください。
1度貼れば、全会話で適用されます（次回以降このプレゼンを開いたときも有効）。

━━━━━━━━━━━━━━━━━━━━━━━━
{Instructions テキスト全文}
━━━━━━━━━━━━━━━━━━━━━━━━

→ 同時に instructions.txt として ログ/2026-MM-{資料名}/ に保存しました
（次回再利用可能）

貼り終わったら教えてください → B4 に進みます
```

→ 同時に `ログ/2026-MM-{資料名}/instructions.txt` に書き出し（再利用用）

---

## B4. 本文プロンプトを貼付・送信

毎回の本文プロンプト（スライド構成・枚数・キーメッセージを指定）を Claude が生成。

企画官を Agent ツールで呼び出し、`brief.yaml` の `storyline / volume_design / key_messages` を入力に
50-150 語のプロンプトを生成させる。雛形は `references/powerpoint-prompts.md`。

ユーザーへの提示:

```
━━━ 本文プロンプト ━━━

サイドバーの入力欄に以下を貼付して送信（Cmd+Enter / Enter）してください。

━━━━━━━━━━━━━━━━━━━━━━━━
{本文プロンプト全文}
━━━━━━━━━━━━━━━━━━━━━━━━

→ prompt.txt として ログ/2026-MM-{資料名}/ に保存しました

ポイント:
• 「アウトラインを先に提示」と指示済み → 確認してから本文化される
• 数値は [TBD: source] でプレースホルダ化 → 捏造防止
• 章配分・テキスト量タグを明示 → 枚数ブレ防止

生成完了したら教えてください → B5 に進みます
```

→ 同時に `ログ/2026-MM-{資料名}/prompt.txt` に書き出し

---

## B5. 出力レビュー

アウトラインが返ってきたら、以下のチェックリストでユーザーに確認を促す:

```
━━━ アウトライン確認チェックリスト ━━━

□ スライド枚数が指定通りか（±1以内）
□ 章の構成・順序が正しいか
□ [TBD: source] が想定通り入っている（数値捏造なし）
□ 各タイトルが「ラベル」ではなく「主張・洞察」になっている
□ キーメッセージが反映されている
□ テンプレのマスター（フォント・色）が踏襲されている

問題あり → アドインに修正指示（例: 「3枚目をもっと簡潔に」「2枚目に競合比較を追加」）
問題なし → 「Generate slides」または「OK, build the deck」と返信して本文化
```

**修正系プロンプトの例**（Sonnet 4.5 に切り替え推奨）:
- `Rewrite slide {N} to be more concise — 30 chars per bullet max`
- `Convert bullets on slide {N} to a process diagram`
- `Replace the placeholder [TBD: source] on slide {N} with: ...`
- `Add a slide between {N} and {N+1} about {topic}`

---

## B6. .pptx 保存 + フォールバックでロゴ挿入

ユーザーが PowerPoint 上で `Cmd+S` / `Ctrl+S` で保存。
その .pptx パスを指揮官に教えてもらう。

### ロゴチェック → 必要なら inject-brand.ts

Claude for PowerPoint は通常マスターのロゴを踏襲するが、以下のケースで欠落することがある:
- 一部スライドのレイアウトが「タイトルのみ」等でマスターのプレースホルダを上書き
- 自動生成された図形がロゴ領域を覆う

**対処**:
```bash
~/.claude/skills/slide/scripts/inject-brand.ts \
  --pptx {受け取ったパス} \
  --brand {ブランド名} \
  --mode logo-only \
  --dry-run    # まず差分確認
```

`--dry-run` で「ロゴ未配置スライド」が見つかった時のみ、本実行で挿入する。
既存ロゴを検出したスライドはスキップ（`brand.yaml` の position と±5%以内の場合）。

---

## B7. SVG 抽出（任意）

社外配布で SVG ベースの編集をしたい場合のみ:

```bash
~/.claude/skills/slide/scripts/pptx-to-svg.sh \
  --pptx {受け取ったパス} \
  --out ~/Documents/{資料名}/
```

LibreOffice headless で各スライドを `slide-NN.svg` として書き出し。

---

## よくある問題と対処

| 症状 | 対処 |
|---|---|
| マスターのロゴ・色が反映されない | template.pptx を**先に開いた状態**でアドインを起動したか確認。違うファイルだとマスター取得に失敗する |
| 枚数が指定 ±2 以上ずれる | プロンプトの Structure 節に `(exact slide count, do not add or remove)` が入っているか確認 |
| 数値が捏造されている | Instructions の `Number rule: never invent figures; use [TBD: source]` が入っているか確認 |
| タイトルが「概要」「機能」とラベル的 | Instructions の `Slide title rule: titles must convey insight, not labels` を追加 |
| 既存スライドが破壊された | アドインは「現在開いているデック」に書き込むので、**先にコピーを作って**から作業するのが安全 |
| 日本語と英語が混在 | プロンプトと Instructions を両方日本語で書く |
| Instructions が次の会話で消えた | Instructions は**プレゼン単位**で保存される。違うファイルを開くと別の Instructions になる |
| アドインが応答しない | サイドバーをリロード（×で閉じて再起動）/ サインアウト→サインイン |
| 機密ファイルへの貼付け | プロンプトインジェクション対策として、信頼できないテンプレ/ベンダーファイルでは使わない |

---

## 参考

- [Use Claude for PowerPoint | Help Center](https://support.claude.com/en/articles/13521390-use-claude-for-powerpoint)
- [Claude for PowerPoint product page](https://claude.com/claude-for-powerpoint)
- [Best Practices: Claude for Excel and PowerPoint](https://www.anthropic.com/webinars/best-practices-for-claude-in-excel-and-powerpoint)