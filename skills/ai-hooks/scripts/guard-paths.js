#!/usr/bin/env node
const { readEvent, aiDir, fs, path } = require("./_common");
const ev = readEvent(); const ai = aiDir(ev); if (!ai) process.exit(0);
const target = String(ev.tool_input?.file_path || ev.tool_input?.path || ev.tool_input?.notebook_path || "");
if (!target) process.exit(0);
let rules = [];
try {
  rules = fs.readFileSync(path.join(ai, "docs", "dont-touch.md"), "utf8").split("\n")
    .filter(l => l.startsWith("- `")).map(l => l.slice(3, l.indexOf("`", 3))).filter(Boolean);
} catch { process.exit(0); }
const cwd = ev.cwd || process.cwd();
const rel = path.relative(cwd, path.resolve(cwd, target)).replace(/\\/g, "/");
const hit = rules.find(r => rel === r || rel.startsWith(r.replace(/\/?$/, "/")) || rel.startsWith(r) || path.basename(rel).startsWith(r));
if (hit) {
  process.stderr.write(`Blocked by ai/docs/dont-touch.md: "${rel}" matches rule "${hit}". Choose another path or ask the developer.\n`);
  process.exit(2);
}
