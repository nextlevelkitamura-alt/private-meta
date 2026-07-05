# openai.yaml fields

`agents/openai.yaml` は、CodexのUIや実行ハーネスが読む製品固有設定。
エージェントが必ず読む手順書ではない。ほかの製品固有設定も `agents/` 配下に置ける。

## Full example

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "Optional user-facing description"
  icon_small: "./assets/small-400px.png"
  icon_large: "./assets/large-logo.svg"
  brand_color: "#3B82F6"
  default_prompt: "Use $skill-name to ..."

dependencies:
  tools:
    - type: "mcp"
      value: "github"
      description: "GitHub MCP server"
      transport: "streamable_http"
      url: "https://api.githubcopilot.com/mcp/"
```

## Field descriptions and constraints

共通制約:

- 文字列値はすべてquoteする。
- keyはquoteしない。
- `interface.default_prompt` は短く実用的な開始プロンプトにする。
- `interface.default_prompt` には対象Skillを `$skill-name` 形式で明示する。

フィールド:

- `interface.display_name`: UIのSkill一覧やchipに表示する人間向け名称。
- `interface.short_description`: 一覧で素早く判断するための短い説明。25-64文字。
- `interface.icon_small`: 小さいアイコンの相対path。通常は `./assets/` 配下。
- `interface.icon_large`: 大きいロゴの相対path。通常は `./assets/` 配下。
- `interface.brand_color`: UIアクセント用のhex color。
- `interface.default_prompt`: Skill呼び出し時に挿入する既定プロンプト。
- `dependencies.tools[].type`: 依存ツール種別。現状は `mcp` のみ。
- `dependencies.tools[].value`: ツールや依存関係の識別子。
- `dependencies.tools[].description`: 依存関係の人間向け説明。
- `dependencies.tools[].transport`: `type` が `mcp` の場合の接続方式。
- `dependencies.tools[].url`: `type` が `mcp` の場合のMCP server URL。
