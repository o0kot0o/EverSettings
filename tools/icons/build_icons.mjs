// Renders the Lucide icons listed in icons.json to white-on-transparent PNGs.
// convert_tga.py then turns them into the 32-bit TGA textures the addon loads.
//
//   cd tools/icons && npm install && node build_icons.mjs && ..\..\.venv\Scripts\python convert_tga.py
//
// Icons are white so the addon can tint them with theme colors (Texture:SetVertexColor).
import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const lucideDir = join(dirname(require.resolve("lucide-static/package.json")), "icons");
const config = JSON.parse(readFileSync(join(here, "icons.json"), "utf8"));
const outDir = join(here, "out");
mkdirSync(outDir, { recursive: true });

for (const [name, spec] of Object.entries(config.icons)) {
  const [icon, mode] = spec.split("*");
  let svg = readFileSync(join(lucideDir, `${icon}.svg`), "utf8");
  svg = svg
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/stroke="currentColor"/, 'stroke="#ffffff"')
    .replace(/stroke-width="[\d.]+"/, `stroke-width="${config.strokeWidth}"`)
    .replace(/width="24"/, `width="${config.size}"`)
    .replace(/height="24"/, `height="${config.size}"`);
  if (mode === "fill") svg = svg.replace(/fill="none"/, 'fill="#ffffff"');
  const png = await sharp(Buffer.from(svg), { density: 72 * 4 })
    .resize(config.size, config.size)
    .png()
    .toBuffer();
  writeFileSync(join(outDir, `${name}.png`), png);
  console.log(`rendered ${name} <- ${icon}${mode ? " (" + mode + ")" : ""}`);
}
