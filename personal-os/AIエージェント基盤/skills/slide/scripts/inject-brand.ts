#!/usr/bin/env -S npx ts-node --esm
/**
 * inject-brand.ts
 * .pptx の全スライドにブランドロゴを挿入する。
 * brand.yaml の position / size_ratio / apply_to を読んで配置。
 * 既存の同位置ロゴを検出した場合はスキップ。
 *
 * Usage:
 *   inject-brand.ts --pptx path.pptx --brand ブランド名 [--mode logo-only] [--dry-run]
 */

import { execSync, spawnSync } from "child_process";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const SKILLS_DIR = path.join(os.homedir(), ".claude/skills/slide");
const BRAND_DIR = path.join(SKILLS_DIR, "資料/ブランド設定");

function parseArgs() {
  const args = process.argv.slice(2);
  const opts: Record<string, string> = { mode: "logo-only" };
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      const key = args[i].slice(2);
      opts[key] = args[i + 1] && !args[i + 1].startsWith("--") ? args[++i] : "true";
    }
  }
  return opts;
}

function readBrandYaml(brandName: string) {
  const yamlPath = path.join(BRAND_DIR, brandName, "brand.yaml");
  if (!fs.existsSync(yamlPath)) {
    console.error(`brand.yaml が見つかりません: ${yamlPath}`);
    process.exit(1);
  }
  const content = fs.readFileSync(yamlPath, "utf-8");
  // 簡易YAMLパーサー（入れ子対応）
  const result: Record<string, unknown> = {};
  let currentSection = result;
  let currentKey = "";
  for (const line of content.split("\n")) {
    const trimmed = line.trimEnd();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const indent = line.match(/^(\s*)/)?.[1].length ?? 0;
    const match = trimmed.trim().match(/^([^:]+):\s*(.*)?$/);
    if (!match) continue;
    const [, key, val] = match;
    if (indent === 0) {
      if (!val) {
        result[key] = {};
        currentSection = result[key] as Record<string, unknown>;
        currentKey = key;
      } else {
        result[key] = val;
        currentSection = result;
      }
    } else {
      if (currentSection !== result) {
        (currentSection as Record<string, string>)[key] = val ?? "";
      }
    }
  }
  return result;
}

function buildPythonScript(
  pptxPath: string,
  logoPath: string,
  position: string,
  sizeRatio: number,
  marginPct: number,
  applyTo: string,
  dryRun: boolean
): string {
  return `
import sys
import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor

PPTX_PATH = ${JSON.stringify(pptxPath)}
LOGO_PATH = ${JSON.stringify(logoPath)}
POSITION   = ${JSON.stringify(position)}
SIZE_RATIO = ${sizeRatio}
MARGIN_PCT = ${marginPct}
APPLY_TO   = ${JSON.stringify(applyTo)}
DRY_RUN    = ${dryRun ? "True" : "False"}

prs = Presentation(PPTX_PATH)
slide_width  = prs.slide_width
slide_height = prs.slide_height

logo_w = int(slide_width * SIZE_RATIO)
margin  = int(slide_width * MARGIN_PCT / 100)

if POSITION == "top-right":
    logo_left = slide_width - logo_w - margin
    logo_top  = margin
elif POSITION == "top-left":
    logo_left = margin
    logo_top  = margin
elif POSITION == "bottom-right":
    logo_left = slide_width - logo_w - margin
    logo_top  = slide_height - int(logo_w * 0.5) - margin
else:
    logo_left = slide_width - logo_w - margin
    logo_top  = margin

changed = 0
for i, slide in enumerate(prs.slides):
    if APPLY_TO == "title-only" and i > 0:
        continue
    if APPLY_TO == "content-only" and i == 0:
        continue

    # 既存ロゴ検出（同位置 ±5% に画像がある）
    threshold = int(slide_width * 0.05)
    already = False
    for shape in slide.shapes:
        if shape.shape_type == 13:  # MSO_SHAPE_TYPE.PICTURE
            if abs(shape.left - logo_left) < threshold and abs(shape.top - logo_top) < threshold:
                already = True
                break
    if already:
        print(f"  slide {i+1}: ロゴ検出済み → スキップ")
        continue

    if not DRY_RUN:
        pic = slide.shapes.add_picture(LOGO_PATH, logo_left, logo_top, width=logo_w)
    print(f"  slide {i+1}: ロゴ配置 ({'DRY RUN' if DRY_RUN else 'OK'})")
    changed += 1

if not DRY_RUN and changed > 0:
    prs.save(PPTX_PATH)
    print(f"\\n✓ {changed} スライドにロゴを配置して保存しました: {PPTX_PATH}")
elif changed == 0:
    print("\\n（変更なし）")
else:
    print(f"\\n[DRY RUN] {changed} スライドを変更予定")
`;
}

async function main() {
  const opts = parseArgs();

  if (!opts.pptx || !opts.brand) {
    console.error("Usage: inject-brand.ts --pptx path.pptx --brand ブランド名 [--mode logo-only] [--dry-run]");
    process.exit(1);
  }

  const pptxPath = path.resolve(opts.pptx.replace(/^~/, os.homedir()));
  if (!fs.existsSync(pptxPath)) {
    console.error(`PPTX が見つかりません: ${pptxPath}`);
    process.exit(1);
  }

  const brand = readBrandYaml(opts.brand);
  const logo = brand.logo as Record<string, string> | undefined;

  if (!logo?.path) {
    console.error("brand.yaml に logo.path が設定されていません");
    process.exit(1);
  }

  const logoPath = path.join(BRAND_DIR, opts.brand, logo.path);
  if (!fs.existsSync(logoPath)) {
    console.error(`ロゴファイルが見つかりません: ${logoPath}`);
    console.error("ロゴを以下に配置してください:");
    console.error(`  ${logoPath}`);
    process.exit(1);
  }

  const position  = logo.position   ?? "top-right";
  const sizeRatio = parseFloat(logo.size_ratio ?? "0.10");
  const marginPct = parseFloat(logo.margin_pct ?? "3");
  const applyTo   = logo.apply_to   ?? "all";
  const dryRun    = opts["dry-run"] === "true";

  console.log(`ブランド: ${opts.brand}`);
  console.log(`PPTX:    ${pptxPath}`);
  console.log(`ロゴ:    ${logoPath}`);
  console.log(`配置:    ${position} / size=${sizeRatio} / margin=${marginPct}%`);
  console.log(`対象:    ${applyTo}${dryRun ? " [DRY RUN]" : ""}`);
  console.log("");

  // python-pptx の存在確認
  const pipCheck = spawnSync("python3", ["-c", "import pptx"], { encoding: "utf-8" });
  if (pipCheck.status !== 0) {
    console.error("python-pptx が見つかりません。以下でインストールしてください:");
    console.error("  pip3 install python-pptx");
    process.exit(1);
  }

  const script = buildPythonScript(pptxPath, logoPath, position, sizeRatio, marginPct, applyTo, dryRun);
  const tmpScript = path.join(os.tmpdir(), `inject-brand-${Date.now()}.py`);
  fs.writeFileSync(tmpScript, script, "utf-8");

  try {
    execSync(`python3 "${tmpScript}"`, { stdio: "inherit" });
  } finally {
    fs.unlinkSync(tmpScript);
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
