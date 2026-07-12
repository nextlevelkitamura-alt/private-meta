#!/usr/bin/env -S npx tsx
/**
 * inject-image.ts — 生成済み画像を .pptx の指定スライドに挿入する
 *
 * /generate-images で作成された画像を、PPTスライドの指定位置に貼る後処理。
 * python-pptx に依存（システムに python3 + python-pptx 必須）。
 *
 * 使い方:
 *   npx tsx inject-image.ts \
 *     --pptx "/path/to/deck.pptx" \
 *     --slide 3 \
 *     --image "/path/to/image.png" \
 *     --position "right-half"  # right-half | left-half | full | top | bottom | center
 *
 * 複数画像を一括挿入する場合は --config json:
 *   npx tsx inject-image.ts --pptx deck.pptx --config '[{"slide":3,"image":"a.png","position":"right-half"},...]'
 */

import { execSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import * as os from "node:os";

interface InjectSpec {
  slide: number;
  image: string;
  position: "right-half" | "left-half" | "full" | "top" | "bottom" | "center";
}

const POSITION_MAP: Record<InjectSpec["position"], { left: number; top: number; width: number; height: number }> = {
  // EMU単位 (1 inch = 914400 EMU)。標準16:9 13.33"x7.5" = 12192000 x 6858000
  "right-half":  { left: 6096000, top: 0,       width: 6096000, height: 6858000 },
  "left-half":   { left: 0,       top: 0,       width: 6096000, height: 6858000 },
  "full":        { left: 0,       top: 0,       width: 12192000, height: 6858000 },
  "top":         { left: 0,       top: 0,       width: 12192000, height: 3429000 },
  "bottom":      { left: 0,       top: 3429000, width: 12192000, height: 3429000 },
  "center":      { left: 3048000, top: 1714500, width: 6096000, height: 3429000 },
};

function parseArgs(): { pptx: string; specs: InjectSpec[] } {
  const args: Record<string, string> = {};
  for (let i = 2; i < process.argv.length; i += 2) {
    args[process.argv[i].replace(/^--/, "")] = process.argv[i + 1];
  }
  if (!args.pptx) throw new Error("--pptx required");

  let specs: InjectSpec[];
  if (args.config) {
    specs = JSON.parse(args.config);
  } else {
    if (!args.slide || !args.image || !args.position) {
      throw new Error("Either --config or --slide/--image/--position required");
    }
    specs = [{
      slide: Number(args.slide),
      image: args.image,
      position: args.position as InjectSpec["position"],
    }];
  }
  return { pptx: args.pptx, specs };
}

function generatePythonScript(pptxPath: string, specs: InjectSpec[]): string {
  return `
from pptx import Presentation
from pptx.util import Emu

prs = Presentation("${pptxPath.replace(/"/g, '\\"')}")

specs = ${JSON.stringify(specs.map(s => ({ ...s, ...POSITION_MAP[s.position] })))}

for spec in specs:
    slide_idx = spec["slide"] - 1
    if slide_idx < 0 or slide_idx >= len(prs.slides):
        print(f"WARNING: slide {spec['slide']} out of range (1-{len(prs.slides)})")
        continue
    slide = prs.slides[slide_idx]
    slide.shapes.add_picture(
        spec["image"],
        Emu(spec["left"]),
        Emu(spec["top"]),
        width=Emu(spec["width"]),
        height=Emu(spec["height"]),
    )
    print(f"Inserted: slide {spec['slide']} <- {spec['image']} ({spec['position']})")

prs.save("${pptxPath.replace(/"/g, '\\"')}")
print("Saved.")
`;
}

function main() {
  const { pptx, specs } = parseArgs();
  if (!fs.existsSync(pptx)) throw new Error(`pptx not found: ${pptx}`);
  for (const s of specs) {
    if (!fs.existsSync(s.image)) throw new Error(`image not found: ${s.image}`);
    if (!POSITION_MAP[s.position]) throw new Error(`invalid position: ${s.position}`);
  }

  const tmpScript = path.join(os.tmpdir(), `inject-image-${Date.now()}.py`);
  fs.writeFileSync(tmpScript, generatePythonScript(pptx, specs));
  try {
    execSync(`python3 "${tmpScript}"`, { stdio: "inherit" });
  } finally {
    fs.unlinkSync(tmpScript);
  }
}

main();
