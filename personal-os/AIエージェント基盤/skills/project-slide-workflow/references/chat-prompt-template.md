# チャット投入用プロンプトテンプレ

## 使う場面

ユーザーが、画像生成ツールや別AIチャットへそのまま送れるプロンプトを欲しがるときに使う。  
共通UIとページ別内容を分けて書くことで、毎回同じ見た目を再現しやすくする。

## まずAIに考えさせる依頼テンプレ

```text
以下の内容をもとに、NEXTLEVEL CAREERの参加者向けスライド資料を作りたいです。
いきなり画像生成せず、まずは内容設計をしてください。

目的:
{資料の目的}

対象者:
{誰に見せるか}

プロジェクト名:
{プロジェクト名}

伝えたいこと:
{一番伝えたいメッセージ}

提供するサポート:
- {サポート1}
- {サポート2}
- {サポート3}

避けたい表現:
- 上から目線
- 誇大広告
- 「必ず」「保証」「誰でも」
- 求職者のプライドを傷つける表現

トーン:
- やさしい
- 伴走感がある
- 本人のペースを尊重する
- 相談しながら進める

まず以下を出してください。
1. 全体コンセプト
2. 5〜6枚のスライド構成
3. 各スライドの見出し
4. 各スライドの本文
5. 各スライドのデザインイメージ
6. 誇大表現や上から目線になっていないかのチェック

まだ画像生成プロンプトは作らないでください。
```

## 内容確定後の画像生成プロンプト化テンプレ

```text
以下のスライド構成を、images gen2に送れる画像生成プロンプトにしてください。

重要:
- 1枚ずつ個別のプロンプトにする
- 共通UIルールを各ページに必ず入れる
- 日本語テキストは指定文言をそのまま使う
- 文言を勝手に増やさない
- 参加者向け資料なのでCTAボタンは不要
- 画像生成はまだしない。プロンプトだけ出す

共通UIルール:
NEXTLEVEL CAREER 白×赤ミニマル。16:9。白背景。余白多め。黒または濃いグレー本文。赤をアクセントに使用。薄いグレーの波形・線・カード背景は可。丸みのある薄いカード。線画アイコン。ロゴは表紙では大きめ、2枚目以降は控えめ。上部ヘッダーなし。濃い背景なし。派手なグラデーションなし。写真素材感の強い人物写真なし。文字は読みやすく、詰め込みすぎない。

ロゴ:
NEXTLEVEL CAREERの横長ロゴを使用。
ロゴパス:
`/Users/kitamuranaohiro/マイドライブ（nextlevel.kitamura@gmail.com）/01_ネクストレベル/素材/ネクレベ　キャリア　ロゴ/ネクストレベル　キャリア　ロゴ　横長.jpg`

スライド構成:
{確定したスライド構成を貼る}

出力形式:
## 1ページ目プロンプト
```text
...
```

## 2ページ目プロンプト
```text
...
```

以降、全ページ分。
```

## 1ページずつ生成する時のテンプレ

```text
Create slide {N} of a Japanese 16:9 presentation deck for NEXTLEVEL CAREER.

Common UI:
Use the NEXTLEVEL CAREER white and red minimal style. Clean white background, lots of whitespace, subtle light gray wave or line accents, black/dark gray Japanese text, minimal red brand accents, rounded light cards when needed, simple line icons, modern corporate recruitment/career support style, calm and supportive. No top header text, no clutter, no dark background, no stock photos, no CTA button unless explicitly requested. Include a small understated NEXTLEVEL CAREER logo near the footer; on cover slides, place the logo larger near the lower center.

Slide role:
{このページの役割}

Main heading:
「{見出し}」

Body copy:
「{本文}」

Elements:
- {カードやロードマップ要素}
- {カードやロードマップ要素}

Bottom accent copy:
「{下部コピー}」

Design notes:
{レイアウト、カード数、アイコン、ロードマップなど}
```

## 注意

- AIに「いい感じにして」とだけ渡さない。共通UI、文言、禁止事項をセットで渡す。
- 表紙以外はロゴを控えめにする。
- 参加者向け資料では「無料相談」「申し込む」などのCTAを入れない。
- 広告/LP向けに転用する時だけCTAを追加する。
- 1回で全ページ生成させるより、1枚ずつ確認して作る方が品質が安定する。

