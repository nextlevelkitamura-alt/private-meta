#!/usr/bin/env -S npx tsx
/**
 * register-brand.ts — 新規ブランドを テンプレ/ブランド/ に登録する
 *
 * 使い方:
 *   npx tsx register-brand.ts \
 *     --name "{ブランド名}" \
 *     --color "#0D0F14" \
 *     --tone "{トーン}" \
 *     --logo "/path/to/logo.png" \
 *     --description "{説明}"
 *
 * --logo は省略可。後から手動でコピー可能。
 */

import * as fs from "node:fs";
import * as path from "node:path";

const BRAND_DIR = path.join(
  process.env.HOME ?? "",
  ".claude/skills/slide/テンプレ/ブランド"
);

function parseArgs(): Record<string, string> {
  const args: Record<string, string> = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    const key = process.argv[i].replace(/^--/, "");
    args[key] = process.argv[i + 1];
  }
  return args;
}

function main() {
  const args = parseArgs();
  if (!args.name || !args.color || !args.tone) {
    console.error("Usage: register-brand.ts --name {name} --color {hex} --tone {tone} [--logo {path}] [--description {desc}]");
    process.exit(1);
  }

  const targetDir = path.join(BRAND_DIR, args.name);
  if (fs.existsSync(targetDir)) {
    console.error(`Brand already exists: ${targetDir}`);
    process.exit(1);
  }
  fs.mkdirSync(targetDir, { recursive: true });

  let logoPath = "";
  if (args.logo) {
    if (!fs.existsSync(args.logo)) {
      console.error(`Logo file not found: ${args.logo}`);
      process.exit(1);
    }
    const ext = path.extname(args.logo);
    const dest = path.join(targetDir, `logo${ext}`);
    fs.copyFileSync(args.logo, dest);
    logoPath = `logo${ext}`;
    console.log(`Logo copied: ${dest}`);
  }

  const brandYaml = `name: ${args.name}
description: ${args.description ?? ""}

colors:
  primary: "${args.color}"
  accent:  "${args.color}"
  text:    "#FFFFFF"
  text_sub: "#A0A8B8"
  bg:      "${args.color}"

fonts:
  heading: "Noto Sans JP Bold"
  body:    "Noto Sans JP Light"

tone: "${args.tone}"

${logoPath ? `logo:
  path: ${logoPath}
  position: top-right
  size_ratio: 0.08
  margin_pct: 3
  apply_to: all
` : `# logo: ロゴ画像未登録。追加するときは logo.png を配置して以下を有効化:
# logo:
#   path: logo.png
#   position: top-right
#   size_ratio: 0.08
#   margin_pct: 3
#   apply_to: all
`}
visual:
  density: 標準
  diagram_text_ratio: バランス
  reference: ""
  ng: []
`;

  const yamlPath = path.join(targetDir, "brand.yaml");
  fs.writeFileSync(yamlPath, brandYaml);
  console.log(`Brand registered: ${yamlPath}`);

  // _last-used.txt も更新
  const lastUsedPath = path.join(BRAND_DIR, "_last-used.txt");
  fs.writeFileSync(lastUsedPath, args.name);
  console.log(`_last-used.txt updated: ${args.name}`);
}

main();
