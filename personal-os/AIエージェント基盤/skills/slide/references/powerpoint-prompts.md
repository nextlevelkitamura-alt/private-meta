# Claude for PowerPoint プロンプト雛形

アドインに渡すテキストを **2層** に分けて設計する。

| 層 | どこに貼る | いつ貼る | 役割 |
|---|---|---|---|
| **Instructions** | サイドバーの設定 → Instructions field | プレゼン1ファイルにつき1回 | 永続ルール（ブランド・bullet・トーン・数値ルール） |
| **本文プロンプト** | サイドバーのチャット入力 | 毎回 | スライド構成・枚数・キーメッセージ |

両者を分けることで:
- 本文を短くできる（50〜150 語に抑えやすい）
- ブランドルールが全会話で一貫する
- 修正系プロンプトでも Instructions が効き続ける

---

## 1. Instructions field 用テンプレ（永続設定）

サイドバーの **歯車・設定アイコン → Instructions** に貼る。

```
Brand: {ブランド名}
Tone: {tone keywords e.g. professional, warm, decisive}

Color usage:
- Primary {#HEX} for headings and emphasis
- Accent {#HEX} for highlights and CTAs
- Use the slide master colors; do not introduce off-brand colors

Typography:
- Heading: {font name e.g. "Noto Sans JP Bold"}
- Body: {font name e.g. "Noto Sans JP Regular"}
- Inherit fonts from the slide master if available

Bullet rule:
- One line per bullet
- Max {N} characters per bullet (default 30 for JP, 60 for EN)
- Use parallel structure (verb + object pattern)

Slide title rule:
- Titles must convey an insight or claim, not a generic label
- Bad: "Overview" / "Features" / "Background"
- Good: "Migration cuts 40% of manual review time" / "3 risks block our Q3 launch"

Number rule:
- Never invent figures
- For unknown numbers, write [TBD: source] inline
- Cite the source when a number is provided

Layout rule:
- Match the active slide master and layouts
- Do not insert decorative shapes that the master doesn't already use
- Preserve the master's logo placement; do not move or replace it

Output review rule:
- When creating multiple slides, present an outline first
- Wait for my "OK" before generating full slide content
- After body generation, list which slides need data filled in
```

### 言語別の差し替え

**日本語版**（出力を日本語にしたい場合は最後に追記）:
```
Output language: 日本語（Japanese）
- Body text and titles must be in 日本語
- Keep technical terms in カタカナ when standard
- One bullet ≤ 30 全角文字
```

---

## 2. 本文プロンプト用テンプレ（毎回送信）

### 2.1 デック全体生成 — 共通雛形

```
Create a {N}-slide {deck_type} for {audience_with_role}.

Context: {1-2 sentence background, including current state and what changed}
Goal: After viewing, the audience should {desired_action}.
Top objection to preempt: {objection}.

Structure (exact slide count, do not add or remove):
1. {role/message} — {tag: min/sm/md/lg}
2. {role/message} — {tag}
...
{N}. {role/message} — {tag}

Constraints:
- Match the active template (slide master, fonts, colors)
- For unknown numbers, write [TBD: source]
- Output as outline first; do not generate full slides until I confirm
```

`{tag}` の意味（テキスト量目安）:
- `min` — タイトル/Hook（5-15 全角字）
- `sm`  — 主張系（30-60 全角字）
- `md`  — 詳細・根拠（100-150 全角字）
- `lg`  — データ表・比較（必要に応じ）

---

### 2.2 用途別実例

#### 例A: 営業提案 BtoB SaaS（10枚・案A 課題ドリブン）

```
Create a 10-slide sales pitch for HR managers at 100-500 person companies.

Context: Manual onboarding takes 12 hours per new hire. The audience is currently
using a mix of email + Excel, and considers it "good enough."
Goal: After viewing, schedule a 30-min product demo within 2 weeks.
Top objection to preempt: "We can build this in-house with our existing tools."

Structure (exact slide count, do not add or remove):
1. Hook: "12 hours per hire — what it actually costs you" — sm
2. The hidden cost of manual onboarding — md
3. Why "good enough" gets worse at scale — md
4. We hear you: 3 reasons in-house feels safer — sm
5. Our approach: automated workflows on top of your stack — md
6. Live walkthrough: hire-to-productive in under 2 hours — md
7. Customer evidence: [TBD: source — case study figures] — lg
8. ROI calculator: [TBD: source — pricing/savings table] — lg
9. Implementation: 3 weeks, with your IT team in the loop — sm
10. Next step: book a 30-min tailored demo — sm

Constraints:
- Match the active template
- For unknown numbers, write [TBD: source]
- Output as outline first; wait for my OK before building full slides
```

---

#### 例B: 社内提案（7枚・案B ベネフィット）

