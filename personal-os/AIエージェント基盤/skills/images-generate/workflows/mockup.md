# モックアップ生成

短い説明、既存UI、スクリーンショット、コードから、プロダクトに忠実な画面イメージを作る。

## 基本原則

1. 生成と編集には Codex 組み込み `image_gen` を使う。
2. リポジトリ文書、既存UI、スクリーンショット、デザイントークンを根拠にし、無関係なアプリやブランドを創作しない。
3. 画像内テキストは短い英語を基本とし、情報を詰め込みすぎない。
4. 実装済み画面のスクリーンショットと誤認させず、成果物はモックアップまたはコンセプト画像として報告する。
5. プロジェクトで使う画像はワークスペースへコピーし、最終パスを報告する。

## 曖昧ゲート

対象プロダクト、用途、見た目の方向性が推測できるなら、そのまま進める。
中核情報が2つ以上欠ける場合だけ、対象機能、現行UI寄りか将来案か、用途、比率や端末枠を最大3問でまとめて聞く。
不足が1つなら保守的に仮定して明示する。ただし広告、投資家資料、ストア画像、主要ヒーローでは曖昧さがあれば1〜2問確認する。

## 速度と品質

1. 通常は文脈から1枚の完成度が高い案を作る。
2. 複数案や重要用途を求められたら、異なる方向性を2〜3案に絞る。
3. 各案は同じプロダクトの識別要素を保ち、1案ずつ生成する。

## コンテキスト収集

1. 会話、添付画像、README、仕様、既存画面、デザイントークンから必要最小限を読む。
2. 対象機能と見た目を誤らないための根拠だけを集める。
3. 視覚検証を依頼されていない限り、情報収集だけのためにサーバーやブラウザを起動しない。

## モックアップ種別

1. `ui-screen-mockup`: 実在感のあるWeb・アプリ画面。
2. `device-product-mockup`: 端末フレームに配置した画面。
3. `lp-hero-mockup`: プロダクト中心のLPヒーロー。
4. `pitch-demo-visual`: 投資家・関係者向けの説明画像。
5. `feature-explainer`: 機能の仕組みを示す画像。
6. `social-preview`: SNS共有・告知用画像。
7. `app-store-screenshot`: 短い説明付きのストア掲載風画像。
8. `before-after-concept`: 現状と改善後を対比する画像。

## プロンプト作成

種別、対象機能、利用者、用途、忠実度を決め、必要なコンテキストを反映する。プロダクトの識別要素を守り、一般的なAIダッシュボード風の装飾や無関係なロゴを避ける。

### Prompt Schema

```text
Use case: ui-mockup
Mockup type: <ui-screen-mockup | device-product-mockup | lp-hero-mockup | pitch-demo-visual | feature-explainer | social-preview | app-store-screenshot | before-after-concept>
Asset type: <where this image will be used>
Product: <product name and one-line purpose>
Target feature/screen: <what the mockup should show>
Audience: <who should understand or be persuaded>
Fidelity: <current UI close-up | polished future concept | promotional product visual>
Style: <visual style grounded in the product>
Composition: <frame, device, viewport, crop, focal hierarchy>
UI content: <short English labels/captions, verbatim when needed>
Brand/context cues: <colors, density, icon style, design tokens, product metaphors>
Constraints: <must preserve, must avoid, no fake brand, no clutter, no unreadable dense text>
Avoid: <generic stock UI, unrelated logos, sci-fi noise, excessive gradients, illegible text, watermark>
```

## テキストの扱い

1. `Tasks`、`Running`、`Needs approval`、`Next action` など短い英語を使う。
2. 必須文言は引用して短く指定し、長文や大きな表を画像に入れない。
3. 正確な長文が必要なら、背景画像を先に生成し、コードやデザインツールで文字を合成する。

## 参照レシピ

LP、端末、ピッチ、ストア、SNS、機能説明、ビフォーアフターの形式が必要な時や、生成結果が一般的すぎる時は `references/mockup-prompt-recipes.md` を読む。