```
Create a 7-slide internal proposal for the engineering leadership team (CTO + 2 VPs).

Context: Our CI pipeline takes 45 minutes per PR; team has been complaining for 6 months.
Goal: Approve a 2-week migration sprint to a parallel-test runner.
Top objection to preempt: "We don't have the bandwidth right now."

Structure (exact slide count, do not add or remove):
1. The CI bottleneck in numbers: 45 min × 80 PRs/week — sm
2. What this is costing us this quarter: [TBD: source] — md
3. Root cause: serial test execution on a single runner — sm
4. Proposed change: parallel runner + targeted retries — md
5. The 2-week plan, week-by-week — md
6. What we are NOT doing (scope guardrails) — sm
7. Decision needed today: approve or defer — sm

Constraints:
- Match the active template
- For unknown numbers, write [TBD: source]
- Output as outline first; wait for my OK
```

---

#### 例C: 投資家ピッチ（12枚・案A）

```
Create a 12-slide investor pitch for a Series A round (target: $4M).
Audience: B2B SaaS-focused VCs, partner level.

Context: We are 18 months in, $80K MRR, 30% MoM growth for the last 4 months.
Goal: Secure a follow-up partner meeting within 1 week.
Top objection to preempt: "Market looks crowded — what's your moat?"

Structure (exact slide count, do not add or remove):
1. One-line company thesis — min
2. The problem we solve, in 1 customer quote — sm
3. Why now: market shift in the last 18 months — md
4. Our product, in 1 visual — md
5. Traction: [TBD: source — MRR + growth chart] — lg
6. Customer evidence: [TBD: source — 3 logos + retention] — lg
7. Why we win: moat in 3 layers — md
8. GTM: how we get from $1M to $10M ARR — md
9. Team: 3 founders, why this team — sm
10. Use of funds across 4 buckets — md
11. The ask: $4M Series A, [TBD: source — terms] — sm
12. Vision: where this goes in 5 years — sm

Constraints:
- Match the active template (use brand color #0A2540 for headings)
- For unknown numbers, write [TBD: source]
- Output as outline first; wait for my OK
```

---

### 2.3 既存資料ベース生成（続編・改訂）

開いているデックを下敷きにする場合:

```
Look at the current deck. Build on it: keep slides {1-3, 7} as-is and replace
slides {4-6} with a new section about {topic}.

The new section must:
- Total 4 slides
- Maintain the existing master, fonts, and color palette
- Use the same bullet style as slides 1-3
- For new numbers, write [TBD: source]

Output the new section as outline first.
```

---

### 2.4 単一スライド修正（Sonnet 4.5 推奨）

サイドバーで **モデルを Sonnet 4.5 に切り替えて**から送る:

```
# 簡潔化
Rewrite slide {N}: keep the title, but reduce each bullet to ≤30 chars.
Remove any bullet that is just a sub-claim — only keep load-bearing points.
```

```
# 図解化
Convert the bullets on slide {N} into a horizontal process diagram.
Use 4 steps. Match the existing brand colors.
```

```
# データ穴埋め
On slide {N}, replace the placeholder [TBD: source] with the following data:
{paste the data}.
Do not change the title or surrounding bullets.
```

```
# 1枚追加
Add a new slide between slide {N} and slide {N+1} titled "{insert insight}".
Body: 3 bullets, ≤30 chars each, parallel structure (verb + object).
Match the active master.
```

---

## 3. プロンプト設計の指針

### やる
- スライド枚数を**正確に固定**（`exact slide count, do not add or remove`）
- 各スライドに**役割 + キーメッセージ + テキスト量タグ**を1行で書く
- 数値は `[TBD: source]` でプレースホルダ化（捏造防止）
- 「アウトラインを先に提示」を毎回入れる
- ブランドカラーが効かない時は **本文プロンプトにも HEX を明記**（Instructions だけでは弱い場合がある）

### やらない
- 曖昧な指示（「いい感じに」「プロっぽく」）
- スライド数の幅指定（「8〜10枚」→ 必ず `9-slide` のように1つに固定）
- 装飾の依頼（「アイコンも入れて」→ マスターに無いものは入れさせない）
- 機密データを Instructions に入れる（永続化されるため）

### モデル使い分け
| モデル | 用途 |
|---|---|
| **Opus 4.6** | デック全体生成・複雑な再構成・複数スライドのリライト |
| **Sonnet 4.5** | 単一スライドの修正・タイポ・1要素の差し替え（高速・低コスト） |

---

## 4. プロンプト保存ルール

`brief.yaml` の `powerpoint:` 節に Instructions 全文と本文プロンプト全文を保存。
さらに `ログ/2026-MM-{資料名}/` に以下を書き出し:

- `instructions.txt` — 永続設定（再利用可・他プレゼンに転用可能）
- `prompt.txt` — 本文プロンプト全文

次回似た資料を作る時は両ファイルを読み、`{プレースホルダ}` だけ差し替える。